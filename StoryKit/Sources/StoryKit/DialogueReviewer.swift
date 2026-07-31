import Foundation

// The one hardcoded reviewer for Phase 2 (D8: reviewers ship as configuration),
// paired with a stub reason stage. The stub lets the retrieve → emit skeleton
// produce a real card today; Item 6 swaps `StubReasoner` for a Claude-backed
// `Reasoner` that consumes `config.rolePrompt` — nothing else changes.

public extension ReviewerConfig {
    /// The Dialogue reviewer: character voice, tone, and grammar.
    static let dialogue = ReviewerConfig(
        reviewer: Reviewer(name: "Dialogue reviewer", focus: ["Character voice", "tone", "grammar"]),
        rolePrompt: """
        You are a dialogue reviewer for a webtoon script. Judge one line for \
        character voice, tone, and grammar. Offer a softer alternative that \
        keeps the character's edge, or endorse keeping the line as written. \
        The author decides; propose, never rewrite.
        """,
        retrieval: RetrievalSpec(neighbors: 2)
    )
}

/// A deterministic stand-in for the reason stage: it echoes the subject line
/// into a quote block, adds fixed reasoning, and offers soften / keep / write
/// options. No model call — this is the seam Item 6 replaces.
public struct StubReasoner: Reasoner {
    public init() {}

    public func reason(context: ReviewContext, config: ReviewerConfig) async throws -> ReviewerVerdict {
        let line = context.target.text
        return ReviewerVerdict(
            blocks: [
                .quote(speaker: context.target.speaker, content: line),
                .text(
                    label: "Why this line",
                    content: """
                    Sample reasoning from the stub reasoner. The real Dialogue \
                    reviewer replaces this at the track merge; the card chrome, \
                    anchor, and options around it are already the shipping shape.
                    """
                ),
            ],
            options: [
                CardOption(
                    id: "opt-soften", kind: .alternative, label: "Soften",
                    detail: "A gentler take that keeps the character's edge."
                ),
                CardOption(id: "opt-keep", kind: .keep, label: "Keep", detail: line),
                CardOption(id: "opt-write", kind: .authorWritten, label: "Write your own…"),
            ]
        )
    }
}
