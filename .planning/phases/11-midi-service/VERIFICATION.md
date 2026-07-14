# Phase 11 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| UMP vectors — channel voice (noteOn/noteOff/cc) and system real-time (clock/start/continue/stop) | ✅ |
| NoteRegistry: tracking, non-note events ignored, full flush (offs + CC123 per channel, empty after), per-channel flush, double-flush no-op | ✅ |
| CoreMIDI loopback: virtual source discoverable by display name; in-process input port receives the sent UMP words; registry balanced after on/off pair | ✅ |
| `flush()` silences hanging notes (activeNoteCount 1 → 0) | ✅ |
| `swift test` (full suite) | ✅ 122 tests / 39 suites |
| TDD red → green | ✅ |

## Human verification items

- [ ] Run the loopback test (or the app once phase 13 wires the service) and
  confirm a "Berlinan …" port appears under MIDI inputs in Ableton's
  Link/Tempo/MIDI preferences.

## Notes

- New `BerlinanRuntime` library target establishes the spec §5.1 three-layer
  architecture in the package layout; the engine remains CoreMIDI-free.
- `MIDIService` is deliberately not thread-safe — it will be owned by the
  scheduler thread (phase 12, spec §5.4).
- Event-list building handles buffer exhaustion by chunked emission; each
  sent event is tracked in the registry at send time.
