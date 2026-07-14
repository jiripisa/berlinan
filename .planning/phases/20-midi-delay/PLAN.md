# Phase 20 — MIDI Delay

## Goal

The user-requested toggleable MIDI delay (FR-MOD-7, deferred from M3): each note's echoes emitted as real MIDI notes for setups without an audio delay — per voice, switchable live, with the cheat-sheet warning (FR-MOD-8 interplay).

## Deliverables

- Engine `MIDIDelay.swift` (spec §7.7):
  - `MIDIDelayConfig` (enabled — default OFF, division dotted8th/eighth/quarter — defaults to the role's hint division, repeats 1–8 default 3, velocityDecay default 0.55 ≈ 50% feedback, gateScale default 0.9); `DelayDivision.ticks` (musical, quarter-based).
  - `MIDIDelay.process(notes:config:)` — echoes at `at + k·division`, velocity chained-decayed (cutoff < 8 — inaudible tail), gates scaled, tagged `isEcho` (`RenderedNote.isEcho`, default false).
  - Echoes exist ONLY at the output boundary: patterns, lifecycle, phasing, convergence never see them; capture includes them (capture = what was played — documented).
- `VoiceConfig.midiDelay: MIDIDelayConfig?` (nil = off; persists in documents); both renderers apply it post velocity/gate maps.
- `LiveEngine`: mutable per-voice delay state + `Action.setMIDIDelay(voiceID:enabled:)` (binds at the render head, ≤ lookahead latency); snapshot exposes `midiDelayEnabled`.
- App: lane toggle button (echo icon, cyan when on) → live action + project persistence; **Delay Cheat Sheet warning row** when a voice's MIDI delay is on ("echoes already in MIDI — disable/lower the audio delay").

## Acceptance criteria

- [x] process(): echo times at k·division; velocities 100→55→30→17 at decay 0.55; gate ×0.9 chain; cutoff below 8; disabled = identity; echoes tagged
- [x] Patterns/snapshot/convergence unaffected (echoes absent from `pattern.notes`)
- [x] Live ≡ offline with delay enabled; chunk-independent (echoes ride with their source window)
- [x] Toggle action: off → subsequent windows echo-free; on → echoes appear
- [x] SMF render with delay carries more note-ons than without; goldens untouched (demo has no delay)
- [x] Cheat sheet shows the warning for delay-on voices
- [x] `swift test` green; build clean; smoke launch
- [ ] Human: toggle the echo button on bedPluck1 while jamming — the "ducka-ducka" appears without any DAW delay; cheat sheet warns

## Out of scope

Per-voice delay parameter UI beyond the toggle (division/repeats editable via document JSON for now), filtered/darkening repeats (impossible in MIDI — hint says so), echoes in the pattern strip visualization.
