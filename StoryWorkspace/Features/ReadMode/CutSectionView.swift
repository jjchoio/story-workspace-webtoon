//
//  CutSectionView.swift
//  StoryWorkspace
//
//  Body of a cut section: optional scene description followed by its lines.
//

import SwiftUI
import StoryKit

struct CutSectionView: View {
    let cut: Cut
    let cutNumber: Int
    let changedLineIDs: Set<LineID>
    let reviewAnchor: StoryKit.Anchor?
    let onToggleReviewLine: (Int, Int, Int?) -> Void
    let onRevert: (LineID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let description = cut.description {
                Text(description)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
            ForEach(Array(cut.lines.enumerated()), id: \.offset) { entry in
                LineRowView(
                    cutNumber: cutNumber,
                    number: entry.offset + 1,
                    line: entry.element,
                    changedLineIDs: changedLineIDs,
                    reviewAnchor: reviewAnchor,
                    onToggleReviewLine: onToggleReviewLine,
                    onRevert: onRevert
                )
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
    }
}
