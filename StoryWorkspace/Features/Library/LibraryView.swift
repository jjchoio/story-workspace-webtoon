//
//  LibraryView.swift
//  StoryWorkspace
//
//  Three-column reading shell (macOS source-list pattern): Library (supporting
//  docs + episodes) → Outline (the selected episode's goal + cuts) → Reading
//  (the episode text, or the North Star). Selecting an episode loads it; the
//  outline is empty and the reading pane shows the North Star when a supporting
//  doc is selected.
//

import SwiftUI
import StoryKit

struct LibraryView: View {
    let loaded: ProjectViewModel.Loaded
    let northStar: NorthStar?
    let changedLineIDs: Set<LineID>
    let onSelectEpisode: (DocumentID) -> Void
    let onAddEpisode: (URL) -> Void
    let onUpdateEpisode: (DocumentID, URL) -> Void
    let onImportNorthStar: (URL) -> Void
    let onMoveEpisodes: (IndexSet, Int) -> Void

    @State private var selection: LibraryItem?
    @State private var readerTarget: ReaderTarget? = .goal

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(
                documents: loaded.documents,
                hasNorthStar: northStar != nil,
                northStarName: northStar?.sourceFilename,
                selection: $selection,
                onAddEpisode: onAddEpisode,
                onUpdateEpisode: onUpdateEpisode,
                onImportNorthStar: onImportNorthStar,
                onMoveEpisodes: onMoveEpisodes
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
        } content: {
            outlineColumn
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            readingColumn
        }
        .onAppear {
            if selection == nil { selection = .episode(loaded.selectedDocumentID) }
        }
        .onChange(of: selection) { _, new in
            if case .episode(let id) = new, id != loaded.selectedDocumentID {
                readerTarget = .goal
                onSelectEpisode(id)
            }
        }
    }

    // MARK: Columns

    @ViewBuilder
    private var outlineColumn: some View {
        switch selection {
        case .episode:
            EpisodeOutlineView(episode: loaded.episode, selection: $readerTarget)
        default:
            // A supporting doc has no sub-outline — read straight through.
            Color.clear
        }
    }

    @ViewBuilder
    private var readingColumn: some View {
        switch selection {
        case .northStar:
            NorthStarView(northStar: northStar)
        default:
            VStack(spacing: 0) {
                ProjectHeaderView(
                    documentName: loaded.documentName,
                    version: loaded.version,
                    importedAt: loaded.importedAt
                )
                Divider()
                ReadModeView(
                    episode: loaded.episode, warnings: loaded.warnings,
                    changedLineIDs: changedLineIDs, selection: $readerTarget
                )
            }
        }
    }
}
