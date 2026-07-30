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
    @StateObject private var model = ProjectViewModel()
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
                    model.importEpisode(from: url)
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
            VStack(spacing: 0) {
                ProjectHeaderView(
                    documentName: loaded.documentName,
                    version: loaded.version,
                    importedAt: loaded.importedAt
                )
                Divider()
                ReadModeView(episode: loaded.episode, warnings: loaded.warnings)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if case .loaded(let loaded) = model.state {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { importing = true } label: {
                    Label("Import Update", systemImage: "square.and.arrow.down")
                }
                Button { showingSettings.toggle() } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsPopover(storePath: loaded.storePath) {
                        showingSettings = false
                        model.resetStore()
                    }
                }
            }
        }
    }
}
