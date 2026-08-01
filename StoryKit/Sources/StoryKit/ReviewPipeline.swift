import Foundation

// Reviewer pipeline skeleton (D8): every reviewer runs retrieve → reason → emit.
// A reviewer is *configuration* plus optionally overridden stages. This file is
// the skeleton and its stage seams; the reason stage is a protocol so Item 6 can
// drop in a real Claude-backed reasoner without reshaping anything around it.
//
// Streaming a card as it is produced is deferred to Item 6 (the track merge);
// `run` returns a finished card for now — deliberately, not an oversight.

/// The author's selection for one review (D1, minimal for v1): the subject
/// anchor plus optional free-text guidance passed through to the reviewer.
public struct ReviewRequest: Equatable, Sendable {
    public var subject: Anchor
    public var note: String?
    /// Alternatives the reviewer already proposed for this line. Non-empty on a
    /// renewal (D12): the reviewer must take a different path or say so honestly.
    public var priorAlternatives: [String]

    public init(subject: Anchor, note: String? = nil, priorAlternatives: [String] = []) {
        self.subject = subject
        self.note = note
        self.priorAlternatives = priorAlternatives
    }
}

/// A reviewer as configuration (D8): identity and its role prompt. `rolePrompt`
/// is unused by the stub reasoner but is the field the real reasoner sends to
/// the model. Per-reviewer retrieval strategy (each reviewer fetching context
/// its own way) is a documented later phase; for now every reviewer reads the
/// whole episode, so there is nothing to configure here yet.
public struct ReviewerConfig: Sendable {
    public var reviewer: Reviewer
    public var rolePrompt: String

    public init(reviewer: Reviewer, rolePrompt: String) {
        self.reviewer = reviewer
        self.rolePrompt = rolePrompt
    }
}

/// What the retrieve stage produced: the whole episode as context plus the
/// single line under review (D2 — the reviewer privately owns its context).
public struct ReviewContext: Equatable, Sendable {
    /// The whole episode under review — the reviewer reads it for context so it
    /// judges the target line against the surrounding dialogue and arc.
    public var episode: Episode
    /// The single line under review. Single-line this phase; when selection
    /// grows to multiple lines / a whole cut, this becomes a set while the
    /// episode stays the shared context, so consumers change little.
    public var address: Anchor
    public var target: Line
    public var note: String?
    /// Alternatives already proposed for this line; non-empty on a renewal.
    public var priorAlternatives: [String]
    /// Shared project context: the North Star text, when the project has one.
    /// Populated by the pipeline, not the retriever — it is ambient project
    /// grounding, not part of the per-line retrieval.
    public var northStar: String?

    public init(
        episode: Episode, address: Anchor, target: Line, note: String? = nil,
        priorAlternatives: [String] = [], northStar: String? = nil
    ) {
        self.episode = episode
        self.address = address
        self.target = target
        self.note = note
        self.priorAlternatives = priorAlternatives
        self.northStar = northStar
    }
}

/// The reason stage's output: the reviewer's judgment as card content, before
/// the pipeline stamps identity/lifecycle chrome (D9 — chrome is fixed).
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
    /// The reasoner's reply could not be parsed into a verdict; the associated
    /// value is the raw reply, retained for debugging.
    case malformedVerdict(String)
}

// MARK: Stages

/// The retrieve stage: turn a subject anchor into a context slice.
public protocol Retriever: Sendable {
    func retrieve(
        subject: Anchor, note: String?, from episode: Episode
    ) throws -> ReviewContext
}

/// The reason stage: the single seam Item 6 replaces with a Claude-backed
/// reasoner. `async throws` now so the network signature never reshapes later.
public protocol Reasoner: Sendable {
    func reason(context: ReviewContext, config: ReviewerConfig) async throws -> ReviewerVerdict
}

/// v1 retrieval: validate the subject anchor and hand the reviewer the whole
/// episode as context. Addressing is per-cut and 1-based (D11).
public struct EpisodeContextRetriever: Retriever {
    public init() {}

    public func retrieve(
        subject: Anchor, note: String?, from episode: Episode
    ) throws -> ReviewContext {
        let cutIndex = subject.cut - 1
        let lineIndex = subject.line - 1
        guard episode.cuts.indices.contains(cutIndex) else {
            throw ReviewError.subjectOutOfRange(subject)
        }
        let lines = episode.cuts[cutIndex].lines
        guard lines.indices.contains(lineIndex) else {
            throw ReviewError.subjectOutOfRange(subject)
        }
        return ReviewContext(
            episode: episode, address: subject, target: lines[lineIndex], note: note
        )
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

    public func run(
        _ request: ReviewRequest, config: ReviewerConfig, episode: Episode,
        northStar: String? = nil
    ) async throws -> Card {
        var context = try retriever.retrieve(
            subject: request.subject, note: request.note, from: episode
        )
        context.priorAlternatives = request.priorAlternatives
        context.northStar = northStar
        let verdict = try await reasoner.reason(context: context, config: config)
        return emit(verdict, request: request, config: config)
    }

    /// Stamp fixed chrome onto the reviewer's verdict: a fresh open v1 card
    /// anchored to the subject. Versioning/lifecycle transitions are the
    /// Phase 3 write loop (D12/D13).
    private func emit(
        _ verdict: ReviewerVerdict, request: ReviewRequest, config: ReviewerConfig
    ) -> Card {
        Card(
            id: cardID(request: request, reviewer: config.reviewer),
            reviewer: config.reviewer,
            anchor: request.subject,
            version: 1,
            status: .open,
            blocks: verdict.blocks,
            options: verdict.options
        )
    }

    private func cardID(request: ReviewRequest, reviewer: Reviewer) -> String {
        let slug = reviewer.name.split(separator: " ").first.map { $0.lowercased() } ?? "reviewer"
        let a = request.subject
        return "card-\(slug)-\(a.episode.lowercased())-c\(a.cut)-l\(a.line)-v1"
    }
}
