# Phase 04 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Determinism: same (config, seed) ⇒ identical pattern (7 config/role combos) | ✅ |
| Varying seeds vary note content (all generators consume the seed stream) | ✅ |
| FR-P-2 invariants across 50 seeds × 7 combos: first sounding = root, accidentals 0, positions in loop, span ≤ 24 st, gates 40–60% of a 16th | ✅ |
| Seed procedure: beats 1&3 timing-locked (bed), bar count → length, bass role roots-only + `satisfiesAnchor`, sparseness 3–7 notes/bar | ✅ |
| High/Mid/Low: +4 contour (high), ±4 stairs with beats 1&3 root-on-grid (mid), exactly two root onsets (low) | ✅ |
| Pulsing bass: 16/16 onsets, ≥ 75% roots, accents ⇔ off-root moves, accent velocity > baseline, step 0 always root | ✅ |
| Provenance records generator id + seed | ✅ |
| TDD red → green | ✅ |
| `swift test` | ✅ 48 tests / 17 suites |

## Notes

- Mutation ops that draw an invalid move (collision, out of range, add-cap
  reached) are skipped, not retried — keeps rng consumption simple and the
  output deterministic.
- Degree moves clamp to −3…+4 so the resolved span can never exceed two
  octaves even with octave-add notes present.
- Listening protocol: deferred to phase 09 (CLI render) when patterns can be
  exported to SMF — first audible validation happens there per plan.
