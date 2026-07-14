# Berlinan — State

## Current position

- **Milestone**: M1 — headless engine
- **Active phase**: none (phases 01 + 02 merged to main, all green)
- **Next entry point**: phase 03 — pattern model (Pattern/PatternNote/GateStep,
  Voice, loop cursors, degree-space invariants; FR-V-1/5, FR-P-2/3)

## Decisions log

- 2026-07-14 — CLI product named `berlinan-cli` (not `berlinan`): a product named
  `berlinan` would collide with the `Berlinan` app product in SPM's build
  directory on case-insensitive APFS.
- 2026-07-14 — v1 unsandboxed, Developer ID + hardened runtime + notarized DMG
  (Sampio pipeline; spec NFR-7 updated).
- 2026-07-14 — docs/synthkeeper transcripts untracked (third-party material).

## Blockers

- none

## Deferred / watch list

- LinkKit licensing check before M4 (spec OQ-3)
- AppIcon.png not yet created — build.sh warns, app has no icon (needed before first dist build)
