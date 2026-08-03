//
//  CardView.swift
//  StoryWorkspace
//
//  Schema-driven review card (D9): fixed chrome (reviewer header, status badge,
//  anchor, footer actions) around a schema-driven body (blocks) and options.
//  Selection and status changes are local for now; applying an option and the
//  real lifecycle are the Phase 3 write loop.
//

import SwiftUI
import StoryKit

struct CardView: View {
    let card: Card
    /// Whether the reviewed line is currently accepted (driven by the model, so
    /// reverting the edit in Read Mode flips the badge back — not stuck on
    /// "accepted").
    var isAccepted: Bool = false
    /// Whether the author declined this card (session state, owned by the deck).
    var isDismissed: Bool = false
    /// The card's position in the deck — picks its default color from the warm
    /// gradient (card 0 is always the same color, card 1 the next, …).
    var cardIndex: Int = 0
    /// Called when the author accepts an option. String is the author's typed
    /// line for an author-written option, nil otherwise.
    var onAccept: (CardOption, String?) -> Void = { _, _ in }
    var onRenew: () -> Void = {}
    var onDismiss: () -> Void = {}
    /// When set, the card is that tall and its body scrolls — so a deck of cards
    /// stays a consistent height regardless of content length.
    var fixedHeight: CGFloat? = nil
    /// Opacity of the inner content (header/body/footer); the framed chrome
    /// (background + outline) stays fully visible. Fading to 0 turns the card
    /// into an empty outlined shell — used for peeked neighbors — without
    /// swapping the view, so focus transitions animate smoothly.
    var contentOpacity: Double = 1

    // TEMP visual sandbox (CardStyle.swift): drives the card's chrome.
    @Environment(CardStyleSettings.self) private var cardStyle

    @State private var selectedOptionID: String?
    @State private var authoredText: String = ""

    init(
        card: Card,
        isAccepted: Bool = false,
        isDismissed: Bool = false,
        cardIndex: Int = 0,
        fixedHeight: CGFloat? = nil,
        contentOpacity: Double = 1,
        onAccept: @escaping (CardOption, String?) -> Void = { _, _ in },
        onRenew: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.card = card
        self.isAccepted = isAccepted
        self.isDismissed = isDismissed
        self.cardIndex = cardIndex
        self.fixedHeight = fixedHeight
        self.contentOpacity = contentOpacity
        self.onAccept = onAccept
        self.onRenew = onRenew
        self.onDismiss = onDismiss
    }

    /// The badge state: accepted (model-driven) wins, then declined, else the
    /// card's own lifecycle status.
    private var displayStatus: CardStatus {
        if isAccepted { return .accepted }
        if isDismissed { return .dismissed }
        return card.status
    }

    private var selectedOption: CardOption? {
        card.options.first { $0.id == selectedOptionID }
    }

    private var canAccept: Bool {
        guard let selectedOption else { return false }
        if selectedOption.kind == .authorWritten {
            return !authoredText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        filledBody
            .opacity(contentOpacity) // fades content only; chrome stays below/over
            .frame(width: 460, height: fixedHeight, alignment: .top)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: accentStyle == .outline ? accentColor.opacity(0.45) : .clear, radius: 4, y: 1)
    }

    private var filledBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if fixedHeight == nil {
                content
            } else {
                ScrollView { content }
            }
            Divider()
            CardFooterView(
                canAccept: canAccept,
                onAccept: {
                    guard let option = selectedOption else { return }
                    onAccept(option, option.kind == .authorWritten ? authoredText : nil)
                    // The badge/color flip via isAccepted (model-driven), so
                    // revert reflects here too.
                },
                onRenew: onRenew,
                onDismiss: onDismiss
            )
        }
    }

    // MARK: Visual treatment (TEMP sandbox — see CardStyle.swift)

    /// State drives the color: accepted → green, declined → grey, else this
    /// card's default gradient tone. Revert (isAccepted back to false) returns to
    /// the default color.
    private var accentColor: Color {
        if isAccepted { return CardAccent.accepted }
        if isDismissed { return CardAccent.declined }
        return CardAccent.defaultColor(index: cardIndex)
    }

    private var accentStyle: CardAccentStyle { cardStyle.style }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        switch accentStyle {
        case .plain, .outline:
            shape.fill(.regularMaterial)
        case .filled:
            shape.fill(.regularMaterial).overlay(shape.fill(accentColor.opacity(0.14)))
        case .solid:
            shape.fill(accentColor)
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        switch accentStyle {
        case .plain:   shape.strokeBorder(.separator.opacity(0.6), lineWidth: 1)
        case .outline: shape.strokeBorder(accentColor, lineWidth: 2)
        case .filled:  shape.strokeBorder(accentColor.opacity(0.5), lineWidth: 1.5)
        case .solid:   shape.strokeBorder(.black.opacity(0.18), lineWidth: 1)
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bubble.left.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(card.reviewer.name).font(.headline)
                Text(card.reviewer.focus.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            CardStatusBadge(version: card.version, status: displayStatus)
        }
        .padding(16)
    }

    // MARK: Body

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(card.anchor.episode) · Cut \(card.anchor.cut) · Line \(card.anchor.line)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            ForEach(Array(card.blocks.enumerated()), id: \.offset) { entry in
                CardBlockView(block: entry.element)
            }

            VStack(spacing: 8) {
                ForEach(card.options) { option in
                    CardOptionRow(option: option, isSelected: option.id == selectedOptionID) {
                        selectedOptionID = option.id
                    }
                }
            }
            .padding(.top, 2)

            if selectedOption?.kind == .authorWritten {
                TextField("Write your line…", text: $authoredText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
            }
        }
        .padding(16)
    }
}
