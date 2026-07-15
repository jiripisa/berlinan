# Phase 22 — Verification

Date: 2026-07-15

| Criterion | Result |
|---|---|
| ClockEstimator: 120 BPM ±0.5 steady, ±2 ms jitter < 3%, outlier absorbed, reset | ✅ |
| External sync loopback: FA launches playback, estimated 240 BPM within ±8, notes flow, FC stops + flushes | ✅ |
| Internal mode unchanged (full suite) | ✅ 214 tests / 77 suites |
| UI: INT/EXT picker (stopped-only), "EXT — waiting for clock" status | ✅ build clean, smoke launch |

## Bugs found by the tests (both real)

1. **Zero timestamps**: events sent with hostTime 0 arrive with timeStamp 0 —
   the estimator starved. Fix: substitute arrival time for zero stamps
   (hardware-slave behavior).
2. **Test-sender drift**: a sleep-per-pulse sender loop overshoots by ~2.5 ms
   per pulse (191 "BPM" at nominal 240). Fix: schedule pulses upfront with
   exact timestamps.

## Process notes

- The session/process restarted twice mid-run; a zombie `swift test` from the
  orphaned session held the build lock and mimicked a hang — killed manually.
- An earlier `git add -A` swept this phase's implementation into the docs(23)
  and docs(24) commits — code correct, history muddled on this branch.
  Lesson adopted: scoped `git add` only.

## Human checklist (user)

- [ ] Ableton: enable Sync OUT to "Berlinan Out"... (correction: set Ableton
  as master → enable Sync on Live's OUTPUT to a port Berlinan hears, e.g.
  IAC) → Berlinan EXT mode → press Play in Live: Berlinan follows tempo and
  transport.
