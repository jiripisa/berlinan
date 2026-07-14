# Berlinan — State

## Current position

- **Milestone**: M1 — headless engine
- **Milestone**: M2 CLOSED 2026-07-14 (tag v0.2.0, 140 tests). Next: M3 —
  musical depth (remaining generators, gate/pitch decoupling, progressions,
  CC lanes + gate ramps, MIDI delay + delay hints, pattern editor, snapshots,
  undo, documents).
- **Next entry point**: break M3 into phases in ROADMAP, then plan phase 15.
- Pending human checks from 13/14 (playheads drift, mute/lock/regen/blank in
  the jam, degree buttons audible, capture export lands in Ableton).
- Phasewerk question RESOLVED 2026-07-14: user decision — ignore Phasewerk
  entirely for now; do not study, reference, or deconflict against it.
- M1 CLOSED 2026-07-14 (tag v0.1.0), 107 tests. Listening protocol passed
  PROVISIONALLY (user could not confidently judge; re-verify musically during
  M2 live jamming — carried as a watch-list item).

## Decisions log

- 2026-07-14 — CLI product named `berlinan-cli` (not `berlinan`): a product named
  `berlinan` would collide with the `Berlinan` app product in SPM's build
  directory on case-insensitive APFS.
- 2026-07-14 — v1 unsandboxed, Developer ID + hardened runtime + notarized DMG
  (Sampio pipeline; spec NFR-7 updated).
- 2026-07-14 — docs/synthkeeper transcripts untracked (third-party material).
- 2026-07-14 — Pattern.id is a stable String (not UUID): random ids would break
  render determinism (NFR-4); spec §6.3 sketch to be amended accordingly.
- 2026-07-14 — Lifecycle semantics: remaining = total verbatim plays left before
  mutable; fresh and post-mutation patterns start at N (default 4).

## Blockers

- none

## Deferred / watch list

- LinkKit licensing check before M4 (spec OQ-3)
- AppIcon.png not yet created — build.sh warns, app has no icon (needed before first dist build)
- ~~Musical sign-off of the M1 demo render deferred~~ RESOLVED 2026-07-14:
  user confirmed the live M2 jam plays and sounds good
