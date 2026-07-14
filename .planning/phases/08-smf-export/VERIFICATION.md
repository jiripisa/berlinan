# Phase 08 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| VLQ vectors (0, 127, 128, 960, 0x0FFFFFFF) | ✅ |
| Header bytes exact (MThd, format 1, ntrks, 960 PPQN) | ✅ |
| Track 0: tempo meta 90 BPM = `0A 2C 2B`, time sig 4/4 and 7/8 (dd=3), markers | ✅ |
| Exact single-note voice-track bytes (name meta, on/off, EoT at length) | ✅ |
| Ratchet 2 → retriggers at 0 and 60 within the gate | ✅ |
| Same-pitch overlap clipped; offs precede ons at equal ticks | ✅ |
| Note-on/off pairing fuzz over generated ensembles (20 seeds × 2 voices × 8 bars) | ✅ |
| Byte determinism | ✅ |
| TDD red → green | ✅ |
| `swift test` | ✅ 95 tests / 30 suites |

## Notes

- Two test-authoring bugs caught during the red run: hand-computed VLQ delta
  (840 = `86 48`, not `87 28`) and tuple-array comparison (tuples aren't
  Equatable for `==` on arrays) — both fixed on the test side; writer logic
  was correct against the SMF spec.
- No running status — full status bytes for maximal DAW compatibility.
- The test-side `noteEvents` scanner is deliberately minimal (channel events
  + metas of the last track), not a general SMF reader — golden masters
  (phase 09) compare whole files byte-for-byte.
