# TECHNICAL_DESIGN.md — Story Workspace

macOS app (SwiftUI). Two top-level areas: **Project Data** and **LLM Service**.

## Architecture Overview

- **Project Data** owns persistence: imported documents (canonical form),
  edit/provenance history, review cards and their version chains, session
  overviews, and promoted intent.
- **LLM Service** owns reviewer execution: an orchestrator manages
  scheduling, cancellation, retries, lifecycle, dependencies, and progress.
  The orchestrator knows nothing about storytelling and never retrieves
  documents — it routes `{subject, note, selected reviewers}` to reviewers.
- Each reviewer runs a **shared pipeline skeleton** — retrieve → reason →
  emit card — configured (and optionally overridden) per reviewer.

## Document Model

Canonical, panel-aware tree (webtoon scroll format):

```
Episode
└── Cut (title, scene description)
    └── Line (stable ID, speaker, text)
```

- **Upload is import.** Text/PDF is parsed into this canonical form. The
  supported input contract is the project's markdown convention; parsing is
  tolerant, arbitrary formats are out of scope for v1.
- **IDs are canonical; numbers are derived.** The parser ignores authored
  numbering (using it only as a matching hint). The app renders and exports
  per-cut addressing (`EP / Cut / Line`), recomputed from document order.
  Reordering cuts or inserting lines never invalidates anchors.
- Structure enables **structural retrieval** ("all Lines where speaker =
  Andie") and **computed stats** for the Flow reviewer (cuts per episode,
  line density) without embeddings.

## Write Paths & History

Two write paths, one unified history:

1. **In-app**: patch acceptance from a card, or free-form edits in write
   mode (refinement only — no document creation).
2. **Re-upload**: replace-with-diff. The new file is parsed, diffed
   structurally against the current canonical version, shown to the author,
   and replaces on confirmation. Line identity across replacement is matched
   by content similarity so anchors survive external editing sessions.

Every mutation is recorded with provenance: who/what/when/why, including a
link back to the causing card and chosen option where applicable. Edit
history is a product surface ("what changed this cycle"), not just an audit
log.

## Review Cycle & Card Lifecycle

- A **session** is transactional: explicit open → close, timestamped, may
  span days. Closing runs the summary agent and archives cards.
- **Scope** is author-defined: manifest selection (+ optional note), plus
  reviewer selection. The note is passed to reviewers as guidance.
- **Subject vs. context**: the author controls the *subject* (what is
  judged); each reviewer's retrieval strategy privately controls its
  *context* (what informs the judgment).
- **Staleness**: every suggestion anchors to stable IDs (line/cut spans).
  Any edit overlapping an anchor flips that suggestion — per-suggestion,
  mechanically, no LLM call — to *stale*. Stale suggestions stay visible and
  actionable; re-review is always a deliberate user action. Never
  auto-refresh.
- **Discussion = versioning.** A challenge note or renewal request produces
  a new card version scoped to the challenged suggestion; other suggestions
  carry forward untouched. Renewal instructions require "same intention,
  different path." After repeated rejection, reviewers defer (honestly, not
  sycophantically). All versions persist under the session ID with the
  causing action recorded.

## Reviewer Architecture

- Shared skeleton: **retrieve → reason → emit**.
- A reviewer = configuration `{role prompt, personality, retrieval spec,
  card schema}` + optional code overrides at any stage. v1 reviewers are
  expected to override nothing; overrides exist for future reviewers with
  genuinely different reasoning shapes.
- Reviewers ship with the app as product features (v1: 3; later versions
  add more). Quality per reviewer is the product.

## Card Rendering

- Card schemas compose a **fixed, compiled-in vocabulary of SwiftUI
  primitives** (title, text block, bullet list, comparison, option buttons,
  simple chart). Schema-driven rendering, no dynamic UI loading — safe
  because reviewers ship with the app.
- Cards stream; each reviewer streams independently.

## Memory Architecture (three tiers)

| Tier | Artifact | Written by | Read by |
|------|----------|-----------|---------|
| 1 | Card history (raw record: versions, challenges, accept/dismiss/skip, timestamps) | System | Author UI; summary agent once at session close; developer debugging |
| 2 | Session overviews (subject, doc versions, per-reviewer outcomes, notable patterns) | Summary agent at close | Reviewers, when re-reviewing the same subject |
| 3 | Promoted intent (author-chosen standing rulings via "remember this") | Author promotion | All reviewers, always; editable/deletable like any document |

**Hard rule:** reviewers never retrieve tier 1. This bounds reviewer context
regardless of project age. Distillation over transcripts: reviewers know
rulings, not litigation.

## Persistence

- Imported documents (canonical form) and their full version lineage
- All edits with provenance; replacement lineage on re-upload
- All card versions, grouped by session, with user actions
- Session overviews and promoted intent
- Latest state restored on app open

## State Management

Project State → Review State → Streaming State → (optional) Discussion
State → Persistent State → (optional) Recomputation State.
*(Carried from draft; to be validated during implementation — see Open
Questions.)*

## Tradeoffs (accepted)

- **Selection-first scope** over free-text scope parsing: keeps v1 simple;
  the note is guidance, not scope.
- **Replace-with-diff** over three-way merge: replacement semantics are
  understandable; merge UIs are disproportionately expensive.
- **Per-suggestion staleness** over transactional discard: discard punished
  editing and didn't avoid staleness anyway (accepting card A's patch can
  stale card B).
- **Shared reviewer skeleton** over bespoke reviewers: intentionality lives
  in config content, not code shape; overrides preserve the escape hatch.
- **Suggestion-scoped renewal** over whole-card regeneration: trades
  holistic reconsideration for stability and trust.
- **No reviewer access to raw history**: trades perfect recall for bounded
  context and ruling-level (not litigation-level) memory.
- **Single input format**: trades ingestion flexibility for a tractable
  parser.

## Open Questions

- Orchestration mechanics: scheduling, cancellation mid-stream, retry
  policy, partial-failure UX when one reviewer errors.
- State management chain above: validate or simplify during build.
- Diff correspondence quality: how well content-similarity matching
  preserves line IDs across heavy external rewrites; fallback UX when
  matching is ambiguous.
- Card schema evolution: versioning schemas as reviewers improve across app
  releases while old cards must still render.
- Tier-2 retrieval trigger: exact-subject match only, or related subjects
  (e.g., EP2 review pulling EP1 overviews)?
- Whether/when free-text scope ("review the latest changes") graduates from
  guidance to a real scope parser.
