# Phase 09 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| VelocityPolicy: accent boost clamped, humanization bounded ±range, deterministic, re-rolls per pattern seed | ✅ |
| Renderer Law 1: bars 0–3 verbatim; mutation appears from bar 4 for some master seed | ✅ |
| phaseSteps −1 → 15-step loop (onset recurs exactly one 15-step loop later) | ✅ |
| Transposition applied (bar-8 bass ≥ 75% on Ab) + `HARM:+5` marker in file | ✅ |
| Project JSON round-trip + committed demo file decodes to `Project.demo` | ✅ |
| Golden master: render(demo, 16 bars) byte-equals `Goldens/demo16.mid` | ✅ |
| CLI end-to-end: `demo` writes JSON; `render --bars 64` produces 16 kB SMF with correct summary (loops 16/15/16 steps, convergence 15 bars ≈ 40 s) | ✅ |
| `swift test` | ✅ 107 tests / 34 suites |

## Human verification items (M1 exit gate — listening protocol, spec §12.6)

- [ ] Import `build/berlinan_demo_64bars.mid` into Ableton Live (3 tracks:
  bedPluck1 ch1, bedPluck2 ch2, bass ch3), assign pluck patches + dotted-8th
  delay per the track-name hints, plain 8th delay on bass.
- [ ] Style checklist: bed phases audibly (16v15 drift, re-convergence ~every
  15 bars), bass anchors beats 1&3, harmonic movement at bars 8/12/16/24/28,
  variation appears without breaking repetition, no hanging notes.

## Notes

- `Project.demo` is the single source of truth: golden fixture, committed
  JSON, and `berlinan-cli demo` output are all the same value.
- Golden regeneration procedure: `swift run berlinan-cli demo -o Tests/BerlinanEngineTests/Goldens/demo_project.json`
  + `render --bars 16` to `demo16.mid`, with musical justification in the
  commit message (spec §12.1).
