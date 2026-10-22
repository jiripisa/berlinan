# Phase 46 — v1.2.4 Release — Verification

Date: 2026-10-22 · Branch: feature/46-v1.2.4-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **330 tests / 114 suites green** |
| Version 1.2.4 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.4 (templates menu while playing, MIDI output device, audit fixes) | ✅ |
| Website: download links → v1.2.4, MIDI device sentence, screenshot from the 1.2.4 release build (engine 1.2.4, output menu) | ✅ |
| `./build.sh dist` | ✅ app + DMG notarized (Accepted) and stapled; `spctl`: Notarized Developer ID |
| Tag v1.2.4 on main + GitHub Release with DMG | ✅ (after merge) |

## Human checklist (pending)

- [ ] Phase 44/45 checks with real hardware (M4 output, stop silences a drone, EXT after template load)
- [ ] Open the 1.2.4 DMG on a second Mac / clean user account (Gatekeeper path)
