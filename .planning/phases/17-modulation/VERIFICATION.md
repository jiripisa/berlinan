# Phase 17 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Sine lane: t=0 center value, full swing reached near extremes, 40-tick grid, 0–127 clamp | ✅ |
| Delta filter: flat lane emits exactly one initial value; sawUp monotone | ✅ |
| Chunk-safety: chained renderCC windows == whole range (stateless delta) | ✅ |
| S&H: 8th steps, pre-strike −10 ticks, deterministic per seed, bounded, varying | ✅ |
| Gate ramp: per-bar multipliers scale gates exactly (0.5/2.0 profile verified) | ✅ |
| CC map: named targets resolve; unmapped lane skipped | ✅ |
| SMF: CC74 events on the demo's bedPluck1 track; same-tick order offs→ccs→ons | ✅ |
| DelayHint: dotted 8th 500 ms / 8th 333 ms / quarter 667 ms @ 90 BPM; role mapping | ✅ |
| Live loopback: 0xB0 CC74 words in the real MIDI stream | ✅ |
| Delay Cheat Sheet window (Window menu) — visual check, copy buttons | ✅ (evidence) |
| Goldens REGENERATED (justified): track names now carry delay hints (FR-MOD-8b) and the demo gained a 16-bar filter lane | ✅ suite green after regen |
| `swift test` | ✅ 176 tests / 62 suites |

## Notes

- MIDI delay (FR-MOD-7) deferred to M4 by user decision — spec + roadmap updated.
- Mute deliberately does NOT drop CC (knob positions stay consistent); capture
  export remains notes-only (CC in capture → M4).
- Engine stays Foundation-free (String(format:) replaced by interpolation).
