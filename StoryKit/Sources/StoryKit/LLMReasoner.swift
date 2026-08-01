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
        var system = config.rolePrompt
        if let northStar = context.northStar, !northStar.isEmpty {
            system += "\n\n" + Self.northStarBlock(northStar)
        }
        system += "\n\n" + Self.jsonContract
        let userText = Self.renderContext(context, reviewer: config.reviewer)

        Self.log.info(
            "reasoning reviewer=\(config.reviewer.name, privacy: .public) anchor=\(context.address.episode, privacy: .public)/c\(context.address.cut, privacy: .public)/l\(context.address.line, privacy: .public) cuts=\(context.episode.cuts.count, privacy: .public) northStar=\(context.northStar != nil, privacy: .public)"
        )

        let response = try await model.send(
            ModelRequest(
                system: system,
                messages: [ModelMessage(role: .user, text: userText)],
                maxTokens: maxTokens
            )
        )
        let verdict = try VerdictParser.parse(response.text)
        // Rebuild any quote block straight from the reviewed line so the card
        // shows exactly that line — the model sometimes duplicates the speaker
        // into the quote content ("Andie: Andie shouts: …").
        let blocks = verdict.blocks.map { block -> CardBlock in
            if case .quote = block {
                return .quote(speaker: context.target.speaker, content: context.target.text)
            }
            return block
        }
        // Normalize each option's detail against the reviewed line's format
        // (drop a stray speaker prefix, mirror its quoting) so the card shows —
        // and Accept applies — a line that matches the original convention.
        let options = verdict.options.map { option -> CardOption in
            guard let detail = option.detail else { return option }
            return CardOption(
                id: option.id, kind: option.kind, label: option.label,
                detail: context.target.formattedReplacement(detail)
            )
        }
        return ReviewerVerdict(blocks: blocks, options: options)
    }

    // MARK: Prompt building

    /// Wrap the project's North Star as durable project grounding in the system
    /// prompt. It sits between the reviewer's identity and the output contract:
    /// stable across calls (conceptually separate from the episode in the user
    /// turn), shared by every reviewer, weighed by each on its own terms.
    static func northStarBlock(_ text: String) -> String {
        """
        PROJECT CONTEXT — North Star
        The story's guiding essence: its arc, characters, and theme. Weigh the \
        line under review against it — judge whether the dialogue serves these \
        truths — but review only the line you are asked about.

        \(text)
        """
    }

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
        { "kind": "alternative", "label": "<short label>", "detail": "<the rewritten line TEXT only>" },
        { "kind": "keep", "label": "Keep", "detail": "<the original line text, verbatim>" },
        { "kind": "authorWritten", "label": "Write your own…" }
      ]
    }
    Use "kind" values from: "keep", "alternative", "authorWritten". Omit "detail"
    for an authorWritten option. Include at least one block and one option.
    A "detail" is the line's TEXT ONLY — never prefix it with the speaker name or
    label (the speaker is carried separately); keep the original's punctuation.
    Likewise a quote block's "content" is the line's text only, with the speaker
    in the "speaker" field.
    """

    /// Render the whole episode as the user turn, with the single target line
    /// marked. The reviewer reads the full episode for context but changes only
    /// the marked line.
    static func renderContext(_ context: ReviewContext, reviewer: Reviewer) -> String {
        var lines: [String] = []
        lines.append("You are the \(reviewer.name) (focus: \(reviewer.focus.joined(separator: ", "))).")
        let lineLabel = "\(context.address.line)\(context.address.child.map { ".\($0)" } ?? "")"
        lines.append(
            "Review ONLY the single line marked » (LINE UNDER REVIEW), at \(context.address.episode) / Cut \(context.address.cut) / Line \(lineLabel). The full episode below is context so you understand the moment — do not review any other line."
        )
        if let note = context.note, !note.isEmpty {
            lines.append("Author note: \(note)")
        }
        lines.append("")
        lines.append("FULL EPISODE (for context):")
        if let goal = context.episode.goal {
            lines.append("Goal: \(goal)")
        }
        lines.append(contentsOf: Self.renderEpisode(context.episode, target: context.address))
        if !context.priorAlternatives.isEmpty {
            lines.append("")
            lines.append("You already suggested: \(context.priorAlternatives.map { "“\($0)”" }.joined(separator: "; ")).")
            lines.append(
                "The author wants a genuinely different approach — same intention, a different path, not a reword of the above. If you have nothing better, say so honestly and endorse keeping the line as written."
            )
        }
        return lines.joined(separator: "\n")
    }

    /// The episode cut-by-cut with per-cut/line numbering; the target line is
    /// prefixed with `»` so the model can locate it unambiguously.
    private static func renderEpisode(_ episode: Episode, target: Anchor) -> [String] {
        var out: [String] = []
        for (ci, cut) in episode.cuts.enumerated() {
            let cutNo = ci + 1
            out.append("")
            out.append("Cut \(cutNo): \(cut.title)")
            if let description = cut.description { out.append("  (\(description))") }
            for (li, line) in cut.lines.enumerated() {
                let lineNo = li + 1
                let parentMark = (cutNo == target.cut && lineNo == target.line && target.child == nil) ? "»" : " "
                out.append("\(parentMark) \(cutNo).\(lineNo)  \(Self.render(line))")
                for (ci, child) in line.children.enumerated() {
                    let childNo = ci + 1
                    let childMark = (cutNo == target.cut && lineNo == target.line && target.child == childNo) ? "»" : " "
                    out.append("\(childMark)     \(cutNo).\(lineNo).\(childNo)  \(Self.render(child))")
                }
            }
        }
        return out
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
