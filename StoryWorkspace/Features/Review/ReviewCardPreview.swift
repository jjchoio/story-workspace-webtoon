//
//  ReviewCardPreview.swift
//  StoryWorkspace
//
//  The review deck: one Claude call reviews every line the author selected in
//  Read Mode and returns a card per line, laid out horizontally. Each card runs
//  its own interaction cycle — Accept patches the document (highlighting the
//  line in Read Mode), Renew re-runs the reviewer for just that line. Re-runs
//  whenever the author presses Review.
//

import SwiftUI
import StoryKit

struct ReviewCardPreview: View {
    let episode: Episode

    @Environment(ProjectViewModel.self) private var model
    @State private var cards: [Card] = []
    @State private var failure: String?
    @State private var reviewing = false
    /// Ids of cards currently being renewed (per-card spinner).
    @State private var renewingIDs: Set<String> = []
    /// Ids of cards the author declined. SCALE: session-only for now — the
    /// durable "declined" record lands with card/session persistence (D13,
    /// PLANNING "Deliberately Deferred"). Cleared on a new review.
    @State private var dismissedIDs: Set<String> = []
    /// Ids of cards accepted via "Keep". Keep endorses the line with no edit, so
    /// it isn't in the document's changed set — we track its accepted (green)
    /// state here. Edit-accepts stay tied to the changed line so Revert un-greens
    /// them. Cleared on a new review.
    @State private var keepAcceptedIDs: Set<String> = []

    private let cardHeight: CGFloat = 520

    var body: some View {
        Group {
            if reviewing && cards.isEmpty {
                ProgressView("Reviewing \(model.reviewAnchors.count) line(s)…")
            } else if !cards.isEmpty {
                deck
            } else if let failure {
                Text(failure)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            } else {
                Text("Select one or more lines in Read Mode, then press Review.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        // Re-run each time the author presses Review (bumps reviewRequestID).
        .task(id: model.reviewRequestID) { await runReview() }
    }

    private var deck: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardView(
                        card: card,
                        isAccepted: isAccepted(card),
                        isDismissed: dismissedIDs.contains(card.id),
                        cardIndex: index,
                        fixedHeight: cardHeight,
                        onAccept: { option, authored in
                            dismissedIDs.remove(card.id) // accepting un-declines
                            // Keep has no edit to track, so record its green here.
                            if option.kind == .keep { keepAcceptedIDs.insert(card.id) }
                            else { keepAcceptedIDs.remove(card.id) }
                            model.accept(
                                option: option, anchor: card.anchor,
                                reviewer: card.reviewer.name, authoredText: authored
                            )
                        },
                        onRenew: { Task { await renew(card) } },
                        onDismiss: {
                            dismissedIDs.insert(card.id)
                            keepAcceptedIDs.remove(card.id) // declining un-accepts a Keep
                        }
                    )
                    .id("\(card.id)-\(card.version)") // re-init on renew
                    .opacity(renewingIDs.contains(card.id) ? 0.5 : 1)
                    .overlay { if renewingIDs.contains(card.id) { ProgressView() } }
                }
            }
            .padding(4)
        }
    }

    /// True while the reviewed line is still an accepted change (in the model's
    /// changed set). Reverting the edit in Read Mode flips the badge off.
    private func isAccepted(_ card: Card) -> Bool {
        if keepAcceptedIDs.contains(card.id) { return true } // Keep: accepted, no edit
        guard case .loaded(let loaded) = model.state,
              let id = loaded.episode.line(at: card.anchor)?.id
        else { return false }
        return model.changedLineIDs.contains(id)
    }

    // MARK: Pipeline

    private func pipeline() throws -> ReviewPipeline {
        ReviewPipeline(
            retriever: EpisodeContextRetriever(),
            reasoner: LLMReasoner(model: try ClaudeModel.fromEnvironment())
        )
    }

    private func runReview() async {
        guard !model.reviewAnchors.isEmpty else {
            failure = "Select one or more lines in Read Mode, then press Review."
            cards = []
            return
        }
        failure = nil
        cards = []
        dismissedIDs = []
        keepAcceptedIDs = []
        reviewing = true
        defer { reviewing = false }
        do {
            let request = ReviewRequest(subjects: model.reviewAnchors)
            cards = try await pipeline().run(
                request, config: .dialogue, episode: episode, northStar: model.northStar?.text
            )
            if cards.isEmpty {
                failure = "The reviewer didn't return any usable cards. Try again."
            }
        } catch ModelError.missingAPIKey {
            failure = "Set ANTHROPIC_API_KEY in the Run scheme’s environment variables, then run again."
        } catch {
            failure = String(describing: error)
        }
    }

    /// Ask for a different approach on ONE card (D12): a single-line re-call that
    /// tells the reviewer which alternatives it already offered, so it takes a new
    /// path or defers honestly. Replaces just that card in the deck.
    private func renew(_ card: Card) async {
        let priors = card.options.filter { $0.kind == .alternative }.compactMap(\.detail)
        renewingIDs.insert(card.id)
        defer { renewingIDs.remove(card.id) }
        do {
            let request = ReviewRequest(subjects: [card.anchor], priorAlternatives: priors)
            let fresh = try await pipeline().run(
                request, config: .dialogue, episode: episode, northStar: model.northStar?.text
            )
            guard var replacement = fresh.first,
                  let index = cards.firstIndex(where: { $0.id == card.id })
            else { return }
            replacement.version = card.version + 1
            replacement.status = .renewed
            cards[index] = replacement
        } catch {
            failure = String(describing: error)
        }
    }
}
