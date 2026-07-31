import Foundation
import os

// The provider-agnostic reason stage (D8): a sibling to StubReasoner at the
// Item-4 seam. It builds a prompt from the reviewer's role prompt plus a fixed
// JSON output contract, sends it through whatever LanguageModel it is handed,
// and parses the reply into a ReviewerVerdict. It knows nothing about which
// vendor answered — swapping the model is a constructor argument.
//
// Structured output is "instructed JSON": the contract asks the model to return
// a JSON object matching our card vocabulary, and VerdictParser decodes it
// tolerantly (models often wrap JSON in prose or ``` fences). The pipeline then
// stamps card chrome around the verdict, exactly as with the stub.

public struct LLMReasoner: Reasoner {
    private let model: LanguageModel
    private let maxTokens: Int

    private static let log = Logger(subsystem: "StoryWorkspace.AI", category: "LLMReasoner")

    public init(model: LanguageModel, maxTokens: Int = 4096) {
        self.model = model
        self.maxTokens = maxTokens
    }

    public func reason(context: ReviewContext, config: ReviewerConfig) async throws -> ReviewerVerdict {
        let system = config.rolePrompt + "\n\n" + Self.jsonContract
        let userText = Self.renderContext(context, reviewer: config.reviewer)

        Self.log.info(
            "reasoning reviewer=\(config.reviewer.name, privacy: .public) anchor=\(context.address.episode, privacy: .public)/c\(context.address.cut, privacy: .public)/l\(context.address.line, privacy: .public) neighbors=\(context.before.count + context.after.count, privacy: .public)"
        )

        let response = try await model.send(
            ModelRequest(
                system: system,
                messages: [ModelMessage(role: .user, text: userText)],
                maxTokens: maxTokens
            )
        )
        return try VerdictParser.parse(response.text)
    }

    // MARK: Prompt building

    /// The output contract appended to every reviewer's role prompt. It pins the
    /// card vocabulary (D9) so the reply maps straight onto our schema.
    static let jsonContract = """
    Reply with ONLY a JSON object (no prose, no markdown fences) of the form:
    {
      "blocks": [
        { "type": "quote", "speaker": "<name or null>", "content": "<the line under review>" },
        { "type": "text", "label": "<short heading or null>", "content": "<your reasoning>" }
      ],
      "options": [
        { "kind": "alternative", "label": "<short label>", "detail": "<the rewritten line>" },
        { "kind": "keep", "label": "Keep", "detail": "<the original line>" },
        { "kind": "authorWritten", "label": "Write your own…" }
      ]
    }
    Use "kind" values from: "keep", "alternative", "authorWritten". Omit "detail"
    for an authorWritten option. Include at least one block and one option.
    """

    /// Render the retrieved slice as the user turn.
    static func renderContext(_ context: ReviewContext, reviewer: Reviewer) -> String {
        var lines: [String] = []
        lines.append("You are the \(reviewer.name) (focus: \(reviewer.focus.joined(separator: ", "))).")
        lines.append("Review this line at \(context.address.episode) / Cut \(context.address.cut) / Line \(context.address.line).")
        if let note = context.note, !note.isEmpty {
            lines.append("Author note: \(note)")
        }
        lines.append("")
        if !context.before.isEmpty {
            lines.append("Preceding lines:")
            lines.append(contentsOf: context.before.map { "  \(Self.render($0))" })
        }
        lines.append("LINE UNDER REVIEW:")
        lines.append("  \(Self.render(context.target))")
        if !context.after.isEmpty {
            lines.append("Following lines:")
            lines.append(contentsOf: context.after.map { "  \(Self.render($0))" })
        }
        if !context.priorAlternatives.isEmpty {
            lines.append("")
            lines.append("You already suggested: \(context.priorAlternatives.map { "“\($0)”" }.joined(separator: "; ")).")
            lines.append(
                "The author wants a genuinely different approach — same intention, a different path, not a reword of the above. If you have nothing better, say so honestly and endorse keeping the line as written."
            )
        }
        return lines.joined(separator: "\n")
    }

    private static func render(_ line: Line) -> String {
        if let speaker = line.speaker { return "\(speaker): \(line.text)" }
        return line.text
    }
}

/// Decodes a model reply (instructed JSON, possibly wrapped in prose or ```
/// fences) into a ReviewerVerdict. Options get their `id`s assigned here — the
/// model supplies only kind/label/detail.
enum VerdictParser {
    private static let log = Logger(subsystem: "StoryWorkspace.AI", category: "VerdictParser")

    static func parse(_ reply: String) throws -> ReviewerVerdict {
        guard let json = extractJSONObject(from: reply),
              let data = json.data(using: .utf8),
              let dto = try? JSONDecoder().decode(VerdictDTO.self, from: data)
        else {
            log.error("unparseable reply: \(reply.prefix(500), privacy: .public)")
            throw ReviewError.malformedVerdict(reply)
        }

        let options = dto.options.enumerated().map { index, option in
            CardOption(
                id: "opt-\(index)-\(option.kind.rawValue)",
                kind: option.kind,
                label: option.label,
                detail: option.detail
            )
        }
        guard !dto.blocks.isEmpty, !options.isEmpty else {
            log.error("verdict missing blocks or options: \(reply.prefix(500), privacy: .public)")
            throw ReviewError.malformedVerdict(reply)
        }

        log.info("parsed blocks=\(dto.blocks.count, privacy: .public) options=\(options.count, privacy: .public)")
        return ReviewerVerdict(blocks: dto.blocks, options: options)
    }

    /// Slice the first balanced `{ … }` object out of a reply, tolerating ```
    /// fences and surrounding prose.
    private static func extractJSONObject(from reply: String) -> String? {
        guard let start = reply.firstIndex(of: "{"),
              let end = reply.lastIndex(of: "}"),
              start < end
        else { return nil }
        return String(reply[start...end])
    }

    /// Model-facing shape: blocks reuse the card vocabulary; options carry no id
    /// (the parser assigns it).
    private struct VerdictDTO: Decodable {
        let blocks: [CardBlock]
        let options: [OptionDTO]

        struct OptionDTO: Decodable {
            let kind: CardOption.Kind
            let label: String
            let detail: String?
        }
    }
}
