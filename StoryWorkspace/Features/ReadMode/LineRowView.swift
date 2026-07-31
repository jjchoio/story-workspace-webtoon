//
//  LineRowView.swift
//  StoryWorkspace
//
//  One top-level line plus its flattened child beats. Speaker in accent,
//  narration plain, short all-caps beats muted; children indented under a guide.
//

import SwiftUI
import StoryKit

struct LineRowView: View {
    let number: Int
    let line: Line
    /// True when an accepted review edited this line this session — subtly
    /// highlighted so the author sees what changed.
    var isChanged: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            row(number: "\(number)", line: line, isChild: false)
                .padding(.horizontal, isChanged ? 8 : 0)
                .padding(.vertical, isChanged ? 4 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(isChanged ? 0.14 : 0))
                )
            if !line.children.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(line.children.enumerated()), id: \.offset) { entry in
                        row(number: nil, line: entry.element, isChild: true)
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
