# Phase 42 — Load a Template While Playing — Verification

Date: 2026-10-22 · Branch: feature/42-live-template-load · Suite: **314 tests / 109 suites green**

## Automated results

| Criterion | Result |
|---|---|
| Playing: old piece sounds until the bar line, then the snapshot shows the new voice set (3 → 6); transport keeps running | ✅ real-time transport test @ 200 BPM |
| Position restarts within the first bar after the swap | ✅ |
| Stopped: loadProject ignored (app rebuilds as before) | ✅ |
| Bar lines count from the loaded project's origin (meter change safe) | ✅ |
| `./build.sh debug` builds | ✅ |

## Review fixes (same phase)

- Bar boundaries (template swap AND runtime tempo) were computed from
  transport tick 0; after loading a project with another meter they must
  count from the new engine's origin → `Transport.nextBar(after:origin:barTicks:)`.
- A template picked while another one is still armed is no longer lost
  (the swap only clears the pending project it actually installed).

## Not verified in the app

UI automation could not open the SwiftUI templates menu (synthetic clicks
are ignored), so the app path was not exercised end-to-end.

## Human checklist (pending)

- [ ] Playing Demo trio → templates menu → Full ensemble: HORIZON shows
      "TEMPLATE FULL ENSEMBLE · next bar", the switch lands on the bar,
      six lanes appear, position restarts at 1.1
- [ ] No hanging notes in Live across the switch; MIDI clock keeps running
- [ ] Same with LINK on (tempo stays the session's)
