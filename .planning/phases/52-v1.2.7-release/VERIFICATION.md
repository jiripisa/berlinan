# Phase 52 — v1.2.7 Release — Verification

Date: 2026-10-25 · Branch: feature/52-v1.2.7-release

v1.2.6 (Takes) was tagged locally but never published; 1.2.7 adds the A
minor default and is the first public release with both. The v1.2.6 tag
is pushed for history, the GitHub Release is 1.2.7 (notes cover both).

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **340 tests / 117 suites green** |
| Version 1.2.7 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.7 (A minor default) on top of 1.2.6 (Takes) | ✅ |
| Website: download links → v1.2.7, screenshot from the 1.2.7 release build (engine 1.2.7, KEY A naturalMinor, playing) | ✅ |
| `./build.sh dist` | ✅ app + DMG notarized (Accepted) and stapled; `spctl`: Notarized Developer ID |
| Tags v1.2.6 + v1.2.7, GitHub Release 1.2.7 with DMG | ✅ (after merge and push) |

## Human checklist (pending)

- [ ] Phase 49/51 checks (take into Live, lane drag name, quit while recording, A minor by ear)
- [ ] Open the 1.2.7 DMG on a second Mac / clean user account (Gatekeeper path)
