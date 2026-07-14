# Berlinan — State

## Current position

- **Milestone**: M1 — headless engine
- **Milestone**: M2 — it plays (first usable jam tool)
- **Active phase**: none (phases 10+11 merged — 122 tests)
- **Next entry point**: phase 12 — transport & scheduler (Clock hostTime↔tick
  mapping, lookahead loop on a dedicated thread, MIDI clock master 24 PPQ,
  start/stop; NFR-1 jitter test via loopback timestamps)
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
- Musical sign-off of the M1 demo render deferred — re-listen during M2 with
  real synths/live MIDI before calling the generators style-correct
