# Phase 50 — v1.2.6 Release — Verification

Date: 2026-10-25 · Branch: feature/50-v1.2.6-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **340 tests / 117 suites green** |
| Version 1.2.6 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.6 (Takes) | ✅ |
| Website: download links → v1.2.6, Capture bullet describes takes, screenshot from the 1.2.6 release build (engine 1.2.6) | ✅ |
| `./build.sh dist` | ✅ app + DMG notarized (Accepted) and stapled; `spctl`: Notarized Developer ID |
| Tag v1.2.6 on main + GitHub Release with DMG | ✅ (after merge and user-confirmed push) |

## Human checklist (pending)

- [ ] Phase 49 checks: drag a take into Live; lane-pattern drag file name; quit while recording
- [ ] Open the 1.2.6 DMG on a second Mac / clean user account (Gatekeeper path)
