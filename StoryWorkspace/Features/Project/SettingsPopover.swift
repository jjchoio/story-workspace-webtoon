//
//  SettingsPopover.swift
//  StoryWorkspace
//
//  Settings popover from the toolbar gear: store location + reveal, and a
//  confirm-gated reset (kept out of the toolbar so it can't be hit by accident).
//

import SwiftUI
import AppKit

struct SettingsPopover: View {
    let storePath: String
    let onReset: () -> Void

    @State private var confirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Store location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(storePath)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .truncationMode(.middle)
                Button("Reveal in Finder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: storePath))
                }
                .controlSize(.small)
            }

            Divider()

            if confirmingReset {
                HStack(spacing: 8) {
                    Text("Delete all versions?").font(.caption)
                    Spacer()
                    Button("Cancel") { confirmingReset = false }
                        .controlSize(.small)
                    Button("Reset", role: .destructive) {
                        confirmingReset = false
                        onReset()
                    }
                    .controlSize(.small)
                }
            } else {
                Button("Reset store…", role: .destructive) { confirmingReset = true }
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onDisappear { confirmingReset = false }
    }
}
