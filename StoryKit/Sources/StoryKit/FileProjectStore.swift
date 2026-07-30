import Foundation

// v1 ProjectStore (D14): a per-project directory of human-readable JSON, one
// file per entity, an append-only JSONL history, and immutable versioned
// document snapshots (a new version is a new file — nothing is ever rewritten).
//
//   <root>/
//     project.json                 written once: {id, name, createdAt}
//     documents/<docID>/
//       created.json               written once: {id, name, createdAt}
//       v0001.json ...             immutable Episode snapshots
//     history.jsonl                append-only, one record per line

public final class FileProjectStore: ProjectStore {
    public let rootDirectory: URL

    private let fm = FileManager.default
    private let entityEncoder: JSONEncoder   // pretty, for readable entity files
    private let lineEncoder: JSONEncoder     // compact, one JSONL record per line
    private let decoder: JSONDecoder

    /// Opens the project at `rootDirectory`, creating it (and project.json) if
    /// it does not yet exist.
    public init(rootDirectory: URL) throws {
        self.rootDirectory = rootDirectory

        entityEncoder = JSONEncoder()
        entityEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        entityEncoder.dateEncodingStrategy = .iso8601

        lineEncoder = JSONEncoder()
        lineEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        lineEncoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try ensureProject()
    }

    // MARK: ProjectStore

    public func createDocument(
        name: String, episode: Episode, provenance: Provenance
    ) throws -> DocumentID {
        let id = DocumentID(UUID().uuidString)
        let dir = documentDirectory(id)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let meta = StoredDocument(id: id, name: name, createdAt: Date())
        try write(meta, to: dir.appendingPathComponent("created.json"))

        try writeVersion(1, episode: episode, in: dir)
        try appendHistory(HistoryEntry(documentID: id, version: 1, provenance: provenance))
        return id
    }

    @discardableResult
    public func addVersion(
        to id: DocumentID, episode: Episode, provenance: Provenance
    ) throws -> Int {
        let dir = documentDirectory(id)
        guard fm.fileExists(atPath: dir.path) else {
            throw StoreError.unknownDocument(id)
        }
        let next = (latestVersionNumber(in: dir) ?? 0) + 1
        try writeVersion(next, episode: episode, in: dir)
        try appendHistory(HistoryEntry(documentID: id, version: next, provenance: provenance))
        return next
    }

    public func latestEpisode(of id: DocumentID) throws -> Episode? {
        let dir = documentDirectory(id)
        guard let (_, url) = latestVersionFile(in: dir) else { return nil }
        return try decoder.decode(Episode.self, from: Data(contentsOf: url))
    }

    public func documents() throws -> [StoredDocument] {
        let docsDir = documentsDirectory
        guard fm.fileExists(atPath: docsDir.path) else { return [] }
        let subdirs = try fm.contentsOfDirectory(
            at: docsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )
        let metas: [StoredDocument] = try subdirs.compactMap { dir in
            let metaURL = dir.appendingPathComponent("created.json")
            guard fm.fileExists(atPath: metaURL.path) else { return nil }
            return try decoder.decode(StoredDocument.self, from: Data(contentsOf: metaURL))
        }
        return metas.sorted { $0.createdAt < $1.createdAt }
    }

    public func history() throws -> [HistoryEntry] {
        guard fm.fileExists(atPath: historyURL.path) else { return [] }
        let text = try String(contentsOf: historyURL, encoding: .utf8)
        return try text.split(separator: "\n").map { line in
            try decoder.decode(HistoryEntry.self, from: Data(line.utf8))
        }
    }

    public enum StoreError: Error, Equatable {
        case unknownDocument(DocumentID)
    }

    // MARK: Layout

    private var projectFileURL: URL { rootDirectory.appendingPathComponent("project.json") }
    private var documentsDirectory: URL { rootDirectory.appendingPathComponent("documents", isDirectory: true) }
    private var historyURL: URL { rootDirectory.appendingPathComponent("history.jsonl") }
    private func documentDirectory(_ id: DocumentID) -> URL {
        documentsDirectory.appendingPathComponent(id.rawValue, isDirectory: true)
    }

    private func ensureProject() throws {
        try fm.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: projectFileURL.path) {
            let project = StoredDocument(
                id: DocumentID(UUID().uuidString),
                name: rootDirectory.lastPathComponent,
                createdAt: Date()
            )
            try write(project, to: projectFileURL)
        }
    }

    // MARK: Versions

    /// Immutable version files are named `v0001.json`, `v0002.json`, …
    private func writeVersion(_ n: Int, episode: Episode, in dir: URL) throws {
        let url = dir.appendingPathComponent(versionFileName(n))
        // Never overwrite an existing version — versions are immutable.
        guard !fm.fileExists(atPath: url.path) else { return }
        try write(episode, to: url)
    }

    private func versionFileName(_ n: Int) -> String {
        String(format: "v%04d.json", n)
    }

    private func versionFiles(in dir: URL) -> [(Int, URL)] {
        let contents = (try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return contents.compactMap { url in
            let name = url.lastPathComponent
            guard name.hasPrefix("v"), name.hasSuffix(".json"),
                  let n = Int(name.dropFirst().dropLast(5)) else { return nil }
            return (n, url)
        }.sorted { $0.0 < $1.0 }
    }

    private func latestVersionFile(in dir: URL) -> (Int, URL)? { versionFiles(in: dir).last }
    private func latestVersionNumber(in dir: URL) -> Int? { latestVersionFile(in: dir)?.0 }

    // MARK: IO helpers

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try entityEncoder.encode(value).write(to: url, options: .atomic)
    }

    private func appendHistory(_ entry: HistoryEntry) throws {
        let line = try lineEncoder.encode(entry) + Data("\n".utf8)
        if let handle = try? FileHandle(forWritingTo: historyURL) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: historyURL, options: .atomic)
        }
    }
}
