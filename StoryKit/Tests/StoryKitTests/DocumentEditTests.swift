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
}
