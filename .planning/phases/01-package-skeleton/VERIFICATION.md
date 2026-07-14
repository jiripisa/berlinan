# Phase 01 — Verification

Date: 2026-07-14 · Toolchain: Swift 6.3.3, Xcode CLT (full Xcode present)

| Criterion | Result |
|---|---|
| `swift build` (debug) | ✅ Build complete (4.2 s) |
| `swift test` | ✅ 1 test, 1 suite passed |
| `swift run berlinan-cli --version` | ✅ prints `berlinan-cli 0.1.0` |
| `./build.sh debug` → `build/debug/Berlinan.app` | ✅ bundle assembled, ad-hoc signed with entitlements (`codesign -dv`: Identifier=io.jp4.berlinan) |
| App launches | ✅ ran 4 s under supervision, no crash; window renders (automated check; visual confirmation = human item below) |

## Human verification items

- [ ] Open `./run.sh debug` and visually confirm the dark skeleton window with tangerine "BERLINAN" label matches design_language.md.

## Notes

- Expected warning: no `Resources/AppIcon.png` yet (tracked in STATE.md watch list).
- `dist` mode not exercised (no Developer ID identity assumption made); to be smoke-tested before the first tagged release.
