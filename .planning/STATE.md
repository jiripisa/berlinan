# Berlinan — State

## Current position

- **Milestone**: M1 — headless engine
- **Active phase**: 09 merged; M1 exit gate = LISTENING PROTOCOL pending
  (user imports build/berlinan_demo_64bars.mid into Ableton, checks style
  checklist in phases/09 VERIFICATION). All engine work green — 107 tests.
- **Next entry point**: after listening sign-off → tag v0.1.0, start M2
  (virtual MIDI out, clock master, transport, voice-lane UI)

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
