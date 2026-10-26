# Phase 60 — v1.2.9 Release — Verification

Date: 2026-10-26 · Branch: feature/60-v1.2.9-release

First update delivered through Sparkle (1.2.8 installs are offered 1.2.9).

| Criterion | Result |
|---|---|
| `swift test` | ✅ 340 tests / 117 suites green |
| Version 1.2.9, CHANGELOG 1.2.9 (clock label fix, tooltip, docs review) | ✅ |
| `./build.sh dist`: app + DMG notarized (Accepted), stapled; `spctl` Notarized Developer ID | ✅ |
| `docs/appcast.xml` 1.2.9 → `v1.2.9/Berlinan-1.2.9.dmg`, EdDSA-signed | ✅ |
| Website + manual links → 1.2.9; hero screenshot from the 1.2.9 build | ✅ |

Manual screenshots still show "engine 1.2.8" in the footer — no visible UI
change otherwise, not retaken.

## Human checklist (pending)

- [ ] An installed 1.2.8 offers 1.2.9 at launch and installs it
