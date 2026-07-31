import Foundation

// In-app edits to the canonical model (D3: the author disposes; only explicit
// action mutates a document). Pure value transforms — persistence and provenance
// are the caller's job (FileProjectStore.addVersion). Line identity is preserved:
// editing text keeps the same LineID, so anchors and future staleness checks
// still resolve.

public extension Episode {
    /// Replace the text of the top-level line at the given per-cut anchor (D11:
    /// EP / Cut / Line, 1-based), returning the updated episode and the changed
    /// line's id. Returns nil if the anchor is out of range.
    func applyingText(_ text: String, at anchor: Anchor) -> (episode: Episode, changed: LineID)? {
        let cutIndex = anchor.cut - 1
        let lineIndex = anchor.line - 1
        guard cuts.indices.contains(cutIndex),
              cuts[cutIndex].lines.indices.contains(lineIndex)
        else { return nil }

        var updated = self
        updated.cuts[cutIndex].lines[lineIndex].text = text
        return (updated, cuts[cutIndex].lines[lineIndex].id)
    }
}
