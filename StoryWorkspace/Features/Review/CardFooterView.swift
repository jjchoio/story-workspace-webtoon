//
//  CardFooterView.swift
//  StoryWorkspace
//
//  Card lifecycle actions (D12): Challenge / Renew / Dismiss. In this step they
//  toggle local status only; the real lifecycle lands with the write loop.
//

import SwiftUI

struct CardFooterView: View {
    let onChallenge: () -> Void
    let onRenew: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onChallenge) {
                Label("Challenge", systemImage: "exclamationmark.bubble")
            }
            Button(action: onRenew) {
                Label("Renew", systemImage: "arrow.triangle.2.circlepath")
            }
            Spacer()
            Button("Dismiss", action: onDismiss)
        }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(16)
    }
}
