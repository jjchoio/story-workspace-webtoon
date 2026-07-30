//
//  ContentView.swift
//  StoryWorkspace
//
//  Created by Joshua Choi on 7/27/26.
//

import SwiftUI
import StoryKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = ProjectViewModel()
    @State private var importing = false

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView("Loading project…")

            case .empty:
                ContentUnavailableView {
                    Label("No episode yet", systemImage: "tray")
                } description: {
                    Text("Import a script (.txt) in either the Scroll Block or Cut convention.")
                } actions: {
                    Button("Import Episode…") { importing = true }
                        .buttonStyle(.borderedProminent)
                }

            case .failed(let message):
                ContentUnavailableView(
                    "Couldn't load project",
                    systemImage: "externaldrive.badge.xmark",
                    description: Text(message)
                )

            case .loaded(let loaded):
                VStack(spacing: 0) {
                    statusBar(loaded)
                    Divider()
                    ReadModeView(episode: loaded.episode, warnings: loaded.warnings)
                }
            }
        }
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
    }

    private func statusBar(_ loaded: ProjectViewModel.Loaded) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loaded.documentName).font(.headline)
                    Text("v\(loaded.version) · \(loaded.historyCount) history \(loaded.historyCount == 1 ? "entry" : "entries")")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Imported \(loaded.importedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Import updated version…") { importing = true }
                Button("Reset store", role: .destructive) { model.resetStore() }
            }
            Text(loaded.storePath)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4))
    }
}
