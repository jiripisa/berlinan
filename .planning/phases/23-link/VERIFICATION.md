# Phase 23 — Verification

Date: 2026-07-15

| Criterion | Result |
|---|---|
| Vendored Ableton/link (GPLv2+) + asio as git submodules; abl_link C wrapper compiles as SPM target CAblLink | ✅ |
| LinkService: tempo round-trip, beat grid advances at session tempo, requestBeat grants without peers | ✅ |
| Transport .link mode: plays at the Link session tempo (project 90 → Link 133), ticks advance, clean stop | ✅ |
| Tests run socket-free (Link never enabled in tests — session state is local) | ✅ |
| Full suite green; build clean; smoke launch | ✅ 224 tests / 82 suites |
| UI: INT/EXT/LINK menu; "LINK — N peers" status | ✅ |

## Design notes

- Same re-anchor machinery as the clock slave: when the session tempo moves
  by > 0.25 BPM, the tick clock re-anchors to the session's current beat
  (tick = beat · 960, quantum = one bar). Between tempo changes both clocks
  count mach time, so no continuous chasing is needed.
- `requestBeat(0)` at play start puts tick 0 on the session's next quantum
  boundary — with peers, Berlinan comes in on the bar line.
- UI `setTempo` in LINK mode proposes the tempo TO the session (abl_link
  set_tempo), and the loop follows it back.
- Network join happens only while LINK is selected (`enable(true/false)`),
  so INT/EXT users never open sockets.

## Human checklist (user)

- [ ] Ableton Live: enable Link (top-left). Berlinan: sync = LINK → status
  shows "LINK — 1 peer". Press play in Berlinan: bars line up with Live;
  tempo drag in Live pulls Berlinan along (and vice versa via BPM field).
