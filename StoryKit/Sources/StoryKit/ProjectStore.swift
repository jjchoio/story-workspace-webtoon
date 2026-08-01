import Foundation

// Persistence boundary (D14). All project access goes through this protocol so
// the storage backend can be swapped without touching callers. FileProjectStore
// is the v1 implementation. Phase 1 scope: documents + append-only history only
// — cards, sessions, and the memory tiers (D13) come later and are not modeled
// here yet.

/// Stable identifier for a stored document (an imported episode and its
/// version lineage).
public struct DocumentID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Metadata for a document in the project (its versions are stored separately).
public struct StoredDocument: Equatable, Sendable, Codable {
    public var id: DocumentID
    public var name: String
    public var createdAt: Date

    public init(id: DocumentID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

/// Why a version came to exist (D4). The card/option link arrives in Phase 3.
public struct Provenance: Equatable, Sendable, Codable {
    public var action: String       // e.g. "import", "reupload", "patch"
    public var timestamp: Date
    public var note: String?

    public init(action: String, timestamp: Date = Date(), note: String? = nil) {
        self.action = action
        self.timestamp = timestamp
        self.note = note
    }
}

/// One append-only history record (a line in history.jsonl).
public struct HistoryEntry: Equatable, Sendable, Codable {
    public var documentID: DocumentID
    public var version: Int
    public var provenance: Provenance

    public init(documentID: DocumentID, version: Int, provenance: Provenance) {
        self.documentID = documentID
        self.version = version
        self.provenance = provenance
    }
}

public protocol ProjectStore {
    /// Create a new document from its first episode version. Returns its id.
    func createDocument(name: String, episode: Episode, provenance: Provenance) throws -> DocumentID

    /// Append a new immutable version of an existing document. Returns the new
    /// version number.
    @discardableResult
    func addVersion(to id: DocumentID, episode: Episode, provenance: Provenance) throws -> Int

    /// The latest stored episode for a document, or nil if unknown/empty.
    func latestEpisode(of id: DocumentID) throws -> Episode?

    /// All documents in the project, in the author's saved order (falling back
    /// to import date for any not yet ordered).
    func documents() throws -> [StoredDocument]

    /// Persist an explicit document ordering (e.g. after a drag-reorder). IDs
    /// not listed sort after the listed ones, by import date.
    func setDocumentOrder(_ ids: [DocumentID]) throws

    /// The full append-only history, in write order.
    func history() throws -> [HistoryEntry]

    /// The project's North Star (shared reviewer context), or nil if none has
    /// been imported.
    func loadNorthStar() throws -> NorthStar?

    /// Save (or replace) the project's North Star. Overwrites in place — unlike
    /// documents, the North Star is not version-tracked; the author versions it
    /// in their own tool and re-imports.
    func saveNorthStar(_ northStar: NorthStar) throws
}
