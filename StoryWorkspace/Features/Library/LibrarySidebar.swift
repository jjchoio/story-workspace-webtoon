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
    let onMoveEpisodes: (IndexSet, Int) -> Void

    /// What a triggered file pick will do when it completes. A SINGLE
    /// fileImporter is driven by this — stacking multiple `.fileImporter`
    /// modifiers on one view makes all but one silently never present.
    private enum ImportKind {
        case episode
        case northStar
        case update(DocumentID)
    }

    @State private var importing = false
    @State private var pendingImport: ImportKind = .episode
    @State private var pendingDropURL: URL?
    @State private var classifyingDrop = false

    var body: some View {
        List(selection: $selection) {
            Section("Supporting Docs") {
                if hasNorthStar {
                    Label(northStarName ?? "North Star", systemImage: "star")
                        .lineLimit(1)
                        .tag(LibraryItem.northStar)
                        .contextMenu {
                            Button("Replace North Star…") { beginImport(.northStar) }
                        }
                } else {
                    // No North Star yet — the row itself uploads one (tap), and
                    // dropping a file still works via the classify dialog.
                    Button { beginImport(.northStar) } label: {
                        Label("Set North Star…", systemImage: "star")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
                            Button("Update…") { beginImport(.update(doc.id)) }
                        }
                }
                .onMove(perform: onMoveEpisodes)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .text]) { result in
            guard case .success(let url) = result else { return }
            switch pendingImport {
            case .episode: onAddEpisode(url)
            case .northStar: onImportNorthStar(url)
            case .update(let id): onUpdateEpisode(id, url)
            }
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
                Button("Add Episode…") { beginImport(.episode) }
                Button(hasNorthStar ? "Replace North Star…" : "Set North Star…") { beginImport(.northStar) }
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

    private func beginImport(_ kind: ImportKind) {
        pendingImport = kind
        importing = true
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
