# Phase 26 — Arranger Core — Verification

Date: 2026-07-17 · Branch: feature/26-arranger-core · Suite: **247 tests / 86 suites green**

## Automated results

| Criterion | Result |
|---|---|
| SM unit: deterministic phase timeline, periods 8–16, build order, subtract reverse, ending thin+stop | ✅ `ArrangementTests` (12 tests) |
| Enabling mid-play with all voices active enters `bed` | ✅ SM + LiveEngine level |
| `advancePhase` binds at the next bar | ✅ second voice enters at bar 1 |
| Live render == offline render with arrangement on | ✅ `offlineParity` (delegation: arranged offline render IS a live render) |
| Chunk-safety with arrangement on (windows 555/1000/3840) | ✅ |
| Arrangement nil → zero behavior change, suite green | ✅ 224 pre-existing tests untouched |
| Transport self-stops at the ending tick, full flush | ✅ `ArrangementTransportTests` |
| `advancePhase` MIDI-learn macro binds + persists | ✅ `ControlMapTests` |
| App builds with the ARR strip (AUTO · phase · advance-now) | ✅ `./build.sh` |

## Design notes

- Ending's `thinToRoots` applies IMMEDIATELY on its bar (the directive fires
  exactly at the musical moment); `nudge`/`accentMove`/`blankCycle` bind at
  the voice's next loop boundary after their bar — one loop later, musically
  indistinguishable at 8–16-bar periods, and it keeps §7.4 ("patterns change
  only at loop boundaries") intact.
- Payoff with nothing to re-add emits a mutation nudge instead of silence
  (M §12.1 promises an audible change every period).
- The arranged offline render delegates to LiveEngine — one implementation,
  parity by construction.

## Incidents (resolved)

- Stale SwiftPM incremental artifacts after cross-module struct layout
  changes caused a phantom Link-test failure and a SIGSEGV (`outlined
  destroy of LiveEngine.Snapshot`). Rule recorded in STATE: `swift package
  clean` after changing a public BerlinanEngine struct layout.
- The Berlinan instance running since 20:40 (user session, alongside
  Ableton Live) was left untouched — visual check of the ARR strip is in
  the human checklist below.

## Human checklist (pending)

- [ ] ARR strip renders in the performance panel; AUTO is OFF on launch
- [ ] AUTO on while stopped → play starts with only bedPluck1, voices join
      one by one 8–16 bars apart
- [ ] AUTO on mid-jam → no restart, phase shows BED
- [ ] ">>" fires an audible change at the next bar
- [ ] Full autopilot arc ends the piece by itself: subtract down to one
      voice, roots-only closing bar, transport stops cleanly
- [ ] LEARN + ">>" + a controller pad → advance fires from hardware
