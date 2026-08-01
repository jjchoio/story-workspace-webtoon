//
//  LineRowView.swift
//  StoryWorkspace
//
//  One top-level line plus its flattened child beats. Speaker in accent,
//  narration plain, short all-caps beats muted; children indented under a guide.
//  Each line (parent or child) is independently selectable for review; a line
//  changed by an accepted review this session highlights and shows Revert.
//

import SwiftUI
import StoryKit

struct LineRowView: View {
    let cutNumber: Int
    let number: Int
    let line: Line
    /// Lines edited by an accepted review this session (highlight + revertable).
    let changedLineIDs: Set<LineID>
    /// The line currently selected for review, if any.
    let reviewAnchor: StoryKit.Anchor?
    /// Toggle the review selection for a (cut, line, child?) — click to deselect.
    let onToggleReviewLine: (Int, Int, Int?) -> Void
    /// Revert a changed line to its pre-Accept text.
    let onRevert: (LineID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            selectableRow(displayNumber: "\(number)", line: line, isChild: false, child: nil)
            if !line.children.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(line.children.enumerated()), id: \.offset) { entry in
                        selectableRow(
                            displayNumber: nil, line: entry.element, isChild: true,
                            child: entry.offset + 1
                        )
                    }
                }
                .padding(.leading, 46)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.quaternary).frame(width: 1).padding(.leading, 38)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// One line wrapped with review selection (tap to toggle), the changed
    /// highlight, and an inline Revert when changed.
    private func selectableRow(displayNumber: String?, line: Line, isChild: Bool, child: Int?) -> some View {
        let isChanged = changedLineIDs.contains(line.id)
        let isSelected = isSelectedForReview(child: child)
        return HStack(spacing: 6) {
            row(number: displayNumber, line: line, isChild: isChild)
            if isChanged {
                Button { onRevert(line.id) } label: {
                    Image(systemName: "arrow.uturn.backward").font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Revert this line")
            }
        }
        .padding(.horizontal, isChanged || isSelected ? 8 : 0)
        .padding(.vertical, isChanged || isSelected ? 4 : 0)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(isSelected ? 0.22 : (isChanged ? 0.14 : 0)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor.opacity(isSelected ? 0.7 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onToggleReviewLine(cutNumber, number, child) }
    }

    private func isSelectedForReview(child: Int?) -> Bool {
        guard let a = reviewAnchor else { return false }
        return a.cut == cutNumber && a.line == number && a.child == child
    }

    private func row(number: String?, line: Line, isChild: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number ?? "")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .trailing)
            SizeChip(size: line.size)
            content(line)
                .font(isChild ? .callout : .body)
                .foregroundStyle(isChild ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    /// Speaker (accent) · text; bare narration plain; short all-caps beats muted.
    private func content(_ line: Line) -> Text {
        if let speaker = line.speaker {
            return Text(speaker).fontWeight(.semibold).foregroundColor(.accentColor)
                + Text("  ·  ").foregroundColor(.secondary)
                + Text(line.text)
        }
        if isBeatMarker(line) {
            return Text(line.text).fontWeight(.medium).foregroundColor(.secondary)
        }
        return Text(line.text)
    }

    private func isBeatMarker(_ line: Line) -> Bool {
        line.size == nil && line.speaker == nil
            && line.text.count <= 12
            && line.text == line.text.uppercased()
            && line.text.allSatisfy { $0.isLetter || $0.isWhitespace }
    }
}
