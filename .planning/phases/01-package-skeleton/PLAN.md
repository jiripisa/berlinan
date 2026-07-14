# Phase 01 — Package Skeleton

## Goal

A buildable, runnable project shell: SPM package with the three targets from spec §5.1, the Sampio-derived build/run pipeline, resources, design tokens, and a smoke-test suite. No musical logic yet.

## Deliverables

- `Package.swift` — targets `BerlinanEngine` (library), `BerlinanCLI` (product `berlinan-cli`), `Berlinan` (app), plus test targets.
- `Sources/BerlinanEngine/EngineInfo.swift` — version constant.
- `Sources/BerlinanCLI/main.swift` — `--version` / `--help`; `render` prints "not implemented (phase 09)".
- `Sources/Berlinan/BerlinanApp.swift` + `ContentView.swift` — dark skeleton window using design tokens.
- `Sources/Berlinan/Theme/DesignTokens.swift` — ported from `design_language.md` (AppColor, AppFont, AppTracking, VoiceColor).
- `Resources/Info.plist` (io.jp4.berlinan, 0.1.0, min macOS 14.0), `Resources/Berlinan.entitlements`.
- `build.sh`, `run.sh` — Sampio scripts with app name swapped.
- `Tests/BerlinanEngineTests/SmokeTests.swift`.

## Acceptance criteria

- [x] `swift build` succeeds (debug)
- [x] `swift test` green
- [x] `swift run berlinan-cli --version` prints version
- [x] `./build.sh debug` produces `build/debug/Berlinan.app` (ad-hoc signed, with entitlements)
- [x] App binary launches and shows the dark skeleton window (brief automated launch + manual check → VERIFICATION.md)

## Out of scope

Musical types (phase 02+), MIDI, icon artwork (todo captured in STATE.md).
