# Phase 06 — Legitimizer

## Goal

Law 1 as code (FR-L-1/2/3): the pattern lifecycle (N verbatim repeats before any change), constrained mutation operators bound at loop boundaries, and the structural guarantee that no per-step chance exists anywhere.

## Deliverables (Sources/BerlinanEngine/)

- `Legitimizer.swift`
  - `Legitimizer.Config` — `repeats` (N, default 4, range 2–32; FR-L-1).
  - `advanceAtLoopBoundary(_:)` — lifecycle countdown: `.repeating(n) → .repeating(n−1) → .established`; `.established` is stable.
  - `isMutable(_:)` — established AND not locked (FR-V-4).
  - `mutate(voice:key:meter:seed:config:)` — returns the voice with a mutated pattern and lifecycle reset to `.repeating(N−1)`. No-op (identity) for locked or not-yet-established patterns. Operators (FR-L-2, spec §7.4):
    - **degree shift**: each non-first note has a 30% chance of a scale-fold-safe degree move up to ±1 octave of degrees; shifts that would push the resolved span past 24 semitones are skipped;
    - **time nudge**: one non-anchor note ±1–2 steps (collision-safe);
    - **accent move**: relocate or toggle one accent ("keep the notes, move the accents" [M §5.8]);
    - **intermittent ratchet** (FR-L-5 groundwork): all ratchets reset each mutation, then a 15% chance one note gets ratchet 2–3 — ratchets never persist beyond one legitimization cycle;
    - **bass voices**: pitch ops skipped entirely (roots stay roots — M §7.1), anchors untouched.
  - FR-L-3: no API accepts or stores a per-step play probability; mutation randomness binds once per cycle, never per render.

## Acceptance criteria

- [ ] Lifecycle countdown: `.repeating(3)` → 3 boundaries → `.established`; `.established` stays; fresh generator output plays exactly N=4 times before becoming mutable
- [ ] `mutate` is identity for locked patterns and for patterns still repeating (Law 1)
- [ ] `mutate` on established patterns: deterministic per seed; produces a change for at least one seed in 1…10
- [ ] Post-mutation invariants hold across 50 seeds: first sounding note = root, accidentals 0, positions in loop, span ≤ 24 st, bass anchor preserved, roots-only bass
- [ ] Post-mutation lifecycle = `.repeating(N−1)`; rendering the mutated pattern is loop-stable (identical content every repeat — randomness never re-rolls per render)
- [ ] At most one note carries ratchet > 1 after any mutation
- [ ] TDD red → green; `swift test` green

## Out of scope

Accumulators (FR-L-4, M3), snapshots (FR-L-6, M3), who *requests* mutations (arrangement SM, M5 / CLI schedule, phase 09).
