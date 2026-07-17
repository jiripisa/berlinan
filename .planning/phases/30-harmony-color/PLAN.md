# Phase 30 — Tension Budget, Chord Layer, Heartbeat Kick

## Goal

The last colors from the manual: the explicit allowance of 1–2 out-of-key
notes per piece (FR-H-7), the §13.3 stochastic chord layer as a pad-voice
generator (FR-H-8), and the quarter-note heartbeat kick voice (FR-V-7).

## Design decisions

- **Tension budget (FR-H-7)**: `Project.tensionBudget` (default 2) seeds an
  engine counter. The live action `.spendTension(voiceID)` (bar-quantized)
  emits ONE sustained non-diatonic note — degree 0 with `accidental = +1`
  (minor 2nd against the root), a whole bar long, accented — through the
  one-and-only quantizer bypass (`DegreePitch.accidental`). Exhausted budget
  → no-op. The snapshot mirrors the remaining count.
- **Chord layer (FR-H-8)**: generator `.chordLayer(periodBars: 7)` — one
  chord sustained for the whole loop. §13.3 recipe per seed: 20% stay on
  the root / 80% pick +1..12 semitones, chromatic-quantize into the key,
  stack +4/+7/+12 semitones, re-quantize each. The Legitimizer's normal
  lifecycle re-rolls it every N loops — "one chord per ~7 bars".
- **Heartbeat (FR-V-7)**: generator `.heartbeat` — the root on every beat,
  quiet and unaccented; assign to a `.rhythm` voice on its own channel.

## Acceptance criteria

- [ ] spendTension: exactly one out-of-key note at the next bar, sustained a
      whole bar; budget decrements; exhausted → silence; snapshot mirror
- [ ] Chord layer: ≥ 3 simultaneous in-scale notes, gate = full loop,
      loop = periodBars; deterministic per seed, varies across seeds
- [ ] Heartbeat: one onset per beat, root only, no accents
- [ ] Suite green; app builds (TENSION button in the performance panel)
- [ ] Human: the m2 stab reads as an event; the chord pad breathes under
      the beds; the kick anchors without pushing

## Out of scope

Release (31). Chord-layer voicing options, kick patterns beyond quarters.
