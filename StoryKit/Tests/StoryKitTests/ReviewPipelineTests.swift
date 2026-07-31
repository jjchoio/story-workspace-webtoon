import Testing
import Foundation
@testable import StoryKit

// Phase 2 pipeline-skeleton acceptance tests (PLANNING.md Phase 2, step 4; D8).
// The retrieve → reason → emit skeleton, with the reason stage stubbed, must
// turn a subject anchor into a well-formed open card. These mirror the step's
// exit criteria and are the seam Item 6 swaps a real reasoner into.

@Suite("Phase 2 — review pipeline")
struct ReviewPipelineTests {

    private func episodeEP2() throws -> Episode {
        try StoryParser.parse(Fixtures.cutScript()).episode
    }

    @Test("Retriever selects the subject line and its trailing neighbors")
    func retrieves() throws {
        let episode = try episodeEP2()
        let subject = Anchor(episode: "EP2", cut: 1, line: 1)
        let context = try NearbyLinesRetriever().retrieve(
            subject: subject, note: nil, spec: RetrievalSpec(neighbors: 2), from: episode
        )
        let lines = episode.cuts[0].lines
        #expect(context.address == subject)
        #expect(context.target == lines[0])
        #expect(context.before.isEmpty)                       // nothing precedes line 1
        #expect(context.after == Array(lines.dropFirst().prefix(2)))
    }

    @Test("A subject outside the episode throws")
    func outOfRange() throws {
        let episode = try episodeEP2()
        #expect(throws: ReviewError.self) {
            try NearbyLinesRetriever().retrieve(
                subject: Anchor(episode: "EP2", cut: 99, line: 1),
                note: nil, spec: RetrievalSpec(neighbors: 1), from: episode
            )
        }
    }

    @Test("Pipeline emits an open v1 card anchored to the subject")
    func runsPipeline() async throws {
        let episode = try episodeEP2()
        let subject = Anchor(episode: "EP2", cut: 1, line: 1)
        let pipeline = ReviewPipeline(retriever: NearbyLinesRetriever(), reasoner: StubReasoner())

        let card = try await pipeline.run(
            ReviewRequest(subject: subject), config: .dialogue, episode: episode
        )

        #expect(card.anchor == subject)
        #expect(card.reviewer == ReviewerConfig.dialogue.reviewer)
        #expect(card.version == 1)
        #expect(card.status == .open)
        #expect(!card.blocks.isEmpty)
        #expect(!card.options.isEmpty)
    }

    @Test("The emitted card round-trips through JSON unchanged")
    func roundTrips() async throws {
        let episode = try episodeEP2()
        let pipeline = ReviewPipeline(retriever: NearbyLinesRetriever(), reasoner: StubReasoner())

        let card = try await pipeline.run(
            ReviewRequest(subject: Anchor(episode: "EP2", cut: 1, line: 1)),
            config: .dialogue, episode: episode
        )
        let encoded = try JSONEncoder().encode(card)
        let again = try JSONDecoder().decode(Card.self, from: encoded)
        #expect(again == card)
    }
}
