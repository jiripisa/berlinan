# Phase 03 — Pattern Model

## Goal

The engine's pattern and voice value types (spec §6.3) with loop-cursor math: given a global tick range, a pattern reports its note occurrences — the primitive everything else (phasing, rendering, export) builds on.

## Deliverables (Sources/BerlinanEngine/)

- `Pattern.swift` — `PatternNote` (position/pitch/velocity/gate/accent/ratchet), `GateStep`, `Provenance`, `Lifecycle` (.repeating/.established), `Pattern` (free-form `length` [FR-P-3], `startOffset` rotation [M §6.2], validation preconditions), `occurrences(in:)` loop-cursor math, `firstSoundingIsRoot(scaleCount:)` helper.
- `Voice.swift` — `VoiceRole`, `AnchorPolicy` (+ `requiredLocalTicks(meter:)`), `Voice` (musical fields only — MIDI routing/mod lanes arrive in later phases), `satisfiesAnchor(meter:)` (FR-V-5 check, rotation-aware, verified across the pattern/bar LCM).
- `Math.swift` — `gcd`/`lcm` for Tick (needed here for anchor check, reused by phase 05 convergence).

## Acceptance criteria

- [ ] Pattern preconditions reject invalid data (empty length, out-of-range positions, zero gate, velocity 0/>127)
- [ ] `occurrences(in:)`: correct global positions across multiple loop iterations, half-open ranges, non-power-of-two lengths (15 steps)
- [ ] Rotation (`startOffset`) shifts occurrence times per `localTick = (global + offset) mod length`
- [ ] `firstSoundingIsRoot` true iff earliest note is a root pitch class with no accidental
- [ ] Anchor check: bass with onsets on beats 1+3 passes; missing beat-3 onset fails; rotated pattern evaluated correctly; verified over LCM(pattern, bar)
- [ ] Codable round-trip: Pattern and Voice survive JSON encode/decode intact
- [ ] TDD: red commit precedes implementation; `swift test` green

## Out of scope

Generators (phase 04), multi-voice convergence display math (phase 05), lifecycle *transitions* (phase 06 — here only the data type).
