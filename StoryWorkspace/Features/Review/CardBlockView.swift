//
//  CardBlockView.swift
//  StoryWorkspace
//
//  Schema-driven body block renderer (D9 primitives): quote and text.
//

import SwiftUI
import StoryKit

struct CardBlockView: View {
    let block: CardBlock

    var body: some View {
        switch block {
        case .quote(let speaker, let content):
            // Content is the reviewed line's text as-is (it already carries its
            // own quotes where appropriate) — don't add another pair.
            (speakerText(speaker) + Text(content))
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))

        case .text(let label, let content):
            VStack(alignment: .leading, spacing: 4) {
                if let label {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func speakerText(_ speaker: String?) -> Text {
        guard let speaker else { return Text("") }
        return Text("\(speaker): ").font(.body.weight(.semibold))
    }
}
