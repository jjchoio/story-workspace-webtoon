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
    @State private var model = ProjectViewModel()
    @State private var importing = false
    @State private var showingSettings = false
    @State private var showingCard = false // TEMP (Phase 2 step 5 demo)

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
            .sheet(isPresented: $showingCard) { cardSheet }
    }

    // TEMP (Phase 2 step 5 demo): preview the sample card before the review flow
    // exists. Remove with SampleCard + bundled JSON when step 6 lands.
    private var cardSheet: some View {
        VStack(spacing: 16) {
            if let card = SampleCard.load() {
                CardView(card: card)
            } else {
                Text("sample-card.json is missing from the app bundle.")
            }
            Button("Close") { showingCard = false }
        }
        .padding(24)
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
            EpisodeReaderView(
                documentName: loaded.documentName,
                version: loaded.version,
                importedAt: loaded.importedAt,
                episode: loaded.episode,
                warnings: loaded.warnings
            )
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if case .loaded(let loaded) = model.state {
            // TEMP (Phase 2 step 5 demo): preview the sample card. Remove at step 6.
            ToolbarItem(placement: .primaryAction) {
                Button { showingCard = true } label: {
                    Label("Sample Card", systemImage: "rectangle.on.rectangle.angled")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingSettings.toggle() } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsPopover(
                        storePath: loaded.storePath,
                        onImport: {
                            showingSettings = false
                            importing = true
                        },
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
