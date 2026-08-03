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
    /// The lines currently selected for review (multi-select).
    let reviewAnchors: [StoryKit.Anchor]
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
        .modifier(ReviewHighlight(isChanged: isChanged, isSelected: isSelected))
        .contentShape(Rectangle())
        .onTapGesture { onToggleReviewLine(cutNumber, number, child) }
    }

    private func isSelectedForReview(child: Int?) -> Bool {
        reviewAnchors.contains { $0.cut == cutNumber && $0.line == number && $0.child == child }
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

/// Read-Mode line highlight: a subtle **grey** wash when the line is selected
/// for review, turning **green** once an accepted change lands — with a one-shot
/// 1.5s "bloom" (an expanding green glow) on that transition. Revert drops it
/// back to grey. Each row owns its own bloom state via this modifier.
private struct ReviewHighlight: ViewModifier {
    let isChanged: Bool
    let isSelected: Bool

    @State private var bloom: CGFloat = 0 // 0 idle → 1 fully bloomed

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, isActive ? 8 : 0)
            .padding(.vertical, isActive ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: 6).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(border, lineWidth: 1))
            .overlay {
                if isChanged {
                    // Bloom by swelling the stroke's thickness (and softening it)
                    // in place, rather than scaling the whole rect outward.
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CardAccent.accepted.opacity(0.6 * (1 - bloom)), lineWidth: 2 + 12 * bloom)
                        .blur(radius: 5 * bloom)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.12), value: isSelected) // near-instant select
            .animation(.easeOut(duration: 0.2), value: isChanged)   // quick turn to green
            .onChange(of: isChanged) { _, changed in
                if changed {
                    bloom = 0
                    withAnimation(.easeOut(duration: 2.0)) { bloom = 1 }
                } else {
                    bloom = 0
                }
            }
    }

    private var isActive: Bool { isChanged || isSelected }
    private var fill: Color {
        if isChanged { return CardAccent.accepted.opacity(0.22) }
        if isSelected { return Color.gray.opacity(0.16) }
        return .clear
    }
    private var border: Color {
        if isChanged { return CardAccent.accepted.opacity(0.55) }
        if isSelected { return Color.gray.opacity(0.45) }
        return .clear
    }
}
