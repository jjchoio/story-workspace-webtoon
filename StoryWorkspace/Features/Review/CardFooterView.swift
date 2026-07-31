//
//  CardFooterView.swift
//  StoryWorkspace
//
//  Card actions. Renew asks the reviewer for a different approach (D12). The
//  primary action is contextual: Accept once the author has picked an option,
//  otherwise Dismiss. (Challenge returns with the full D12 loop.)
//

import SwiftUI

struct CardFooterView: View {
    let hasSelection: Bool
    let canAccept: Bool
    let onAccept: () -> Void
    let onRenew: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onRenew) {
                Label("Renew", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            if hasSelection {
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAccept)
            } else {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(16)
    }
}
