# Changelog

## 1.0.0 — 2026-07-15 (M4 — sync & integration)

First release. Berlinan is open source under GPL-2.0-or-later.

- MIDI delay: engine-side echo notes per voice (toggle live, next-bar bound),
  with the Delay Cheat Sheet warning when both digital echoes and an audio
  delay would stack
- Seed freshness: every session opens a new musical universe; the dice
  button (new seed) swaps universes at the next bar, undoable
- Runtime tempo and key changes while playing, bar-quantized (piecewise
  clock segments; degree-space re-rooting keeps every voice in scale)
- MIDI clock slave (EXT): follows Start/Stop and tempo of incoming MIDI
  clock — median-of-9 + EMA tempo estimator, per-wake segment re-anchor
- Ableton Link (LINK): tempo and bar-phase lock to the local-network
  session via the vendored GPLv2+ abl_link wrapper; peer count in the
  transport bar; joins the network only while LINK is selected
- MIDI learn: "Berlinan Control" virtual destination; LEARN mode binds a
  controller CC/note to play/stop, degrees 1-7, re-roll, new seed, and
  snapshot slots; bindings persist in Application Support
- Drag & drop: a voice lane's pattern strip drags into Ableton (or Finder)
  as a bar-aligned, LCM-looped .mid clip
- Synth CC profiles: built-in Generic and Microfreak maps plus user JSON
  profiles; applied per voice from the lane context menu
- App icon, README, GPL licensing (mirrors Ableton Link's dual license)

## 0.3.0 — 2026-07-14 (M3 — musical depth)

The full manual toolkit lands in the engine and the UI.

- Harmony modes: progression player with the manual's preset walks,
  weighted-random transposition ("sweet vs dark"), bass reharmonization
  with held roots; harmony strip with upcoming-event chips
- Generators 4-6: drunkard's walk, staged pluck (signature closing note),
  arpeggiator expansion with cycle-length loops (native polymeter);
  decoupled gate/pitch patterns (8v6 -> re-sync at 24)
- Modulation output: CC LFO lanes in musical time (bars, not Hz) with
  stateless delta filtering, S&H pre-strike, gate ramps, per-voice CC maps;
  Delay Cheat Sheet window (per-voice audio-delay settings at live tempo)
- Legitimizer plus: Metropolix accumulators, configurable ratchet policy
  (+ live/export ratchet consistency fix), state snapshots with 6 UI slots
  (recall at next bar), undo (Cmd-Z) over generative actions
- Pattern editor (hand edits lock and persist), project settings sheet
  (key/mode/BPM/meter presets), .berlinan documents (open/save incl.
  snapshot slots and hand edits)
- Deferred by user decision: MIDI delay echo notes (FR-MOD-7 -> M4)

## 0.2.0 — 2026-07-14 (M2 — "it plays")

First usable jam tool. Berlinan publishes a virtual MIDI source ("Berlinan
Out"), plays the built-in demo project live with sample-accurate timestamps,
and acts as MIDI clock master.

- Live engine: pull-model renderer with quantized actions (transpose,
  regenerate, blank cycle, lock); byte-equivalent to the offline renderer
- CoreMIDI runtime: virtual source, timestamped sends, note registry + flush
  (nothing ever hangs), MIDI clock 24 PPQ + Start/Stop
- Scheduler: 25 ms wake / 150 ms lookahead / clock-timestamp jitter ≤ 1 ms
- UI: transport bar (POS/BPM/KEY/DEG), voice lanes with live pattern strips,
  per-voice playheads (phasing visible), lifecycle dots, mute/lock/
  regenerate/blank, degree buttons 1–7, re-roll, convergence readout
- Capture: rolling ~60 min buffer; export the last 8/16/32/64 whole bars as
  a bar-aligned multitrack .mid

## 0.1.0 — 2026-07-14 (M1 — headless engine)

- Degree-based musical core (scales, resolution, octave fold, quantize)
- Generators: seed procedure, high/mid/low, pulsing bass
- Phasing ops + LCM convergence; legitimizer (Law 1); diatonic transposition
- SMF type-1 writer; `berlinan-cli render` with golden-master suite
