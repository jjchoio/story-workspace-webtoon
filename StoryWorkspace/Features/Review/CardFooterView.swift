//
//  CardFooterView.swift
//  StoryWorkspace
//
//  Card actions. Renew asks the reviewer for a different approach (D12); Dismiss
//  declines the card (author disposes, D3). Accept applies the selected option.
//  Renew · Dismiss sit on the left; Accept is the prominent primary on the
//  right, enabled once a choice is selected.
//

import SwiftUI

struct CardFooterView: View {
    let canAccept: Bool
    let onAccept: () -> Void
    let onRenew: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onRenew) {
                Label("Renew", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button(action: onDismiss) {
                Label("Dismiss", systemImage: "hand.thumbsdown")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Accept", action: onAccept)
                .buttonStyle(.borderedProminent)
                .disabled(!canAccept)
        }
        .font(.callout)
        .padding(16)
    }
}
