# Phase 43 — v1.2.3 Release — Verification

Date: 2026-10-22 · Branch: feature/43-v1.2.3-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **314 tests / 109 suites green** |
| Version 1.2.3 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.3 (templates load while playing, phase 42) | ✅ |
| Website: download links → v1.2.3, screenshot from the 1.2.3 release build (engine 1.2.3) | ✅ |
| `./build.sh dist` | ✅ app + DMG notarized (Accepted) and stapled; `spctl`: Notarized Developer ID |
| Tag v1.2.3 on main + GitHub Release with DMG | ✅ (after merge) |

## Human checklist (pending)

- [ ] Phase 42 checks in the app (live template switch, no hanging notes, LINK)
- [ ] Open the 1.2.3 DMG on a second Mac / clean user account (Gatekeeper path)
