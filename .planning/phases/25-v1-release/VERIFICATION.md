# Phase 25 — Verification

Date: 2026-07-15

| Criterion | Result |
|---|---|
| Icon in bundle (AppIcon.icns generated; no missing-icon warning) | ✅ |
| README present and accurate (incl. Link, GPL, doc map) | ✅ |
| swift test green | ✅ 224 tests / 82 suites |
| ./build.sh release clean | ✅ |
| ./build.sh dist | ✅ **EXCEEDED**: a Developer ID identity (Jiri Pisa, 88X62ZUGT7) exists on this machine — dist produced a SIGNED and NOTARIZED build/Berlinan.dmg (staple validated). The "graceful skip" path was not needed. |
| Release app smoke launch | ✅ |
| Tag v1.0.0 on main | ✅ (after merge) |

## Notes

- Plan text said "Link ships deferred" — superseded: the user's open-source
  decision unblocked phase 23 and Link IS in 1.0.
- Version 1.0.0 in Info.plist + EngineInfo; CHANGELOG 1.0.0 entry written.
- Icon: generated 1024² from the design tokens (three phasing lanes in voice
  identity colors, tangerine playhead, studio-dark squircle).

## Human checklist (user)

- [ ] Final 1.0 jam pass: INT/EXT/LINK sync both directions, LEARN a knob,
  drag a lane into Live, delay cheat sheet + echo, dice/undo.
- [ ] Open build/Berlinan.dmg on another Mac — Gatekeeper accepts it.
