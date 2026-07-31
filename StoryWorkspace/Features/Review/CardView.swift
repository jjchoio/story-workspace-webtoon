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

    @State private var selectedOptionID: String?
    @State private var status: CardStatus

    init(card: Card) {
        self.card = card
        _status = State(initialValue: card.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            CardFooterView(
                onChallenge: { status = .challenged },
                onRenew: { status = .renewed },
                onDismiss: { status = .dismissed }
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
        }
        .padding(16)
    }
}
