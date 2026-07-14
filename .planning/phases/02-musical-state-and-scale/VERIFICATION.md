# Phase 02 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Scale presets match manual §4.2 | ✅ explicit offset-list test for all 10 modes |
| Resolution basics (C minor @ 60: 0→60, 2→63, 4→67, 7→72; negatives; root shift; accidental) | ✅ |
| Property: resolved pitch class ∈ scale (500 random cases) | ✅ |
| Fold: inside window, pitch class preserved, no clamp (500 random windows/notes) | ✅ |
| Quantize: in-scale idempotent; C#→C tie-down; property in-scale + ≤6 semitones (500 cases) | ✅ |
| SplitMix64 determinism + SeedStream stability/label-sensitivity | ✅ |
| TDD | ✅ red commit (161 compile errors) precedes implementation |
| `swift test` | ✅ 19 tests / 7 suites passed |

## Notes

- `SeedStream.derive` deliberately uses FNV-1a over labels (not `String.hashValue`,
  which is per-process seeded) + one SplitMix64 mixing round.
- `floorDiv`/`floorMod` are internal helpers — Swift `%` truncates toward zero
  and would corrupt negative-degree math.
