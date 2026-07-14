# Phase 08 — SMF Export

## Goal

A byte-exact, deterministic Standard MIDI File writer (FR-IO-6, engine part of FR-IO-8): type 1, 960 PPQN, tempo/meter/markers on track 0, one track per voice. Pure bytes — no Foundation/CoreMIDI. This unlocks phase 09's CLI render and the first listening test in Ableton.

## Deliverables (Sources/BerlinanEngine/)

- `SMF.swift`
  - `SMFTrack` (name, channel 0–15, `[RenderedNote]`).
  - `SMFWriter.encode(bpm:meter:tracks:length:markers:)` → `[UInt8]`:
    - header `MThd`, format 1, ntrks = voices + 1, division 960;
    - track 0: set-tempo meta (rounded µs/quarter), time-signature meta (nn, dd = log2 denom, cc = 24, bb = 8), markers (FF 06), end-of-track at `length`;
    - voice tracks: track-name meta, note on/off pairs (no running status — full status bytes for maximal DAW compatibility), end-of-track at `length`;
    - **ratchet expansion**: ratchet r > 1 splits a note into r retriggers across its gate (sub-gate ≈ 90% of the slice, min 1 tick) [M §13.5];
    - **note-off integrity** (FR-IO-8): same-pitch overlaps clipped (a note's off lands no later than the next same-pitch onset); at equal ticks, offs are ordered before ons;
    - VLQ delta-time encoding (internal, tested directly).

## Acceptance criteria

- [x] VLQ vectors: 0→`00`, 127→`7F`, 128→`81 00`, 960→`87 40`, 0x0FFFFFFF→`FF FF FF 7F`
- [x] Header bytes exact: `MThd 00000006 0001 <ntrks> 03C0`
- [x] Track 0 carries `FF 51 03 0A2C2B` (90 BPM) and `FF 58 04 04 02 18 08` (4/4)
- [x] Single-note fixture produces the exact expected track bytes (on/off pair, EoT at length)
- [x] Ratchet 2 with gate 120 → onsets at 0 and 60; sub-gates ≤ slice
- [x] Same-pitch overlap: first note's off clipped to the second's onset; offs precede ons at equal ticks
- [x] Every note-on has exactly one matching note-off (fuzz over generated ensembles)
- [x] Determinism: identical inputs → identical bytes
- [x] TDD red → green; `swift test` green

## Out of scope

CC lanes in export (M3, FR-MOD-3/4), capture-buffer scopes (M2, FR-IO-7), SMF reading (not needed for golden masters — they compare bytes).
