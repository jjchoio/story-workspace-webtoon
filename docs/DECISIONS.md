# DECISIONS.md — Story Workspace

Architectural decision log. Format per entry: Decision / Reasoning /
Alternatives considered / Tradeoffs.

---

## D1. Review scope is user-defined per cycle

**Decision.** The app maintains an auto-updating content manifest (all
uploaded items). The author selects one or more items as the scope of a
review and may add a free-text note. "Review" is a request object
`{selection, note, reviewers}`, not an implicit "review whatever's new."

**Reasoning.** Authors know what needs attention; the system shouldn't
guess.

**Alternatives.** Auto-scope to latest changes; free-text scope parsed by an
LLM into manifest items.

**Tradeoffs.** For v1 the note is *guidance* passed to reviewers, not parsed
scope — keeps one code path. Free-text scoping may graduate later.

---

## D2. Subject vs. context separation

**Decision.** *Subject* = what is judged (author's selection). *Context* =
what informs the judgment (each reviewer's private retrieval strategy).
The orchestrator routes the subject and never touches documents.

**Reasoning.** All documents are author-uploaded, so cross-references are
unsurprising. Transparency comes from cards citing what they noticed, not
from exposing retrieval mechanics. Preserves "orchestrator doesn't know
storytelling."

**Alternatives.** User-visible/controllable context per review.

**Tradeoffs.** Author cannot force isolation ("review EP3 ignoring
everything else") in v1.

---

## D3. Write path: AI proposes, author disposes

**Decision.** Cards offer concrete options (keep / alternative(s) /
author-written replacement), Claude-Code style. Accepting applies a patch.
Only explicit author action mutates a document.

**Reasoning.** Makes "generate alternatives" actionable without AI writing
autonomously; consistent with non-goals.

**Alternatives.** Advice-only (dead-ends alternatives); AI applies edits
during discussion (violates product philosophy).

**Tradeoffs.** None significant; this is the philosophy made mechanical.

---

## D4. Upload is import; canonical representation + provenance history

**Decision.** Uploads (text/PDF) are parsed into a canonical internal
representation supporting fine-grained edits. Every mutation is recorded
with provenance, including a link to the causing card/option.

**Reasoning.** Enables patching, anchoring, diffing. History doubles as a
product surface ("what changed this cycle") and connects AI feedback to
document evolution.

**Alternatives.** Store files as opaque blobs; re-parse on demand.

**Tradeoffs.** Requires a parser and a canonical schema (scoped by D10/D11).

---

## D5. Re-upload = replace-with-diff

**Decision.** A re-uploaded file becomes the new canonical version after the
author reviews a structural diff against the current in-app copy and
confirms. No merging. Lineage records the replacement.

**Reasoning.** Once the app owns a patched canonical copy, re-upload is a
fork; replacement is the only mental model that stays understandable. The
diff doubles as a feature ("review the latest changes" can mean the diff).

**Alternatives.** Silent replace (loses work invisibly); three-way merge
(correct, prohibitively expensive, merge UIs are where products die).

**Tradeoffs.** Author can still lose in-app patches by confirming a
replacement — but knowingly.

---

## D6. In-app editing = refinement only

**Decision.** Read/write mode shows full document text. The author can
freely edit within existing documents; the app cannot create new documents.
Export to text/PDF supported.

**Reasoning.** "Creation is external, refinement is internal" preserves the
"not a writing tool" non-goal with a structural boundary (no new-file
affordance) rather than a fuzzy one.

**Alternatives.** No in-app editing (patch-application only) — rejected as
annoyingly restrictive; full writing tool — rejected by non-goals.

**Tradeoffs.** Must build a competent editing surface for long documents,
but not file management, fonts, autocorrect, etc.

---

## D7. Hybrid card lifecycle with per-suggestion staleness

**Decision.** Sessions are transactional (open → close; close archives).
During an open session both write paths are allowed. Every suggestion
anchors to stable spans; any overlapping edit flips that suggestion to
*stale* — per-suggestion, mechanical span-overlap, no LLM. Stale suggestions
remain visible/actionable. Never auto-refresh; re-review is deliberate.
Cards persist forever.

**Reasoning.** The rejected alternative (discard all cards on entering edit
mode) punished editing and didn't escape staleness anyway: accepting card
A's patch can stale card B mid-session, so span bookkeeping is required
regardless.

**Alternatives.** Silent staleness (trust-destroying); transactional discard
(workflow rigidity); auto-refresh (costly, violates user-initiated review
philosophy).

**Tradeoffs.** Anchor bookkeeping is a real subsystem — but it is also one
of the system's most interesting artifacts: cards as versioned artifacts
anchored to versioned documents.

---

## D8. Reviewers: shared pipeline skeleton + config + optional overrides

**Decision.** Every reviewer runs retrieve → reason → emit. A reviewer is
configuration `{role prompt, personality, retrieval spec, card schema}` with
optional code overrides at any stage. Reviewers ship with the app as
product features. Author selects reviewers per cycle.

**Reasoning.** Intentionality (the product's core quality bet) lives in
config *content*, not code *shape*. Common case cheap, special case
possible. Ten bespoke reviewers = 30 custom surfaces and no interesting
system shape.

**Alternatives.** Fully bespoke code per reviewer; pure config with no
overrides.

**Tradeoffs.** If a future reviewer truly needs a different pipeline (e.g.,
build-a-timeline-first), it uses overrides — the skeleton must keep that
door open.

---

## D9. Card schemas over a fixed, compiled-in SwiftUI primitive vocabulary

**Decision.** Cards are declared as schemas composing native primitives
(title, text, bullets, comparison, option buttons, simple chart) rendered
by a schema-driven SwiftUI renderer. No dynamic UI loading.

**Reasoning.** Per-reviewer unique UI from data, not code. Safe because
reviewers ship with the app (D8), so schema and vocabulary versions always
match at build time.

**Alternatives.** Hand-built views per reviewer; server-driven UI (wrong
fit for a local macOS app).

**Tradeoffs.** Reviewers can only use primitives that shipped; adding a
primitive is an app release. Schema versioning across releases is an open
question.

---

## D10. v1 targets webtoon (vertical scroll) only

**Decision.** One medium, one format. Naming and structure follow the
medium.

**Reasoning.** Focus; the document model can be medium-true instead of
generic.

**Alternatives.** Generic "story" documents (token soup — loses structural
retrieval, semantic anchors, computed pacing stats).

**Tradeoffs.** Paged manga / prose novels are out until the model is
generalized.

---

## D11. Document model: Episode → Cut → Line; IDs canonical, numbers derived

**Decision.** Canonical tree with stable internal IDs assigned at import.
Authored numbers are ignored (used only as diff-matching hints). The app
renders/export per-cut addressing (`EP / Cut / Line`), recomputed from
order. Industry term "cut" adopted in the data model.

**Reasoning.** No standard webtoon script format exists; the one widespread
convention is cut-based addressing for collaborator communication. Derived
numbering makes insertion/reordering free and keeps anchors stable. Line
identity across re-upload is matched by content similarity.

**Alternatives.** Episode-continuous numbering (renumbers globally on
insert); authored numbers as identity (fragile, chaotic under reorder).

**Tradeoffs.** Content-similarity matching on replace is the one genuinely
non-trivial algorithm; ambiguous matches need a fallback UX (open
question).

---

## D12. Discussion = card versioning within a session

**Decision.** No chat surface. A challenge note or renewal produces a new
card version *scoped to that suggestion*; other suggestions carry forward.
Renewal = "same intention, different path" (no repetition). After repeated
rejection the reviewer defers — honestly, without pretending to be
convinced. All versions persist under the session ID with causes recorded.
Sessions are timestamped and may span days.

**Reasoning.** The conversation is absorbed into the artifact rather than
displayed beside it — the product's central interaction bet. Suggestion
scoping prevents unrelated-suggestion churn (trust erosion). Escalating
deference encodes USER MAKES DECISIONS; honest deference preserves the
reviewer's future credibility.

**Alternatives.** Chat-in-a-drawer per card; whole-card regeneration on
challenge; reviewers that never defer (control) or instantly agree
(sycophancy — makes agreement worthless).

**Tradeoffs.** Multi-round arguments are possible but each round is
note → version; nuanced long debates are deliberately unsupported.

---

## D13. Three-tier memory architecture

**Decision.**
- **Tier 1 — card history (raw record):** everything (versions, challenges,
  accept/dismiss/ignore/skip, timestamps). Written by the system; read by
  the author's UI, by the summary agent once at session close, and by the
  developer for tuning. Never retrieved by reviewers.
- **Tier 2 — session overviews:** distilled at close by the summary agent
  (timestamp, subject, document versions, per-reviewer outcomes, notable
  patterns like repeated challenges). Retrieved when re-reviewing the same
  subject.
- **Tier 3 — promoted intent:** rulings the author explicitly promotes via
  "remember this." Retrieved by all reviewers, always. Editable/deletable.

**Hard rule:** reviewers read tiers 2–3 only.

**Reasoning.** The record and the memory are different things. Raw history
is unbounded, noisy, and teaches reviewers the litigation rather than the
ruling. Distillation bounds context regardless of project age. Promotion
keeps even memory itself a user decision; automatic learning rots (an
EP1-specific ruling silently becoming a global rule).

**Alternatives.** No cross-session memory (author re-litigates settled
decisions every cycle); automatic memory (silent, creepy, rots); reviewers
reading raw history (unbounded context, litigation-level reasoning).

**Tradeoffs.** Tier-2 quality depends on the summary agent's distillation;
the retrieval trigger (exact subject vs. related subjects) is open.

---

## D14. Plain-file persistence behind a ProjectStore protocol

**Decision.** Per-project directory; human-readable JSON, one file per
entity; append-only JSONL history log; documents versioned as immutable
files (never mutate, only add). All access goes through a `ProjectStore`
protocol; `FileProjectStore` is the v1 implementation.

**Reasoning.** Debuggability while the schema is fluid (you can read your
own history), zero migration machinery, portfolio-legible. Append-only
immutable facts make both debugging and any future migration (new store
implementation + a one-time importer) trivial.

**Alternatives.** SwiftData/Core Data (migration overhead + opacity during
schema churn); SQLite directly (premature).

**Tradeoffs.** No query engine — acceptable while reads are
whole-document loads; revisit if tier-2 retrieval ever needs real queries.
Migration insurance is the protocol boundary, not an anticipatory schema.

## D15. Canonical model: one-level nesting + episode goal

**Decision.** `Line` gains optional children, exactly one level deep; the
parser flattens deeper authored nesting (e.g. 15.1.1.1 becomes a child of
15) rather than erroring. `Episode` gains optional metadata parsed from
the header block, including `goal`. Addressing extends naturally:
`EP / Cut / Line / Child` (e.g. EP2 / Cut 3 / Line 15.1).

**Nested staleness semantics.** An edit to a child stales suggestions
anchored to that child AND to its parent (the parent's moment changed);
an edit to a parent stales the parent's suggestions only, not every
child's.

**Reasoning.** The scripts contain real sub-beats within a moment —
structure reviewers can use (beat density is pacing signal). Depth beyond
one level is treated as formatting habit, consistent with D11's
numbers-are-hints philosophy. The episode goal is a second retrieval
source for the North Star reviewer (global north star + per-episode
goal), promised in PRODUCT.md but previously homeless in the model.

**Alternatives.** Flat model discarding nesting (loses beat structure);
unlimited depth (complexity the anchor/staleness machinery inherits
forever).

**Tradeoffs.** Anchor bookkeeping must handle the parent/child overlap
case; accepted with the asymmetric rule above.

---

## D16. Cut description + size codes as structured metadata

**Decision.** `Cut` regains `description: String?` (the scene-description
line; general-purpose home for unnumbered cut-top prose in v1). `Line`
gains `size: SizeCode?` (S/M/L enum) parsed from explicit delimited codes,
stripped from text. Accepted input forms: `(S) (M) (L)` and `<S> <M> <L>`,
case-exact, immediately after the line number. Canonical export form:
parentheses. Bare glued codes (legacy corrupted exports like "Szoom",
"LAndie") are NEVER parsed as size codes — they produce an import warning
("possible lost size marker") and text stays verbatim.

**Reasoning.** Scene description was always in the technical design; size
codes are visual weight encoded in the script — the Flow reviewer's
primary v1 signal beyond line density (a large cut is a held beat; a run
of smalls is rapid rhythm). The original authored syntax (~S~) was
destroyed by the Ulysses plain-text export, which surfaced the governing
principle: **when the format is ours to define, fix the format rather
than teach the parser to guess.** Tolerance is for sloppiness, not for
lost information. A lexical heuristic ("is the remainder a plausible
token?") was considered and rejected — it fails silently (e.g. a line
starting "Since" after a size mark) and erodes trust in the parser.

**Alternatives.** Lexical disambiguation of glued codes (rejected as
above); keeping codes in text verbatim (loses queryable pacing signal).

**Tradeoffs.** Authors must use the delimited syntax; legacy scripts get
warnings, not silent repair. The export pipeline is now explicitly part
of the input format's spec (see FORMAT.md).

---

## D17. Review Mode: upfront holistic pass, guided reveal

**Decision.** Review Mode is a presentation lens over the existing card
model, not a new generation architecture. The reviewer reviews its full
scope in ONE call, producing its complete suggestion list. Review Mode
then walks suggestions one at a time in document order. Accepting applies
the patch immediately and highlights the change in read mode.
Freshness comes from existing machinery: suggestions whose anchors were
not touched by earlier accepts present instantly (no LLM call); when the
walk reaches a suggestion staled by an earlier accept, the app
auto-triggers a scoped renewal (D12) against current text. Toggling the
mode off returns remaining suggestions to the normal card view — the mode
is a lens, not a lifecycle. A live indicator animates during the walk.

**Reasoning.** "One thing at a time" is a core interaction value, but
per-finding generation was rejected on three grounds: (1) token cost
inverts — each incremental call re-sends the full context plus an
accumulating decision log, so a completed walk costs a multiple of the
single-pass approach; (2) streaming reduces perceived latency but not
per-step thinking time — a pause after every accept survives streaming;
(3) a reviewer generating one finding at a time never sees the episode
whole, structurally preventing cross-line observations — the thing that
distinguishes a specialist from a linter.

**Alternatives.** Incremental generation per accept (rejected as above);
one-card-per-finding data model (rejected earlier in the same discussion —
it breaks D7's per-suggestion staleness, dilutes reviewer identity, and
turns the deck into a notification pile).

**Tradeoffs.** Non-overlapping edits are assumed independent; a
tone-level change can invalidate a distant suggestion without touching
its anchor. Escape hatch: explicit per-reviewer "re-look."

---

## D18. Per-reviewer thoroughness setting in Preferences

**Decision.** Each reviewer has a persistent thoroughness setting —
Light / Standard (default) / Deep — stored as reviewer config, changeable
anytime in Preferences, injected into the prompt as the flagging
threshold. Light: only what meaningfully hurts the story; silence is
endorsement. Standard: important findings plus clear improvements, skip
nitpicks. Deep: everything worth knowing, still ranked by severity.
Severity remains in the card schema at every stop, so Deep ranks rather
than floods.

**Reasoning.** Flagging volume is the difference between a helpful
reviewer and an exhausting one, and the right volume is per-author
preference — "tuning your staff," not answering a survey every cycle.
Three stops because a continuous slider promises precision a prompt
cannot honor.

**Alternatives.** Fixed personality-defined threshold (no user control);
per-cycle dial (repetitive friction, wrong mental model); continuous
slider (false precision).

**Tradeoffs.** A Light review finding little is good news only if the
user knows it was Light — cards should eventually display the
thoroughness that produced them (cheap metadata, real trust dividend).

---

## D19. Batch review, minimal contract, salvage-tolerant parsing

**Decision.** A review is ONE model call over the selected lines. The reviewer
returns `{ cards: [ { target, blocks, alternatives } ] }` — for each line, its
reasoning blocks (`quote`/`text`) and 0–2 rewrite `alternatives`. Each card is
matched to its line by the model-echoed `target` id (`cut.line[.child]`), not by
position. The app **synthesizes the constant options** (Keep + Write-your-own);
the model never emits them. Zero alternatives is legal — silence is endorsement.
Parsing is **salvage-based**: entries are classified by `type`/`kind` wherever
the model placed them (a rewrite mis-dropped into `blocks` is reclassified), a
truncated final card is discarded, junk elements are dropped — each logged — so
one malformed card never sinks the deck.

**Reasoning.** The episode + North Star are the expensive context; sending them
once per selection instead of per line saves ~N× input tokens and N−1 round
trips. Shrinking the model's job to the *variable* part (reasoning +
alternatives) removes whole classes of malformed output — it can't mis-type the
constant actions. Id-based anchoring is the load-bearing seam: it lets a future
reviewer decide *which* lines in a broader scope deserve a card (D17) as a
prompt change, not a plumbing change. Tolerant parsing accepts the empirical
truth that instructed-JSON output drifts.

**Alternatives.** A call per line (N× context, N round trips); position-based
card↔line mapping (fragile to omission/reorder); a single strict decode (one
bad element throws away the whole batch); the model emitting Keep/Write itself
(more surface to malform).

**Tradeoffs.** Per-line depth can be slightly shallower in a large batch, and
output tokens grow with the line count (capped, with a logged token estimate +
warning). Streaming the reply is deferred. Structured-output/JSON-schema
enforcement (Anthropic-specific) is a future hardening option, kept out for now
to preserve the provider-agnostic seam (D8).
