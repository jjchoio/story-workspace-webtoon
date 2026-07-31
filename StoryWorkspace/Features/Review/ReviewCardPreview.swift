//
//  ReviewCardPreview.swift
//  StoryWorkspace
//
//  TEMP (Phase 2 step 6 demo): runs a real Claude review of EP2/Cut1/Line1 and
//  hosts the card's interaction cycle — Accept patches the document via the
//  shared model (highlighting the line in Read Mode), Renew re-runs the reviewer
//  for a different approach. Remove with the real review flow.
//

import SwiftUI
import StoryKit

struct ReviewCardPreview: View {
    let episode: Episode

    @Environment(ProjectViewModel.self) private var model
    @State private var card: Card?
    @State private var failure: String?
    @State private var renewing = false

    private let anchor = Anchor(episode: "EP2", cut: 1, line: 1)

    var body: some View {
        Group {
            if let card {
                CardView(
                    card: card,
                    onAccept: { option, authored in
                        model.accept(
                            option: option, anchor: anchor,
                            reviewer: card.reviewer.name, authoredText: authored
                        )
                    },
                    onRenew: { Task { await renew() } }
                )
                .id(card.version)
                .opacity(renewing ? 0.5 : 1)
                .overlay { if renewing { ProgressView() } }
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

    // MARK: Pipeline

    private func produceCard(priorAlternatives: [String]) async throws -> Card {
        let claude = try ClaudeModel.fromEnvironment()
        let pipeline = ReviewPipeline(
            retriever: NearbyLinesRetriever(),
            reasoner: LLMReasoner(model: claude)
        )
        let request = ReviewRequest(subject: anchor, priorAlternatives: priorAlternatives)
        return try await pipeline.run(request, config: .dialogue, episode: episode)
    }

    private func runReview() async {
        do {
            card = try await produceCard(priorAlternatives: [])
        } catch ModelError.missingAPIKey {
            failure = "Set ANTHROPIC_API_KEY in the Run scheme’s environment variables, then run again."
        } catch {
            failure = String(describing: error)
        }
    }

    /// Ask for a different approach (D12): re-run, telling the reviewer which
    /// alternatives it already offered so it takes a new path or defers honestly.
    private func renew() async {
        guard let current = card else { return }
        let priors = current.options.filter { $0.kind == .alternative }.compactMap(\.detail)
        renewing = true
        defer { renewing = false }
        do {
            var renewed = try await produceCard(priorAlternatives: priors)
            renewed.version = current.version + 1
            renewed.status = .renewed
            card = renewed
        } catch {
            failure = String(describing: error)
        }
    }
}
