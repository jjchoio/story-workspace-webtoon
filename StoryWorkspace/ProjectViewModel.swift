//
//  ProjectViewModel.swift
//  StoryWorkspace
//
//  App glue between StoryKit's FileProjectStore and the SwiftUI shell. First
//  launch starts empty; the author imports a .txt episode (v1). Re-importing a
//  (changed) file appends a new immutable version. All parsing/persistence
//  lives in StoryKit — this only orchestrates.
//
//  Phase 1 behavior on re-import is deliberately minimal: parse fresh and store
//  a new version. Replace-with-diff review and content-matching ID stability
//  (D5 / D11) are deferred to Phase 3.
//

import Foundation
import StoryKit

@MainActor
final class ProjectViewModel: ObservableObject {

    struct Loaded {
        var episode: Episode
        var documentID: DocumentID
        var documentName: String
        var version: Int
        var historyCount: Int
        var importedAt: Date
        var storePath: String
        var warnings: [ParseWarning]
    }

    enum State {
        case loading
        case empty
        case loaded(Loaded)
        case failed(String)
    }

    @Published var state: State = .loading

    private let projectName = "CafeAlameda"

    /// On launch: load the existing document if there is one, else stay empty.
    func load() {
        do {
            let url = try projectURL()
            let store = try FileProjectStore(rootDirectory: url)
            if let existing = try store.documents().first {
                state = try loadedState(store: store, id: existing.id, url: url, warnings: [])
            } else {
                state = .empty
            }
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Import a .txt episode. First import creates the document (v1); later
    /// imports append a new version to it.
    func importEpisode(from fileURL: URL) {
        do {
            let text = try readText(fileURL)
            let result = try StoryParser.parse(text)

            let url = try projectURL()
            let store = try FileProjectStore(rootDirectory: url)
            let id: DocumentID
            if let existing = try store.documents().first {
                id = existing.id
                try store.addVersion(
                    to: id, episode: result.episode,
                    provenance: Provenance(action: "reimport", note: fileURL.lastPathComponent)
                )
            } else {
                let name = fileURL.deletingPathExtension().lastPathComponent
                id = try store.createDocument(
                    name: name, episode: result.episode,
                    provenance: Provenance(action: "import", note: fileURL.lastPathComponent)
                )
            }
            state = try loadedState(store: store, id: id, url: url, warnings: result.warnings)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Delete the on-disk project so the app returns to the empty first-launch
    /// state.
    func resetStore() {
        if let url = try? projectURL() {
            try? FileManager.default.removeItem(at: url)
        }
        state = .loading
        load()
    }

    // MARK: Helpers

    private func loadedState(
        store: FileProjectStore, id: DocumentID, url: URL, warnings: [ParseWarning]
    ) throws -> State {
        guard let episode = try store.latestEpisode(of: id) else {
            return .failed("No stored version found for this document.")
        }
        let history = try store.history().filter { $0.documentID == id }
        let doc = try store.documents().first { $0.id == id }
        return .loaded(Loaded(
            episode: episode,
            documentID: id,
            documentName: doc?.name ?? "Document",
            version: history.map(\.version).max() ?? 1,
            historyCount: history.count,
            importedAt: doc?.createdAt ?? Date(),
            storePath: url.path,
            warnings: warnings
        ))
    }

    private func projectURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return base.appendingPathComponent("StoryWorkspace/\(projectName)", isDirectory: true)
    }

    private func readText(_ fileURL: URL) throws -> String {
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
