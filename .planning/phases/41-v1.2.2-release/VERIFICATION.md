# Phase 41 — v1.2.2 Release — Verification

Date: 2026-10-22 · Branch: feature/41-v1.2.2-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **311 tests / 108 suites green** |
| Version 1.2.2 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.2 (role-based voice names from phase 40, "1 bar" singular fix) | ✅ |
| Website download links → v1.2.2 | ✅ |
| `./build.sh dist` | ✅ app + DMG notarized (Accepted) and stapled; `spctl`: Notarized Developer ID |
| Tag v1.2.2 on main + GitHub Release with DMG | ✅ (after merge) |

## Human checklist (pending)

- [ ] Open the 1.2.2 DMG on a second Mac / clean user account (Gatekeeper path)
