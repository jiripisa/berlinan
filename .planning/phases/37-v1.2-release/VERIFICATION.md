# Phase 37 — v1.2.0 Release — Verification

Date: 2026-07-18 · Branch: feature/37-v1.2-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **305 tests / 107 suites green** |
| `./build.sh release` | ✅ clean |
| Version 1.2.0 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.0 (horizon strip, drone intro, slides, CC scenes, forms + reprise, template gallery) | ✅ |
| README refreshed (templates menu, ARR forms, SCENE, HORIZON strip) | ✅ |
| `./build.sh dist` | ⏭ NOT re-run — notarization still blocked on the `notary` keychain profile (see the 1.1 note in STATE); run after `xcrun notarytool store-credentials notary` |
| Tag v1.2.0 on main | ✅ (after merge) |

## Human checklist (pending)

- [ ] Full M6 jam: Ambient drift template end-to-end; horizon narration;
      slides on a mono bass; SCENE morphs; classic-arc reprise
- [ ] `./build.sh dist` after restoring the notary profile
