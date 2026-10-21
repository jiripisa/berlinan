# Phase 44 — Choose the MIDI Output — Verification

Date: 2026-10-22 · Branch: feature/44-midi-output-device · Suite: **318 tests / 110 suites green** (full suite run 3× in a row)

## Automated results (CoreMIDI loopback, test-owned virtual destinations as "synths")

| Criterion | Result |
|---|---|
| Destinations listed; our own control input never offered | ✅ |
| Device chosen → note-on arrives at the device | ✅ |
| Switching output → note-off reaches the previous device, nothing to the new one | ✅ |
| Unplugged device → events dropped, no crash; back to virtual works | ✅ |
| Choice persisted (UserDefaults, unique ID + name) | ✅ by construction (AppServices init restores) |

Note: the first full-suite run failed because the new test reused the
CoreMIDI port name "Berlinan Test Control" of ControlProfileTests (parallel
suites saw each other's port) — test-only collision, renamed.

## Manual (debug build)

| Check | Result |
|---|---|
| Output label opens a menu: "Berlinan Out (virtual)" ✓ + Devices (here: "M4") | ✅ screenshot |
| Status dot kept outside the menu (macOS menu labels drop non-text views) | ✅ screenshot |

Not exercised: actually sending to the user's real device (M4) — not
touched without the user present.

## Human checklist (pending)

- [ ] Pick a hardware synth / IAC bus: notes, CC and clock arrive; pick
      Berlinan Out again: nothing hangs on the device
- [ ] Unplug the device while playing: label says "disconnected", no crash;
      replug: it resumes
- [ ] Relaunch: the choice is remembered
