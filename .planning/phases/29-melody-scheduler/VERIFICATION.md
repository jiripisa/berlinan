# Phase 29 — Alternation, Tension, Bass Melody — Verification

Date: 2026-07-18 · Branch: feature/29-melody-scheduler · Suite: **279 tests / 96 suites green**

## Automated results

| Criterion | Result |
|---|---|
| Alternation: no onset outside the voice's slot over 16 bars; gates clamp at slot edges (tick-level "never simultaneous", echoes included) | ✅ |
| `setAlternating(nil)` restores both voices; chunk-independent | ✅ |
| Alternating voices get different delay-hint divisions (slot B answers on quarters) | ✅ |
| TensionTable ordering per M §4.4 (m2 max … P5/unison restful; octave fold) | ✅ |
| Tension-walk growth: tense position picks the m7 candidate, release picks the fifth | ✅ |
| bassMelody: downbeat roots match the schedule (0→5→3), passing tones stepwise |Δ| ≤ 2 incl. across bars and the loop wrap | ✅ |
| App builds: "Alternate With" context menu, cheat-sheet slot tags | ✅ |

## Design notes

- Alternation filters at the very end of the voice's render (after MIDI-delay
  echoes) — the never-simultaneous guarantee covers everything the voice emits.
- Melody growth (phase 28's 4-bar clock) now scores by the tension table
  with the walk policy: growth stages cycle tense → release → release.
- `bassMelody` is the first deterministic generator (`usesRandomness =
  false`): the walk IS the harmony. Live regeneration passes the LIVE
  schedule, so a B-part reshapes the bass walk on the next regenerate.

## Human checklist (pending)

- [ ] Alternating beds: 4-bar call and answer, no overlap, different echoes
- [ ] Growth over minutes: tense reach, then settling (the walk audible)
- [ ] bassMelody voice against a progression: roots land, passing tones walk
