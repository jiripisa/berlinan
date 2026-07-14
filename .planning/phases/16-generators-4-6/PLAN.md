# Phase 16 — Generators 4–6, Gate/Pitch Decoupling, Pattern Ops

## Goal

Complete the generator palette (FR-P-1 items 4–6), render the decoupled gate/pitch mode (FR-P-4), and add the standalone pattern operators (duplicate-and-tweak FR-P-6, accent ops FR-P-5). Engine-only, TDD.

## Deliverables

- `Generators.swift` additions:
  - **Drunkard's walk** [M §13.2]: chromatic walk (next pitch ≤ ±scatter semitones, default 2) starting on the root, quantized to the key, clamped to a 2-octave window (FR-P-2); non-metronomic rhythm = burst (2–5 steps) / rest (1–4 steps) state machine on the 16th grid.
  - **Staged pluck** [M §5.6]: per bar — syncopated roots (home base, root pinned at position 0) → octave jumps → scale-note fills → micro-melody (degrees 4–7) in the final bar → accented **signature closing note** on the last step.
  - **Arpeggiator expansion** [M §5.9]: held chord degrees × octave range (1–2) × direction (up / down / upDown) at 8th or 16th rate; **loop length = one full cycle** (e.g. 3 tones × 2 octaves of 8ths = 3 beats → natural polymeter against 4/4); down-direction cycle rotated to start on a root (FR-P-2 invariant holds).
- `Pattern.swift`: decoupled mode rendered — `Pattern.decoupled(id:pitches:gates:stepTicks:provenance:)` builds length = LCM(pitches, gates) × step; `occurrences`/`hasOnset` expand the two cycles ("both advance every step; gate off = silent step" — the 8v6 → re-sync at 24 model, M §6.4).
- `PatternOps.swift`: `duplicateAndTweak` (×N length, reps 1–2 verbatim, 1–2 mutations only in the later reps [M §5.7]); `moveAccents` (same notes, relocated accent [M §5.8]).

## Acceptance criteria

- [ ] New generators join the shared determinism + FR-P-2 invariant suites (50 seeds each)
- [ ] Walk: consecutive sounding pitches ≤ scatter semitones apart; rests exist; density < 70% of steps
- [ ] Staged pluck: root at position 0; octave-up note present; accented signature note on the final step
- [ ] Arpeggiator: up = ascending resolved pitches; down starts on a root pitch class; 3×2-octave 8th cycle → 3-beat loop
- [ ] Decoupled: 8 pitches v 6 gates (8ths) → 24-step composite, 16 onsets/period, correct pitch indexing, silent gaps; 7v8 → 56-step period; window chaining seam-safe
- [ ] duplicateAndTweak: first half verbatim, ≥1 change in the later reps (across seeds), deterministic; moveAccents keeps pitches/times/velocities intact
- [ ] `swift test` green; goldens untouched
- [ ] TDD red → green

## Out of scope

Generator/pattern-ops UI (phase 19 editor), decoupled patterns in the demo project (listening pass later in M3), 3-octave arps (register fold covers reach; span invariant caps generation at 2).
