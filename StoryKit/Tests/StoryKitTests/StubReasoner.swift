import Foundation
import StoryKit

// A deterministic stand-in for the reason stage, used by the pipeline tests to
// exercise retrieve → emit without a live model. It lives in the test target
// because it is scaffolding, not a shipping reviewer — the real reason stage is
// LLMReasoner.

struct StubReasoner: Reasoner {
    func reason(context: ReviewContext, config: ReviewerConfig) async throws -> ReviewerVerdict {
        let line = context.target.text
        return ReviewerVerdict(
            blocks: [
                .quote(speaker: context.target.speaker, content: line),
                .text(label: "Why this line", content: "Deterministic stub reasoning."),
            ],
            options: [
                CardOption(id: "opt-soften", kind: .alternative, label: "Soften", detail: "A gentler take."),
                CardOption(id: "opt-keep", kind: .keep, label: "Keep", detail: line),
                CardOption(id: "opt-write", kind: .authorWritten, label: "Write your own…"),
            ]
        )
    }
}
