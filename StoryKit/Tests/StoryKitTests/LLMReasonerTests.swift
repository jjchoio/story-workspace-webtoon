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

// A batch reply with one card for the reviewed line (Cut 1 / Line 1 → id "1.1").
private let wellFormedReply = """
{
  "cards": [
    {
      "target": "1.1",
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
  ]
}
"""

@Suite("Phase 2 — LLM reasoner")
struct LLMReasonerTests {

    private let anchor1 = Anchor(episode: "EP2", cut: 1, line: 1)

    private func episodeEP2() throws -> Episode {
        try StoryParser.parse(Fixtures.cutScript()).episode
    }

    private func context() throws -> ReviewContext {
        try EpisodeContextRetriever().retrieve(subjects: [anchor1], note: nil, from: episodeEP2())
    }

    @Test("A well-formed batch reply parses into a per-line verdict with option ids")
    func parsesWellFormed() async throws {
        let reasoner = LLMReasoner(model: FakeLanguageModel(reply: wellFormedReply))
        let verdicts = try await reasoner.reason(context: context(), config: .dialogue)

        let verdict = try #require(verdicts[anchor1])
        #expect(verdict.blocks.count == 2)
        // The quote block is rebuilt from the reviewed line, not the model's copy.
        let target = try episodeEP2().cuts[0].lines[0]
        #expect(verdict.blocks.first == .quote(speaker: target.speaker, content: target.text))
        #expect(verdict.options.map(\.kind) == [.alternative, .keep, .authorWritten])
        #expect(verdict.options.allSatisfy { !$0.id.isEmpty })
        #expect(verdict.options.last?.detail == nil) // authorWritten carries no preview
    }

    @Test("JSON wrapped in prose and code fences still parses")
    func parsesTolerant() async throws {
        let wrapped = "Sure — here's the cards:\n```json\n\(wellFormedReply)\n```\nLet me know!"
        let reasoner = LLMReasoner(model: FakeLanguageModel(reply: wrapped))
        let verdict = try #require(try await reasoner.reason(context: context(), config: .dialogue)[anchor1])
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

    @Test("A junk block is dropped; the card is still salvaged")
    func salvagesJunkBlock() async throws {
        // A stray malformed block in the array must not sink the card.
        let withJunk = """
        {"cards":[{"target":"1.1",
          "blocks":[
            {"type":"quote","speaker":"Andie","content":"Order up, you trash-can!"},
            {"kind":null,"type":null},
            {"type":"text","label":"Voice","content":"Reads hostile."}
          ],
          "options":[
            {"kind":"alternative","label":"Soften","detail":"Order up, careful now."},
            {"kind":"keep","label":"Keep","detail":"Order up, you trash-can!"},
            {"kind":"authorWritten","label":"Write your own…"}
          ]}]}
        """
        let verdict = try #require(try await LLMReasoner(model: FakeLanguageModel(reply: withJunk))
            .reason(context: context(), config: .dialogue)[anchor1])
        #expect(verdict.blocks.count == 2)   // junk block dropped
        #expect(verdict.options.count == 3)
    }

    @Test("A truncated reply salvages the complete cards before the cut-off")
    func salvagesTruncatedTail() async throws {
        // Two lines requested; the second card is cut off mid-string.
        let context = try EpisodeContextRetriever().retrieve(
            subjects: [anchor1, Anchor(episode: "EP2", cut: 1, line: 3)], note: nil, from: episodeEP2()
        )
        let truncated = """
        {"cards":[
          {"target":"1.1","blocks":[{"type":"text","label":"A","content":"ok"}],
           "options":[{"kind":"keep","label":"Keep","detail":"x"}]},
          {"target":"1.3","blocks":[{"type":"text","label":"B","content":"cut off here
        """
        let verdicts = try await LLMReasoner(model: FakeLanguageModel(reply: truncated))
            .reason(context: context, config: .dialogue)
        #expect(verdicts[anchor1] != nil)                                   // complete card kept
        #expect(verdicts[Anchor(episode: "EP2", cut: 1, line: 3)] == nil)  // truncated card dropped
    }

    @Test("New shape: blocks + alternatives → alternatives plus synthesized Keep/Write")
    func parsesAlternativesShape() async throws {
        let reply = """
        {"cards":[{"target":"1.1",
          "blocks":[
            {"type":"quote","speaker":"Andie","content":"Order up, you trash-can!"},
            {"type":"text","label":"Voice","content":"Reads hostile."}
          ],
          "alternatives":[
            {"label":"Softer","detail":"Order up, careful now."},
            {"label":"Sharper","detail":"Order up, scrap heap."}
          ]}]}
        """
        let verdict = try #require(try await LLMReasoner(model: FakeLanguageModel(reply: reply))
            .reason(context: context(), config: .dialogue)[anchor1])
        #expect(verdict.options.map(\.kind) == [.alternative, .alternative, .keep, .authorWritten])
        #expect(verdict.options.last?.detail == nil) // Write-your-own has no preview
    }

    @Test("Payload fixture: alternatives mis-placed inside blocks are reclassified")
    func reclassifiesMisplacedAlternatives() async throws {
        // The failing payload shape: rewrites emitted as type:"alternative" inside
        // "blocks", with no "options"/"alternatives" array. Must still salvage.
        let reply = """
        {"cards":[{"target":"1.1","blocks":[
          {"type":"quote","speaker":null,"content":"Caption: “A cup settles… and the surface stirs.”"},
          {"type":"text","label":"Opening image","content":"The image is right but a touch neutral."},
          {"type":"alternative","label":"Plainer, heavier","detail":"Caption: “A cup is set down. The surface remembers.”"},
          {"type":"alternative","label":"Second take","detail":"Caption: “A cup settles. Something under it wakes.”"}
        ]}]}
        """
        let verdict = try #require(try await LLMReasoner(model: FakeLanguageModel(reply: reply))
            .reason(context: context(), config: .dialogue)[anchor1])
        #expect(verdict.options.map(\.kind) == [.alternative, .alternative, .keep, .authorWritten])
        #expect(verdict.blocks.count == 2) // rebuilt quote + the reasoning text
    }

    @Test("A card with zero alternatives is legal — Keep + Write only")
    func zeroAlternativesIsLegal() async throws {
        let reply = """
        {"cards":[{"target":"1.1","blocks":[
          {"type":"quote","speaker":"Andie","content":"Order up, you trash-can!"},
          {"type":"text","label":"Fine","content":"Lands exactly as intended — no change needed."}
        ]}]}
        """
        let verdict = try #require(try await LLMReasoner(model: FakeLanguageModel(reply: reply))
            .reason(context: context(), config: .dialogue)[anchor1])
        #expect(verdict.options.map(\.kind) == [.keep, .authorWritten])
    }

    @Test("A card for an unknown target id is dropped, not matched")
    func dropsUnknownTarget() async throws {
        let stray = wellFormedReply.replacingOccurrences(of: "\"1.1\"", with: "\"9.9\"")
        let verdicts = try await LLMReasoner(model: FakeLanguageModel(reply: stray))
            .reason(context: context(), config: .dialogue)
        #expect(verdicts.isEmpty) // no target matched → empty deck, no crash
    }

    @Test("The request carries the role prompt, JSON contract, and the marked line")
    func buildsRequest() async throws {
        let fake = FakeLanguageModel(reply: wellFormedReply)
        _ = try await LLMReasoner(model: fake).reason(context: context(), config: .dialogue)

        let request = try #require(fake.lastRequest)
        #expect(request.system?.contains(ReviewerConfig.dialogue.rolePrompt) == true)
        #expect(request.system?.contains("\"cards\"") == true) // the JSON contract
        #expect(request.messages.first?.role == .user)
        #expect(request.messages.first?.text.contains("LINE UNDER REVIEW") == true)
        #expect(request.messages.first?.text.contains("»[1.1]") == true) // the marked target
    }

    @Test("The North Star is injected into the system prompt as project context")
    func northStarInSystemPrompt() async throws {
        var context = try context()
        context.northStar = "Coffee is an act of attention, craft, and recognition."

        let fake = FakeLanguageModel(reply: wellFormedReply)
        _ = try await LLMReasoner(model: fake).reason(context: context, config: .dialogue)

        let system = try #require(fake.lastRequest?.system)
        #expect(system.contains("PROJECT CONTEXT — North Star"))
        #expect(system.contains("Coffee is an act of attention, craft, and recognition."))
        #expect(fake.lastRequest?.messages.first?.text.contains("North Star") == false)
    }

    @Test("Without a North Star, no project-context block appears")
    func noNorthStarByDefault() async throws {
        let fake = FakeLanguageModel(reply: wellFormedReply)
        _ = try await LLMReasoner(model: fake).reason(context: context(), config: .dialogue)
        #expect(fake.lastRequest?.system?.contains("PROJECT CONTEXT") == false)
    }

    @Test("The pipeline threads a North Star argument into the reasoner")
    func pipelinePassesNorthStar() async throws {
        let fake = FakeLanguageModel(reply: wellFormedReply)
        let pipeline = ReviewPipeline(retriever: EpisodeContextRetriever(), reasoner: LLMReasoner(model: fake))
        _ = try await pipeline.run(
            ReviewRequest(subjects: [anchor1]),
            config: .dialogue, episode: episodeEP2(),
            northStar: "The café resists by recognizing each Diver as a person."
        )
        #expect(fake.lastRequest?.system?.contains("The café resists by recognizing each Diver as a person.") == true)
    }

    @Test("A renewal request adds different-approach + honesty framing to the prompt")
    func renewalFraming() async throws {
        var context = try context()
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
            retriever: EpisodeContextRetriever(),
            reasoner: LLMReasoner(model: FakeLanguageModel(reply: wellFormedReply))
        )
        let cards = try await pipeline.run(
            ReviewRequest(subjects: [anchor1]), config: .dialogue, episode: episodeEP2()
        )
        let card = try #require(cards.first)
        #expect(card.status == .open)
        #expect(card.version == 1)
        #expect(!card.blocks.isEmpty)
        #expect(!card.options.isEmpty)
    }
}
