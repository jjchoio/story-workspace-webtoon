import Foundation

// In-app edits to the canonical model (D3: the author disposes; only explicit
// action mutates a document). Pure value transforms — persistence and provenance
// are the caller's job (FileProjectStore.addVersion). Line identity is preserved:
// editing text keeps the same LineID, so anchors and future staleness checks
// still resolve.

public extension Episode {
    /// Replace the text of the line at the given per-cut anchor (D11/D15:
    /// EP / Cut / Line [ / Child ], 1-based), returning the updated episode and
    /// the changed line's id. Returns nil if the anchor is out of range.
    func applyingText(_ text: String, at anchor: Anchor) -> (episode: Episode, changed: LineID)? {
        let cutIndex = anchor.cut - 1
        let lineIndex = anchor.line - 1
        guard cuts.indices.contains(cutIndex),
              cuts[cutIndex].lines.indices.contains(lineIndex)
        else { return nil }

        var updated = self
        if let child = anchor.child {
            let childIndex = child - 1
            guard updated.cuts[cutIndex].lines[lineIndex].children.indices.contains(childIndex)
            else { return nil }
            updated.cuts[cutIndex].lines[lineIndex].children[childIndex].text = text
            return (updated, updated.cuts[cutIndex].lines[lineIndex].children[childIndex].id)
        }
        updated.cuts[cutIndex].lines[lineIndex].text = text
        return (updated, updated.cuts[cutIndex].lines[lineIndex].id)
    }

    /// The line addressed by an anchor (top-level or child), or nil if out of
    /// range. Used to capture a line's current text before an edit (for revert)
    /// or to format a replacement against the target line ([[Line.formattedReplacement]]).
    func line(at anchor: Anchor) -> Line? {
        let cutIndex = anchor.cut - 1
        let lineIndex = anchor.line - 1
        guard cuts.indices.contains(cutIndex),
              cuts[cutIndex].lines.indices.contains(lineIndex)
        else { return nil }
        let parent = cuts[cutIndex].lines[lineIndex]
        guard let child = anchor.child else { return parent }
        let childIndex = child - 1
        guard parent.children.indices.contains(childIndex) else { return nil }
        return parent.children[childIndex]
    }
}

public extension Line {
    /// Normalize a proposed replacement to THIS line's format: strip a leading
    /// "<speaker>:" prefix (the model sometimes adds it, but the speaker is a
    /// separate field) and mirror this line's surrounding quotes — if this line's
    /// text is wrapped in quotes (dialogue is authored `Speaker: "text"`) and the
    /// replacement is not, wrap it in the same pair. Idempotent: applying it to
    /// already-normalized text is a no-op.
    func formattedReplacement(_ replacement: String) -> String {
        var t = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        if let speaker, !speaker.isEmpty {
            let prefix = "\(speaker):"
            if t.lowercased().hasPrefix(prefix.lowercased()) {
                t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        if let pair = Line.surroundingQuotePair(text), Line.surroundingQuotePair(t) == nil {
            t = "\(pair.0)\(t)\(pair.1)"
        }
        // Preserve an embedded lead-in (attribution/stage direction) when the
        // line has NO parsed speaker field — e.g. `Andie shouts: "…"`. If the
        // rewrite dropped that lead-in and is just the quoted dialogue, re-attach
        // the original lead-in so accepting doesn't wipe "Andie shouts:".
        if speaker == nil,
           let leadRange = text.range(of: #"^.+?:\s+(?=["“])"#, options: .regularExpression) {
            let lead = String(text[leadRange])
            let startsWithQuote = t.first.map { "\"“".contains($0) } ?? false
            if startsWithQuote, !t.hasPrefix(lead) {
                t = lead + t
            }
        }
        return t
    }

    private static let quotePairs: [(Character, Character)] = [
        ("\"", "\""), ("“", "”"), ("'", "'"), ("‘", "’"),
    ]

    /// The recognized open/close quote pair wrapping a string, or nil.
    private static func surroundingQuotePair(_ s: String) -> (Character, Character)? {
        guard s.count >= 2, let first = s.first, let last = s.last else { return nil }
        return quotePairs.first { $0.0 == first && $0.1 == last }
    }
}
