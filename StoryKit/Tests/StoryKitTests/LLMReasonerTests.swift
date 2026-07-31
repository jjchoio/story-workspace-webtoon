import Testing
import Foundation
@testable import StoryKit

// Phase 2 track-merge tests (PLANNING.md Phase 2, step 6). The provider-agnostic
// LLMReasoner is exercised with a fake LanguageModel returning canned replies,
// so prompt-building and JSON parsing are covered with no network. The real
// ClaudeModel adapter is verified manually in the app (needs a key + network).

/// A LanguageModel that captures the request and returns a scripted reply.
private final class FakeLanguageModel: LanguageModel, @unchecked Sendable {
    let reply: String
    private(set) var lastRequest: ModelRequest?

    init(reply: String) { self.reply = reply }

    func send(_ request: ModelRequest) async throws -> ModelResponse {
        lastRequest = request
        return ModelResponse(text: reply)
    }
}

private let wellFormedReply = """
{
  "blocks": [
    { "type": "quote", "speaker": "Andie", "content": "Order up, you trash-can!" },
    { "type": "text", "label": "Voice", "content": "Reads hostile before her warmth lands." }
  ],
  "options": [
    { "kind": "alternative", "label": "Soften", "detail": "Order up… try not to break this one." },
    { "kind": "keep", "label": "Keep", "detail": "Order up, you trash-can!" },
    { "kind": "authorWritten", "label": "Write your own…" }
  ]
}
"""

@Suite("Phase 2 — LLM reasoner")
struct LLMReasonerTests {

    private func episodeEP2() throws -> Episode {
        try StoryParser.parse(Fixtures.cutScript()).episode
    }

    private func context() throws -> ReviewContext {
        try NearbyLinesRetriever().retrieve(
            subject: Anchor(episode: "EP2", cut: 1, line: 1),
            note: nil, spec: RetrievalSpec(neighbors: 2), from: episodeEP2()
        )
    }

    @Test("A well-formed JSON reply parses into blocks and options with ids")
    func parsesWellFormed() async throws {
        let reasoner = LLMReasoner(model: FakeLanguageModel(reply: wellFormedReply))
        let verdict = try await reasoner.reason(context: context(), config: .dialogue)

        #expect(verdict.blocks.count == 2)
        #expect(verdict.blocks.first == .quote(speaker: "Andie", content: "Order up, you trash-can!"))
        #expect(verdict.options.map(\.kind) == [.alternative, .keep, .authorWritten])
        #expect(verdict.options.allSatisfy { !$0.id.isEmpty })
        #expect(verdict.options.last?.detail == nil) // authorWritten carries no preview
    }

    @Test("JSON wrapped in prose and code fences still parses")
    func parsesTolerant() async throws {
        let wrapped = "Sure — here's the card:\n```json\n\(wellFormedReply)\n```\nLet me know!"
        let reasoner = LLMReasoner(model: FakeLanguageModel(reply: wrapped))
        let verdict = try await reasoner.reason(context: context(), config: .dialogue)
        #expect(verdict.blocks.count == 2)
        #expect(verdict.options.count == 3)
    }

    @Test("A reply with no JSON object throws malformedVerdict")
    func throwsOnNonJSON() async throws {
        let reasoner = LLMReasoner(model: FakeLanguageModel(reply: "I can't help with that."))
        await #expect(throws: ReviewError.self) {
            _ = try await reasoner.reason(context: context(), config: .dialogue)
        }
    }

    @Test("The request carries the role prompt, JSON contract, and the target line")
    func buildsRequest() async throws {
        let fake = FakeLanguageModel(reply: wellFormedReply)
        _ = try await LLMReasoner(model: fake).reason(context: context(), config: .dialogue)

        let request = try #require(fake.lastRequest)
        #expect(request.system?.contains(ReviewerConfig.dialogue.rolePrompt) == true)
        #expect(request.system?.contains("\"blocks\"") == true) // the JSON contract
        #expect(request.messages.first?.role == .user)
        #expect(request.messages.first?.text.contains("LINE UNDER REVIEW") == true)
    }

    @Test("A renewal request adds different-approach + honesty framing to the prompt")
    func renewalFraming() async throws {
        let episode = try episodeEP2()
        let renewalContext = try NearbyLinesRetriever().retrieve(
            subject: Anchor(episode: "EP2", cut: 1, line: 1),
            note: nil, spec: RetrievalSpec(neighbors: 2), from: episode
        )
        var context = renewalContext
        context.priorAlternatives = ["Order up… try not to break this one."]

        let fake = FakeLanguageModel(reply: wellFormedReply)
        _ = try await LLMReasoner(model: fake).reason(context: context, config: .dialogue)

        let userText = try #require(fake.lastRequest?.messages.first?.text)
        #expect(userText.contains("You already suggested"))
        #expect(userText.contains("genuinely different approach"))
        #expect(userText.contains("honestly"))
        #expect(userText.contains("try not to break this one")) // the prior alternative
    }

    @Test("Without a renewal, no different-approach framing appears")
    func noRenewalFramingByDefault() async throws {
        let fake = FakeLanguageModel(reply: wellFormedReply)
        _ = try await LLMReasoner(model: fake).reason(context: context(), config: .dialogue)
        #expect(fake.lastRequest?.messages.first?.text.contains("You already suggested") == false)
    }

    @Test("Pipeline with the LLM reasoner emits an open v1 card")
    func runsThroughPipeline() async throws {
        let pipeline = ReviewPipeline(
            retriever: NearbyLinesRetriever(),
            reasoner: LLMReasoner(model: FakeLanguageModel(reply: wellFormedReply))
        )
        let card = try await pipeline.run(
            ReviewRequest(subject: Anchor(episode: "EP2", cut: 1, line: 1)),
            config: .dialogue, episode: episodeEP2()
        )
        #expect(card.status == .open)
        #expect(card.version == 1)
        #expect(!card.blocks.isEmpty)
        #expect(!card.options.isEmpty)
    }
}
