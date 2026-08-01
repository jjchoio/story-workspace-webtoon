//
//  ReviewCardPreview.swift
//  StoryWorkspace
//
//  Runs a live Claude review of the line the author selected in Read Mode, and
//  hosts the card's interaction cycle — Accept patches the document via the
//  shared model (highlighting the line in Read Mode), Renew re-runs the reviewer
//  for a different approach. Re-runs whenever the author presses Review.
//

import SwiftUI
import StoryKit

struct ReviewCardPreview: View {
    let episode: Episode

    @Environment(ProjectViewModel.self) private var model
    @State private var card: Card?
    @State private var failure: String?
    @State private var renewing = false

    var body: some View {
        Group {
            if let card {
                CardView(
                    card: card,
                    isAccepted: isAccepted(card),
                    onAccept: { option, authored in
                        model.accept(
                            option: option, anchor: card.anchor,
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
        // Re-run each time the author presses Review (bumps reviewRequestID).
        .task(id: model.reviewRequestID) { await runReview() }
    }

    /// True while the reviewed line is still an accepted change (in the model's
    /// changed set). Reverting the edit in Read Mode removes it, flipping the
    /// card's badge off "accepted".
    private func isAccepted(_ card: Card) -> Bool {
        guard case .loaded(let loaded) = model.state,
              let id = loaded.episode.line(at: card.anchor)?.id
        else { return false }
        return model.changedLineIDs.contains(id)
    }

    // MARK: Pipeline

    private func produceCard(anchor: StoryKit.Anchor, priorAlternatives: [String]) async throws -> Card {
        let claude = try ClaudeModel.fromEnvironment()
        let pipeline = ReviewPipeline(
            retriever: EpisodeContextRetriever(),
            reasoner: LLMReasoner(model: claude)
        )
        let request = ReviewRequest(subject: anchor, priorAlternatives: priorAlternatives)
        return try await pipeline.run(
            request, config: .dialogue, episode: episode, northStar: model.northStar?.text
        )
    }

    private func runReview() async {
        guard let anchor = model.reviewAnchor else {
            failure = "Select a line in Read Mode, then press Review."
            card = nil
            return
        }
        failure = nil
        card = nil
        do {
            card = try await produceCard(anchor: anchor, priorAlternatives: [])
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
            var renewed = try await produceCard(anchor: current.anchor, priorAlternatives: priors)
            renewed.version = current.version + 1
            renewed.status = .renewed
            card = renewed
        } catch {
            failure = String(describing: error)
        }
    }
}
