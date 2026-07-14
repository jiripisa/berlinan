# Phase 21 — Verification

Date: 2026-07-15

| Criterion | Result |
|---|---|
| TickClock anchorTick math; old/new segments agree at the swap boundary; new segment runs at the new rate | ✅ |
| Runtime key change: binds at next bar (C→A rooted), post-change mutations/regens stay in the new key, chunk-independent | ✅ |
| Snapshot carries the effective key; recall + key interleave by bind tick (recall restores material, NOT the key — key is a performance setting) | ✅ |
| Transport tempo integration (240→120 live): clock spacing ratio ≈ 2.0 (±15%), both regimes present, currentBPM updates, currentTick monotonic | ✅ |
| UI: settings usable while playing (key + BPM; meter disabled mid-play), KEY/BPM in the transport bar track live values | ✅ build clean, smoke launch OK |
| `swift test` | ✅ 209 tests / 75 suites; goldens untouched |
| TDD red → green | ✅ |

## Human checklist (user)

- [ ] While jamming: settings → new key → bed re-roots at the next bar (KEY chip updates)
- [ ] While jamming: BPM change → Ableton follows via clock, groove stays continuous at the boundary

## Notes / descope

- Runtime METER change descoped to backlog with a design sketch (piecewise
  meter map / bar-origin bookkeeping) — stopped-only meter changes remain.
- Live tempo changes update project.bpm (persisted + capture export uses the
  current tempo); they are NOT recorded as an SMF tempo map (single-tempo
  export).
