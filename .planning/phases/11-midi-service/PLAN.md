# Phase 11 — MIDI Service (Runtime Layer)

## Goal

First Runtime-layer code (spec §5.1): a new `BerlinanRuntime` library target hosting CoreMIDI — virtual source "Berlinan Out", timestamped sends (FR-IO-1/2), MIDI 1.0-in-UMP encoding, and the active-note registry with flush (runtime half of FR-IO-8). The engine stays CoreMIDI-free.

## Deliverables

- `Package.swift`: new `BerlinanRuntime` library target (depends on `BerlinanEngine`) + `BerlinanRuntimeTests`; the `Berlinan` app target now depends on the runtime.
- `Sources/BerlinanRuntime/MIDI1Event.swift` — `MIDI1Event` (noteOn/noteOff/cc/clock/start/stop/continue) with UMP word encoding (MIDI 1.0 channel voice = message type 0x2; system real-time = type 0x1) — pure logic, fully unit-tested.
- `Sources/BerlinanRuntime/NoteRegistry.swift` — tracks sounding (channel, note) pairs from sent events; `flushEvents(channel:)` emits note-offs for everything sounding + CC 123 per touched channel and clears (transport stop / mute / route change safety net). Pure logic.
- `Sources/BerlinanRuntime/MIDIService.swift` — CoreMIDI client + virtual source (`MIDISourceCreateWithProtocol`, MIDI 1.0 protocol), `send([(hostTime, MIDI1Event)])` via `MIDIEventList` with host-time timestamps (0 = now), automatic registry tracking, `flush()` convenience, clean dispose.

## Acceptance criteria

- [ ] UMP vectors: noteOn ch0 60 vel100 → `0x20903C64`; noteOff ch2 48 → `0x2082 3000`; CC ch1 74 → `0x20B14A..`; clock `0x10F80000`, start `0x10FA0000`, continue `0x10FB0000`, stop `0x10FC0000`
- [ ] NoteRegistry: on adds / off removes; flush emits offs for all sounding notes + CC123 per touched channel, then is empty; per-channel flush leaves other channels sounding; double flush emits nothing
- [ ] Loopback integration: an in-process input port connected to the virtual source receives the sent words (content verified)
- [ ] "Berlinan Out" is visible to the system while the service lives (endpoint name check)
- [ ] `swift test` green (loopback test may be environment-sensitive — must pass locally)
- [ ] Human item: with the test run or app running, "Berlinan Out" appears as a MIDI input in Ableton's preferences

## Out of scope

Scheduler/clock (phase 12), per-voice routing UI + multiple sources mode (M4/FR-IO-1b), clock-in (M4), CC lanes (M3).
