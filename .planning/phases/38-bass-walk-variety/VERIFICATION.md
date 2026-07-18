# Phase 38 — Bass Walk Variety — Verification

Date: 2026-07-18 · Branch: feature/38-bass-walk-variety · Suite: **307 tests / 107 suites green**

## Automated results

| Criterion | Result |
|---|---|
| Laws across 16 seeds: downbeat roots = schedule, ≤2-degree steps incl. wrap, same-seed determinism | ✅ |
| 16 seeds → ≥ 4 distinct walks (got real variety) | ✅ |
| Live regenerate re-rolls the walk over the same harmony | ✅ |
| Pre-existing bassMelody tests green; goldens untouched (demo has no bassMelody) | ✅ |
| App builds: regenerate disabled + explained on drone/heartbeat; explanatory tooltip on bassMelody | ✅ |

## Design notes

- The fix keeps M §8.4's split: roots are the harmony's (law), the path is
  the player's (seeded). Passing-tone minimum = what a ≤2-step path needs;
  extras, syncopation (20 % off-beat) and octave dips (15 %, degree-space
  unchanged) come from the seed stream.
- Note for released documents: 1.2.0 bassMelody patterns regenerate
  differently now (the walk was seed-blind before) — flagged in the
  Unreleased CHANGELOG entry.

## Human checklist (pending)

- [ ] Full ensemble: regenerate on the bass gives a new line, dice gives a
      new universe including the bass; the harmony's roots never move
