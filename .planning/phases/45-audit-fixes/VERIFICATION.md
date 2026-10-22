# Phase 45 — Audit Fixes — Verification

Date: 2026-10-22 · Branch: feature/45-audit-fixes · Suite: **330 tests / 114 suites green**

Every finding was checked against the code first; all five were confirmed.

| # | Finding | Regression test | Fails without fix |
|---|---|---|---|
| 1 | Invalid document crashes the app | ProjectValidationTests (dup ids, beatUnit 0, bpm 0, channel 16, built-ins valid) + CLI run on a dup-id file → "invalid project — two voices share the id" | ✅ (compile-red; CLI crashed path removed) |
| 2 | Stop/mute leave scheduled long notes | ScheduledFlushTests (registry until off time; loopback: note-off + CC 123 arrive now, not in 3 s) | ✅ |
| 3 | EXT lost after transport rebuild | ExternalSyncTests.followAfterRebuild | ✅ behavioral (isPlaying false before fix) |
| 4 | Capture takes overlap | CaptureTakesTests | ✅ behavioral (proved by disabling the offset) |
| 5 | CLI export ignores arranger | OfflineArrangementTests (arranged parity with renderNotes; unarranged unchanged) | ✅ behavioral (proved by disabling the LiveEngine path) |

Goldens unchanged. Engine stays Foundation-free (`Project.validate()` is
pure; decoding + validation happens at the call sites).

## Flake observed during verification

Two consecutive full-suite runs failed with every CoreMIDI test throwing
`clientCreation(-304)` at the same instant (the on-demand MIDI server was
not accepting clients). Not reproduced afterwards: 0/15 runs on `main`
(worktree) and 0/15 on this branch. Environmental, not a code defect as far
as could be determined; recorded here in case it returns.

## Human checklist (pending)

- [ ] Long drone + Stop: silence immediately on the synth/in Live
- [ ] EXT from Live → load a template → Live Start still drives Berlinan
- [ ] Two takes of different length → Export Capture returns the latest take
- [ ] Open a hand-broken .berlinan → alert, current project kept
