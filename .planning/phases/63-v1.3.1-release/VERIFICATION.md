# Phase 63 — v1.3.1 Release — Verification

Date: 2026-10-29 · Branch: feature/63-v1.3.1-release

Patch version: one small UI addition (user request) — right-click the CC LFO
Phase knob for presets 0 % (0°), 25 % (90°), 50 % (180°), 75 % (270°).
`KnobView` gained an optional `presets` list shown as a context menu; no
engine or document change.

| Criterion | Result |
|---|---|
| `swift test` | ✅ 359 tests / 119 suites green |
| Phase presets in the app: right-click shows the four items; 25 % sets 90° and the sine preview starts at Max | ✅ (debug build, screenshot) |
| midi.guide catalog refreshed: unchanged (commit 776c9ef) | ✅ |
| Version 1.3.1, CHANGELOG 1.3.1, manual EN + CS mention the right-click menu | ✅ |
| `./build.sh dist`: app + DMG notarized (Accepted), stapled; `spctl` Notarized Developer ID | ✅ |
| `docs/appcast.xml` 1.3.1 → `v1.3.1/Berlinan-1.3.1.dmg`, EdDSA-signed | ✅ |
| Website + manual links → 1.3.1; hero screenshot from the 1.3.1 build | ✅ |

## Human checklist (pending)

- [ ] An installed 1.3.0 offers 1.3.1 at launch and installs it
