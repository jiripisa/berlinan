# Phase 35 — Form Templates & Reprise

## Goal

Long-form memory (M §12): named arrangement forms (classic arc, slow build,
ambient plateau) and the reprise — the A material captured when the bed
settles RETURNS at the payoff, so the climax is the theme's return with the
full ensemble (the manual's additive repetition, §12.3 S6–S8), not new
material.

## Design decisions

- `ArrangementConfig.reprise: Bool?` (optional — old documents decode) +
  preset factories: `.classicArc` (8–16 bars, reprise), `.slowBuild`
  (12–24 bars, reprise), `.ambientPlateau` (ambient, no reprise — plateaus
  don't return, they drift).
- Engine: entering BED captures a theme `StateSnapshot` (once); entering
  PAYOFF with reprise on recalls it at that bar — patterns, generations and
  the harmony schedule come home (the B-part walk resolves back to A).
  Voice activation is untouched (the payoff's re-add directives already ran).
- UI: FORM menu in the ARR cluster (stopped-only), sets the config and
  lights AUTO.

## Acceptance criteria

- [ ] Presets: distinct configs with documented periods/flags
- [ ] Reprise: the payoff's patterns equal the bed-entry theme (after
      variation mutated them in between); schedule returns to A
- [ ] reprise off → payoff keeps the mutated material (no recall)
- [ ] Suite green; app builds with the FORM menu
- [ ] Human: the payoff feels like "the theme returns", not "another change"

## Out of scope

Multiple themes / user-picked reprise points (backlog), template gallery (36).
