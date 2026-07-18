# Phase 38 — Bass Walk Variety (user feedback)

## Goal

User report (2026-07-18): in Full ensemble the bass line never changes —
regenerate and the dice do nothing. Cause: `bassMelody` was fully
deterministic (the walk ignored its seed). Fix: the ROOTS stay the law
(M §8.4 — the walk states the harmony), but the seed now decides HOW the
walk gets there: passing-tone count, stepwise path, syncopation, octave
dips. Regenerate and New Seed produce a new bass line telling the same
harmony.

## Design decisions

- Constraints that never break, any seed: downbeat = the bar's progression
  root (accented, held); consecutive degree steps ≤ 2 (incl. across bars
  and the loop wrap); at least the minimum passing tones a ≤2-step path
  needs.
- Seeded freedoms: extra passing tones (up to the bar's room), the
  constrained random path (±1/±2 steps toward the next root), 20% off-beat
  syncopation per passing tone, 15% octave dip (degree-space unchanged).
- `usesRandomness` flips to true for bassMelody; drone + heartbeat stay
  deterministic and their lane regenerate button now says so (disabled +
  tooltip); bassMelody's regenerate tooltip explains "new walk, same
  harmony".

## Acceptance criteria

- [ ] Laws hold across many seeds (roots, ≤2 steps, min counts)
- [ ] Same seed → identical; seeds vary the walk; live regenerate changes
      the bass line
- [ ] Existing bassMelody tests stay green; goldens untouched (demo has no
      bassMelody)
- [ ] Lane regenerate: disabled + tooltip on drone/heartbeat; explanatory
      tooltip on bassMelody
- [ ] Human: regenerate/dice audibly re-roll the Full-ensemble bass
