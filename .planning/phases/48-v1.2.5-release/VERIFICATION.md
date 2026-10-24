# Phase 48 — v1.2.5 Release — Verification

Date: 2026-10-24 · Branch: feature/48-v1.2.5-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **333 tests / 115 suites green** |
| Version 1.2.5 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.5 (per-voice MIDI channel) | ✅ |
| Website: download links → v1.2.5, channel sentence in the routing example, screenshot from the 1.2.5 release build (engine 1.2.5) | ✅ |
| `./build.sh dist` | ✅ app + DMG notarized (Accepted) and stapled; `spctl`: Notarized Developer ID |
| Tag v1.2.5 on main + GitHub Release with DMG | ✅ (after merge) |

## Human checklist (pending)

- [ ] Phase 47 check with real hardware (two voices on two channels, switch while playing)
- [ ] Open the 1.2.5 DMG on a second Mac / clean user account (Gatekeeper path)
