//
//  ReviewCardPreview.swift
//  StoryWorkspace
//
//  TEMP (Phase 2 step 6 demo): runs a real Claude review of EP2/Cut1/Line1
//  through the pipeline and renders the returned card. Proves the end-to-end
//  single-reviewer path (retrieve → reason via LLM → emit) in the running app.
//  The API key comes from ANTHROPIC_API_KEY in the Run scheme's environment.
//  Remove this and the toolbar hook when the real review flow lands.
//

import SwiftUI
import StoryKit

struct ReviewCardPreview: View {
    let episode: Episode

    @State private var card: Card?
    @State private var failure: String?

    var body: some View {
        Group {
            if let card {
                CardView(card: card)
            } else if let failure {
                Text(failure)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            } else {
                ProgressView("Reviewing…")
            }
        }
        .task { await runReview() }
    }

    private func runReview() async {
        do {
            let model = try ClaudeModel.fromEnvironment()
            let pipeline = ReviewPipeline(
                retriever: NearbyLinesRetriever(),
                reasoner: LLMReasoner(model: model)
            )
            let request = ReviewRequest(subject: Anchor(episode: "EP2", cut: 1, line: 1))
            card = try await pipeline.run(request, config: .dialogue, episode: episode)
        } catch ModelError.missingAPIKey {
            failure = "Set ANTHROPIC_API_KEY in the Run scheme’s environment variables, then run again."
        } catch {
            failure = String(describing: error)
        }
    }
}
