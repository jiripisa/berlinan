# Berlinan — State

## Current position

- **Milestone**: M5 IN PROGRESS (opened 2026-07-17) — arranger & polish,
  full scope P2+P3, target v1.1.0. Phase plan: 26 arranger core →
  27 density/ambient/B-part → 28 melody extraction → 29 melody scheduler →
  30 harmony color → 31 release.
- **Current phase**: 26-arranger-core (PLAN written; implementation starting).
- M4 CLOSED 2026-07-15 (tag v1.0.0, 224 tests). Signed and notarized DMG
  built (Developer ID present on this machine).
- Backlog: runtime METER changes (piecewise meter map design sketch in
  phases/21 PLAN).
- Pending human checks (19): hand edit audible + survives save/reopen;
  settings regenerate in new key/meter.
- Pending human checks from 13/14 (playheads drift, mute/lock/regen/blank in
  the jam, degree buttons audible, capture export lands in Ableton).
- 2026-07-15 — user decision: Berlinan is OPEN SOURCE (GPL-2.0-or-later,
  mirroring Ableton Link) — phase 23 unblocked.
- 2026-07-15 — user feedback "generates the same melody": fixed by FR-UX-6
  (random session seed + New Seed button); determinism stays engine-only.
- 2026-07-14 — MIDI delay (FR-MOD-7) deferred from phase 17 to M4 by user
  decision; delay hints (FR-MOD-8) stay in M3.
- Phasewerk question RESOLVED 2026-07-14: user decision — ignore Phasewerk
  entirely for now; do not study, reference, or deconflict against it.
- M1 CLOSED 2026-07-14 (tag v0.1.0), 107 tests. Listening protocol passed
  PROVISIONALLY (user could not confidently judge; re-verify musically during
  M2 live jamming — carried as a watch-list item).

## Decisions log

- 2026-07-17 — M5 scope: FULL (P2 + P3 — all of FR-A-*, FR-MEL-*, FR-H-7/8,
  FR-V-7), vertical feature slices (arranger first). User decision.
- 2026-07-17 — Arrangement SM is OFF by default (performance mode is the
  first-run experience); the automaton is advisory (FR-A-6). User decision.

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

- ~~LinkKit licensing check before M4 (spec OQ-3)~~ RESOLVED 2026-07-15:
  open source (GPL-2.0-or-later), official abl_link vendored in phase 23
- ~~AppIcon.png not yet created~~ RESOLVED 2026-07-15 (phase 25)
- Pending human checks (22-25): EXT sync from Live, LINK session with Live,
  LEARN with a hardware controller, lane drag into Live, DMG on another Mac
- ~~Musical sign-off of the M1 demo render deferred~~ RESOLVED 2026-07-14:
  user confirmed the live M2 jam plays and sounds good
