# FORMAT.md — Story Workspace script convention

The supported input format for webtoon (vertical scroll) scripts. If it
parses, it works. Numbers and structure below reflect the canonical model
in TECHNICAL_DESIGN.md; decisions D10, D11, D15, D16.

## Structure

```
## EP2 (arc name)
## Goal of CH 2
One or two sentences describing what this episode must accomplish.

### Cut 1: Intro
Scene description: What the reader sees in this cut.
1. Caption: "A cup settles… and the surface stirs."
2. (S) Radio: "Another café erased today…"
3. Andie: "Order up!"
   3.1 (S) She slides the cup without looking.
```

- **Episode header**: `## EP<n>` with optional parenthetical. An optional
  goal block follows (`## Goal…` heading + prose) and is parsed into
  episode metadata.
- **Cut**: `### Cut <n>: <title>`. Legacy `### Scroll Block <n>: <title>`
  is accepted and converts on export.
- **Scene description**: an unnumbered line starting `Scene description:`
  directly under the cut header. Parsed into the cut's description field
  (label stripped). Other unnumbered prose at the cut top also lands in
  the description.
- **Lines**: `<n>. [size] [Speaker:] text`. Sub-lines use `<n>.<m>` and
  nest exactly one level; deeper numbering (15.1.1.1) is flattened to one
  level on import.

## Numbering

Numbers are display labels, not identity. The app assigns stable internal
IDs on import and renders/exports per-cut addressing (`EP / Cut / Line`),
recomputed from document order. Authored numbers are used only as
matching hints and validated for gaps at the top level (a jump from 7 to
9 produces an import warning). Insert and reorder freely; the app
renumbers on export.

## Size codes

Visual weight per line, used by the Flow reviewer as pacing signal.

- Accepted input: `(S) (M) (L)` or `<S> <M> <L>`, case-exact, immediately
  after the line number: `15. (L) Andie: …`
- Canonical export form: `(S) (M) (L)` — angle-bracket input round-trips
  out as parentheses.
- A bare `S`/`M`/`L` glued to text (`Szoom`, `LAndie`) is NEVER parsed as
  a size code. It produces an import warning ("possible lost size
  marker") and the text is kept verbatim. This protects against markup
  lost in export (see below) without letting the parser guess.

## Speakers

`Speaker: text` — the token before the first colon is parsed into the
line's speaker field (e.g. `Andie`, `Caption`, `Radio`). Lines without
the pattern have no speaker.

## Writing in Ulysses (authoring guidance)

The export pipeline is part of this format's spec: the app parses the
**plain-text export**, so only constructs that survive it are supported.

- **Do not use Ulysses inline markup for script semantics.** `~S~`
  exports as a bare `S` (marker destroyed → warning, not a size code).
  Other inline markup can leave stray shells like `()` or `([` in the
  export, which the parser surfaces as stray-markup warnings.
- Write size codes literally as `(S)` / `(M)` / `(L)` in the text.
- Keep one line of script per line of text; a new `<n>.<m>` marker
  mid-line splits into a new sub-line only within the current parent.
- Export as plain text (or paste directly). PDF export is not supported
  as intake: text extraction demonstrably mangles nested structure.

## Compatibility

- Legacy convention (Scroll Block headers, episode-continuous numbering,
  glued size codes) imports with warnings where information was lost, and
  exports in the current convention — the app doubles as a migration
  tool for the back catalog.
- Import is tolerant (sloppy whitespace, missing colons in headers);
  export is opinionated (one canonical form).
