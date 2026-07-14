# Phase 13 — UI Shell

## Goal

The real main window per spec §11.1–11.3 and design_language.md: transport bar, voice lanes with live pattern strips + lifecycle dots + per-voice controls (mute / lock / regenerate / blank), convergence readout. The snapshot pipeline (engine → transport → 30 Hz UI mirror) per spec §5.4.

## Deliverables

- Engine: `LiveEngine.snapshot()` — lightweight `Snapshot` (per voice: id, role, pattern, blankActive; plus `transpositionOffset(atBar:)`), unit-tested.
- Runtime: `Transport.snapshot()` (latest engine snapshot, lock-protected, updated each scheduler wake; a preview snapshot before first play) + `Transport.currentTick` (nil when stopped) + `isMuted(_:)`.
- App (`Sources/Berlinan/`):
  - `UIState` — 30 Hz timer-driven mirror (playhead tick, voice snapshots, degree offset, bar:beat), only while the window is visible.
  - `TransportBarView` — PLAY/STOP, bar:beat (`timecodeBig` mono), BPM, key/mode, current degree chip, MIDI LED; toolbar gradient (design §2.1).
  - `VoiceLaneView` + `PatternStripView` (Canvas) — step grid, notes in voice identity colors (§2.6), accents outlined, **per-voice playhead sweep** (each lane's own loop position — the phasing is visible), lifecycle dots `●●●○`, loop-length label in steps, blank indicator.
  - Lane buttons: M (mute, runtime gate), lock, regenerate, blank — wired to `Transport.setMuted` / `enqueue(.setLock/.regenerate/.blankCycle)` (FR-UX-2/4).
  - `ConvergenceView` — LCM in bars + seconds, cyan accent (§11.3).
  - `ContentView` rewrite composing the above; space = play/stop.

## Acceptance criteria

- [ ] Engine: snapshot reflects pattern changes after boundary renders; offset lookup matches the schedule (unit tests)
- [ ] Runtime: preview snapshot exists before play; currentTick nil when stopped / advances while playing (integration test)
- [ ] `swift test` green; `./build.sh debug` clean
- [ ] Manual checklist (human):
  - [ ] Lanes show 3 voices with distinct identity colors; playheads drift apart (16 vs 15 steps visible)
  - [ ] Lifecycle dots count down and reset on mutation; pattern strip changes when a mutation lands
  - [ ] Mute silences a voice ≤ perceptibly instantly and its notes stop in Ableton; unmute resumes
  - [ ] Lock freezes a lane's pattern (dots stay full); regenerate swaps the pattern at the next loop; blank skips one loop visibly/audibly
  - [ ] Convergence readout shows 15 bars ≈ 40 s; degree chip updates at bars 8/12/16/24/28
  - [ ] Window matches design_language.md (dark surfaces, tangerine playhead/accents, mono data)

## Out of scope

Degree buttons + snapshot slots (14), pattern editing (M3), inspector panel (M3), documents (M3 — still the built-in demo project).
