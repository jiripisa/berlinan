# Phase 57 — v1.2.8 Release — Verification

Date: 2026-10-25 · Branch: feature/57-v1.2.8-release

First self-updating release (Sparkle) and the legibility fixes.

| Criterion | Result |
|---|---|
| `swift test` | ✅ 340 tests / 117 suites green |
| Version 1.2.8 (EngineInfo + Info.plist), CHANGELOG 1.2.8 | ✅ |
| `./build.sh dist`: app + DMG notarized (Accepted), stapled, `spctl` Notarized Developer ID | ✅ |
| `docs/appcast.xml` 1.2.8, enclosure `v1.2.8/Berlinan-1.2.8.dmg`, EdDSA signature + length of the stapled DMG | ✅ |
| Website (EN + CS) links → 1.2.8; hero screenshot from the 1.2.8 build | ✅ |
| Manual (EN + CS): all 15 screenshots retaken from the 1.2.8 build (brighter labels), marks re-measured with a percent grid (performance panel moved down after phase 55) | ✅ rendered and reviewed |
| Publish order: tag → GitHub Release with DMG → push main (appcast goes live only after the DMG exists) | ✅ (after merge) |

## Human checklist (pending)

- [ ] Back up the Sparkle private key (`generate_keys -x`)
- [ ] Install 1.2.8 from the DMG; when 1.2.9 is out, it offers the update
