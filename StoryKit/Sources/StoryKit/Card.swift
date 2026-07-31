import Foundation

// Review card schema (D9): schema-driven content over a compiled-in primitive
// vocabulary. v1 primitives: text, quote, options. Reviewer identity, status,
// and anchor are fixed card chrome. Types live here so reviewer JSON <-> model
// round-trips are testable via `swift test`.

public struct Card: Equatable, Sendable, Codable, Identifiable {
    public var id: String
    public var reviewer: Reviewer
    public var anchor: Anchor
    public var version: Int
    public var status: CardStatus
    public var blocks: [CardBlock]
    public var options: [CardOption]

    public init(
        id: String,
        reviewer: Reviewer,
        anchor: Anchor,
        version: Int,
        status: CardStatus,
        blocks: [CardBlock],
        options: [CardOption]
    ) {
        self.id = id
        self.reviewer = reviewer
        self.anchor = anchor
        self.version = version
        self.status = status
        self.blocks = blocks
        self.options = options
    }
}

/// The reviewer that produced the card (D8: reviewer = configuration).
public struct Reviewer: Equatable, Sendable, Codable {
    public var name: String        // "Dialogue reviewer"
    public var focus: [String]     // ["Character voice", "tone", "grammar"]

    public init(name: String, focus: [String]) {
        self.name = name
        self.focus = focus
    }
}

/// Where the card points, in per-cut addressing (D11). A stable Line-ID link
/// (D7 anchoring for staleness) arrives with the write loop in Phase 3.
public struct Anchor: Equatable, Sendable, Codable {
    public var episode: String     // "EP1"
    public var cut: Int
    public var line: Int

    public init(episode: String, cut: Int, line: Int) {
        self.episode = episode
        self.cut = cut
        self.line = line
    }
}

/// Card lifecycle state (D12/D13). The header badge displays whichever it is.
public enum CardStatus: String, Sendable, Codable, Equatable {
    case open, challenged, renewed, accepted, dismissed, stale, overruled
}

/// A schema-driven body block. v1 vocabulary; encoded as a `type`-discriminated
/// object for readable JSON.
public enum CardBlock: Equatable, Sendable, Codable {
    case text(label: String?, content: String)
    case quote(speaker: String?, content: String)

    private enum CodingKeys: String, CodingKey {
        case type, label, speaker, content
    }
    private enum Kind: String, Codable {
        case text, quote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let content = try container.decode(String.self, forKey: .content)
        switch try container.decode(Kind.self, forKey: .type) {
        case .text:
            self = .text(
                label: try container.decodeIfPresent(String.self, forKey: .label),
                content: content
            )
        case .quote:
            self = .quote(
                speaker: try container.decodeIfPresent(String.self, forKey: .speaker),
                content: content
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let label, let content):
            try container.encode(Kind.text, forKey: .type)
            try container.encodeIfPresent(label, forKey: .label)
            try container.encode(content, forKey: .content)
        case .quote(let speaker, let content):
            try container.encode(Kind.quote, forKey: .type)
            try container.encodeIfPresent(speaker, forKey: .speaker)
            try container.encode(content, forKey: .content)
        }
    }
}

/// An actionable choice on a card (D3: keep / alternative(s) / author-written).
public struct CardOption: Equatable, Sendable, Codable, Identifiable {
    public enum Kind: String, Sendable, Codable, Equatable {
        case keep, alternative, authorWritten
    }

    public var id: String
    public var kind: Kind
    public var label: String       // "Soften", "Keep", "Write your own…"
    public var detail: String?     // replacement text / preview; nil for author-written

    public init(id: String, kind: Kind, label: String, detail: String? = nil) {
        self.id = id
        self.kind = kind
        self.label = label
        self.detail = detail
    }
}
