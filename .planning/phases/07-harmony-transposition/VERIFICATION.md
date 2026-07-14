# Phase 07 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Pedal default (empty schedule → offset 0 everywhere) | ✅ |
| Schedule partitioning, normalization, same-bar last-wins | ✅ |
| Diatonic correctness: +2→Eb, +4→G, +5→Ab; i→VI→iv→i walk = C–Ab–F–C | ✅ |
| Law 2 property: 200 random offsets −7…+7, every note stays in scale | ✅ |
| Per-voice opt-out (lead static, bed moves) | ✅ |
| Bar precision: new offset binds exactly at the bar-start tick, not one tick earlier | ✅ |
| `quantizedEventBar`: next-boundary semantics, exact boundary maps to itself, quanta 2/4 | ✅ |
| Register fold after transposition | ✅ |
| Velocity/gate/accent/ratchet passthrough | ✅ |
| TDD red → green | ✅ |
| `swift test` | ✅ 85 tests / 27 suites |

## Notes

- `TranspositionEvent` is bar-indexed by construction — FR-H-3 is a type-level
  guarantee, not a runtime check.
- Transposition binds per onset; notes sounding across a change keep their
  pitch (spec §7.5 "no retuning mid-note") — inherent in the onset-stream
  design.
