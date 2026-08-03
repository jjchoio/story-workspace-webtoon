# CLAUDE.md — Story Workspace

macOS app (SwiftUI) that helps webtoon authors review and refine scripts
using specialized AI reviewers. Authors flip through persistent review
cards — not a chat interface. AI proposes; the author decides.

## Read Before Working

- `docs/PRODUCT.md` — what we're building and why; non-goals matter
- `docs/TECHNICAL_DESIGN.md` — architecture; document model; memory tiers
- `docs/DECISIONS.md` — settled decisions (D1–D19). These are closed unless
  explicitly reopened by the author. Do not silently deviate.
- `docs/FORMAT.md` — the supported script input format (Ulysses export is
  part of the format spec; D16).
- `docs/PLANNING.md` — phased plan. Work ONLY within the current phase;
  items under "Deliberately Deferred" are off-limits even if convenient.

## Current Scope

Phase 1 (data spine) and **Phase 2 — one reviewer through the pipe** are
delivered: the Dialogue reviewer runs end to end (retrieve → reason → emit)
against a live model, a multi-line selection is reviewed in ONE batched call
that returns a deck of schema-driven cards, and a thin write-loop slice landed
early (Accept patches the document + persists an immutable version; Revert
restores; Renew re-runs honestly). A three-column library reads a project
North Star (shared reviewer context) and multiple episodes.

**Phase 3 — the write loop** is next: per-suggestion staleness (D7),
card/session persistence + card history (D13), and the Review Mode walk (D17).
See PLANNING.md — work only within the current phase; "Deliberately Deferred"
items stay off-limits.

## Structure

- `StoryKit/` — SwiftPM package: parser, canonical model (Episode → Cut →
  Line, stable IDs; Line carries one level of flattened children; Episode
  carries optional GOAL header metadata), ProjectStore protocol +
  FileProjectStore. ALL logic lives here so it is testable via `swift test`.
- App target — thin SwiftUI shell importing StoryKit. Keep logic out. Views
  are organized by feature: `App/` (RootView routing + toolbar), `Features/*`
  (ReadMode, Project, …), `Components/` (reusable atoms), `ViewModels/`.
- `fixtures/` — Cafe Alameda EP2 as `.txt` in both script conventions
  (`EP2-sample.txt` legacy "Scroll Block"/continuous numbering; `Episode 2
  (cut)-cleaned.txt` updated "Cut"/per-cut numbering), plus `*-size-revised`
  and `legacy-glued-size` samples that exercise the import-warning paths.

## Conventions

- Tests use Swift Testing (`@Test`, `#expect`, parameterized arguments) —
  NOT XCTest. Run with `swift test`.
- Acceptance tests mirror the exit criteria in PLANNING.md; keep them in
  sync. Write/adjust failing tests before implementing.
- Persistence: human-readable JSON, one file per entity, append-only JSONL
  history. Never mutate stored files; add new versions (D14).
- Parser: tolerant on input (both conventions, sloppy whitespace),
  opinionated on output (export emits Cut convention). Authored numbers
  are ignored for structure, validated for gaps (D11).
- Addressing in code, tests, and UI: `EP / Cut / Line` (per-cut), plus an
  optional `Child` for one-level sub-lines (D15).
- AI layer (D8, D19): provider-agnostic `LanguageModel` seam (Claude adapter
  first, env-var key). A review is ONE batched call over the selected lines,
  returning `{ cards: [ { target, blocks, alternatives } ] }`; the app
  synthesizes the constant Keep + Write-your-own options and matches cards to
  lines by the echoed `target` id. Parsing is salvage-tolerant — never let one
  malformed card sink the deck. StoryKit tests use a fake model (no network).
- State & UI: Observation and modern patterns only — `@Observable` + `@State`
  (+ `@Bindable` for two-way binding). Never `ObservableObject`/`@Published`/
  `@StateObject`. Prefer current-era idioms (NavigationSplitView, async/await).
  Deployment target is macOS 15.4.

## Edit Discipline

- Every changed line must trace to the current request. Don't "improve"
  adjacent code, reformat untouched lines, or refactor what isn't broken.
- Clean up orphans YOUR change created (unused imports, variables,
  functions). Leave pre-existing dead code alone — mention it instead.
- State assumptions explicitly before implementing. If multiple
  interpretations of a task exist, present them — don't pick silently.
  
## Working Rules

- If implementation reveals a problem with a documented decision, STOP and
  surface it — do not work around it silently. Findings feed the
  "Learnings" section of the current phase in PLANNING.md.
- Prefer the simplest implementation that passes the acceptance tests; no
  speculative abstractions for deferred features.
- Small, reviewable changes. The author reviews all diffs.
