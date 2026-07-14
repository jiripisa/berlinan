# Phase 07 — Harmony & Global Diatonic Transposition

## Goal

The style's primary harmony mechanism (M §7.1; FR-H-1/2/3): a bar-indexed transposition schedule applied to the ensemble stream in degree space, per-voice opt-out, bar quantization — and the completed note pipeline (degrees → transpose → resolve → register fold → MIDI numbers) that SMF export (phase 08) will consume.

## Deliverables (Sources/BerlinanEngine/)

- `Harmony.swift`
  - `TranspositionEvent` (bar, degreeOffset) + `TranspositionSchedule` — bar-indexed by construction (FR-H-3: changes can only exist on bar boundaries), sorted, last-wins per bar; empty schedule = pedal on the root (FR-H-1); `offset(atBar:)`.
  - `HarmonyEngine.quantizedEventBar(requestTick:meter:quantumBars:)` — where a live change request lands (next boundary; exact boundary maps to itself; quantum 1/2/4/8 bars).
  - `RenderedNote` — voice-tagged, MIDI-ready note (UInt8 note number after transpose + resolve + fold, velocity, gate, accent, ratchet passthrough).
  - `HarmonyEngine.render(voices:schedule:key:meter:in:)` — PhasingEngine stream → transposition (participating voices only, FR-H-2) → `Key.resolve` → `RegisterWindow.fold` → `[RenderedNote]`.

## Acceptance criteria

- [ ] Empty schedule = pedal: all offsets 0 (FR-H-1)
- [ ] Schedule lookup: events at bars 4 (+3) and 8 (0) partition the timeline correctly; unsorted input normalized; same-bar duplicates last-wins
- [ ] Diatonic correctness in C minor: offsets +2/+4/+5 move the root to Eb/G/Ab; the i→VI→iv→i bass walk renders C–Ab–F–C
- [ ] Law 2 property: transposed + resolved pitch class stays in scale for random offsets −7…+7
- [ ] Per-voice opt-out: non-participating voice's pitches unchanged while others move (FR-H-2)
- [ ] Bar boundary precision: onset at bar-start tick uses the new offset; onset one tick earlier uses the old one
- [ ] `quantizedEventBar`: mid-bar request → next bar; exact boundary → same bar; quantum 4 honored
- [ ] Register fold applies after transposition (high offsets fold back into the voice window)
- [ ] TDD red → green; `swift test` green

## Out of scope

Progression player + weighted-random mode (FR-H-4/5, M3), bass reharmonization mode (FR-H-6, M3), tension budget (FR-H-7, P3), ratchet expansion into retriggers (phase 08 render).
