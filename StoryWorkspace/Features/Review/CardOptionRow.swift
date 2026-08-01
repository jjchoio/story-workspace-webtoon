//
//  CardOptionRow.swift
//  StoryWorkspace
//
//  One selectable option (D3: keep / alternative / author-written). Selection is
//  local highlight for now; applying an option is the Phase 3 write loop.
//

import SwiftUI
import StoryKit

struct CardOptionRow: View {
    let option: CardOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            label
                .fixedSize(horizontal: false, vertical: true) // wrap, don't clip
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                // Opaque chip so a tinted/solid card background doesn't color the
                // buttons — they sit in front of the fill.
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var label: Text {
        if let detail = option.detail {
            // Show the proposed line as-is — it may carry its own quotes, so we
            // don't add another pair (that produced the “"…"” doubling).
            return Text("\(option.label): ").fontWeight(.medium) + Text(detail)
        }
        return Text(option.label).foregroundColor(.secondary) // e.g. "Write your own…"
    }
}
