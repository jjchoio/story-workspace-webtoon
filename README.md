# Story Workspace

A macOS app that helps webtoon authors review and refine long-form scripts with
specialized AI reviewers. Findings arrive as persistent, interactive **review
cards** — not a chat. The AI proposes; the author decides.

> v1 scope: webtoon (vertical-scroll) format only.

## Principles

- **The author decides.** Reviewers advise; nothing mutates a document except an
  explicit author action.
- **Creation is external, refinement is internal.** Authors write elsewhere and
  upload; the app owns review, patches, and history — it is not a writing tool.
- **Cards, not chat.** Every AI response is a structured, persistent card.

## Status

- **Phase 1 — data spine (complete):** script parser → canonical
  `Episode → Cut → Line` model → file-based persistence → Read mode with a
  sidebar outline.
- **Phase 2 — one reviewer through the pipe (in progress):** card schema +
  schema-driven renderer first (against a sample card), then the live pipeline.

## Layout

```
StoryKit/         Swift package — all logic (parser, canonical model,
                  persistence, card schema). Testable via `swift test`.
StoryWorkspace/   SwiftUI app (thin shell); views organized by feature.
fixtures/         Sample scripts (both conventions) + a sample review card.
docs/             Design docs (below).
```

## Docs

| Doc | What it covers |
|-----|----------------|
| [PRODUCT.md](docs/PRODUCT.md) | Vision, principles, goals, non-goals |
| [TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md) | Architecture, document model, memory tiers |
| [DECISIONS.md](docs/DECISIONS.md) | Architectural decision log (D1–D14) |
| [PLANNING.md](docs/PLANNING.md) | Phased execution plan + exit criteria |

`CLAUDE.md` holds the working conventions for AI-assisted development.

## Build & test

```sh
# Logic + tests (no Xcode needed)
cd StoryKit && swift test

# App
open StoryWorkspace.xcodeproj   # then ⌘R
```

Requires macOS 14+ and a recent Xcode. State/UI use the Observation framework;
tests use Swift Testing.
