import Foundation

// Reviewer pipeline (D8): retrieve → reason → emit. Batch-capable — one reason
// call reviews all selected lines and returns a card per line (a deck).
//
// SCALE — why this shape now, and how it evolves (recorded so we have context
// when we return):
//  • The author selects N lines; we send the episode + North Star to the model
//    ONCE and get N verdicts back — saving ~N× input tokens and N−1 round trips
//    vs one call per line. That is the whole point of batching.
//  • Today the rule is "one card per selected line." The next phase (D17) lets
//    the reviewer decide WHICH lines in a broader scope deserve a card. Both are
//    the SAME mechanism: cards are matched to lines by a model-echoed target id
//    (see LLMReasoner), not by position — so relaxing the rule is a prompt
//    change, not a plumbing change.
//  • Selection is `[Anchor]` (explicit lines) now; a higher-level `ReviewScope`
//    (a cut / the whole episode) will wrap this later as an additive layer.
//  • Streaming the reply is deliberately deferred; `run` returns finished cards.

/// The author's selection for one review: the lines to review plus optional
/// guidance. SCALE: `subjects` is a set of explicit lines now; a `ReviewScope`
/// (cut / episode) will wrap it later without reshaping the reason stage.
public struct ReviewRequest: Equatable, Sendable {
    public var subjects: [Anchor]
    public var note: String?
    /// Alternatives already proposed (renewal, D12). Applies to a single-line
    /// re-review; on a multi-line batch it is normally empty.
    public var priorAlternatives: [String]

    public init(subjects: [Anchor], note: String? = nil, priorAlternatives: [String] = []) {
        self.subjects = subjects
        self.note = note
        self.priorAlternatives = priorAlternatives
    }
}

/// One resolved line under review: its address plus the actual Line.
public struct ReviewTarget: Equatable, Sendable {
    public var address: Anchor
    public var line: Line

    public init(address: Anchor, line: Line) {
        self.address = address
        self.line = line
    }
}

/// A reviewer as configuration (D8): identity and its role prompt. Per-reviewer
/// retrieval strategy is a documented later phase; for now every reviewer reads
/// the whole episode, so there is nothing to configure here yet.
public struct ReviewerConfig: Sendable {
    public var reviewer: Reviewer
    public var rolePrompt: String

    public init(reviewer: Reviewer, rolePrompt: String) {
        self.reviewer = reviewer
        self.rolePrompt = rolePrompt
    }
}

/// What the retrieve stage produced: the whole episode as shared context plus
/// the lines under review (D2 — the reviewer privately owns its context).
public struct ReviewContext: Equatable, Sendable {
    /// The whole episode — shared context so the reviewer judges each target
    /// against the surrounding dialogue and arc. Sent to the model once.
    public var episode: Episode
    /// The lines under review (≥1). SCALE: a set now that the episode is the
    /// shared context; the reviewer marks each and returns a card per line.
    public var targets: [ReviewTarget]
    public var note: String?
    /// Alternatives already proposed; non-empty on a single-line renewal.
    public var priorAlternatives: [String]
    /// Shared project context: the North Star text, when the project has one.
    public var northStar: String?

    public init(
        episode: Episode, targets: [ReviewTarget], note: String? = nil,
        priorAlternatives: [String] = [], northStar: String? = nil
    ) {
        self.episode = episode
        self.targets = targets
        self.note = note
        self.priorAlternatives = priorAlternatives
        self.northStar = northStar
    }
}

/// The reason stage's output for one line: card content before the pipeline
/// stamps identity/lifecycle chrome (D9 — chrome is fixed).
public struct ReviewerVerdict: Equatable, Sendable {
    public var blocks: [CardBlock]
    public var options: [CardOption]

    public init(blocks: [CardBlock], options: [CardOption]) {
        self.blocks = blocks
        self.options = options
    }
}

/// Failures raised while running the pipeline.
public enum ReviewError: Error, Equatable {
    /// The subject anchor points outside the episode's cuts/lines.
    case subjectOutOfRange(Anchor)
    /// The reasoner's reply could not be parsed at all; the associated value is
    /// the raw reply, retained for debugging. (Individual malformed cards in a
    /// batch are skipped, not thrown — see LLMReasoner.)
    case malformedVerdict(String)
}

// MARK: Stages

/// The retrieve stage: resolve subject anchors into a context slice.
public protocol Retriever: Sendable {
    func retrieve(
        subjects: [Anchor], note: String?, from episode: Episode
    ) throws -> ReviewContext
}

/// The reason stage: the single seam a real reasoner replaces. Batch — returns a
/// verdict per target, keyed by its anchor. SCALE: keyed (not positional) so a
/// future "reviewer picks which lines" can return a subset without breaking the
/// mapping; the pipeline emits one card per verdict returned.
public protocol Reasoner: Sendable {
    func reason(
        context: ReviewContext, config: ReviewerConfig
    ) async throws -> [Anchor: ReviewerVerdict]
}

/// v1 retrieval: validate the subject anchors and hand the reviewer the whole
/// episode as shared context. Addressing is per-cut and 1-based (D11/D15).
public struct EpisodeContextRetriever: Retriever {
    public init() {}

    public func retrieve(
        subjects: [Anchor], note: String?, from episode: Episode
    ) throws -> ReviewContext {
        let targets = try subjects.map { subject -> ReviewTarget in
            guard let line = episode.line(at: subject) else {
                throw ReviewError.subjectOutOfRange(subject)
            }
            return ReviewTarget(address: subject, line: line)
        }
        return ReviewContext(episode: episode, targets: targets, note: note)
    }
}

// MARK: Skeleton

/// The shared retrieve → reason → emit skeleton. Stages are injected so a
/// reviewer can override any of them (D8) without changing this type.
public struct ReviewPipeline {
    public var retriever: Retriever
    public var reasoner: Reasoner

    public init(retriever: Retriever, reasoner: Reasoner) {
        self.retriever = retriever
        self.reasoner = reasoner
    }

    /// Review the requested lines and return one card per line, in document
    /// order. SCALE: partial-safe — a target the reasoner skipped or failed on
    /// simply yields no card; the successful cards are unaffected.
    public func run(
        _ request: ReviewRequest, config: ReviewerConfig, episode: Episode,
        northStar: String? = nil
    ) async throws -> [Card] {
        var context = try retriever.retrieve(
            subjects: request.subjects, note: request.note, from: episode
        )
        context.priorAlternatives = request.priorAlternatives
        context.northStar = northStar
        let verdicts = try await reasoner.reason(context: context, config: config)

        return request.subjects
            .sorted(by: Self.inDocumentOrder)
            .compactMap { anchor in
                verdicts[anchor].map { emit($0, anchor: anchor, config: config) }
            }
    }

    /// Stamp fixed chrome onto a verdict: a fresh open v1 card anchored to its
    /// line. Versioning/lifecycle transitions are the write loop (D12/D13).
    private func emit(
        _ verdict: ReviewerVerdict, anchor: Anchor, config: ReviewerConfig
    ) -> Card {
        Card(
            id: cardID(anchor: anchor, reviewer: config.reviewer),
            reviewer: config.reviewer,
            anchor: anchor,
            version: 1,
            status: .open,
            blocks: verdict.blocks,
            options: verdict.options
        )
    }

    private func cardID(anchor a: Anchor, reviewer: Reviewer) -> String {
        let slug = reviewer.name.split(separator: " ").first.map { $0.lowercased() } ?? "reviewer"
        let child = a.child.map { "-k\($0)" } ?? ""
        return "card-\(slug)-\(a.episode.lowercased())-c\(a.cut)-l\(a.line)\(child)-v1"
    }

    /// Order cards by where the line sits in the episode (not selection order).
    static func inDocumentOrder(_ a: Anchor, _ b: Anchor) -> Bool {
        if a.cut != b.cut { return a.cut < b.cut }
        if a.line != b.line { return a.line < b.line }
        return (a.child ?? 0) < (b.child ?? 0)
    }
}
