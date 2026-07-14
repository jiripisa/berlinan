# Phase 03 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Pattern/PatternNote/GateStep preconditions | ✅ (positions in loop, gate > 0, velocity 1–127, ratchet 1–3, gate width 0.4–0.99) |
| `occurrences(in:)` loop-cursor math | ✅ repeats at loop intervals, half-open ranges, mid-loop windows, 15-step loops, sorted output |
| Rotation semantics `(global + offset) mod length` | ✅ occurrence + anchor tests |
| `firstSoundingIsRoot` (earliest note, degree ≡ 0 mod count, accidental 0) | ✅ incl. rest-start patterns |
| Anchor check (FR-V-5): beats1and3 / beat1 / none, rotation-aware, LCM-verified (sub-bar + 3-beat counterexample) | ✅ |
| Codable round-trips (Pattern with gateCycle + lifecycle, Voice) | ✅ |
| `lcm` helper (16/15→240, 16/24/19→912) | ✅ |
| TDD red → green | ✅ |
| `swift test` | ✅ 34 tests / 12 suites |

## Notes / deviations

- **Pattern.id is a stable String** (e.g. "bedPluck1/gen3"), not the UUID from
  the spec §6.3 sketch — random UUIDs would break render determinism (NFR-4).
  Recorded in STATE.md decisions; spec sketch to be amended when §6 is next
  touched.
- Voice carries musical fields only; MIDI routing/CC maps/mod lanes join in
  their phases so the engine stays dependency-free.
