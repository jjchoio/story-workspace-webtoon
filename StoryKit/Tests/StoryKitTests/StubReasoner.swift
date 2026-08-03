import Foundation
import StoryKit

// A deterministic stand-in for the reason stage, used by the pipeline tests to
// exercise retrieve → emit without a live model. It lives in the test target
// because it is scaffolding, not a shipping reviewer — the real reason stage is
// LLMReasoner. Batch: one stub verdict per target, keyed by its anchor.

struct StubReasoner: Reasoner {
    func reason(
        context: ReviewContext, config: ReviewerConfig
    ) async throws -> [Anchor: ReviewerVerdict] {
        var result: [Anchor: ReviewerVerdict] = [:]
        for target in context.targets {
            let line = target.line.text
            result[target.address] = ReviewerVerdict(
                blocks: [
                    .quote(speaker: target.line.speaker, content: line),
                    .text(label: "Why this line", content: "Deterministic stub reasoning."),
                ],
                options: [
                    CardOption(id: "opt-soften", kind: .alternative, label: "Soften", detail: "A gentler take."),
                    CardOption(id: "opt-keep", kind: .keep, label: "Keep", detail: line),
                    CardOption(id: "opt-write", kind: .authorWritten, label: "Write your own…"),
                ]
            )
        }
        return result
    }
}
