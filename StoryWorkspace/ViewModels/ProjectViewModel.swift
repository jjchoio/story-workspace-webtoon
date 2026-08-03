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
import Observation
import StoryKit

@MainActor
@Observable
final class ProjectViewModel {

    struct Loaded {
        /// Every episode in the project, in import-date order — the library.
        var documents: [StoredDocument]
        /// Which episode is currently open in the reader.
        var selectedDocumentID: DocumentID
        var episode: Episode
        var documentName: String
        var version: Int
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

    var state: State = .loading

    /// Lines edited by an accepted review this session — the reader highlights
    /// them. Reset on reload; the highlight is "what changed this session," not a
    /// persisted attribute.
    private(set) var changedLineIDs: Set<LineID> = []

    /// The project's North Star (shared reviewer context), loaded from the store.
    /// Independent of the loaded episode — it grounds every review.
    private(set) var northStar: NorthStar?

    /// The lines the author has selected in Read Mode to review. SCALE: a set of
    /// explicit lines now (one card per line); a higher-level scope (cut /
    /// episode) with AI-chosen cards is the next phase. Clears when the open
    /// episode changes.
    private(set) var reviewAnchors: [Anchor] = []

    /// Bumped each time the author presses Review, so the review window re-runs
    /// for the current selection even when it is already open.
    private(set) var reviewRequestID = 0

    /// Pre-change text captured at Accept, keyed by the changed line's id, so a
    /// change can be reverted this session (D14: revert appends a restoring
    /// version, it does not roll one back). Cleared when a new review begins.
    private var revertInfo: [LineID: (anchor: Anchor, previousText: String, reviewer: String)] = [:]

    private let projectName = "CafeAlameda"

    /// On launch: load the existing document if there is one, else stay empty.
    func load() {
        do {
            let url = try projectURL()
            let store = try FileProjectStore(rootDirectory: url)
            northStar = try store.loadNorthStar()
            if let existing = try store.documents().first {
                state = try loadedState(store: store, id: existing.id, url: url, warnings: [])
            } else {
                state = .empty
            }
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Add a .txt as a new, independent episode document (v1) and open it.
    /// Distinct episodes are always separate documents; a revised draft of an
    /// existing episode is an Update (see `updateEpisode`), not an add.
    func addEpisode(from fileURL: URL) {
        do {
            let text = try readText(fileURL)
            let result = try StoryParser.parse(text)
            let url = try projectURL()
            let store = try FileProjectStore(rootDirectory: url)
            let name = fileURL.deletingPathExtension().lastPathComponent
            let id = try store.createDocument(
                name: name, episode: result.episode,
                provenance: Provenance(action: "import", note: fileURL.lastPathComponent)
            )
            reviewAnchors = []
            changedLineIDs = []
            revertInfo = [:]
            state = try loadedState(store: store, id: id, url: url, warnings: result.warnings)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Update a specific episode with a revised draft: append a new immutable
    /// version to that document (D14 version control) and open it.
    func updateEpisode(_ id: DocumentID, from fileURL: URL) {
        do {
            let text = try readText(fileURL)
            let result = try StoryParser.parse(text)
            let url = try projectURL()
            let store = try FileProjectStore(rootDirectory: url)
            try store.addVersion(
                to: id, episode: result.episode,
                provenance: Provenance(action: "reimport", note: fileURL.lastPathComponent)
            )
            reviewAnchors = []
            changedLineIDs = []
            revertInfo = [:]
            state = try loadedState(store: store, id: id, url: url, warnings: result.warnings)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Reorder episodes in the library (drag-reorder) and persist the new order.
    func moveEpisodes(fromOffsets: IndexSet, toOffset: Int) {
        guard case .loaded(var loaded) = state else { return }
        loaded.documents.move(fromOffsets: fromOffsets, toOffset: toOffset)
        do {
            let store = try FileProjectStore(rootDirectory: try projectURL())
            try store.setDocumentOrder(loaded.documents.map(\.id))
        } catch {
            // Keep the in-memory reorder even if persisting the order fails.
        }
        state = .loaded(loaded)
    }

    /// Open a different episode from the library.
    func selectEpisode(_ id: DocumentID) {
        guard case .loaded(let loaded) = state, loaded.selectedDocumentID != id else { return }
        do {
            let url = try projectURL()
            let store = try FileProjectStore(rootDirectory: url)
            reviewAnchors = [] // selection belongs to the previously open episode
            changedLineIDs = []
            revertInfo = [:]
            state = try loadedState(store: store, id: id, url: url, warnings: [])
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Toggle the review selection for a line in the open episode (click again
    /// to deselect). The episode label is derived for display only — the cut and
    /// line index the currently open episode.
    func toggleReviewLine(cut: Int, line: Int, child: Int?) {
        guard case .loaded(let loaded) = state else { return }
        let anchor = Anchor(episode: episodeLabel(loaded.documentName), cut: cut, line: line, child: child)
        if let index = reviewAnchors.firstIndex(of: anchor) {
            reviewAnchors.remove(at: index)
        } else {
            reviewAnchors.append(anchor)
        }
    }

    /// Request a review of the current selection (bumps the trigger the review
    /// window watches). Starting a new review clears the prior session's change
    /// highlight and Revert affordances.
    func requestReview() {
        guard !reviewAnchors.isEmpty else { return }
        changedLineIDs = []
        revertInfo = [:]
        reviewRequestID += 1
    }

    /// Revert a changed line to its pre-Accept text (D14: append a restoring
    /// version, never roll back). Drops the line's highlight/Revert.
    func revert(lineID: LineID) {
        guard case .loaded(var loaded) = state, let info = revertInfo[lineID],
              let result = loaded.episode.applyingText(info.previousText, at: info.anchor)
        else { return }
        loaded.episode = result.episode
        changedLineIDs.remove(lineID)
        revertInfo[lineID] = nil
        do {
            let store = try FileProjectStore(rootDirectory: try projectURL())
            let a = info.anchor
            let note = "revert · \(info.reviewer) @ \(a.episode)/Cut\(a.cut)/Line\(a.line)\(a.child.map { ".\($0)" } ?? "")"
            let newVersion = try store.addVersion(
                to: loaded.selectedDocumentID, episode: result.episode,
                provenance: Provenance(action: "revert", note: note)
            )
            loaded.version = newVersion
        } catch {}
        state = .loaded(loaded)
    }

    /// Import (or replace) the project's North Star from a .txt file. Stored
    /// verbatim, overwriting any previous one; does not touch the episode. Kept
    /// silent on failure (the previous North Star, if any, stays in place) —
    /// reading a plain-text file the user just picked rarely fails.
    func importNorthStar(from fileURL: URL) {
        do {
            let text = try readText(fileURL)
            let store = try FileProjectStore(rootDirectory: try projectURL())
            let star = NorthStar(text: text, sourceFilename: fileURL.lastPathComponent)
            try store.saveNorthStar(star)
            northStar = star
        } catch {
            // Leave the previous North Star untouched.
        }
    }

    /// Apply an accepted review option to the document (D3: only explicit author
    /// action mutates). `.alternative` uses the option's detail, `.authorWritten`
    /// the author's typed line; `.keep` is an endorsement with no edit. A text
    /// change patches the in-memory episode, highlights the line, and persists a
    /// new immutable version with provenance (D4/D14).
    func accept(option: CardOption, anchor: Anchor, reviewer: String, authoredText: String? = nil) {
        guard case .loaded(var loaded) = state else { return }

        let rawText: String?
        switch option.kind {
        case .alternative: rawText = option.detail
        case .authorWritten: rawText = authoredText
        case .keep: rawText = nil // endorsement — no edit, no new version
        }
        let targetLine = loaded.episode.line(at: anchor)
        let previousText = targetLine?.text
        guard let rawText else { return }
        // Format the replacement to the target line's convention (drop a stray
        // speaker prefix, mirror its quotes) so speaker + quotes are preserved.
        let newText = targetLine?.formattedReplacement(rawText)
            ?? rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty,
              let result = loaded.episode.applyingText(newText, at: anchor)
        else { return }

        loaded.episode = result.episode
        changedLineIDs.insert(result.changed)
        if revertInfo[result.changed] == nil, let previousText {
            revertInfo[result.changed] = (anchor: anchor, previousText: previousText, reviewer: reviewer)
        }

        do {
            let store = try FileProjectStore(rootDirectory: try projectURL())
            let note = "\(reviewer) · \(option.label) @ \(anchor.episode)/Cut\(anchor.cut)/Line\(anchor.line)"
            let newVersion = try store.addVersion(
                to: loaded.selectedDocumentID, episode: result.episode,
                provenance: Provenance(action: "accept", note: note)
            )
            loaded.version = newVersion
        } catch {
            // Keep the in-memory edit + highlight even if the write fails; the
            // version counter just won't advance.
        }
        state = .loaded(loaded)
    }

    /// Delete the on-disk project so the app returns to the empty first-launch
    /// state.
    func resetStore() {
        if let url = try? projectURL() {
            try? FileManager.default.removeItem(at: url)
        }
        changedLineIDs = []
        revertInfo = [:]
        northStar = nil
        reviewAnchors = []
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
        let documents = try store.documents()
        let history = try store.history().filter { $0.documentID == id }
        let doc = documents.first { $0.id == id }
        return .loaded(Loaded(
            documents: documents,
            selectedDocumentID: id,
            episode: episode,
            documentName: doc?.name ?? "Document",
            version: history.map(\.version).max() ?? 1,
            importedAt: doc?.createdAt ?? Date(),
            storePath: url.path,
            warnings: warnings
        ))
    }

    /// A short episode label for anchors/cards ("EP2", "Episode 2") pulled from
    /// the document name; falls back to the name when no episode number is found.
    private func episodeLabel(_ name: String) -> String {
        if let r = name.range(of: #"EP\s*\d+"#, options: [.regularExpression, .caseInsensitive]) {
            return name[r].replacingOccurrences(of: " ", with: "").uppercased()
        }
        if let r = name.range(of: #"Episode\s*\d+"#, options: [.regularExpression, .caseInsensitive]) {
            return String(name[r])
        }
        return name
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
