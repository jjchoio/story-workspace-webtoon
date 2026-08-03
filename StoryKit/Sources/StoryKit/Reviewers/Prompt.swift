import Foundation

// Loads a reviewer's role-prompt text from the bundled Reviewers/Prompts/*.md.
// Prompts are authored as Markdown so they can be edited and previewed without
// touching Swift and so prompt churn shows up as clean text diffs. The files
// ship as package resources, so a missing one is a build/config error — we trap
// rather than degrade a reviewer to an empty prompt.

enum Prompt {
    static func load(_ name: String) -> String {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: "md"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("Missing bundled reviewer prompt: \(name).md")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
