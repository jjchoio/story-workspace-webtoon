//
//  RootView.swift
//  StoryWorkspace
//
//  Root shell: routes project state (loading / empty / failed / loaded), owns
//  the toolbar, and delegates each surface to a feature view. No domain logic.
//

import SwiftUI
import StoryKit
import UniformTypeIdentifiers

struct RootView: View {
    // Shared across the reader and the floating review-card window (owned by the App).
    @Environment(ProjectViewModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var importing = false
    @State private var showingSettings = false

    var body: some View {
        content
            .frame(minWidth: 620, minHeight: 680)
            .background(WindowFocusResetter())
            .onAppear { if case .loading = model.state { model.load() } }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    model.addEpisode(from: url)
                }
            }
            .toolbar { toolbar }
    }

    // MARK: State routing

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading project…")

        case .empty:
            EmptyProjectView { importing = true }

        case .failed(let message):
            ContentUnavailableView(
                "Couldn't load project",
                systemImage: "externaldrive.badge.xmark",
                description: Text(message)
            )

        case .loaded(let loaded):
            LibraryView(
                loaded: loaded,
                northStar: model.northStar,
                changedLineIDs: model.changedLineIDs,
                onSelectEpisode: { model.selectEpisode($0) },
                onAddEpisode: { model.addEpisode(from: $0) },
                onUpdateEpisode: { model.updateEpisode($0, from: $1) },
                onImportNorthStar: { model.importNorthStar(from: $0) },
                onMoveEpisodes: { model.moveEpisodes(fromOffsets: $0, toOffset: $1) },
                reviewAnchors: model.reviewAnchors,
                onToggleReviewLine: { model.toggleReviewLine(cut: $0, line: $1, child: $2) },
                onRevert: { model.revert(lineID: $0) }
            )
        }
    }

    private var reviewButtonTitle: String {
        let n = model.reviewAnchors.count
        return n > 1 ? "Review \(n) Lines" : "Review Line"
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if case .loaded(let loaded) = model.state {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.requestReview()
                    openWindow(id: "review-card")
                } label: {
                    Label(reviewButtonTitle, systemImage: "sparkles")
                }
                .disabled(model.reviewAnchors.isEmpty)
                .help(model.reviewAnchors.isEmpty ? "Select one or more lines in Read Mode to review" : "Review the selected line(s)")
            }
            // TEMP: open the card-style A/B debug window (drop with CardStyle.swift).
            ToolbarItem(placement: .primaryAction) {
                Button { openWindow(id: "card-style-debug") } label: {
                    Label("Card Style", systemImage: "paintpalette")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingSettings.toggle() } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsPopover(
                        storePath: loaded.storePath,
                        onReset: {
                            showingSettings = false
                            model.resetStore()
                        }
                    )
                }
            }
        }
    }
}
