# Phase 21 — Runtime Tempo & Key Changes

## Goal

Change tempo and key while playing, bar-quantized (FR-GS-5): tempo via clock re-anchoring in the Transport (ticks are musical — the engine never notices), key via a pending global engine change (degree-space patterns re-root instantly; no hanging notes because offs are already scheduled).

**Descoped**: runtime METER changes → backlog. The harmony schedule is bar-indexed with a uniform bar length; a mid-stream meter change needs a piecewise meter map (bar origin bookkeeping through HarmonyEngine and quantization). Design sketch: engine-internal `barOrigin: (tick, barIndex)` rebased at each change, all bar math routed through it. Stopped-only meter changes (settings sheet) remain.

## Deliverables

- Runtime `TickClock`: `anchorTick` (default 0) — piecewise-linear host-time map segments (spec §8.1).
- `Transport.setTempo(_:)`: pending until the render head reaches the next bar boundary (windows clamp to it), then the clock swaps with continuity (`machTime(atBoundary)` equal across old/new segments); `currentBPM` published; capture export uses the current tempo.
- Engine: `project` becomes mutable; `Action.setKey(Key)`; `pendingRecall` generalized to a queue of global changes (recall | key), the render window splitting at each bind tick; mutation/regeneration after the change use the new key; `Snapshot.key` for the UI.
- App: settings sheet usable while playing for key + BPM (meter picker disabled mid-play); transport-bar KEY/BPM reflect the live values (snapshot key, transport BPM).

## Acceptance criteria

- [ ] TickClock: nonzero anchorTick math; old/new segments agree at the boundary tick
- [ ] Engine key change: binds at the next bar (C-rooted before, A-rooted after); all post-change notes in the new scale (incl. after mutations); chunk-independent; snapshot carries the key
- [ ] Key + recall interleave correctly (queue ordering by tick)
- [ ] Transport integration: clock-pulse spacing halves/doubles after a live tempo change at a bar boundary; currentTick stays monotonic; currentBPM updates
- [ ] `swift test` green; goldens untouched
- [ ] Human: while jamming, open settings → change key (bed re-roots at the next bar) and BPM (Ableton follows via clock)

## Out of scope

Runtime meter (backlog + design sketch above), tempo ramps/automation, persisting live tempo changes as an SMF tempo map (single-tempo export with the current BPM).
