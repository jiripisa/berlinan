# Phase 13 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Engine snapshot: initial mirror, lifecycle countdown visible, mutation reflected, blank visible, offset lookup incl. live events | ✅ (unit tests) |
| Transport: preview snapshot before play, currentTick nil↔advancing, isMuted query | ✅ (integration test) |
| `swift test` | ✅ 135 tests / 44 suites |
| `./build.sh debug` clean (no warnings beyond missing AppIcon) | ✅ |
| Visual check (automated window capture — `window_evidence.png`) | ✅ transport bar (POS/BPM/KEY/DEG + MIDI LED), 3 lanes with identity colors, 16/15/16-step strips, lifecycle dots, lane buttons, cyan LCM footer "15 bars ≈ 40 s" — matches design_language.md |

## Human checklist (user, while jamming)

- [ ] Playheads drift apart across lanes (16 vs 15 steps visible)
- [ ] Lifecycle dots count down; strip changes when a mutation lands
- [ ] Mute silences instantly (incl. in Ableton); unmute resumes
- [ ] Lock freezes a lane; regenerate swaps at next loop; blank skips one loop
- [ ] Degree chip updates at bars 8/12/16/24/28

## Notes / polish backlog

- KEY shows the raw mode id ("naturalMinor") — prettify mode names (M3 polish).
- The screenshot pass surfaced that a separate app ("Phasewerk", also present
  in ~/Development/Claude) is a mature Berlin School sequencer with heavily
  overlapping concepts — flagged to the user for a roadmap decision.
