//
//  ReadModeView.swift
//  StoryWorkspace
//
//  Phase 1 read-mode render: parse a bundled fixture via StoryKit and show the
//  full episode with per-cut EP / Cut / Line addressing. Thin shell — all logic
//  lives in StoryKit; this view only lays the canonical model out.
//

import SwiftUI
import StoryKit

struct ReadModeView: View {
    /// Fixture bundled with the app (see StoryWorkspace/EP2-clened.txt).
    let fixtureName = "EP2-clened"

    var body: some View {
        Group {
            switch load() {
            case .success(let result):
                episodeView(result)
            case .failure(let error):
                ContentUnavailableView(
                    "Couldn't load fixture",
                    systemImage: "doc.questionmark",
                    description: Text(error.message)
                )
            }
        }
        .frame(minWidth: 560, minHeight: 640)
    }

    // MARK: Rendering

    private func episodeView(_ result: ParseResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(result)
                if !result.warnings.isEmpty {
                    warningsBanner(result.warnings)
                }
                ForEach(Array(result.episode.cuts.enumerated()), id: \.offset) { cutIndex, cut in
                    cutView(number: cutIndex + 1, cut: cut)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ result: ParseResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EP2 — Read Mode")
                .font(.largeTitle.weight(.bold))
            Text("\(result.detectedConvention == .legacyScrollBlock ? "Legacy Scroll Block" : "Cut") convention · \(result.episode.cuts.count) cuts · \(result.episode.lineCount) lines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let goal = result.episode.goal {
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
            lineRow(address: "EP2 / C\(cut) / L\(number)", line: line)
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

    // MARK: Loading

    private func load() -> Result<ParseResult, LoadError> {
        guard let url = Bundle.main.url(forResource: fixtureName, withExtension: "txt") else {
            return .failure(LoadError(message: "\(fixtureName).txt is not in the app bundle. Confirm it has StoryWorkspace target membership."))
        }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            return .success(try StoryParser.parse(text))
        } catch {
            return .failure(LoadError(message: String(describing: error)))
        }
    }

    private struct LoadError: Error {
        let message: String
    }
}

#Preview {
    ReadModeView()
}
