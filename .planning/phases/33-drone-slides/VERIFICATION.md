# Phase 33 — Drone Intro & Slides — Verification

Date: 2026-07-18 · Branch: feature/33-drone-slides · Suite: **295 tests / 103 suites green**

## Automated results

| Criterion | Result |
|---|---|
| Drone generator: root + fifth, gates = loop length, quiet, deterministic | ✅ |
| Build order: drone first when present; demo order unchanged | ✅ |
| applyTies: gate reaches next onset + overlap; wrap tie covers loop end → first onset; untied notes untouched | ✅ |
| Rendered tied note overlaps the following onset (live), offline applies the same op | ✅ |
| slides OFF → whole suite incl. golden masters byte-identical (mutation stream untouched); slides ON → a bass tie appears within 30 seeds × 24 bars | ✅ |
| App builds: Slides toggle in project settings (stopped-only), glide hints in the Delay Cheat Sheet | ✅ |

## Design notes

- `PatternNote.tie` is optional (`Bool?`) so pre-1.2 documents decode
  unchanged; the slides mutation op sits AFTER all existing rng draws and
  runs only when `Project.slidesEnabled` — old projects render
  byte-identically (the golden-master suite proves it).
- Ties resolve at render (`applyTies` beside the density cap, live and
  offline) — stored patterns keep their short gates, so toggling slides off
  later never leaves stretched gates behind.
- Same-pitch tie overlaps are clipped by the existing note-registry rule
  (no glide, but no hang) — documented behavior.

## Human checklist (pending)

- [ ] Mono bass + portamento ≈ 80 ms: mutations start sliding within a few
      cycles (slides on)
- [ ] AUTO with a drone voice: the piece opens on the drone alone
- [ ] Cheat sheet shows the glide row for bass/lead when slides are on

## Backlog note

Tie editing in the pattern editor (hand-placed slides) — deferred.
