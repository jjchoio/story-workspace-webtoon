//
//  LibrarySidebar.swift
//  StoryWorkspace
//
//  The left column: supporting docs (North Star) grouped above episodes. New
//  documents arrive by dragging a .txt in — then classifying it — or via the +
//  menu; a revised draft updates a specific episode through its right-click
//  menu (a new immutable version). Episodes list in import-date order.
//

import SwiftUI
import StoryKit
import UniformTypeIdentifiers

struct LibrarySidebar: View {
    let documents: [StoredDocument]
    let hasNorthStar: Bool
    let northStarName: String?
    @Binding var selection: LibraryItem?
    let onAddEpisode: (URL) -> Void
    let onUpdateEpisode: (DocumentID, URL) -> Void
    let onImportNorthStar: (URL) -> Void

    @State private var addingEpisode = false
    @State private var settingNorthStar = false
    @State private var updatingEpisode = false
    @State private var updateTargetID: DocumentID?
    @State private var pendingDropURL: URL?
    @State private var classifyingDrop = false

    var body: some View {
        List(selection: $selection) {
            Section("Supporting Docs") {
                if hasNorthStar {
                    Label(northStarName ?? "North Star", systemImage: "star")
                        .lineLimit(1)
                        .tag(LibraryItem.northStar)
                } else {
                    Label("North Star — none yet", systemImage: "star")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Episodes") {
                if documents.isEmpty {
                    Text("Drop a script, or use +")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(documents, id: \.id) { doc in
                    Label(doc.name, systemImage: "doc.text")
                        .lineLimit(1)
                        .tag(LibraryItem.episode(doc.id))
                        .contextMenu {
                            Button("Update…") {
                                updateTargetID = doc.id
                                updatingEpisode = true
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .fileImporter(isPresented: $addingEpisode, allowedContentTypes: [.plainText, .text]) { result in
            if case .success(let url) = result { onAddEpisode(url) }
        }
        .fileImporter(isPresented: $settingNorthStar, allowedContentTypes: [.plainText, .text]) { result in
            if case .success(let url) = result { onImportNorthStar(url) }
        }
        .fileImporter(isPresented: $updatingEpisode, allowedContentTypes: [.plainText, .text]) { result in
            if case .success(let url) = result, let id = updateTargetID { onUpdateEpisode(id, url) }
        }
        .confirmationDialog(
            "Import as", isPresented: $classifyingDrop, presenting: pendingDropURL
        ) { url in
            Button("Episode") { onAddEpisode(url) }
            Button(hasNorthStar ? "North Star (replace)" : "North Star") { onImportNorthStar(url) }
            Button("Cancel", role: .cancel) {}
        } message: { url in
            Text("What kind of document is “\(url.lastPathComponent)”?")
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Add Episode…") { addingEpisode = true }
                Button(hasNorthStar ? "Replace North Star…" : "Set North Star…") { settingNorthStar = true }
            } label: {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    /// A dropped file has a URL but no type — classify it before importing.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) })
        else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                pendingDropURL = url
                classifyingDrop = true
            }
        }
        return true
    }
}
