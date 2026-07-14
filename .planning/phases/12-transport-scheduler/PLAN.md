# Phase 12 — Transport & Scheduler

## Goal

Make it play (FR-IO-2/3, NFR-1/2): the musical↔host-time clock, the lookahead scheduler thread pulling `LiveEngine`, MIDI clock master, start/stop — plus a minimal Play/Stop in the skeleton window so the first live jam into Ableton happens at the end of this phase.

## Deliverables (Sources/BerlinanRuntime/ unless noted)

- `Clock.swift` — `TickClock`: bpm + mach-time anchor + injected timebase; `machTime(forTick:)` / `tick(atMach:)`; pure math, unit-tested.
- `EventConversion.swift` — pure helpers, unit-tested:
  - `NoteEventConverter.events(for: [RenderedNote], channelMap:)` → timed (tick, MIDI1Event) on/off pairs (offs may exceed the window — they are timestamped ahead);
  - `clockTicks(in:)` — 24 PPQ grid = every 40 ticks (FR-IO-3);
  - mute filtering by voiceID (runtime post-render gate, spec §8.2).
- `Transport.swift` — `Transport` class owning the scheduler thread:
  - `play()`: anchors the clock ~100 ms ahead, sends MIDI Start, spins a dedicated thread (25 ms wake, 150 ms lookahead) that consumes queued actions, pulls `engine.render`, converts + timestamps + sends;
  - `stop()`: joins the thread, sends MIDI Stop, flushes the note registry (FR-IO-8);
  - `enqueue(_ action:)` (thread-safe, binds at the current tick), `setMuted(_:_:)` (immediate + channel flush);
  - play always restarts from tick 0 (M2 simplification — documented).
- App: `AppServices` builds a `Transport` over `Project.demo`; `ContentView` gets Play/Stop button + status (proper transport bar arrives in phase 13).

## Acceptance criteria

- [x] TickClock: 1 beat @ 90 BPM = 666.67 ms in mach(=ns) units; tick(anchor) = 0; round-trip monotonic
- [x] clockTicks: 96 clocks per 4/4 bar, multiples of 40 ticks
- [x] Converter: on/off pair per note (off = at + gate), channel from map, muted voices dropped
- [x] Integration (loopback): play ≈ 0.6 s → Start received, clock count in expected range, note-ons arrive, clock timestamp spacing ≈ 40 ticks ± 1 ms (NFR-1 evidence at the scheduling layer)
- [x] Stop: MIDI Stop received, `activeNoteCount == 0` after flush
- [ ] Human item: app running + Play → notes audible on an Ableton instrument track armed to "Berlinan Out"; Ableton clock-syncs when Sync is enabled on the port
- [x] `swift test` green

## Out of scope

Clock slave / Link (M4), UI transport bar + lanes (13), capture buffer (14), tempo changes while playing (M3 — bar-quantized per FR-GS-5).
