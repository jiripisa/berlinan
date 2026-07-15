# Phase 22 — Verification

Date: 2026-07-15

| Criterion | Result |
|---|---|
| ClockEstimator: steady 120 BPM ±0.5; ±2 ms jitter < 3%; outlier absorbed; reset | ✅ |
| External sync loopback: FA + scheduled-timestamp F8 stream @240 → auto-play, BPM ≈ 240, notes flow; FC stops + flushes | ✅ |
| Internal mode unchanged (full suite green — 214 tests / 77 suites) | ✅ |
| Zero-timestamp packets ("send now") get arrival-time substitution in handleRealTime | ✅ |
| UI: INT/EXT sync menu (stopped-only switch), "EXT — waiting for clock" status | ✅ |
| TDD red → green (test-side fix: the sender must SCHEDULE pulse timestamps — a sleep-loop sender drifts ~2 ms/pulse and the estimator correctly measured that slower clock, 196 vs 240) | ✅ |

## Human checklist (user)

- [ ] Ableton: enable Sync OUT to "Berlinan Out"?? — no: enable Sync on Live's
  OUTPUT port routed to a virtual bus into Berlinan, or use Live's "MIDI Clock
  Sync" out to IAC; set Berlinan to EXT; press Play in Live → Berlinan follows
  tempo and transport.

## Notes

- Pulse k = tick k·40; per-wake segment re-anchoring (bpm delta > 0.25) =
  micro-warping through piecewise clock segments; freewheel = hold segment.
- Clock OUT is suppressed in EXT (never re-broadcast a followed clock).
