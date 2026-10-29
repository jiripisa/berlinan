# Phase 62 — v1.3.0 Release — Verification

Date: 2026-10-29 · Branch: feature/62-v1.3.0-release

Minor version: a new editor (CC LFOs + midi.guide parameter list) and a
removed menu item (CC Profile).

| Criterion | Result |
|---|---|
| `swift test` | ✅ 359 tests / 119 suites green |
| Version 1.3.0, CHANGELOG 1.3.0 (phase 61) | ✅ |
| `./build.sh dist`: app + DMG notarized (Accepted), stapled; `spctl` Notarized Developer ID | ✅ |
| Release bundle contains `MIDIGuide/` and `Credits.rtf` | ✅ |
| `docs/appcast.xml` 1.3.0 → `v1.3.0/Berlinan-1.3.0.dmg`, EdDSA-signed | ✅ |
| Website + manual links → 1.3.0; hero screenshot from the 1.3.0 build (shows the LFO strip) | ✅ |

## Human checklist (pending)

- [ ] An installed 1.2.9 offers 1.3.0 at launch and installs it
- [ ] A CC LFO audibly moves a real synth's filter
