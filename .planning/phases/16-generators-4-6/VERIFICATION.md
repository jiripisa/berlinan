# Phase 16 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Generators 4–6 in the shared determinism + FR-P-2 suites (50 seeds × 6 configs) | ✅ |
| Walk: consecutive pitches ≤ scatter+1 st (quantized-state walk), rests ≥ 2 steps exist, density < 70% | ✅ |
| Staged pluck: root pinned at 0, octave jump present, accented signature note on the final 16th, grid-aligned | ✅ |
| Arpeggiator: up ascending, down rotated onto a root, upDown single peak; 3×2-octave 8ths = 3-beat loop (native polymeter) | ✅ |
| Decoupled: 8v6 → 24-step composite / 16 onsets / per-step pitch indexing / silences; 7v8 → 56 steps; window chaining seam-safe | ✅ |
| duplicateAndTweak: first half verbatim, tweaks land in later reps, span-guarded, deterministic | ✅ |
| moveAccents: pitches/times/velocities/gates untouched, accents relocate | ✅ |
| Goldens untouched; `swift test` | ✅ 165 tests / 56 suites |
| TDD red → green (one test-side fix: Bool vs GateStep array) | ✅ |

## Notes

- Walk state is the QUANTIZED offset (not raw chromatic) — this is what makes
  the ≤ scatter+1 bound provable after scale quantization.
- Arpeggiator loop length = one full cycle, deliberately NOT bar-aligned:
  a 3-tone × 2-octave arp of 8ths is a 3-beat loop that phases against 4/4
  out of the box (M §5.9 "5 held notes against 4/4").
- Decoupled mode is expanded via `effectiveNotes`, so all existing machinery
  (occurrences, hasOnset, anchors, phasing, SMF) works on it unchanged.
