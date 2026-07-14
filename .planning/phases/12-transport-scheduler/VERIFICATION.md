# Phase 12 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| TickClock: beat duration @ 90 BPM, round-trip, negative pre-anchor ticks, non-identity timebase scaling | ✅ |
| clockTicks: 96/bar, 40-tick grid, half-open seam-safety | ✅ |
| Converter: on/off pairs, off = at + gate, channel map, muted voices dropped | ✅ |
| Integration loopback @ 120 BPM ≈ 0.7 s: Start + Stop received, clock count in range, note-ons flow, consecutive clock timestamps spaced 1/24 beat ± 1 ms (NFR-1 evidence), flush leaves 0 active notes | ✅ |
| App: Play/Stop button (space bar) over the demo project; smoke launch OK | ✅ |
| `swift test` | ✅ 129 tests / 42 suites |
| TDD red → green (one engine fix: public RenderedNote init) | ✅ |

## Human verification items

- [ ] Run the app, arm an Ableton MIDI track on "Berlinan Out" (ch 1/2/3 →
  three tracks), hit PLAY in Berlinan: notes audible, phasing bed + bass,
  harmonic movement at bars 8/12/16/24/28. **This doubles as the deferred
  musical sign-off from M1.**
- [ ] Enable Sync on the port in Ableton: Live's tempo follows 90 BPM
  (Berlinan is clock master).

## Notes

- `play()` restarts from tick 0 with a fresh engine (M2 simplification,
  deterministic every run).
- Mute latency path: flag read at each 25 ms wake + immediate channel flush.
- Scheduler thread: 25 ms wake / 150 ms lookahead / 100 ms preroll anchor;
  jitter is absorbed by CoreMIDI timestamps, as designed (spec §8.2).
