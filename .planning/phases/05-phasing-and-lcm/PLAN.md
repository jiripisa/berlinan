# Phase 05 — Phasing & LCM Convergence

## Goal

The style's variation engine (M §6): voices with unequal loop lengths rendered against a shared tick grid, one-action phased-copy setup, and the convergence math the UI will display (FR-PH-1/2/4).

## Deliverables (Sources/BerlinanEngine/)

- `Phasing.swift`
  - `Pattern.withLength(_:)` — truncate (drops cut-off notes — "cutting off notes mid-loop is fine" [M §6.1]) or extend a loop, non-destructive copy.
  - `Pattern.rotated(by:)` — start-point rotation as a copy (FR-PH-3 groundwork; normalizes mod length).
  - `PhasingOps.phasedCopy(of:newLength:idSuffix:)` — the FR-PH-2 primitive ("phase this voice").
  - `EnsembleEvent` + `PhasingEngine.events(voices:in:)` — multi-voice merged, time-sorted note occurrences over a global tick range (FR-PH-1); the note-stream primitive phases 07–09 build on.
  - `Convergence.period(lengths:)` — LCM with **overflow guard** (returns nil = practically infinite, spec §7.3); `Convergence.bars(period:meter:)`, `Convergence.seconds(period:bpm:)` (FR-PH-4).

## Acceptance criteria

- [ ] `withLength`: truncation drops notes at/after the new end, extension preserves all; rotation normalizes into 0..<length
- [ ] 16-step vs 15-step pair: onsets of the short copy traverse **all 16 relative offsets** (unison + 15 variations [M §6.1]) before re-sync; 14-step copy yields 8 offsets (unison + 7)
- [ ] Convergence: 16v15 steps → 15 bars in 4/4; 16/24/19 chord-tone polymeter → 57 bars; overflow → nil
- [ ] `PhasingEngine.events`: merged stream is time-sorted, respects half-open windows, tags events with voice ids
- [ ] TDD red → green; `swift test` green

## Out of scope

Gate/pitch decoupling rendering (M3, FR-P-4), the UI convergence ring (M2), harmony transposition of the stream (phase 07).
