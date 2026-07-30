import Foundation

// Canonical document model: Episode → Cut → Line (CLAUDE.md, PLANNING.md
// Phase 1.1). Addressing is per-cut (EP / Cut / Line). These are plain data
// types; the parser is responsible for building them. Intentionally minimal —
// no speculative structure for deferred features.

/// Stable internal identifier for a line (D11). Identity is content-derived
/// and assigned by the parser; downstream code treats it as opaque. Authored
/// numbers are NOT identity — they are validated as a checksum, not used here.
public struct LineID: Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

/// Panel size authored as a delimited code immediately after the line number:
/// `(S)`/`(M)`/`(L)` or `<S>`/`<M>`/`<L>`, case-exact. Both input forms parse
/// identically; export always emits the parenthesized canonical form. A bare
/// glued letter (legacy `Szoom`) is NOT a size code — the parser keeps the
/// text verbatim and emits a "possible lost size marker" warning.
public enum SizeCode: String, Equatable, Sendable {
    case s = "S"
    case m = "M"
    case l = "L"
}

/// A single script line within a cut.
///
/// A top-level line may carry one level of children (sub-beats such as `9.1`).
/// The source nests arbitrarily deep (`15.1.1.1`); the parser flattens
/// everything below a top-level line into this single ordered child level, in
/// document order. Children are always leaves — their own `children` is empty.
public struct Line: Equatable, Sendable {
    public var id: LineID
    /// Pure line content: the authored number, any recognized size code, and a
    /// leading "Speaker:" label are all stripped (structure/metadata, not
    /// identity).
    public var text: String
    /// Panel size parsed from a delimited (S)/(M)/(L) or <S>/<M>/<L> code.
    public var size: SizeCode?
    /// Speaker/caption label from a leading "Name:" prefix, captured verbatim
    /// (e.g. "Andie", "ANDIE (internal)", "SFX"); nil when there is no prefix.
    public var speaker: String?
    /// Sub-beats, flattened to one level. Empty for leaves.
    public var children: [Line]

    public init(
        id: LineID,
        text: String,
        size: SizeCode? = nil,
        speaker: String? = nil,
        children: [Line] = []
    ) {
        self.id = id
        self.text = text
        self.size = size
        self.speaker = speaker
        self.children = children
    }
}

/// A cut (a.k.a. legacy "Scroll Block"): a titled, ordered run of lines.
public struct Cut: Equatable, Sendable {
    /// Cut title with the "Cut N:" / "Scroll Block N:" prefix removed.
    public var title: String
    /// Unnumbered scene-setting prose at the top of the cut, if any, with the
    /// "Scene description:" label stripped (TECHNICAL_DESIGN.md). In v1 any
    /// other unnumbered top-of-cut prose also lands here rather than erroring.
    public var description: String?
    public var lines: [Line]

    public init(title: String, description: String? = nil, lines: [Line]) {
        self.title = title
        self.description = description
        self.lines = lines
    }
}

/// A full episode: an ordered list of cuts plus optional header metadata. Both
/// source conventions parse to the identical canonical tree (modulo IDs).
public struct Episode: Equatable, Sendable {
    /// The episode GOAL parsed from the header, if present.
    public var goal: String?
    public var cuts: [Cut]

    public init(goal: String? = nil, cuts: [Cut]) {
        self.goal = goal
        self.cuts = cuts
    }

    /// Total number of top-level lines across all cuts (children excluded).
    public var lineCount: Int {
        cuts.reduce(0) { $0 + $1.lines.count }
    }
}
