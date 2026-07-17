# Phase 33 — Drone Intro & Slides

## Goal

Two genre signatures: pieces OPEN on a drone (the arranger's intro starts
with the drone voice alone, sequences enter over it), and bass/lead lines
GLIDE — tie steps produce legato overlaps that a mono synth with portamento
turns into the classic slide.

## Design decisions

- **Drone generator** `.drone(bars:)`: root + fifth sustained for the whole
  loop, quiet, unaccented — deterministic (no dice). Role `.drone` moves to
  the FRONT of the derived build order (FR-A-2 extension): with a drone in
  the project, AUTO opens on it; without one, behavior is unchanged.
- **Ties (slides)**: `PatternNote.tie: Bool?` (optional — old documents
  decode unchanged). A tied note's gate stretches to the next onset plus a
  small overlap (`PatternOps.applyTies`, applied at render next to the
  density cap) — MIDI legato overlap = portamento glide on a mono synth.
- **Mutation operator**: gated by `Project.slidesEnabled` (default OFF so
  every existing project renders byte-identically): when on, the mutation
  pool may set/clear a tie on one note (bass and lead roles only — beds
  stay ducka-ducka).
- **Hint**: the Delay Cheat Sheet row shows a "glide" tag for voices whose
  pattern carries ties ("enable portamento ≈ 60–120 ms, legato mode").

## Acceptance criteria

- [ ] Drone: one root+fifth chord, gates = loop length, quiet; build order
      puts a drone first; demo (no drone) order unchanged
- [ ] applyTies: tied gate reaches the next onset (+overlap), last note
      wraps to the loop's first onset; untied notes untouched
- [ ] Rendered tied notes overlap the following note (note-off after the
      next note-on)
- [ ] slidesEnabled=false → whole suite (incl. golden masters) untouched;
      =true → some seed yields a tie on a bass voice within a few cycles
- [ ] Human: AUTO with the ambient template opens on the drone; a mono bass
      with portamento audibly slides

## Out of scope

Tie editing in the pattern editor (backlog note), CC scenes (34).
