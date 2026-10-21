# Phase 39 — v1.2.1 Release — Verification

Date: 2026-10-21 · Branch: feature/39-v1.2.1-release

## Results

| Criterion | Result |
|---|---|
| `swift test` | ✅ **307 tests / 107 suites green** |
| Version 1.2.1 (EngineInfo + Info.plist) | ✅ |
| CHANGELOG 1.2.1 (seeded bass walks from phase 38, notarized dist) | ✅ |
| `./build.sh dist` | ✅ app + DMG notarized (Accepted) and stapled; `spctl`: Notarized Developer ID |
| Tag v1.2.1 on main | ✅ (after merge) |

## Notes

- Notarization was blocked by an expired Apple Developer agreement (HTTP 403),
  not by the `notary` profile; resolved by the account holder accepting it.
  `build.sh dist` aligned with MDPre (timestamp, app notarized + stapled
  before the DMG, abort without Developer ID).

## Human checklist (pending)

- [ ] Open the 1.2.1 DMG on a second Mac / clean user account (Gatekeeper path)
