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
    @Environment(CardStyleSettings.self) private var styleSettings
    @State private var cards: [Card] = []
    @State private var failure: String?
    @State private var reviewing = false
    /// The centered card in the carousel.
    @State private var focusedIndex = 0
    /// Ids of cards currently being renewed (per-card spinner).
    @State private var renewingIDs: Set<String> = []
    /// Per-card renew outcome message (failure / no different take), shown on the
    /// card so a renew never silently appears to do nothing.
    @State private var renewNotices: [String: String] = [:]
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
    private let cardWidth: CGFloat = 460

    private var deckStyle: DeckStyle { styleSettings.deck }

    var body: some View {
        Group {
            if reviewing && cards.isEmpty {
                ProgressView("Reviewing \(model.reviewAnchors.count) line(s)…")
            } else if !cards.isEmpty {
                if deckStyle.layout == .strip { strip } else { carousel }
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

    /// A focused carousel: the centered card is full-size and interactive; the
    /// neighbors peek (scaled + dimmed) so you know there's more without being
    /// able to read them — "one thing at a time" (D17). Arrows / ← → flip; the
    /// controls sit 100px below the card. The peek/dim is driven by DeckStyle so
    /// we can A/B the feel from the debug window.
    private var carousel: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let spacing = max(12, (width - cardWidth) / 2 - deckStyle.peek)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: spacing) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, item in
                            let focused = index == focusedIndex
                            // Focused: neighbors fade their content to an empty
                            // outlined shell (same view → smooth, no blink).
                            let hideContent = !focused && !deckStyle.neighborShowsContent
                            cardView(item, index: index, contentOpacity: hideContent ? 0 : 1)
                                .scaleEffect(focused ? 1 : deckStyle.neighborScale)
                                .opacity(focused ? 1 : deckStyle.neighborOpacity)
                                .blur(radius: focused ? 0 : deckStyle.neighborBlur)
                                .allowsHitTesting(focused)
                        }
                    }
                    .offset(x: centeringOffset(index: focusedIndex, containerWidth: width, spacing: spacing))
                }
                .frame(width: width, height: cardHeight, alignment: .topLeading)
                .clipped()
                .animation(.snappy(duration: 0.28), value: focusedIndex)
            }
            .frame(height: cardHeight)

            Spacer(minLength: 100)
            controls
                .padding(.bottom, 8)
        }
        .focusable()
        .focusEffectDisabled() // no blue focus ring around the deck
        .onKeyPress(.leftArrow) { move(-1); return .handled }
        .onKeyPress(.rightArrow) { move(1); return .handled }
    }

    /// Simple: a plain scrollable strip of full cards — enlarge the window and
    /// they all sit side by side. No focus/arrows.
    private var strip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, item in
                    cardView(item, index: index)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func cardView(_ card: Card, index: Int, contentOpacity: Double = 1) -> some View {
        CardView(
            card: card,
            isAccepted: isAccepted(card),
            isDismissed: dismissedIDs.contains(card.id),
            cardIndex: index,
            fixedHeight: cardHeight,
            contentOpacity: contentOpacity,
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
        .overlay(alignment: .bottom) {
            if let notice = renewNotices[card.id] {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button { move(-1) } label: { Image(systemName: "chevron.left.circle.fill") }
                .disabled(focusedIndex <= 0)
            Text("\(min(focusedIndex + 1, cards.count)) of \(cards.count)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64)
            Button { move(1) } label: { Image(systemName: "chevron.right.circle.fill") }
                .disabled(focusedIndex >= cards.count - 1)
        }
        .buttonStyle(.plain)
        .font(.largeTitle)
        .foregroundStyle(.secondary)
    }

    /// Shift the strip so `index`'s card centers in the container.
    private func centeringOffset(index: Int, containerWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let step = cardWidth + spacing
        return containerWidth / 2 - (CGFloat(index) * step + cardWidth / 2)
    }

    private func move(_ delta: Int) {
        focusedIndex = min(max(focusedIndex + delta, 0), max(0, cards.count - 1))
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
        renewNotices = [:]
        focusedIndex = 0
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
        renewNotices[card.id] = nil
        defer { renewingIDs.remove(card.id) }
        do {
            let request = ReviewRequest(subjects: [card.anchor], priorAlternatives: priors)
            let fresh = try await pipeline().run(
                request, config: .dialogue, episode: episode, northStar: model.northStar?.text
            )
            // Surface the outcome on the card itself — a masked full-screen error
            // would just look like "renew did nothing."
            guard var replacement = fresh.first,
                  let index = cards.firstIndex(where: { $0.id == card.id })
            else {
                renewNotices[card.id] = "No usable result — try Renew again."
                return
            }
            replacement.version = card.version + 1
            replacement.status = .renewed
            cards[index] = replacement
        } catch ModelError.missingAPIKey {
            renewNotices[card.id] = "Set ANTHROPIC_API_KEY, then try again."
        } catch {
            renewNotices[card.id] = "Renew failed: \(error)"
        }
    }
}
