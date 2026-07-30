# CLAUDE.md — Story Workspace

macOS app (SwiftUI) that helps webtoon authors review and refine scripts
using specialized AI reviewers. Authors flip through persistent review
cards — not a chat interface. AI proposes; the author decides.

## Read Before Working

- `docs/PRODUCT.md` — what we're building and why; non-goals matter
- `docs/TECHNICAL_DESIGN.md` — architecture; document model; memory tiers
- `docs/DECISIONS.md` — settled decisions (D1–D14). These are closed unless
  explicitly reopened by the author. Do not silently deviate.
- `docs/PLANNING.md` — phased plan. Work ONLY within the current phase;
  items under "Deliberately Deferred" are off-limits even if convenient.

## Current Scope

Phase 1 (data spine): parser → canonical model → FileProjectStore → read
mode. No LLM calls, no reviewers, no card UI in this phase.

## Structure

- `StoryKit/` — SwiftPM package: parser, canonical model (Episode → Cut →
  Line, stable IDs; Line carries one level of flattened children; Episode
  carries optional GOAL header metadata), ProjectStore protocol +
  FileProjectStore. ALL logic lives here so it is testable via `swift test`.
- App target — thin SwiftUI shell importing StoryKit. Keep logic out.
- `fixtures/` — Cafe Alameda EP2 as `.txt` in both script conventions
  (`EP2.txt` legacy "Scroll Block"/continuous numbering; `Episode 2
  (cut).txt` updated "Cut"/per-cut numbering).

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
- Addressing in code, tests, and UI: `EP / Cut / Line` (per-cut).

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
