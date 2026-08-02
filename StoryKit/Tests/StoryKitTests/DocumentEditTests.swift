import Testing
import Foundation
@testable import StoryKit

// Phase 3 slice (write loop): applying an accepted option's text to the canonical
// model. Editing text keeps the same LineID so anchors stay stable.

@Suite("Phase 3 — document edit")
struct DocumentEditTests {

    private func episodeEP2() throws -> Episode {
        try StoryParser.parse(Fixtures.cutScript()).episode
    }

    @Test("Applying text replaces the anchored line and keeps its id")
    func appliesText() throws {
        let episode = try episodeEP2()
        let anchor = Anchor(episode: "EP2", cut: 1, line: 1)
        let originalID = episode.cuts[0].lines[0].id

        let result = try #require(episode.applyingText("A gentler line.", at: anchor))
        #expect(result.episode.cuts[0].lines[0].text == "A gentler line.")
        #expect(result.changed == originalID)          // identity preserved
        #expect(episode.cuts[0].lines[0].text != "A gentler line.") // original untouched
    }

    @Test("An out-of-range anchor yields nil")
    func outOfRange() throws {
        let episode = try episodeEP2()
        #expect(episode.applyingText("x", at: Anchor(episode: "EP2", cut: 99, line: 1)) == nil)
        #expect(episode.applyingText("x", at: Anchor(episode: "EP2", cut: 1, line: 999)) == nil)
    }

    // MARK: Child (sub-line) addressing (D15)

    private func episodeWithChild() -> Episode {
        Episode(cuts: [
            Cut(title: "Hook", lines: [
                Line(id: LineID("p"), text: "parent text", children: [
                    Line(id: LineID("c1"), text: "child one"),
                    Line(id: LineID("c2"), text: "child two"),
                ]),
            ]),
        ])
    }

    @Test("Applying text to a child anchor edits the child, not the parent")
    func appliesChildText() throws {
        let episode = episodeWithChild()
        let anchor = Anchor(episode: "EP2", cut: 1, line: 1, child: 1)

        let result = try #require(episode.applyingText("a gentler child", at: anchor))
        #expect(result.episode.cuts[0].lines[0].children[0].text == "a gentler child")
        #expect(result.episode.cuts[0].lines[0].text == "parent text")    // parent untouched
        #expect(result.changed == LineID("c1"))                            // the child's id
    }

    @Test("A child anchor out of range yields nil")
    func childOutOfRange() throws {
        let episode = episodeWithChild()
        #expect(episode.applyingText("x", at: Anchor(episode: "EP2", cut: 1, line: 1, child: 9)) == nil)
    }

    // MARK: Replacement formatting (mirror the line's speaker/quotes)

    @Test("A replacement mirrors a quoted dialogue line's quotes and drops a stray speaker")
    func formatsQuotedDialogue() {
        let line = Line(id: LineID("l"), text: "“Order up, you trash-can!”", speaker: "Andie")
        #expect(line.formattedReplacement("Order up, tin can.") == "“Order up, tin can.”")
        #expect(line.formattedReplacement("Andie: Order up, tin can.") == "“Order up, tin can.”")
        #expect(line.formattedReplacement("“Order up, tin can.”") == "“Order up, tin can.”") // idempotent
    }

    @Test("A replacement leaves an unquoted narration line unquoted")
    func formatsNarration() {
        let line = Line(id: LineID("l"), text: "Andie thinks briefly.")
        #expect(line.formattedReplacement("Andie considers the diver.") == "Andie considers the diver.")
    }

    @Test("A rewrite of a line with an embedded lead-in keeps the lead-in")
    func preservesEmbeddedLeadIn() {
        // Multi-word attribution isn't parsed into `speaker`, so it lives in text.
        let line = Line(id: LineID("l"), text: "Andie shouts: “Order up, TRASH CAN!”")
        // Dialogue-only rewrite → the lead-in is re-attached.
        #expect(line.formattedReplacement("“Order up, tin can.”") == "Andie shouts: “Order up, tin can.”")
        // Rewrite that already includes the lead-in → no duplication.
        #expect(line.formattedReplacement("Andie shouts: “Order up, tin can.”") == "Andie shouts: “Order up, tin can.”")
    }

    @Test("line(at:) resolves parent and child anchors")
    func lineAtResolves() throws {
        let episode = episodeWithChild()
        #expect(episode.line(at: Anchor(episode: "EP2", cut: 1, line: 1))?.text == "parent text")
        #expect(episode.line(at: Anchor(episode: "EP2", cut: 1, line: 1, child: 2))?.text == "child two")
        #expect(episode.line(at: Anchor(episode: "EP2", cut: 1, line: 1, child: 9)) == nil)
    }
}
