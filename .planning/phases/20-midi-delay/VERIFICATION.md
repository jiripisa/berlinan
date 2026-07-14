# Phase 20 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| process(): echo times k·division, velocities 100→55→30→17 (decay 0.55), gates ×0.9 chain, tagging | ✅ |
| Inaudible-tail cutoff (< velocity 8); idempotence (echoes are derived data, recomputed from sources) | ✅ |
| Disabled = identity; division ticks 720/480/960 | ✅ |
| Patterns/snapshot echo-free (output boundary only); snapshot exposes the toggle state | ✅ |
| Live ≡ offline with delay enabled (777-tick windows) | ✅ |
| Live toggle: off → echo-free windows, on → echoes return | ✅ |
| SMF with delay > without; goldens untouched (demo carries no delay) | ✅ |
| UI: lane echo button (cyan when on, live + persisted), cheat-sheet warning row | ✅ build clean, smoke launch OK |
| `swift test` | ✅ 201 tests / 71 suites |
| TDD red → green (impl fix: idempotence via source-filtering; test fix: key paths in #expect) | ✅ |

## Human checklist (user)

- [ ] Jam WITHOUT any DAW delay, toggle the echo button on bedPluck1 —
  the "ducka-ducka" appears; toggle off — it stops at the next window
- [ ] Open the Delay Cheat Sheet with the toggle on — the amber warning shows

## Notes

- Echo division defaults to the voice's hint division (bed → dotted 8th).
- Capture includes echoes (capture = what was played) — documented choice.
- Live same-pitch echo overlaps rely on registry/synth handling (SMF path
  clips them); revisit if a synth misbehaves.
