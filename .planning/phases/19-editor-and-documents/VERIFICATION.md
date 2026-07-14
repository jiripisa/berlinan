# Phase 19 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| replacePattern: binds at next loop boundary, locked + established, never auto-mutates (10 bars verbatim), chunk-independent | ✅ |
| overridePattern: materialized verbatim + locked; offline render reproduces hand notes every bar | ✅ |
| Document format: snapshots + overridePattern JSON round-trip; 0.2.x JSON decodes; goldens untouched | ✅ |
| App: editor sheet (note table on the 16th grid, hand edits lock + persist + live-swap), settings sheet (root/mode/BPM/meter presets, stopped-only), File Open/Save As with .berlinan UTI | ✅ build clean, smoke launch OK |
| Version 0.3.0 + CHANGELOG | ✅ |
| `swift test` | ✅ 191 tests / 69 suites |
| TDD red → green (one app-target fix: Pattern name collision → qualified type) | ✅ |

## Human checklist (user)

- [ ] Edit a note in a lane (pencil) → hear the change at the next loop; lock engages (amber pencil)
- [ ] Save the project (⌘⇧S), reopen (⌘O) — the hand edit and snapshot slots survive
- [ ] Settings: switch to 7/8 or a new key — patterns regenerate recognizably (same seeds)

## Notes / deviations

- `.berlinan` is a single JSON file for now (spec §10 describes a package);
  the package format lands with capture persistence — deviation recorded.
- Runtime tempo/key/meter changes remain M4 scope (FR-GS-5).
