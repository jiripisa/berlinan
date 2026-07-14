# Phase 02 — Musical State & Scale

## Goal

The engine's tonal and temporal foundation (spec §6.1–6.2): time math, scale/key model, the degree-based pitch representation with resolution, octave fold, chromatic quantization, and the deterministic RNG. Pure value types, TDD.

## Deliverables (Sources/BerlinanEngine/)

- `Time.swift` — `Tick` (960 PPQN), `Meter` (beatsPerBar, beatUnit, grouping, tick math).
- `Tonality.swift` — `ModeID`, `Scale` (+ presets for the 10 manual modes [M §4.2]), `Key`.
- `DegreePitch.swift` — degree/octave/accidental; `Key.resolve(_:referenceC:)` (the ONLY degree→MIDI path, spec §6.2); `Key.quantize(midi:referenceC:)` with **ties resolving downward** (spec §7.1).
- `RegisterWindow.swift` — octave fold, never clamp (FR-V-3).
- `Rand.swift` — `SplitMix64` (stable across OS/Swift versions) + `SeedStream.derive` using FNV-1a label hashing (NOT `String.hashValue` — not stable across processes).

## Acceptance criteria

- [ ] Scale presets match manual §4.2 offset lists exactly
- [ ] Resolution: C minor @ referenceC 60 — degree 0→60, 2→63, 4→67, 7→72, negative degrees descend correctly
- [ ] Property: resolved pitch class ∈ scale pitch classes for random degree/octave (accidental 0)
- [ ] Fold: preserves pitch class, lands inside window, never clamps (window span ≥ 11 enforced)
- [ ] Quantize: in-scale MIDI is idempotent; C# in C major → C (tie goes DOWN)
- [ ] SplitMix64: same seed ⇒ identical sequence; SeedStream.derive stable and label-sensitive
- [ ] `swift test` green; tests written before implementation (TDD commits)

## Out of scope

Pattern/Voice types (phase 03), transposition scheduling (phase 07).
