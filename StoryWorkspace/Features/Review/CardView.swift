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
    /// Called when the author accepts an option. String is the author's typed
    /// line for an author-written option, nil otherwise.
    var onAccept: (CardOption, String?) -> Void = { _, _ in }
    var onRenew: () -> Void = {}
    var onDismiss: () -> Void = {}

    @State private var selectedOptionID: String?
    @State private var status: CardStatus
    @State private var authoredText: String = ""

    init(
        card: Card,
        onAccept: @escaping (CardOption, String?) -> Void = { _, _ in },
        onRenew: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.card = card
        self.onAccept = onAccept
        self.onRenew = onRenew
        self.onDismiss = onDismiss
        _status = State(initialValue: card.status)
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
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            CardFooterView(
                hasSelection: selectedOptionID != nil,
                canAccept: canAccept,
                onAccept: {
                    guard let option = selectedOption else { return }
                    onAccept(option, option.kind == .authorWritten ? authoredText : nil)
                    status = .accepted
                },
                onRenew: onRenew,
                onDismiss: { status = .dismissed; onDismiss() }
            )
        }
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator.opacity(0.6)))
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
            CardStatusBadge(version: card.version, status: status)
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
