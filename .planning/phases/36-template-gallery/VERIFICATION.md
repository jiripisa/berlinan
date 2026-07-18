# Phase 36 — Template Gallery — Verification

Date: 2026-07-18 · Branch: feature/36-template-gallery · Suite: **305 tests / 107 suites green**

## Automated results

| Criterion | Result |
|---|---|
| `Project.fullEnsemble`: 6 voices (chordLayer pad, bassMelody, heartbeat, lead), renders | ✅ |
| `Project.ambientDrift`: drone-led build order, ambient arrangement, ≥2 scenes + phase map, renders | ✅ |
| Fresh seed on instantiation (`applyTemplate`) | ✅ (code path shared with FR-UX-6 machinery) |
| Suite green; app builds with the TEMPLATES menu (grid icon, stopped-only) + Save as Template… | ✅ |

## Incidents (resolved)

- `RegisterWindow(36, 36)` for the kick TRAPPED at static-template init:
  the window precondition demands an octave span, and JSON decoding
  (examples/full_ensemble) silently bypasses init preconditions — which is
  why the example file worked while the code template crashed. Both now use
  36–47. Watch-list note: decoded documents skip precondition validation
  (a future document-validation pass could close this).

## Human checklist (pending)

- [ ] Templates menu → Ambient drift → play: drone opens, ~1 change/min,
      filter journey follows the phases
- [ ] Save as Template… → appears under "My templates" and loads
