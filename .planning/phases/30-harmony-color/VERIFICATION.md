# Phase 30 — Tension Budget, Chord Layer, Heartbeat — Verification

Date: 2026-07-18 · Branch: feature/30-harmony-color · Suite: **285 tests / 99 suites green**

## Automated results

| Criterion | Result |
|---|---|
| spendTension: exactly one extra note vs baseline, at the next bar, out of key (pitch class 1 in C minor), sustained a whole bar | ✅ |
| Budget finite: two spends land, the third adds nothing; snapshot mirrors the countdown 2→1→0 | ✅ |
| Chord layer: 7-bar loop, ≥ 3 distinct in-scale degrees at position 0, gates = full loop, `accidental == 0` everywhere | ✅ |
| Chord layer deterministic per seed, varies across 12 seeds | ✅ |
| Heartbeat: one root per beat, no accents | ✅ |
| App builds: T·n button (disabled at zero) | ✅ |

## Design notes

- The tension note goes through `DegreePitch.accidental = +1` — the one and
  only quantizer bypass in the codebase (FR-GS-6 exception), consumed as a
  bar-bound one-shot in the render (chunk-safe: windows partition).
- The chord layer leans on the Legitimizer for its "~every 7 bars"
  stochasticity: the pattern IS one chord; lifecycle re-rolls it.
- Generators now include two deterministic members (bassMelody, heartbeat) —
  `usesRandomness` documents which draw from the seed stream.

## Human checklist (pending)

- [ ] T button mid-jam: the m2 stab reads as an event, resolves back
- [ ] A `.pad` voice on `.chordLayer(periodBars: 7)`: slow chord changes
      under the beds, always in key
- [ ] A `.rhythm` voice on `.heartbeat`: anchors without pushing
