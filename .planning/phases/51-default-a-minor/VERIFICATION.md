# Phase 51 — Default Key A Minor — Verification

Date: 2026-10-25 · Branch: feature/51-default-a-minor · Suite: **340 tests / 117 suites green** (engine goldens untouched)

## Manual (debug build)

| Check | Result |
|---|---|
| Launch: KEY "A naturalMinor" | ✅ screenshot |
| Notes played in A minor: take of the launch project → pitch classes {0,2,4,5,7,9,11} (A natural minor); a short take → A/C/E | ✅ take JSON |
| Templates ▸ Full ensemble (stopped) → KEY "A naturalMinor", 96 BPM, 6 voices | ✅ screenshot |
| Ambient drift / user templates / saved documents | by construction (`TemplateStore.builtIns` sets the key; user templates and documents are decoded as saved) |

No automated test: the default lives in the app target, which has no test
target; the engine's `Key.default` deliberately stays C minor.

## Human checklist (pending)

- [ ] Listen: the launch project sounds in A minor
