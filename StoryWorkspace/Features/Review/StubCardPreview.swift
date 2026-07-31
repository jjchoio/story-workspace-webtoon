//
//  StubCardPreview.swift
//  StoryWorkspace
//
//  TEMP (Phase 2 step 4 demo): runs the stub review pipeline against the loaded
//  episode and renders the produced card, so the retrieve → reason → emit
//  skeleton is visible in the app before the real reviewer and review flow land
//  at step 6. Remove with the toolbar hook when the review flow exists.
//

import SwiftUI
import StoryKit

struct StubCardPreview: View {
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
            } else {
                ProgressView("Reviewing…")
            }
        }
        .task { await runReview() }
    }

    private func runReview() async {
        let pipeline = ReviewPipeline(retriever: NearbyLinesRetriever(), reasoner: StubReasoner())
        let request = ReviewRequest(subject: Anchor(episode: "EP2", cut: 1, line: 1))
        do {
            card = try await pipeline.run(request, config: .dialogue, episode: episode)
        } catch {
            failure = String(describing: error)
        }
    }
}
