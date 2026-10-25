# Berlinan — State

## Current position

- **Milestone**: M5 CLOSED 2026-07-18 (tag v1.1.0, 285 tests / 99 suites).
  Full P2+P3 scope shipped: arranger autopilot, density, ambient, B-part,
  melody engine (extraction/promotion/alternation/tension), bassMelody +
  chordLayer + heartbeat generators, tension budget.
- **Milestone**: M6 CLOSED 2026-07-18 (tag v1.2.0, 305 tests / 107 suites).
  Shipped: horizon strip, drone intro, slides, CC scenes, form presets +
  reprise, template gallery. Next entry point: M7 candidates — capture
  browser, runtime meter (backlog), tie editing in the pattern editor.
- Phase 38 (bass-walk variety, user feedback) DONE 2026-07-18 — 307 tests.
- 2026-10-21 — v1.2.1 RELEASED (phase 39): phase 38 + notarized DMG.
- 2026-10-21 — repo PUBLIC; website live at https://jiripisa.github.io/berlinan/
  (GitHub Pages from main:/docs).
- Phase 40 (role-based voice names, FR-UX-7, user feedback) DONE 2026-10-22 —
  311 tests.
- 2026-10-22 — v1.2.2 RELEASED (phase 41): voice names + "1 bar" fix,
  notarized DMG, GitHub Release.
- Phase 42 (live template load, FR-UX-4, user feedback) DONE 2026-10-22 —
  314 tests.
- 2026-10-22 — v1.2.3 RELEASED (phase 43): live template load, notarized
  DMG, GitHub Release, website updated.
- ⚠️ 1.2.3 shipped phase 42 UNREACHABLE: the templates menu was
  `.disabled(ui.isPlaying)`. Fixed on main 2026-10-22, verified in the app.
- Phase 44 (MIDI output device, FR-IO-1 app-wide, user request) DONE
  2026-10-22 — 318 tests. Unreleased (CHANGELOG, incl. the menu fix). No
  phase open. Next entry point: M7; FR-IO-1 per-voice routing still open.
- Phase 45 (Codex audit fixes, all 5 findings verified + fixed) DONE
  2026-10-22 — 330 tests.
- 2026-10-22 — v1.2.4 RELEASED (phase 46): templates menu fix, MIDI output
  device, audit fixes; notarized DMG, GitHub Release, website. No phase
  open. Next entry point: M7.
- 2026-10-24 — user decision: per-voice output routing NOT wanted now (one
  output device is enough); instead each voice's MIDI channel selectable.
- Phase 47 (per-voice MIDI channel, user request) DONE 2026-10-24 — 333
  tests.
- 2026-10-24 — v1.2.5 RELEASED (phase 48): per-voice MIDI channel;
  notarized DMG, GitHub Release, website.
- Phase 49 (Takes — M7 capture browser, FR-IO-11) DONE 2026-10-25 — 340
  tests.
- 2026-10-25 — v1.2.6 RELEASED (phase 50): Takes; notarized DMG, GitHub
  Release, website (tag local only — superseded by 1.2.7 before publishing).
- Phase 51 (default key A minor, user request) DONE 2026-10-25 — app-level
  default; engine Key.default stays C minor.
- 2026-10-25 — v1.2.7 RELEASED (phase 52): Takes + A minor default;
  notarized DMG, GitHub Release, website.
- Phase 53 (HTML manual with marked screenshots) DONE 2026-10-25 — docs
  only; new screenshots must be retaken when the UI changes (marks are
  percent coordinates).
- Phase 54 (bilingual site, EN + CS) DONE 2026-10-25 — every site change
  now goes into both docs/*.html and docs/cs/*.html. No phase open. Remaining M7
  candidates:
  tie editing in the pattern editor, undo for configuration edits; runtime
  meter stays backlog.
- 2026-07-18 — published to GitHub: https://github.com/jiripisa/berlinan
  (user-confirmed push of main + tags v0.1.0–v1.1.0). Made PUBLIC
  2026-10-21 (see above).
- 2026-07-18 — `examples/full_ensemble.berlinan` showcase added (6 voices:
  chord layer, bassMelody, heartbeat, lead for promotion).
- Pending human checks (26-31): see the phase VERIFICATIONs — AUTO arc,
  DENS/B/T moves, melody extraction + promotion, alternation, ambient jam,
  and the 1.1 dist re-run below.
- ~~v1.1.0 DMG signed but NOT notarized~~ RESOLVED 2026-10-21: the real
  cause was an expired Apple Developer agreement (notary HTTP 403); v1.2.1
  DMG notarized and stapled.
- 2026-07-18 — deviation: ambient mode is stopped-only in the UI (live
  switch would need mid-flight re-materialization of lifecycles; descoped).
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

- 2026-07-17 — RESOLVED (root cause found later the same day): the Link
  test "flake" and a subsequent SIGSEGV (`outlined destroy of
  LiveEngine.Snapshot`) were both stale SwiftPM incremental artifacts after
  cross-module struct layout changes (fields added to `Project`, then to
  `LiveEngine.Snapshot`) — dependents were not rebuilt. Fix: `swift package
  clean` + full rebuild. RULE: after changing the layout of a public
  BerlinanEngine struct, run `swift package clean` before trusting test
  results. (The Link test keeps its condition-based wait — strictly better.)

- ~~LinkKit licensing check before M4 (spec OQ-3)~~ RESOLVED 2026-07-15:
  open source (GPL-2.0-or-later), official abl_link vendored in phase 23
- ~~AppIcon.png not yet created~~ RESOLVED 2026-07-15 (phase 25)
- Pending human checks (22-25): EXT sync from Live, LINK session with Live,
  LEARN with a hardware controller, lane drag into Live, DMG on another Mac
- ~~Musical sign-off of the M1 demo render deferred~~ RESOLVED 2026-07-14:
  user confirmed the live M2 jam plays and sounds good
