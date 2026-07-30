//
//  ContentView.swift
//  StoryWorkspace
//
//  Created by Joshua Choi on 7/27/26.
//

import SwiftUI
import StoryKit
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var model = ProjectViewModel()
    @State private var importing = false
    @State private var showingSettings = false
    @State private var confirmingReset = false

    var body: some View {
        content
            .frame(minWidth: 620, minHeight: 680)
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

    // MARK: State content

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading project…")

        case .empty:
            emptyState

        case .failed(let message):
            ContentUnavailableView(
                "Couldn't load project",
                systemImage: "externaldrive.badge.xmark",
                description: Text(message)
            )

        case .loaded(let loaded):
            VStack(spacing: 0) {
                header(loaded)
                Divider()
                ReadModeView(episode: loaded.episode, warnings: loaded.warnings)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No episode yet", systemImage: "tray")
        } description: {
            Text("Import a script (.txt) in either the Scroll Block or Cut convention.")
        } actions: {
            Button("Import Episode…") { importing = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Title header (below the toolbar)

    private func header(_ loaded: ProjectViewModel.Loaded) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(loaded.documentName)
                    .font(.title.weight(.semibold))
                Text("v\(loaded.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Imported on \(loaded.importedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(.bar)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if case .loaded = model.state {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { importing = true } label: {
                    Label("Import Update", systemImage: "square.and.arrow.down")
                }
                .focusEffectDisabled()
                Button { showingSettings.toggle() } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .focusEffectDisabled()
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    settings
                }
            }
        }
    }

    // MARK: Settings popover

    @ViewBuilder
    private var settings: some View {
        if case .loaded(let loaded) = model.state {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings").font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Store location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(loaded.storePath)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .truncationMode(.middle)
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: loaded.storePath))
                    }
                    .controlSize(.small)
                }

                Divider()

                if confirmingReset {
                    HStack(spacing: 8) {
                        Text("Delete all versions?")
                            .font(.caption)
                        Spacer()
                        Button("Cancel") { confirmingReset = false }
                            .controlSize(.small)
                        Button("Reset", role: .destructive) {
                            confirmingReset = false
                            showingSettings = false
                            model.resetStore()
                        }
                        .controlSize(.small)
                    }
                } else {
                    Button("Reset store…", role: .destructive) { confirmingReset = true }
                        .controlSize(.small)
                }
            }
            .padding(16)
            .frame(width: 320)
            .onDisappear { confirmingReset = false }
        }
    }
}
