import Foundation

// Loads the shared script fixtures at <repo>/fixtures. The package lives at
// <repo>/StoryKit, so we resolve the sibling directory relative to this source
// file rather than duplicating the fixtures into the package.
//
// Fixtures are plain UTF-8 text (re-exported from the source scripts), so the
// loader just reads the file — StoryKit stays a pure text parser.

enum FixtureError: Error {
    case unreadable(String)
}

enum Fixtures {
    /// <repo>/fixtures — four directories up from this file, then `fixtures`.
    /// (.../StoryKit/Tests/StoryKitTests/Fixtures.swift → <repo>)
    static var directory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("fixtures", isDirectory: true)
    }

    /// Raw text of a fixture file.
    static func text(_ fileName: String) throws -> String {
        let url = directory.appendingPathComponent(fileName)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw FixtureError.unreadable(url.path)
        }
    }

    /// Legacy convention ("Scroll Block N", episode-continuous numbering),
    /// cleaned, authored with parenthesized (S)/(M)/(L) size codes.
    static func legacyScript() throws -> String { try text("EP2-clened.txt") }

    /// Updated convention ("Cut N", per-cut numbering), cleaned, authored with
    /// angle-bracket <S>/<M>/<L> size codes.
    static func cutScript() throws -> String { try text("Episode 2 (cut)-cleaned.txt") }

    /// Minimal legacy sample containing a bare glued size marker ("LAndie"),
    /// used to exercise the "possible lost size marker" warning path.
    static func gluedSizeSample() throws -> String { try text("legacy-glued-size.txt") }

    /// Uncleaned export retaining stray bracket residue ("()", "([)"), used to
    /// exercise the "stray markup residue" warning path.
    static func strayMarkupSample() throws -> String { try text("EP2-size-revised.txt") }
}
