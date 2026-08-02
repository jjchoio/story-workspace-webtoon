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

    @Test("Retriever resolves each subject and carries the whole episode")
    func retrieves() throws {
        let episode = try episodeEP2()
        let subject = Anchor(episode: "EP2", cut: 1, line: 1)
        let context = try EpisodeContextRetriever().retrieve(
            subjects: [subject], note: nil, from: episode
        )
        #expect(context.targets.count == 1)
        #expect(context.targets.first?.address == subject)
        #expect(context.targets.first?.line == episode.cuts[0].lines[0])
        #expect(context.episode == episode)                   // full episode as context
    }

    @Test("A subject outside the episode throws")
    func outOfRange() throws {
        let episode = try episodeEP2()
        #expect(throws: ReviewError.self) {
            try EpisodeContextRetriever().retrieve(
                subjects: [Anchor(episode: "EP2", cut: 99, line: 1)],
                note: nil, from: episode
            )
        }
    }

    @Test("Pipeline emits an open v1 card per subject, in document order")
    func runsPipeline() async throws {
        let episode = try episodeEP2()
        // Deliberately out of order — cards must come back in document order.
        let subjects = [Anchor(episode: "EP2", cut: 1, line: 3), Anchor(episode: "EP2", cut: 1, line: 1)]
        let pipeline = ReviewPipeline(retriever: EpisodeContextRetriever(), reasoner: StubReasoner())

        let cards = try await pipeline.run(
            ReviewRequest(subjects: subjects), config: .dialogue, episode: episode
        )

        #expect(cards.count == 2)
        #expect(cards.map(\.anchor.line) == [1, 3])           // document order, not selection order
        #expect(cards.allSatisfy { $0.version == 1 && $0.status == .open })
        #expect(cards.allSatisfy { !$0.blocks.isEmpty && !$0.options.isEmpty })
        #expect(cards.allSatisfy { $0.reviewer == ReviewerConfig.dialogue.reviewer })
    }

    @Test("An emitted card round-trips through JSON unchanged")
    func roundTrips() async throws {
        let episode = try episodeEP2()
        let pipeline = ReviewPipeline(retriever: EpisodeContextRetriever(), reasoner: StubReasoner())

        let cards = try await pipeline.run(
            ReviewRequest(subjects: [Anchor(episode: "EP2", cut: 1, line: 1)]),
            config: .dialogue, episode: episode
        )
        let card = try #require(cards.first)
        let encoded = try JSONEncoder().encode(card)
        let again = try JSONDecoder().decode(Card.self, from: encoded)
        #expect(again == card)
    }
}
