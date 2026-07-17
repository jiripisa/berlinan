# Phase 31 — v1.1.0 Release — Verification

Date: 2026-07-18 · Branch: feature/31-v1.1-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **285 tests / 99 suites green** |
| `./build.sh release` | ✅ clean |
| Version 1.1.0 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.1.0 entry (arranger, density, ambient, B-part, melody engine, alternation, new generators, tension budget) | ✅ |
| README refreshed (jam surface incl. ARR/DENS/B/T/♪; channels corrected to the real 3-voice demo) | ✅ |
| `./build.sh dist` | ⚠️ app + DMG **signed** (Developer ID, signature valid); **notarization failed** — the `notary` keychain profile is not accessible in this session (`No Keychain password item found`). v1.0 notarized fine two days ago, so this is a credentials/keychain-session issue, not a pipeline change. |
| Tag v1.1.0 on main | ✅ (after merge) |

## To finish notarization (human)

```sh
xcrun notarytool store-credentials notary   # Apple ID + app-specific password
./build.sh dist                             # re-run: signs, notarizes, staples
```

## Human checklist (pending)

- [ ] Final 1.1 jam pass: AUTO arc end-to-end, DENS sweep, B move,
      T stab, melody extraction + promotion, alternation
- [ ] Re-run dist after restoring the notary profile; Gatekeeper check
