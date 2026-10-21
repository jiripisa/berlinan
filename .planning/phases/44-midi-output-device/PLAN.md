# Phase 44 — Choose the MIDI Output (user request)

## Goal

User request (2026-10-22): besides the virtual source "Berlinan Out", the
user can pick a connected MIDI device (DIN interface, USB synth, IAC bus)
and Berlinan sends its notes, CC and clock straight to it — no DAW or
routing utility in between. Completes the "routable to an existing
destination" part of FR-IO-1 (app-wide, not yet per voice).

## Design decisions

- One app-wide output, exclusive: either the virtual source or one
  destination. Sending to both would double every note for a DAW that
  listens to Berlinan Out while also routing the device.
- Everything that goes out follows the choice: notes, CC, MIDI clock and
  Start/Stop.
- Destinations are identified by CoreMIDI unique ID (stable across
  launches and replugging); the choice persists in UserDefaults with the
  device name for display while it is unplugged.
- Hot-plug (NFR-5): the endpoint is resolved at send time; a missing
  device drops events (no crash) and resumes when it is plugged back in.
- Switching output (also while playing) first sends note-offs + CC 123 to
  the previous output, so nothing hangs there.
- Berlinan's own "Berlinan Control" destination is never offered.
- UI: the output label in the transport bar ("● Berlinan Out") becomes a
  menu: Berlinan Out (virtual) + connected devices; the dot turns red with
  "disconnected" when the chosen device is gone.
- Out of scope: per-voice routing (FR-IO-1 rest), one source per voice.

## Acceptance criteria

- [ ] Destinations list external/virtual destinations, never our own
- [ ] With a destination chosen, sent events arrive there (loopback test)
- [ ] Switching output flushes sounding notes to the previous output
- [ ] Missing destination → events dropped, no crash
- [ ] Choice persists across launches; full suite green; app builds
- [ ] Human: pick a hardware synth / IAC bus, notes and clock arrive
