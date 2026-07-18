# Phase 35 — Form Templates & Reprise — Verification

Date: 2026-07-18 · Branch: feature/35-form-templates · Suite: **303 tests / 106 suites green**

## Automated results

| Criterion | Result |
|---|---|
| Presets: classicArc (8–16, reprise), slowBuild (12–24, reprise), ambientPlateau (ambient, no reprise) | ✅ |
| Reprise: payoff's note content == bed-entry theme (after variation mutated it) | ✅ |
| No reprise: payoff keeps the evolved material | ✅ |
| Suite green; app builds — FORM presets via right-click on AUTO | ✅ |

## Design notes

- The theme is a full `StateSnapshot` (patterns + generations + harmony
  schedule), captured once on entering BED, recalled on entering PAYOFF —
  so the B-part's progression also resolves home with the theme. Voice
  activation is untouched (the payoff's re-add directives run first at the
  same boundary).
- `ArrangementConfig.reprise` is optional for document compatibility.

## Human checklist (pending)

- [ ] Classic arc end-to-end: the payoff lands as "the theme returns"
- [ ] Slow build: patient, still arrives
- [ ] Form picker discoverable via right-click on AUTO

## Backlog note

Multiple themes / user-chosen reprise points; a visible FORM label in the
ARR cluster (right-click only for now).
