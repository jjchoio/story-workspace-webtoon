import Foundation
import os

// The provider-agnostic reason stage (D8). It builds ONE prompt from the
// reviewer's role prompt + North Star + a JSON contract, sends it through
// whatever LanguageModel it is handed, and parses an ARRAY of verdicts — one per
// selected line. It knows nothing about which vendor answered.
//
// SCALE — batching (why now, how it evolves):
//  • The episode + North Star are the expensive context; we send them ONCE and
//    mark every selected line, so N lines cost ~1× context instead of N×.
//  • Each marked line gets a stable id ("cut.line[.child]"); the model echoes it
//    on each returned card, and we map cards → lines by that id (order- and
//    count-independent). That is the seam that lets a future reviewer return
//    cards only for the lines IT decides need attention (D17) with no plumbing
//    change — only the instruction "one card per marked line" relaxes.
//  • Streaming is deferred; for now we log an approximate input-token count and
//    warn when a selection gets large, so cost/latency stays visible.

public struct LLMReasoner: Reasoner {
    private let model: LanguageModel
    private let maxTokens: Int

    private static let log = Logger(subsystem: "StoryWorkspace.AI", category: "LLMReasoner")

    public init(model: LanguageModel, maxTokens: Int = 8192) {
        self.model = model
        self.maxTokens = maxTokens
    }

    public func reason(
        context: ReviewContext, config: ReviewerConfig
    ) async throws -> [Anchor: ReviewerVerdict] {
        var system = config.rolePrompt
        if let northStar = context.northStar, !northStar.isEmpty {
            system += "\n\n" + Self.northStarBlock(northStar)
        }
        system += "\n\n" + Self.jsonContract

        // Stable id per target ("cut.line[.child]"), echoed by the model.
        let idToTarget = Dictionary(
            context.targets.map { (Self.targetID($0.address), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let userText = Self.renderContext(context, reviewer: config.reviewer, targetIDs: Set(idToTarget.keys))

        // SCALE: keep cost/latency visible until we add streaming + real usage.
        let approxInputTokens = (system.count + userText.count) / 4
        let effectiveMax = Self.maxTokens(targetCount: context.targets.count, cap: maxTokens)
        Self.log.info(
            "batch reason reviewer=\(config.reviewer.name, privacy: .public) targets=\(context.targets.count, privacy: .public) ~inputTokens=\(approxInputTokens, privacy: .public) maxTokens=\(effectiveMax, privacy: .public)"
        )
        print("[Review] ~\(approxInputTokens) input tokens · \(context.targets.count) target(s) · maxTokens=\(effectiveMax)")
        if approxInputTokens > Self.tokenWarn || context.targets.count > Self.targetWarn {
            let msg = "⚠️ [Review] large prompt: ~\(approxInputTokens) tokens for \(context.targets.count) target(s) — consider narrowing the selection"
            Self.log.warning("\(msg, privacy: .public)")
            print(msg)
        }

        let response = try await model.send(
            ModelRequest(
                system: system,
                messages: [ModelMessage(role: .user, text: userText)],
                maxTokens: effectiveMax
            )
        )

        // Parse the array; map each card back to its line by echoed id, and
        // normalize its content against that line. SCALE: partial-safe — unknown
        // ids and malformed cards are skipped, never failing the good ones.
        let cards = try VerdictParser.parseBatch(response.text)
        var result: [Anchor: ReviewerVerdict] = [:]
        for card in cards {
            guard let target = idToTarget[card.target] else {
                Self.log.error("card for unknown target id=\(card.target, privacy: .public) — skipped")
                continue
            }
            if result[target.address] != nil { continue } // first card per line wins
            result[target.address] = Self.normalize(card.verdict, for: target.line)
        }
        Self.log.info("batch parsed cards=\(cards.count, privacy: .public) matched=\(result.count, privacy: .public)")
        return result
    }

    // MARK: Budgeting

    /// One card per line plus the shared context. SCALE: scale output room with
    /// the line count, capped so a huge selection can't run away.
    static func maxTokens(targetCount: Int, cap: Int) -> Int {
        min(cap, max(3000, targetCount * 1400))
    }

    private static let tokenWarn = 12_000
    private static let targetWarn = 12

    static func targetID(_ a: Anchor) -> String {
        a.child.map { "\(a.cut).\(a.line).\($0)" } ?? "\(a.cut).\(a.line)"
    }

    /// Rebuild a verdict's quote block from the reviewed line and format its
    /// option details to that line's convention (speaker/quotes) — the model's
    /// copy is unreliable. Kept identical to the single-line path, per target.
    static func normalize(_ verdict: ReviewerVerdict, for line: Line) -> ReviewerVerdict {
        let blocks = verdict.blocks.map { block -> CardBlock in
            if case .quote = block { return .quote(speaker: line.speaker, content: line.text) }
            return block
        }
        let options = verdict.options.map { option -> CardOption in
            guard let detail = option.detail else { return option }
            return CardOption(id: option.id, kind: option.kind, label: option.label,
                              detail: line.formattedReplacement(detail))
        }
        return ReviewerVerdict(blocks: blocks, options: options)
    }

    // MARK: Prompt building

    static func northStarBlock(_ text: String) -> String {
        """
        PROJECT CONTEXT — North Star
        The story's guiding essence: its arc, characters, and theme. Weigh the \
        lines under review against it — judge whether the dialogue serves these \
        truths — but review only the lines you are asked about.

        \(text)
        """
    }

    /// The output contract. SCALE: it currently demands ONE card per marked line;
    /// the next phase relaxes this to "cards only for lines that need attention"
    /// — same `cards[]`/`target` shape, so the parser/pipeline don't change.
    static let jsonContract = """
    Reply with ONLY a JSON object (no prose, no markdown fences) of the form:
    {
      "cards": [
        {
          "target": "<the id in brackets next to the » line, e.g. 4.1>",
          "blocks": [
            { "type": "quote", "speaker": "<name or null>", "content": "<the line text>" },
            { "type": "text", "label": "<short heading or null>", "content": "<your reasoning>" }
          ],
          "options": [
            { "kind": "alternative", "label": "<short label>", "detail": "<rewritten line TEXT only>" },
            { "kind": "alternative", "label": "<short label>", "detail": "<a DIFFERENT rewritten line>" },
            { "kind": "keep", "label": "Keep", "detail": "<original line text, verbatim>" },
            { "kind": "authorWritten", "label": "Write your own…" }
          ]
        }
      ]
    }
    Return EXACTLY ONE card per line marked » — no more, no fewer — and set each
    card's "target" to that line's bracketed id. Give each card FOUR options in
    this order: TWO distinct "alternative" rewrites, then one "keep", then one
    "authorWritten" (omit its "detail"). A "detail"/quote "content" is the line's
    TEXT ONLY — never prefix the speaker name (it is carried separately); keep the
    original's punctuation.
    """

    /// Render the whole episode as the user turn, with every target line marked
    /// `»[id]`. The reviewer reads the full episode for context but reviews only
    /// the marked lines.
    static func renderContext(
        _ context: ReviewContext, reviewer: Reviewer, targetIDs: Set<String>
    ) -> String {
        var lines: [String] = []
        lines.append("You are the \(reviewer.name) (focus: \(reviewer.focus.joined(separator: ", "))).")
        let labels = context.targets.map(\.address)
            .sorted(by: ReviewPipeline.inDocumentOrder)
            .map { "\(Self.targetID($0))" }
            .joined(separator: ", ")
        lines.append(
            "Review each line marked » (LINE UNDER REVIEW): \(labels). Return one card per marked line. The full episode below is context so you understand the moment — do not review any unmarked line."
        )
        if let note = context.note, !note.isEmpty {
            lines.append("Author note: \(note)")
        }
        lines.append("")
        lines.append("FULL EPISODE (for context):")
        if let goal = context.episode.goal {
            lines.append("Goal: \(goal)")
        }
        lines.append(contentsOf: Self.renderEpisode(context.episode, targetIDs: targetIDs))
        if !context.priorAlternatives.isEmpty {
            lines.append("")
            lines.append("You already suggested: \(context.priorAlternatives.map { "“\($0)”" }.joined(separator: "; ")).")
            lines.append(
                "The author wants a genuinely different approach — same intention, a different path, not a reword of the above. If you have nothing better, say so honestly and endorse keeping the line as written."
            )
        }
        return lines.joined(separator: "\n")
    }

    /// The episode cut-by-cut with per-cut/line numbering; each target line is
    /// prefixed with `»[id]` so the model can locate it and echo the id back.
    private static func renderEpisode(_ episode: Episode, targetIDs: Set<String>) -> [String] {
        var out: [String] = []
        for (ci, cut) in episode.cuts.enumerated() {
            let cutNo = ci + 1
            out.append("")
            out.append("Cut \(cutNo): \(cut.title)")
            if let description = cut.description { out.append("  (\(description))") }
            for (li, line) in cut.lines.enumerated() {
                let lineNo = li + 1
                let id = "\(cutNo).\(lineNo)"
                out.append("\(mark(id, in: targetIDs)) \(id)  \(Self.render(line))")
                for (ki, child) in line.children.enumerated() {
                    let childID = "\(cutNo).\(lineNo).\(ki + 1)"
                    out.append("\(mark(childID, in: targetIDs))     \(childID)  \(Self.render(child))")
                }
            }
        }
        return out
    }

    private static func mark(_ id: String, in targetIDs: Set<String>) -> String {
        targetIDs.contains(id) ? "»[\(id)]" : "  "
    }

    private static func render(_ line: Line) -> String {
        if let speaker = line.speaker { return "\(speaker): \(line.text)" }
        return line.text
    }
}

/// Decodes a model reply (instructed JSON, possibly wrapped in prose/fences)
/// into a batch of verdicts. Each card carries the target id the model echoed;
/// malformed cards are skipped so one bad card can't sink the deck.
enum VerdictParser {
    private static let log = Logger(subsystem: "StoryWorkspace.AI", category: "VerdictParser")

    struct ParsedCard { let target: String; let verdict: ReviewerVerdict }

    /// Parse `{ "cards": [ … ] }` into per-line verdicts, tolerantly. Rather than
    /// one strict decode (where a single junk block or a truncated tail sinks the
    /// whole deck), we scan out each COMPLETE card object and decode each one
    /// leniently — skipping malformed blocks/options and any cut-off final card.
    /// Throws only when nothing at all could be salvaged.
    static func parseBatch(_ reply: String) throws -> [ParsedCard] {
        let objects = cardObjectStrings(in: reply)
        let cards = objects.compactMap(decodeCard)
        guard !cards.isEmpty else {
            log.error("no salvageable cards (objects=\(objects.count, privacy: .public)): \(reply.prefix(500), privacy: .public)")
            throw ReviewError.malformedVerdict(reply)
        }
        if cards.count < objects.count {
            log.error("salvaged \(cards.count, privacy: .public)/\(objects.count, privacy: .public) cards — dropped malformed ones")
        }
        return cards
    }

    /// Scan the `"cards"` array and return each top-level `{ … }` object as a
    /// string, respecting strings/escapes and tolerating a truncated final
    /// object (which never closes and is simply omitted).
    private static func cardObjectStrings(in reply: String) -> [String] {
        guard let cardsKey = reply.range(of: "\"cards\""),
              let arrayStart = reply[cardsKey.upperBound...].firstIndex(of: "[")
        else { return [] }

        var objects: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        var escaped = false

        var i = reply.index(after: arrayStart)
        while i < reply.endIndex {
            let ch = reply[i]
            if depth > 0 { current.append(ch) }

            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else if ch == "\"" {
                inString = true
            } else if ch == "{" {
                if depth == 0 { current = "{" }
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 { objects.append(current) }
            } else if ch == "]", depth == 0 {
                break // end of the cards array
            }
            i = reply.index(after: i)
        }
        return objects
    }

    /// Decode one card object; nil if it lacks a target or has no usable block or
    /// option after dropping malformed elements.
    private static func decodeCard(_ object: String) -> ParsedCard? {
        guard let data = object.data(using: .utf8),
              let dto = try? JSONDecoder().decode(CardDTO.self, from: data),
              let target = dto.target
        else { return nil }

        let blocks = dto.blocks.compactMap(\.value)
        let optionDTOs = dto.options.compactMap(\.value)
        guard !blocks.isEmpty, !optionDTOs.isEmpty else { return nil }

        let options = optionDTOs.enumerated().map { index, option in
            CardOption(
                id: "opt-\(target)-\(index)-\(option.kind.rawValue)",
                kind: option.kind, label: option.label, detail: option.detail
            )
        }
        return ParsedCard(target: target, verdict: ReviewerVerdict(blocks: blocks, options: options))
    }

    /// Wraps a decodable so a malformed array element decodes to nil (and is
    /// filtered) instead of failing the whole array.
    private struct Lenient<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    private struct CardDTO: Decodable {
        let target: String?
        let blocks: [Lenient<CardBlock>]
        let options: [Lenient<OptionDTO>]
    }
    private struct OptionDTO: Decodable {
        let kind: CardOption.Kind
        let label: String
        let detail: String?
    }
}
