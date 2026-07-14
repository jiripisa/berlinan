# Phase 05 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| `withLength` truncate/extend, `rotated(by:)` normalization, `phasedCopy` (FR-PH-2) | ✅ |
| 16v15 steps → 16 distinct relative offsets (unison + 15 variations, M §6.1); 16v14 → 8 offsets | ✅ |
| Convergence: 16v15 = 15 bars; 16/24/19 = 57 bars; identical lengths = 1 loop; overflow → nil; wall-clock seconds (40 s @ 90 BPM) | ✅ |
| `PhasingEngine.events`: time-sorted, voice-tagged, half-open window chaining exactly reproduces the whole-range render | ✅ |
| TDD red → green | ✅ |
| `swift test` | ✅ 62 tests / 21 suites |

## Notes

- The window-chaining test (unaligned 1000-tick windows over a 15-step + 1-bar
  ensemble) is the strongest guarantee here: it proves the event stream can be
  pulled incrementally by the future lookahead scheduler (spec §5.2) with no
  duplication or loss at window seams.
- Manual's "15 automatic variations" phrasing maps to 16 distinct offsets
  (unison + 15) — the test encodes the unambiguous formulation.
