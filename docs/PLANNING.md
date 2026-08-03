# PLANNING.md — Story Workspace

Living execution plan. Phases get updated, reordered, and annotated with
outcomes as we learn. Stable truths live in PRODUCT.md / TECHNICAL_DESIGN.md
/ DECISIONS.md; this document is allowed to churn.

## Working Model: Two Parallel Tracks

- **Track A — Prompt harness (no app code).** Using Claude/ChatGPT directly
  to develop per-reviewer system prompts and output schemas against real
  script material (Cafe Alameda). Builds on ~2 years of informal reviewer
  simulation. Output: refined prompts + JSON card-shaped outputs that become
  fixtures for Track B.
- **Track B — Application code.** Builds the foundation in dependency order
  along the data spine. The tracks merge when the pipeline can execute a
  real reviewer prompt (Phase 2, step 6).

Rationale: reviewer quality is the product's load-bearing wall; the harness
systematizes it while the foundation is built, instead of blocking either on
the other.

---

## Phase 1 — The Data Spine (no LLM, minimal UI)

1. **Parser**: markdown script convention → canonical `Episode → Cut → Line`
   tree with stable internal ID assignment (D11).
   - Accepts BOTH conventions: legacy (`Scroll Block`, episode-continuous
     numbering) and updated (`Cut`, per-cut numbering). Both parse to the
     identical canonical tree; downstream code never knows which was used.
   - Tolerant on input, opinionated on output: export always emits the
     updated Cut convention (free migration path for legacy scripts).
   - Authored numbers ignored for structure, but validated: numbering gaps
     produce an import warning (numbers as checksum, not identity).
2. **Persistence**: `FileProjectStore` behind the `ProjectStore` protocol
   (D14). Per-project directory, human-readable JSON, one file per entity,
   append-only JSONL history.
3. **Read mode rendering**: full episode view from the canonical model with
   per-cut addressing visible.

**Exit criteria (all must pass):**
- [ ] Both format variants of Cafe Alameda EP2 parse into identical
      canonical trees (modulo IDs)
- [ ] Project persists via FileProjectStore and survives app restart
- [ ] Read mode renders the episode with per-cut addressing
- [ ] Stress test: edit source externally (insert a line, reorder two
      cuts), re-import → IDs remain stable via content matching
- [ ] Legacy-format import → export round-trip emits updated Cut convention

**Learnings:**
- **PDF intake is a dead end for v1.** Naive text extraction demonstrably
  mangles nested structure (per-cut numbers collapsed onto shared lines);
  real PDF intake means layout-aware parsing — a subsystem, not a step.
  Writers don't author in PDF anyway; their source tool's plain-text
  export is lossless and equally available. Parser input is a String;
  intake is a separate adapter seam (text/paste in v1, PDF deferred).
- **The export pipeline is part of the input format.** Two corruption
  modes surfaced from the Ulysses → plain text export: ~S~ size markers
  eaten, stray paren shells from other markup. The spec is now "write in
  Ulysses using only constructs that export losslessly" — documented in
  FORMAT.md. Governing principle (D16): fix the format, don't teach the
  parser to guess. The parser surfaces corruption as import warnings and
  never silently repairs.
- **The model was missing real structure the scripts already had:**
  one-level line nesting (sub-beats), episode goal, cut scene
  description, and size codes (D15, D16). The verification-gate habit —
  human confirms the derived tree before parser implementation — caught
  a corrupted-source artifact that would otherwise have been encoded
  into test expectations as ground truth.
- **Fixture strategy:** clean fixture pair (one per size-code syntax
  variant) asserts the tree; one deliberately dirty legacy export
  asserts the warning path and verbatim-text preservation.

---

## Phase 2 — One Reviewer Through the Pipe (delivered)

*Delivered beyond the original slice: batch multi-line review into a card
deck, a provider-agnostic AI layer, whole-episode + North Star context, a
focused-card carousel with switchable deck styles, and an early write-loop
slice (accept/revert/renew). See Learnings.*

4. Pipeline skeleton: retrieve → reason → emit, with one hardcoded reviewer
   config (D8).
5. Card schema types + schema-driven SwiftUI renderer with a minimal
   primitive set (title, text, option buttons) — just enough to render
   Track A's real output (D9). Include the at-a-glance status affordance
   (accepted / dismissed / stale / overruled) in the base schema.
6. **Track merge:** wire one reviewer end-to-end — select EP2 → review →
   rendered card using Track A's refined prompt.
   
   - Card schema as output contract: reviewer emits JSON to a fixed schema
  (header: reviewer, scope, overall read ≤2 sentences; suggestions[]:
  anchors, verdict, note ≤2 sentences, alternative, severity). Structure
  is constrained by the contract; personality lives in the field content.
- Reviewer prompt architecture: three separable blocks — identity (fixed
  personality), contract (schema + budgets + anchor format), calibration
  (thoroughness injection point, D18) — so tuning one never perturbs the
  others.

**Exit criteria:**
- [x] A real review of EP2 by one reviewer renders into a card
- [x] Card schema round-trips: reviewer JSON output → schema types →
      rendered SwiftUI
- [x] Expected fight: D9's primitive vocabulary held — `quote`/`text` blocks
      and `keep`/`alternative`/`authorWritten` options survived contact. What
      changed was the *envelope*, not the primitives (see Learnings).

**Learnings:**
- **Batch beats per-line.** The episode + North Star are the expensive
  context; sending them ONCE per multi-line selection and returning a deck of
  cards saves ~N× input tokens and N−1 round trips. Cards map to lines by a
  model-echoed `target` id (not position) — the seam that lets a reviewer pick
  *which* lines deserve a card later (D17) as a prompt change, not a rewrite.
  Formalized as D19.
- **Shrink the model's job.** The reviewer emits only reasoning + alternatives
  (0–2; zero = endorsement); the app synthesizes the constant Keep +
  Write-your-own. Removing those from the model's output killed a whole class
  of malformed cards (it can no longer mis-type the constant actions).
- **LLM output drifts; parse defensively.** Real replies mis-placed fields
  (alternatives inside `blocks`), truncated mid-array, and emitted junk
  elements. A reclassifying, salvage-based parser recovers/drops per element
  and never fails the whole deck — with warnings logged so drift stays visible.
- **Context shape:** whole-episode context (target line marked) beat an
  N-neighbour window; the North Star rides in the system prompt as shared
  grounding for every reviewer.
- **The write loop wanted to come early.** Accept → patch → immutable version
  (D14) + honest Renew (D12) + inline Revert (restoring version) proved the
  core loop mid-phase; that validated the model before more UI investment.
- **Formatting is fiddly at the seam.** A line's speaker/attribution and its
  quoting must be preserved on Accept — including *embedded* lead-ins the
  parser doesn't split into the speaker field (e.g. `Andie shouts:`).

---

## Phase 3 — The Write Loop (next)

7. ~~Accept-a-suggestion → patch applied to canonical model → provenance
   entry linking back to card/option (D3, D4).~~ **Landed early in Phase 2:**
   accept patches the document + persists an immutable version with
   provenance; revert appends a restoring version; renew re-runs honestly.
   *Remaining here:* link provenance back to the specific card/option.
8. Staleness: anchor bookkeeping; overlapping edits flip suggestions to
   stale, per-suggestion (D7).
9. Card + session persistence (D13): cards persist forever, grouped by
   review session — the review history *is* the project history. Includes
   the durable "declined" record that Dismiss currently keeps only in
   session.
10. Review Mode walk (D17): presentation lens over the card model — reveals
   a review's suggestions one at a time in document order, accepting in
   place. Builds directly on item 8's staleness (D7) + scoped renewal
   (D12) for freshness, which is why it lands here, not in Phase 2.

**Exit criteria:**
- [~] Accepting an option mutates the document and records provenance
      *(done; card/option link outstanding)*
- [ ] An edit overlapping an anchor marks exactly that suggestion stale
- [ ] Stale suggestions remain visible and dismissible
- [ ] Cards and their outcomes (accepted / declined / reverted) persist
      across restart, grouped by session
- [ ] Review Mode walks a review's suggestions in order; a suggestion
      staled by an earlier accept auto-triggers a scoped renewal (D12)

**Learnings:** *(fill in)*

---

## Design Work Queued (whiteboard, not code)

- **Diff correspondence**: line identity across re-upload via content
  similarity — D5/D7/D11 all lean on it; design on paper before Phase 3
  makes it unavoidable. Includes fallback UX for ambiguous matches.

## Deliberately Deferred

- Second/third reviewer (proves config is cheap — or that the skeleton was
  wrong)
- Sessions, summary agent, session overviews (tier 2)
- Promoted intent (tier 3)
- Re-upload diff UX
- Write mode (free-form in-app editing)
- Challenge loop + persisted card-version chains with escalating deference
  (scoped renewal D12 is in-scope — an honest-renew slice already landed;
  the full challenge/versioning loop stays deferred)

Deferral logic: none of these are on the critical path to learning whether
the core loop (parse → review → card → accept → patch) works.
