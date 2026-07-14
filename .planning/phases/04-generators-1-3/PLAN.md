# Phase 04 — Generators 1–3

## Goal

The first three pattern generators (FR-P-1), deterministic and invariant-safe: Seed procedure [M §5.2], High/Mid/Low contour [M §5.3], Pulsing 16th bassline [M §5.5]. Engine-only, TDD.

## Deliverables (Sources/BerlinanEngine/)

- `Generators.swift` — `GeneratorConfig` (enum with per-generator params), `HMLRegister`, `PatternFactory.make(id:config:role:key:meter:seed:)`.
  - **Seed procedure**: roots on every beat → N mutation ops (move-time on non-locked ticks, move-degree except first sounding note, add octave-up note, toggle accent); beats 1&3 timing-locked [M §5.3]; bass role reduces to root onsets on beats 1&3 (anchor-safe, transposable [M §7.1]).
  - **High/Mid/Low**: high = root/+4/root/−3 contour with backbeat time shifts; mid = stair steps (+4/−4), beats 1&3 locked on grid; low = beats 1&3 roots only.
  - **Pulsing bass**: all 16th steps on the root, low velocity, short gates; 2–4 off-root mutations (octave ±1 / few scale steps) with raised velocity + accent flag; majority stays on the root.

## Acceptance criteria (all generators unless noted)

- [x] Determinism: same (config, seed) ⇒ identical pattern; varying seeds produce differing note content
- [x] Invariants (FR-P-2): first sounding note = root; all accidentals 0; positions within loop; resolved span ≤ 24 semitones; gates 40–60% of a 16th step
- [x] Seed procedure: onsets exist at beats 1&3 (bed roles); bass role → passes `satisfiesAnchor(.beats1and3)` with roots only
- [x] High/Mid/Low: high contains the +4 (5th-up) degree; low = exactly two onsets (beats 1&3); mid keeps beats 1&3 as on-grid roots
- [x] Pulsing bass: onset count = 16th steps per bar; ≥ 75% root pitch class; exactly the off-root notes are accented with velocity > baseline
- [x] Provenance carries generator id + seed
- [x] TDD red → green; `swift test` green

## Out of scope

Density-cap enforcement (FR-V-6, P2), drunkard's walk/staged pluck/arpeggiator (P2 generators), velocity humanization policy (phase 09 / M3).
