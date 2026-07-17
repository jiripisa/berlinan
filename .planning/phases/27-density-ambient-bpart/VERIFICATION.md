# Phase 27 — Density, Ambient, B-Part — Verification

Date: 2026-07-18 · Branch: feature/27-density-ambient-bpart · Suite: **262 tests / 90 suites green**

## Automated results

| Criterion | Result |
|---|---|
| Density 1 = identity; existing suite untouched | ✅ |
| Density 0.4 caps per-loop notes at ceil(n·d); both accents survive a cap of 3; positions stay sorted; density 0 silences | ✅ `DensityCapTests` |
| Project density caps every rendered loop; `setDensity` binds at the next bar; chunk-independent | ✅ `DensityLiveTests` |
| Ambient: fixed change periods at bars-per-minute (SM unit) | ✅ |
| Ambient: a seed that mutates at bar 4 plain stays verbatim 16 bars ambient | ✅ (after fixing project-level legit scaling — see notes) |
| SM: payoff emits setDensity(1.0); subtract steps decrease; bPart fires the bundle exactly once | ✅ |
| B-part: progression walk lands in the schedule from the fire bar; bass regenerates; dropBed silences bed 2; `setVoiceActive` recovers it | ✅ `BPartTests` |
| `fireBPart` MIDI-learn macro binds + persists | ✅ |
| App builds with DENS slider, AMBIENT toggle, B button | ✅ |

## Design notes & deviations

- Ambient legitimization scaling had to happen at the PROJECT level (before
  voice materialization), not just in the engine's mutate config — otherwise
  patterns kept their 4-play initial lifecycle (caught by the red test).
- **Deviation from plan**: ambient is stopped-only in the UI (the toggle
  disables while playing). A live ambient switch would need re-materialized
  lifecycles mid-flight; descoped — the SM period change alone would be
  misleading without the legitimization half.
- The phase-26 fast-forward arc test now sees the B-part walk still in force
  at the ending; its "roots only" assertion checks a single pitch class
  rather than literal C.

## Human checklist (pending)

- [ ] DENS slider audibly thins the bed (accents last to go), returns clean
- [ ] B button: one press → harmonic shift + new bass line in one bar
- [ ] AMBIENT + AUTO from stopped: a patient piece, ~1 change/min
- [ ] Full AUTO arc now breathes: payoff denser, subtract thinner
