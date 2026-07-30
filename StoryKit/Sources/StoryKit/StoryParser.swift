import Foundation

// Phase 1.1 parser. Tolerant on input (both conventions, both size-code
// delimiter forms, sloppy whitespace, garbled deep-nest numbering), opinionated
// on output (export always emits the Cut convention with (S)/(M)/(L) codes).

/// Which authored convention a source script used. Detected, not required —
/// downstream code never branches on it.
public enum ScriptConvention: Sendable, Equatable {
    /// Legacy: `Scroll Block N` headers, episode-continuous line numbering.
    case legacyScrollBlock
    /// Updated: `Cut N` headers, per-cut line numbering.
    case cut
}

/// A non-fatal note surfaced during import. Numbering is a checksum, not
/// identity (D11): gaps and residue warn, they do not fail the parse.
public struct ParseWarning: Equatable, Sendable {
    public var message: String
    public init(message: String) { self.message = message }
}

/// Result of parsing a script: the canonical tree plus import metadata.
public struct ParseResult: Equatable, Sendable {
    public var episode: Episode
    public var detectedConvention: ScriptConvention
    public var warnings: [ParseWarning]

    public init(
        episode: Episode,
        detectedConvention: ScriptConvention,
        warnings: [ParseWarning]
    ) {
        self.episode = episode
        self.detectedConvention = detectedConvention
        self.warnings = warnings
    }
}

public enum StoryParser {

    // MARK: Parse

    public static func parse(_ source: String) throws -> ParseResult {
        let rawLines = source.components(separatedBy: "\n")
        let trimmed = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }

        let isLegacy = trimmed.contains {
            $0.range(of: #"^Scroll Block\s+\d+\s*:"#, options: .regularExpression) != nil
        }
        let convention: ScriptConvention = isLegacy ? .legacyScrollBlock : .cut

        // GOAL header metadata: the first non-empty line after a "GOAL" line.
        var goal: String?
        if let gi = trimmed.firstIndex(of: "GOAL") {
            var j = gi + 1
            while j < trimmed.count && trimmed[j].isEmpty { j += 1 }
            if j < trimmed.count { goal = trimmed[j] }
        }

        var warnings: [ParseWarning] = []
        var cuts: [Cut] = []

        // Accumulators for the cut currently being built.
        var title: String?
        var desc: [String] = []
        var lines: [Line] = []
        var started = false
        var expected = 1 // next authored top-level number we expect

        func flushCut() {
            guard let t = title else { return }
            cuts.append(Cut(
                title: t,
                description: desc.isEmpty ? nil : desc.joined(separator: " "),
                lines: lines
            ))
            title = nil; desc = []; lines = []
        }

        for line in trimmed {
            if line.isEmpty { continue }

            // Cut header?
            if let hm = line.range(
                of: #"^(Scroll Block|Cut)\s+\d+\s*:\s*"#, options: .regularExpression
            ) {
                flushCut()
                started = true
                title = String(line[hm.upperBound...]).trimmingCharacters(in: .whitespaces)
                if convention == .cut { expected = 1 } // per-cut numbering restarts
                continue
            }

            if !started { continue } // episode title / GOAL region

            let token = leadingNumberToken(line)
            if token.isEmpty {
                // Unnumbered top-of-cut prose → cut description.
                var d = line
                if let r = d.range(of: #"^Scene description:\s*"#, options: .regularExpression) {
                    d = String(d[r.upperBound...])
                }
                desc.append(d.trimmingCharacters(in: .whitespaces))
                continue
            }

            let rest = String(line.dropFirst(token.count)).trimmingCharacters(in: .whitespaces)

            if isTopLevelToken(token) {
                let n = Int(token.dropLast()) ?? expected
                if n != expected {
                    warnings.append(ParseWarning(
                        message: "numbering gap: expected \(expected), found \(n)"
                    ))
                }
                expected = n + 1
                let (size, speaker, text) = parseContent(rest, &warnings)
                let id = LineID("c\(cuts.count).l\(lines.count)")
                lines.append(Line(id: id, text: text, size: size, speaker: speaker))
            } else {
                // Sub-beat: flatten (any depth) into the current top-level line.
                let (size, speaker, text) = parseContent(rest, &warnings)
                guard !lines.isEmpty else { continue }
                let li = lines.count - 1
                let kid = LineID("c\(cuts.count).l\(li).\(lines[li].children.count)")
                lines[li].children.append(Line(id: kid, text: text, size: size, speaker: speaker))
            }
        }
        flushCut()

        return ParseResult(
            episode: Episode(goal: goal, cuts: cuts),
            detectedConvention: convention,
            warnings: warnings
        )
    }

    // MARK: Export (opinionated: always the Cut convention)

    public static func export(_ episode: Episode) throws -> String {
        var out: [String] = ["Episode"]
        if let goal = episode.goal {
            out.append("")
            out.append("GOAL")
            out.append(goal)
        }
        for (i, cut) in episode.cuts.enumerated() {
            out.append("")
            out.append("Cut \(i + 1): \(cut.title)")
            out.append("")
            if let d = cut.description {
                out.append("Scene description: \(d)")
            }
            for (j, line) in cut.lines.enumerated() {
                out.append(format(marker: "\(j + 1).", line: line))
                for (k, child) in line.children.enumerated() {
                    out.append("    " + format(marker: "\(j + 1).\(k + 1)", line: child))
                }
            }
        }
        return out.joined(separator: "\n") + "\n"
    }

    private static func format(marker: String, line: Line) -> String {
        var s = "\(marker) "
        if let size = line.size { s += "(\(size.rawValue)) " }
        if let speaker = line.speaker { s += "\(speaker): " }
        s += line.text
        return s
    }

    // MARK: Line-content parsing

    /// Splits a line body (number already removed) into its size code, speaker,
    /// and clean text, appending any warnings.
    private static func parseContent(
        _ raw: String, _ warnings: inout [ParseWarning]
    ) -> (SizeCode?, String?, String) {
        var s = raw.trimmingCharacters(in: .whitespaces)

        // Delimited size code: (S)/(M)/(L) or <S>/<M>/<L>, case-exact.
        var size: SizeCode?
        if let m = s.range(of: #"^\([SML]\)\s*"#, options: .regularExpression)
            ?? s.range(of: #"^<[SML]>\s*"#, options: .regularExpression) {
            if let letter = String(s[m]).first(where: { "SML".contains($0) }) {
                size = SizeCode(rawValue: String(letter))
            }
            s = String(s[m.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if s.range(of: #"^[SML][A-Z]"#, options: .regularExpression) != nil,
                  !startsWithSpeaker(s) {
            // Bare glued marker (legacy corruption): never parsed, only flagged.
            warnings.append(ParseWarning(
                message: "possible lost size marker: “\(String(s.prefix(16)))”"
            ))
        }

        // Stray bracket residue left by a dirty export (e.g. "()", "([)").
        if s.range(of: #"\([\s\[\]]*\)"#, options: .regularExpression) != nil {
            warnings.append(ParseWarning(
                message: "stray markup residue: “\(String(s.prefix(24)))”"
            ))
        }

        // Speaker/caption label: a leading "Name:" (optionally "Name (mod):").
        var speaker: String?
        if let m = s.range(
            of: #"^[A-Za-z]+(\s*\([^)]*\))?\s*:\s+"#, options: .regularExpression
        ) {
            let head = String(s[m])
            if let colon = head.firstIndex(of: ":") {
                speaker = String(head[..<colon]).trimmingCharacters(in: .whitespaces)
            }
            s = String(s[m.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        return (size, speaker, s)
    }

    private static func startsWithSpeaker(_ s: String) -> Bool {
        s.range(of: #"^[A-Za-z]+(\s*\([^)]*\))?\s*:\s+"#, options: .regularExpression) != nil
    }

    // MARK: Number-token helpers

    /// The leading run of digits and dots (e.g. "12.", "13.4", "15.15.1.1").
    private static func leadingNumberToken(_ s: String) -> String {
        String(s.prefix(while: { $0.isNumber || $0 == "." }))
    }

    /// True for a top-level marker: digits followed by exactly one trailing dot.
    private static func isTopLevelToken(_ token: String) -> Bool {
        token.range(of: #"^\d+\.$"#, options: .regularExpression) != nil
    }
}
