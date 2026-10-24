# Phase 47 — Per-voice MIDI Channel (user request)

## Goal

User request (2026-10-24): every voice can be sent on a MIDI channel the
user picks. With one output device (phase 44) this is how a multitimbral
synth or a DAW separates the voices. Until now the channel came fixed from
the template (`VoiceConfig.channel`) and was only displayed ("ch 3").

User decisions: the channel is stored in the project (the `.berlinan`
document already has `VoiceConfig.channel`); per-voice output routing
(rest of FR-IO-1) is NOT wanted now.

## Design decisions

- UI: the "ch N" label in the voice lane becomes a menu, Channel 1–16; a
  channel used by another voice shows that voice's name ("Channel 3 —
  Bass"). Sharing a channel is allowed (the user may want it), not blocked.
- Works while playing: `Transport.setChannel(_:_:)` updates the channel map
  under the lock (next scheduler wake, ≤ 25 ms) and flushes what still
  sounds on the old channel (FR-IO-8). A pending template load (phase 42)
  carries the change, so it survives the bar-line swap.
- The transport's project copy is updated too, so capture export (FR-IO-7)
  names and writes the track on the new channel.
- App: `AppServices.setVoiceChannel` writes `project.voices[i].channel`;
  stopped → transport rebuild, playing → live set + stale flag (rebuild on
  stop), like the other per-voice edits.
- Not undoable: the Undo command covers generative engine state only
  (FR-UX-5), the same as CC profiles and MIDI delay. Re-picking the channel
  reverts it.

## Acceptance criteria

- [ ] Playing: after `setChannel`, the voice's notes go out on the new
      channel and none on the old one (loopback test)
- [ ] The old channel gets note-offs + CC 123 for notes still sounding
- [ ] A change made while a template load is pending survives the swap
- [ ] Capture export writes the voice's track on the new channel
- [ ] Lane menu changes the channel, stopped and playing; the label follows;
      saved documents keep it; full suite green; app builds
- [ ] Human: two voices to two channels of a multitimbral synth / two Live
      tracks

## Files

- `Sources/BerlinanRuntime/Transport.swift` — `setChannel`
- `Sources/Berlinan/AppServices.swift`, `UIState.swift` — `setVoiceChannel`
- `Sources/Berlinan/Views/VoiceLaneView.swift` — channel menu
- `Tests/BerlinanRuntimeTests/VoiceChannelTests.swift`
- spec FR-IO-1 status note, README, CHANGELOG

## Out of scope

Per-voice output devices and per-voice virtual sources (FR-IO-1 rest);
undo of project configuration edits.
