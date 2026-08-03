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

## How this is built

![The AI-native development loop — design-partner sessions → DECISIONS.md → PLANNING.md → acceptance tests → human verification gate → Claude Code implementation → learnings, looping back to sessions. Purple = human decisions, green = AI execution, grey = shared artifacts.](docs/assets/ai-native-dev-loop.jpg)

**Built AI-natively, with the human holding the gates.** The system was designed
through structured AI design-partner sessions — one question at a time, every
decision logged with its reasoning, alternatives, and tradeoffs. Claude Code
implements against acceptance tests derived from each phase's exit criteria,
governed by working rules in CLAUDE.md — and nothing gets built until the author
has ruled on ground truth.

**Where to start reading:**

- [D12 — discussion as card versioning](docs/DECISIONS.md): why there's no chat thread.
- [D7 — per-suggestion staleness](docs/DECISIONS.md): how cards stay honest when the script changes.
- [D16](docs/DECISIONS.md) + [PLANNING.md Phase 1 learnings](docs/PLANNING.md): the export-pipeline-is-part-of-the-format story.

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
| [DECISIONS.md](docs/DECISIONS.md) | Architectural decision log |
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
