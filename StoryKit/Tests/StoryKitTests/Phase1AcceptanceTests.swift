import Testing
import Foundation
@testable import StoryKit

// Phase 1 acceptance tests for the parser (PLANNING.md Phase 1, exit criteria).
// These mirror the exit criteria and are written to FAIL until the parser is
// implemented — StoryParser.parse/export currently throw .notImplemented.
//
// Scope: the parse-related exit criteria only. Persistence (FileProjectStore),
// read-mode rendering, and the ID-stability stress test are deferred until
// those components exist.
//
// Ground truth is Cafe Alameda EP2 in fixtures/ (both conventions): four cuts,
// 27 top-level lines distributed 12 / 6 / 5 / 4, with sub-beats flattened to
// one level of children, plus a header GOAL. See the derived tree shape that
// accompanies this change.

@Suite("Phase 1 — parser acceptance")
struct Phase1AcceptanceTests {

    static let expectedGoal = "Raged Diver as machinery monster & the Realm"

    static let expectedCutTitles = [
        "Hook + Tension",
        "Transition & the Realm",
        "Diver in the Realm",
        "Order Declared",
    ]

    /// Top-level lines per cut; sums to 27.
    static let expectedLinesPerCut = [12, 6, 5, 4]

    /// Children per top-level line, one entry per cut (document order). Deeper
    /// source nesting is flattened into this single child level.
    static let expectedChildrenPerCut: [[Int]] = [
        [0, 0, 1, 1, 1, 1, 0, 1, 6, 1, 0, 1], // Cut 1 — 13 children
        [4, 0, 9, 0, 2, 1],                    // Cut 2 — 16 children
        [1, 1, 1, 1, 2],                       // Cut 3 —  6 children
        [0, 1, 0, 1],                          // Cut 4 —  2 children
    ]

    /// Scene-setting description per cut (label stripped). Only Cut 1 has one.
    static let expectedDescriptions: [String?] = [
        "Steam hissing sound. Pipes running through the panels.",
        nil,
        nil,
        nil,
    ]

    /// Size code per top-level line, one entry per cut (document order).
    /// nil = no code. Derived from the fixtures' delimited (S)/(M)/(L) markers.
    static let expectedSizesPerCut: [[SizeCode?]] = [
        [.m, .s, .s, .s, .s, .s, .m, .s, .m, .s, .s, .s], // Cut 1
        [nil, nil, nil, nil, .m, .s],                     // Cut 2
        [.s, .s, .s, .l, .m],                             // Cut 3
        [.s, .s, .m, .m],                                 // Cut 4
    ]

    /// Speaker per top-level line, one entry per cut (document order).
    /// nil = no "Speaker:" prefix. Most dialogue speakers live on children.
    static let expectedSpeakersPerCut: [[String?]] = [
        ["Andie", nil, "ANDIE (internal)", nil, nil, nil, nil, nil, nil, nil, nil, nil], // Cut 1
        [nil, nil, nil, nil, nil, nil],                                                  // Cut 2
        [nil, nil, nil, nil, nil],                                                       // Cut 3
        [nil, nil, nil, nil],                                                            // Cut 4
    ]

    // MARK: Header metadata

    @Test("Episode goal is parsed from the header")
    func goalParsed() throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        #expect(result.episode.goal == Self.expectedGoal)
    }

    // MARK: Structure (legacy fixture)

    @Test("Episode parses into four cuts")
    func fourCuts() throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        #expect(result.episode.cuts.count == 4)
    }

    @Test("Episode has 27 top-level lines in total")
    func twentySevenLines() throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        #expect(result.episode.lineCount == 27)
    }

    @Test(
        "Each cut has the expected top-level line count",
        arguments: zip(0..<4, Phase1AcceptanceTests.expectedLinesPerCut)
    )
    func perCutLineCount(index: Int, expected: Int) throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        try #require(result.episode.cuts.indices.contains(index))
        #expect(result.episode.cuts[index].lines.count == expected)
    }

    @Test(
        "Each top-level line has the expected number of flattened children",
        arguments: zip(0..<4, Phase1AcceptanceTests.expectedChildrenPerCut)
    )
    func perLineChildCounts(cutIndex: Int, expected: [Int]) throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        try #require(result.episode.cuts.indices.contains(cutIndex))
        let counts = result.episode.cuts[cutIndex].lines.map { $0.children.count }
        #expect(counts == expected)
    }

    @Test(
        "Each cut carries the expected scene description",
        arguments: zip(0..<4, Phase1AcceptanceTests.expectedDescriptions)
    )
    func perCutDescription(index: Int, expected: String?) throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        try #require(result.episode.cuts.indices.contains(index))
        #expect(result.episode.cuts[index].description == expected)
    }

    @Test(
        "Each top-level line has the expected size code",
        arguments: zip(0..<4, Phase1AcceptanceTests.expectedSizesPerCut)
    )
    func perLineSizeCodes(cutIndex: Int, expected: [SizeCode?]) throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        try #require(result.episode.cuts.indices.contains(cutIndex))
        let sizes = result.episode.cuts[cutIndex].lines.map { $0.size }
        #expect(sizes == expected)
    }

    @Test(
        "Each top-level line has the expected speaker",
        arguments: zip(0..<4, Phase1AcceptanceTests.expectedSpeakersPerCut)
    )
    func perLineSpeakers(cutIndex: Int, expected: [String?]) throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        try #require(result.episode.cuts.indices.contains(cutIndex))
        let speakers = result.episode.cuts[cutIndex].lines.map { $0.speaker }
        #expect(speakers == expected)
    }

    @Test("Size code and speaker are stripped, leaving pure content in text")
    func codeAndSpeakerStrippedFromText() throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        // Line 1 is authored: "1. (M) Andie: “Order up, you trash-can!”"
        let first = try #require(result.episode.cuts.first?.lines.first)
        #expect(first.size == .m)
        #expect(first.speaker == "Andie")
        #expect(first.text == "“Order up, you trash-can!”")
    }

    // MARK: Both input delimiter forms accepted

    @Test("Both (S) and <S> delimiter forms parse to the same size codes")
    func bothDelimiterFormsAccepted() throws {
        // Legacy fixture uses (S); cut fixture uses <S>.
        let paren = try StoryParser.parse(Fixtures.legacyScript()).episode
        let angle = try StoryParser.parse(Fixtures.cutScript()).episode
        let parenSizes = paren.cuts.map { $0.lines.map(\.size) }
        let angleSizes = angle.cuts.map { $0.lines.map(\.size) }
        #expect(parenSizes == angleSizes)
    }

    // MARK: Glued-code warning path

    @Test("A bare glued size marker warns and is kept verbatim, not parsed")
    func gluedSizeMarkerWarns() throws {
        let result = try StoryParser.parse(Fixtures.gluedSizeSample())
        let glued = try #require(result.episode.cuts.first?.lines.first)
        #expect(glued.size == nil)
        #expect(glued.text == "LAndie stands arms crossed firm eyes opened")
        #expect(!result.warnings.isEmpty)
    }

    @Test("Stray bracket residue produces an import warning")
    func strayMarkupWarns() throws {
        let result = try StoryParser.parse(Fixtures.strayMarkupSample())
        #expect(!result.warnings.isEmpty)
    }

    @Test("Flattened children are leaves (no grandchildren)")
    func childrenAreLeaves() throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        for cut in result.episode.cuts {
            for line in cut.lines {
                for child in line.children {
                    #expect(child.children.isEmpty)
                }
            }
        }
    }

    @Test(
        "Cut titles are parsed without their prefix",
        arguments: zip(0..<4, Phase1AcceptanceTests.expectedCutTitles)
    )
    func cutTitle(index: Int, expected: String) throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        try #require(result.episode.cuts.indices.contains(index))
        #expect(result.episode.cuts[index].title == expected)
    }

    // MARK: Convention detection

    @Test("Legacy source is detected as the Scroll Block convention")
    func detectsLegacyConvention() throws {
        let result = try StoryParser.parse(Fixtures.legacyScript())
        #expect(result.detectedConvention == .legacyScrollBlock)
    }

    @Test("Updated source is detected as the Cut convention")
    func detectsCutConvention() throws {
        let result = try StoryParser.parse(Fixtures.cutScript())
        #expect(result.detectedConvention == .cut)
    }

    // MARK: Core exit criterion — both conventions parse identically

    @Test("Both conventions produce the identical canonical tree (modulo IDs)")
    func conventionsAgreeModuloIDs() throws {
        let legacy = try StoryParser.parse(Fixtures.legacyScript()).episode
        let cut = try StoryParser.parse(Fixtures.cutScript()).episode
        #expect(skeleton(legacy) == skeleton(cut))
    }

    // MARK: Exit criterion — numbering validated as a checksum

    @Test("A contiguous legacy script imports without numbering warnings")
    func noWarningsWhenNumberingIsContiguous() throws {
        // EP2's legacy numbering runs 1...27 with no gaps.
        let result = try StoryParser.parse(Fixtures.legacyScript())
        #expect(result.warnings.isEmpty)
    }

    // MARK: Exit criterion — legacy → export round-trips to Cut convention

    @Test("Export emits the Cut convention and round-trips structurally")
    func legacyExportsToCutConvention() throws {
        let legacy = try StoryParser.parse(Fixtures.legacyScript()).episode

        let exported = try StoryParser.export(legacy)
        let reparsed = try StoryParser.parse(exported)

        // Opinionated output: always the Cut convention.
        #expect(reparsed.detectedConvention == .cut)
        // Opinionated output: size codes emit in the parenthesized canonical
        // form, never the angle-bracket form. (Guard on the code tokens, not a
        // bare "<", since line content legitimately contains "<-".)
        #expect(exported.contains("(M)"))
        #expect(!exported.contains("<S>"))
        #expect(!exported.contains("<M>"))
        #expect(!exported.contains("<L>"))
        // Round-trip preserves the canonical structure.
        #expect(skeleton(reparsed.episode) == skeleton(legacy))
    }

    // MARK: Helpers

    /// Structure with IDs stripped: goal, and per cut the title, description,
    /// and ordered lines (text + size, plus one level of children with their
    /// own text + size). Everything the two conventions must agree on.
    private struct EpisodeSkeleton: Equatable {
        let goal: String?
        let cuts: [CutSkeleton]
    }
    private struct CutSkeleton: Equatable {
        let title: String
        let description: String?
        let lines: [LineSkeleton]
    }
    private struct LineSkeleton: Equatable {
        let text: String
        let size: SizeCode?
        let speaker: String?
        let children: [LineSkeleton]
    }

    private func skeleton(_ episode: Episode) -> EpisodeSkeleton {
        func line(_ l: Line) -> LineSkeleton {
            LineSkeleton(
                text: l.text,
                size: l.size,
                speaker: l.speaker,
                children: l.children.map(line)
            )
        }
        return EpisodeSkeleton(
            goal: episode.goal,
            cuts: episode.cuts.map { cut in
                CutSkeleton(
                    title: cut.title,
                    description: cut.description,
                    lines: cut.lines.map(line)
                )
            }
        )
    }
}
