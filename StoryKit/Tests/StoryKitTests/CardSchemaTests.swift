import Testing
import Foundation
@testable import StoryKit

// Phase 2 card-schema acceptance tests (PLANNING.md Phase 2, step 5; D9).
// The hand-authored sample card (the Dialogue reviewer card) must decode into
// the schema types and round-trip back through JSON unchanged.

@Suite("Phase 2 — card schema")
struct CardSchemaTests {

    private func decodeSample() throws -> Card {
        try JSONDecoder().decode(Card.self, from: Fixtures.sampleCardData())
    }

    @Test("Header decodes: reviewer, focus, anchor, version, status")
    func decodesHeader() throws {
        let card = try decodeSample()
        #expect(card.reviewer.name == "Dialogue reviewer")
        #expect(card.reviewer.focus == ["Character voice", "tone", "grammar"])
        #expect(card.anchor == Anchor(episode: "EP2", cut: 1, line: 1))
        #expect(card.version == 2)
        #expect(card.status == .challenged)
    }

    @Test("Body decodes as a quote block followed by a labeled text block")
    func decodesBlocks() throws {
        let card = try decodeSample()
        #expect(card.blocks.count == 2)
        #expect(card.blocks.first == .quote(speaker: "Andie", content: "Order up, you trash-can!"))

        guard case .text(let label, let content) = card.blocks[1] else {
            Issue.record("second block should be a text block")
            return
        }
        #expect(label?.contains("Responding to your note") == true)
        #expect(content.hasPrefix("Understood"))
    }

    @Test("Options decode with keep / alternative / author-written kinds")
    func decodesOptions() throws {
        let card = try decodeSample()
        #expect(card.options.map(\.kind) == [.alternative, .keep, .authorWritten])
        #expect(card.options.first?.label == "Soften")
        #expect(card.options.first?.detail == "Order up… try not to break this one.")
        #expect(card.options.last?.detail == nil) // "Write your own…" carries no preview
    }

    @Test("Card round-trips through JSON unchanged")
    func roundTrips() throws {
        let card = try decodeSample()
        let encoded = try JSONEncoder().encode(card)
        let again = try JSONDecoder().decode(Card.self, from: encoded)
        #expect(again == card)
    }
}
