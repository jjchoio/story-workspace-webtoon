//
//  ReadModeView.swift
//  StoryWorkspace
//
//  Composes the read-mode outline: episode header, optional warnings, then a
//  pinned-header section per cut. Pure renderer — no logic beyond layout.
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
                    WarningsBanner(warnings: warnings)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 8)
                }

                ForEach(Array(episode.cuts.enumerated()), id: \.offset) { entry in
                    Section {
                        CutSectionView(cut: entry.element)
                    } header: {
                        CutHeaderView(number: entry.offset + 1, title: entry.element.title)
                    }
                }

                Color.clear.frame(height: 24)
            }
        }
    }

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
}
