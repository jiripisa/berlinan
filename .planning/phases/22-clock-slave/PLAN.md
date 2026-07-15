# Phase 22 — Clock Slave

## Goal

Berlinan follows an external MIDI clock (FR-IO-4): tempo/phase locked to incoming F8 pulses with PLL-style smoothing (spec §8.4), transport obeying Start/Stop. The reverse gear of phase 12 — jam inside an existing Ableton session.

## Deliverables

- Runtime `ClockEstimator` (pure, unit-tested): median-of-9 inter-pulse intervals + EMA smoothing → BPM; pulse counter (pulse k = tick k·40).
- `MIDIService.connectClockInput(sourceName:handler:)` — input port over external sources (self-source excluded; optional name filter), parsing UMP real-time (F8/FA/FB/FC) with packet timestamps.
- `Transport` sync modes: `.internalClock` (default) / `.externalClock`:
  - external: clock OUT suppressed; Start → play anchored at the start message; Stop → stop; each wake re-anchors the clock segment to the latest pulse (tick = count·40) with the smoothed BPM — micro-warping via piecewise segments (anchorTick from phase 21), never tick jumps;
  - freewheel: no pulse for > 500 ms → hold the last segment, surface a flag.
  - `currentBPM` reflects the estimate.
- UI: INT/EXT sync picker in the transport bar (switchable while stopped); status text ("EXT — waiting for clock" / estimated BPM).

## Acceptance criteria

- [x] ClockEstimator: 120 BPM synthetic pulses → 120 ±0.5; ±2 ms jitter smoothed within 3%; single outlier absorbed by the median
- [x] Integration (loopback): a test sender's FA + F8 stream at 240 BPM → transport auto-plays, currentBPM ≈ 240 ±5, notes flow; FC stops it and flushes
- [x] Internal mode behavior unchanged (suite green)
- [ ] Human: Ableton set as clock master (Sync OUT to Berlinan) → Berlinan follows Live's tempo and transport

## Out of scope

Ableton Link (23), MIDI Song Position Pointer relocation (start always from 0 — matches internal-mode behavior), clock-source picker UI (name filter is API-level; EXT listens to all external sources).
