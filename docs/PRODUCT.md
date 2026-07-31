# PRODUCT.md — Story Workspace

## Vision

An AI-assisted creative editor that helps authors maintain story quality across
long-form webtoon projects. It organizes project knowledge (North Star,
character arcs, episodes) and launches specialized AI reviewers that analyze
selected material in parallel. Their findings stream into interactive review
cards, where authors can explore suggestions, challenge them, generate
alternatives, and decide what to keep — a structured, transparent collaboration
between human and AI instead of a traditional chat interface.

**v1 scope: webtoon (vertical scroll) format only.**

## Core Principles

- **USER MAKES DECISIONS.** Reviewers advise; the author decides. Nothing
  mutates a document except the author's explicit action.
- **Creation is external; refinement is internal.** New material is written in
  the author's own tools and uploaded. The app owns review, refinement,
  patches, and history — it is deliberately *not* a writing tool.
- **Cards, not chat.** Every AI response is a structured, persistent card.
  There is no free-form chat surface anywhere in the product.
- **Reviewers advise with integrity.** A reviewer may hold its position under
  challenge (while visibly metabolizing the author's reasoning), and after
  repeated pushback it defers honestly — "keeping it as-is per your call" —
  without pretending to be convinced. Deference is about authority, not truth.

## Goals

- Upload & persist documents: North Star, character arcs, episodes
- Author-defined review scope: select any items from an auto-maintained
  content manifest, optionally with a free-text note
- Multiple specialized reviewers (v1: Dialogue, North Star, Flow), each with
  intentional prompt, expertise, retrieval strategy, card design, and
  personality; author selects which reviewers run per cycle
- One persistent review card per reviewer per cycle
- Challenge/renew loop per suggestion: author input produces a new card
  version (no chat thread)
- Accept a suggestion → applies a patch to the document
- In-app refinement editing (read/write mode showing full episode text)
- Re-upload of revised files with diff-and-confirm replacement
- Session close: a summary agent produces an overview + todo list
- "Remember this" promotion: author can turn a ruling into standing intent
  that future reviews respect
- Export episodes as text/PDF

## Non-Goals

- Not a chat experience with an AI agent
- Not a writing tool — no document creation in-app, no fonts/autocorrect/file
  management; the app refines existing documents only
- Not a tool where AI does the work for you — AI proposes, author disposes
- v1 is text-only (no art/image analysis); the Flow reviewer judges pacing
  only as inferable from script structure
- v1 supports one input format: the project's markdown script convention
  (episodes → cuts → scene descriptions + speaker lines)

## v1 Reviewers

1. **Dialogue** — grammar, tone, and character voice consistency (voice is the
   differentiating job; grammar is bundled convenience)
2. **North Star** — alignment of episodes with the uploaded North Star and
   per-episode goals
3. **Flow** — pacing as inferable from script structure (cuts per episode,
   line density per cut, scene lengths); explicitly scoped to not judge
   visuals it cannot see

## User Flow

1. First use: author uploads North Star, character arcs, episodes (markdown
   convention; PDF/text accepted and parsed on import).
2. Author defines review scope: selects items from the content manifest
   (auto-updated on every upload) and/or adds a note; selects reviewers.
3. Each selected reviewer streams its findings into its own card.
4. Per suggestion, the author can: **accept** (patch applied), **dismiss**,
   **challenge** (note → new card version), **renew** (ask for a different
   approach), or **ignore/skip** — all actions are recorded.
5. Author may edit freely in write mode during an open cycle; suggestions
   whose anchors are touched are marked **stale** (still visible, still
   dismissible, re-review on request — never auto-refreshed).
6. When the author finishes, the summary agent closes the session: summary,
   todo list, and a session overview for future reference.
7. Author makes further edits in-app or externally (re-upload shows a diff
   before replacing).
8. Repeat.

## Interaction Philosophy

- All AI responses are card UI — streamed, dynamic, unique per reviewer.
- Cards are composed from a fixed vocabulary of native primitives (title,
  text, bullets, comparisons, option buttons, simple charts).
- Suggestions offer concrete options Claude-Code style: keep as-is / proposed
  alternative(s) / author-written replacement.
- Discussion has no surface of its own: a challenge is absorbed into the next
  card version, which must visibly respond to the author's note.
- Cards persist forever, grouped by review session — the review history *is*
  the project history, replacing chat history as the product's memory surface.
- Read/write mode shows full episode text side-by-side with cards.
- The history isn't a scroll — it's a deck. Authors flip through
  reviewed cards, each a complete thought with its verdict, version
  chain, and provenance attached. Cards are skimmable at a glance:
  status (accepted / dismissed / stale / overruled) is visible without
  opening.
- Review Mode: an optional guided walk through a review's suggestions,
  one at a time in document order. Accepting applies the change
  immediately and highlights it in the script; the walk continues
  against the updated text. Turning the mode off returns remaining
  suggestions to the card view — nothing is discarded.
- Every reviewer has a thoroughness setting (Light / Standard / Deep)
  in Preferences — the author tunes their staff once, not every cycle.
