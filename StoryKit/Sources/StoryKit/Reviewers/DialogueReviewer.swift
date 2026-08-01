import Foundation

// The Dialogue reviewer (D8: a reviewer is configuration). Its personality lives
// in Reviewers/Prompts/Dialogue.md; this file only binds that prompt to the
// reviewer's identity. The card output contract is shared and lives in
// LLMReasoner, so the prompt file stays about voice, not JSON shape.

public extension ReviewerConfig {
    /// The Dialogue reviewer: character voice, tone, and grammar.
    static let dialogue = ReviewerConfig(
        reviewer: Reviewer(name: "Dialogue reviewer", focus: ["Character voice", "tone", "grammar"]),
        rolePrompt: Prompt.load("Dialogue")
    )
}
