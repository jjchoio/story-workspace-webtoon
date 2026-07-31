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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.quaternary.opacity(isSelected ? 0 : 0.35), in: RoundedRectangle(cornerRadius: 10))
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
            return Text("\(option.label): ").fontWeight(.medium) + Text("“\(detail)”")
        }
        return Text(option.label).foregroundColor(.secondary) // e.g. "Write your own…"
    }
}
