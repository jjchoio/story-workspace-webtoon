//
//  ReadModeView.swift
//  StoryWorkspace
//
//  Pure renderer for a canonical Episode: an outline of cuts with per-cut
//  EP / Cut / Line addressing, color-coded size chips, inline speakers, and
//  nested child beats. Loading/persistence lives in ProjectViewModel; this view
//  only lays out the model it is handed (CLAUDE.md: keep logic out of the shell).
//

import SwiftUI
import StoryKit

struct ReadModeView: View {
    let episode: Episode
    let warnings: [ParseWarning]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                episodeHeader
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 8)

                if !warnings.isEmpty {
                    warningsBanner
                        .padding(.horizontal, 28)
                        .padding(.bottom, 8)
                }

                ForEach(Array(episode.cuts.enumerated()), id: \.offset) { entry in
                    Section {
                        cutBody(entry.element)
                    } header: {
                        cutHeader(number: entry.offset + 1, title: entry.element.title)
                    }
                }
                Color.clear.frame(height: 24)
            }
        }
    }

    // MARK: Episode header

    private var episodeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let goal = episode.goal {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "target").foregroundStyle(.tint)
                    Text(goal).font(.title3.weight(.semibold))
                }
            }
            Text("\(episode.cuts.count) cuts · \(episode.lineCount) lines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var warningsBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { entry in
                Label(entry.element.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.primary)
    }

    // MARK: Cut

    private func cutHeader(number: Int, title: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 4, height: 20)
            (Text("Cut \(number)").foregroundColor(.accentColor) + Text("  " + title))
                .font(.headline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func cutBody(_ cut: Cut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let description = cut.description {
                Text(description)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
            ForEach(Array(cut.lines.enumerated()), id: \.offset) { entry in
                lineBlock(number: entry.offset + 1, line: entry.element)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
    }

    // MARK: Lines

    private func lineBlock(number: Int, line: Line) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            row(number: "\(number)", line: line, isChild: false)
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
            sizeChip(line.size)
            lineContent(line)
                .font(isChild ? .callout : .body)
                .foregroundStyle(isChild ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    /// Speaker (accent) · text; bare narration plain; short all-caps beats muted.
    private func lineContent(_ line: Line) -> Text {
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

    // MARK: Size chip

    @ViewBuilder
    private func sizeChip(_ size: SizeCode?) -> some View {
        ZStack {
            if let size {
                Text(size.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sizeColor(size))
                    .frame(width: 20, height: 18)
                    .background(sizeColor(size).opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .frame(width: 20, height: 18)
    }

    private func sizeColor(_ size: SizeCode) -> Color {
        switch size {
        case .s: return .blue
        case .m: return .orange
        case .l: return .purple
        }
    }
}
