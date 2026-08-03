import Testing
import Foundation
@testable import StoryKit

// Phase 1 persistence acceptance tests (PLANNING.md Phase 1, step 2; D14).
// Exercises the FileProjectStore contract: human-readable JSON, one file per
// entity, append-only JSONL history, immutable versioned snapshots, and reload
// across store instances (the "survives restart" criterion, in-process).

@Suite("Phase 1 — FileProjectStore")
struct PersistenceTests {

    // MARK: Fixtures

    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoryKitTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleEpisode(goal: String) -> Episode {
        Episode(goal: goal, cuts: [
            Cut(title: "Hook", description: "opening", lines: [
                Line(id: LineID("a"), text: "line one", size: .m, speaker: "Andie", children: [
                    Line(id: LineID("a.1"), text: "beat", size: .s),
                ]),
                Line(id: LineID("b"), text: "line two"),
            ]),
        ])
    }

    // MARK: Survives "restart" (a fresh store on the same directory)

    @Test("A saved episode reloads from a new store on the same directory")
    func reloadsAcrossStoreInstances() throws {
        let dir = tempDir()
        let episode = sampleEpisode(goal: "first")

        let store = try FileProjectStore(rootDirectory: dir)
        let id = try store.createDocument(
            name: "EP2", episode: episode, provenance: Provenance(action: "import")
        )

        let reopened = try FileProjectStore(rootDirectory: dir)
        #expect(try reopened.latestEpisode(of: id) == episode)
    }

    // MARK: Immutable versions

    @Test("Adding a version leaves the previous version file untouched")
    func versionsAreImmutable() throws {
        let dir = tempDir()
        let v1 = sampleEpisode(goal: "v1")
        var v2 = v1; v2.goal = "v2 revised"

        let store = try FileProjectStore(rootDirectory: dir)
        let id = try store.createDocument(name: "EP2", episode: v1, provenance: Provenance(action: "import"))
        let version = try store.addVersion(to: id, episode: v2, provenance: Provenance(action: "patch"))

        #expect(version == 2)
        #expect(try store.latestEpisode(of: id) == v2)

        // v0001.json must still decode to the original v1.
        let v1URL = dir.appendingPathComponent("documents/\(id.rawValue)/v0001.json")
        let decoded = try JSONDecoder().decode(Episode.self, from: Data(contentsOf: v1URL))
        #expect(decoded == v1)
    }

    // MARK: Append-only history

    @Test("History records one ordered entry per saved version")
    func historyIsAppendOnly() throws {
        let dir = tempDir()
        let store = try FileProjectStore(rootDirectory: dir)
        let id = try store.createDocument(
            name: "EP2", episode: sampleEpisode(goal: "v1"), provenance: Provenance(action: "import")
        )
        try store.addVersion(to: id, episode: sampleEpisode(goal: "v2"), provenance: Provenance(action: "patch"))

        let history = try store.history()
        #expect(history.count == 2)
        #expect(history.map(\.version) == [1, 2])
        #expect(history.map(\.provenance.action) == ["import", "patch"])
        #expect(history.allSatisfy { $0.documentID == id })
    }

    // MARK: Human-readable JSON

    @Test("Stored entity JSON is pretty-printed and readable")
    func jsonIsHumanReadable() throws {
        let dir = tempDir()
        let store = try FileProjectStore(rootDirectory: dir)
        let id = try store.createDocument(
            name: "EP2", episode: sampleEpisode(goal: "readable"), provenance: Provenance(action: "import")
        )

        let v1URL = dir.appendingPathComponent("documents/\(id.rawValue)/v0001.json")
        let text = try String(contentsOf: v1URL, encoding: .utf8)
        #expect(text.contains("\n"))          // multi-line
        #expect(text.contains("  "))          // indented
        #expect(text.contains("\"goal\""))    // named keys
    }

    // MARK: Document listing

    @Test("Created documents are listed with their name")
    func documentsAreListed() throws {
        let dir = tempDir()
        let store = try FileProjectStore(rootDirectory: dir)
        let id = try store.createDocument(
            name: "Cafe Alameda EP2", episode: sampleEpisode(goal: "x"), provenance: Provenance(action: "import")
        )

        let docs = try store.documents()
        #expect(docs.count == 1)
        #expect(docs.first?.id == id)
        #expect(docs.first?.name == "Cafe Alameda EP2")
    }

    // MARK: Document ordering (drag-reorder in the library)

    @Test("A saved document order drives documents() and survives reopen")
    func documentOrderPersists() throws {
        let dir = tempDir()
        let store = try FileProjectStore(rootDirectory: dir)
        let ep2 = try store.createDocument(name: "EP2", episode: sampleEpisode(goal: "2"), provenance: Provenance(action: "import"))
        let ep1 = try store.createDocument(name: "EP1", episode: sampleEpisode(goal: "1"), provenance: Provenance(action: "import"))

        try store.setDocumentOrder([ep1, ep2])
        #expect(try store.documents().map(\.id) == [ep1, ep2])

        let reopened = try FileProjectStore(rootDirectory: dir)
        #expect(try reopened.documents().map(\.id) == [ep1, ep2])
    }

    @Test("Documents absent from the saved order sort after the ordered ones")
    func documentOrderAppendsUnlisted() throws {
        let dir = tempDir()
        let store = try FileProjectStore(rootDirectory: dir)
        let a = try store.createDocument(name: "A", episode: sampleEpisode(goal: "a"), provenance: Provenance(action: "import"))
        let b = try store.createDocument(name: "B", episode: sampleEpisode(goal: "b"), provenance: Provenance(action: "import"))

        try store.setDocumentOrder([b]) // only b is ordered
        #expect(try store.documents().map(\.id) == [b, a])
    }

    // MARK: North Star (shared reviewer context)

    @Test("A saved North Star reloads from a new store on the same directory")
    func northStarReloadsAcrossStoreInstances() throws {
        let dir = tempDir()
        let northStar = NorthStar(
            text: "Humanity survives through memory, craft, grief, care, and connection.",
            sourceFilename: "Cafe_Alameda_North_Star_v1_4.txt",
            // Whole-second date: the store encodes ISO-8601 (no sub-second
            // precision), so a pinned second round-trips exactly.
            importedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let store = try FileProjectStore(rootDirectory: dir)
        try store.saveNorthStar(northStar)

        let reopened = try FileProjectStore(rootDirectory: dir)
        #expect(try reopened.loadNorthStar() == northStar)
    }

    @Test("A project with no North Star loads nil")
    func northStarAbsentIsNil() throws {
        let store = try FileProjectStore(rootDirectory: tempDir())
        #expect(try store.loadNorthStar() == nil)
    }

    @Test("Re-importing replaces the North Star in place (not versioned)")
    func northStarReplaces() throws {
        let dir = tempDir()
        let store = try FileProjectStore(rootDirectory: dir)
        try store.saveNorthStar(NorthStar(text: "v1", sourceFilename: "ns_v1.txt"))
        try store.saveNorthStar(NorthStar(text: "v2 revised", sourceFilename: "ns_v2.txt"))

        let loaded = try store.loadNorthStar()
        #expect(loaded?.text == "v2 revised")
        #expect(loaded?.sourceFilename == "ns_v2.txt")
    }

    // MARK: Full-fidelity round-trip of a real parsed episode

    @Test("A parsed EP2 episode round-trips through the store unchanged")
    func parsedEpisodeRoundTrips() throws {
        let dir = tempDir()
        let parsed = try StoryParser.parse(Fixtures.legacyScript()).episode

        let store = try FileProjectStore(rootDirectory: dir)
        let id = try store.createDocument(
            name: "EP2", episode: parsed, provenance: Provenance(action: "import")
        )

        let reopened = try FileProjectStore(rootDirectory: dir)
        #expect(try reopened.latestEpisode(of: id) == parsed)
    }
}
