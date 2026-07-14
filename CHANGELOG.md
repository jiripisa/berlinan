# Changelog

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
