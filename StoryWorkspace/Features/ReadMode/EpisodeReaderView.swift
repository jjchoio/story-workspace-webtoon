//
//  EpisodeReaderView.swift
//  StoryWorkspace
//
//  Read experience: a sidebar outline (Goal + cuts) beside the detail column,
//  which stacks the project title over the scrolling reading pane. Owns the
//  shared reader selection — clicking the sidebar jumps the pane, and scrolling
//  the pane highlights the current cut.
//

import SwiftUI
import StoryKit

struct EpisodeReaderView: View {
    let documentName: String
    let version: Int
    let importedAt: Date
    let episode: Episode
    let warnings: [ParseWarning]
    let changedLineIDs: Set<LineID>

    @State private var selection: ReaderTarget? = .goal

    var body: some View {
        NavigationSplitView {
            EpisodeOutlineView(episode: episode, selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            VStack(spacing: 0) {
                ProjectHeaderView(
                    documentName: documentName,
                    version: version,
                    importedAt: importedAt
                )
                Divider()
                ReadModeView(
                    episode: episode, warnings: warnings,
                    changedLineIDs: changedLineIDs, selection: $selection
                )
            }
        }
    }
}
