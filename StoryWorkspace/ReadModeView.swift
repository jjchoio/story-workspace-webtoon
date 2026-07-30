//
//  ReadModeView.swift
//  StoryWorkspace
//
//  Pure renderer for a canonical Episode with per-cut EP / Cut / Line
//  addressing. Loading/persistence lives in ProjectViewModel; this view only
//  lays out the model it is handed (CLAUDE.md: keep logic out of the shell).
//

import SwiftUI
import StoryKit

struct ReadModeView: View {
    let episode: Episode
    let warnings: [ParseWarning]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !warnings.isEmpty {
                    warningsBanner(warnings)
                }
                ForEach(Array(episode.cuts.enumerated()), id: \.offset) { cutIndex, cut in
                    cutView(number: cutIndex + 1, cut: cut)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Read Mode")
                .font(.largeTitle.weight(.bold))
            Text("\(episode.cuts.count) cuts · \(episode.lineCount) lines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let goal = episode.goal {
                Label(goal, systemImage: "target")
                    .font(.callout)
                    .padding(.top, 2)
            }
        }
    }

    private func warningsBanner(_ warnings: [ParseWarning]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, w in
                Label(w.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }

    private func cutView(number: Int, cut: Cut) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cut \(number): \(cut.title)")
                .font(.title2.weight(.semibold))
            if let description = cut.description {
                Text(description)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(cut.lines.enumerated()), id: \.offset) { lineIndex, line in
                lineView(cut: number, number: lineIndex + 1, line: line)
            }
        }
        .padding(.bottom, 8)
    }

    private func lineView(cut: Int, number: Int, line: Line) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            lineRow(address: "EP / C\(cut) / L\(number)", line: line)
            ForEach(Array(line.children.enumerated()), id: \.offset) { childIndex, child in
                lineRow(address: "\(number).\(childIndex + 1)", line: child)
                    .padding(.leading, 28)
            }
        }
    }

    private func lineRow(address: String, line: Line) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(address)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .leading)
            if let size = line.size {
                Text(size.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.tint.opacity(0.2), in: Capsule())
            }
            (speakerText(line.speaker) + Text(line.text))
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private func speakerText(_ speaker: String?) -> Text {
        guard let speaker else { return Text("") }
        return Text("\(speaker): ").font(.body.weight(.semibold))
    }
}
