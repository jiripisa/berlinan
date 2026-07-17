# Phase 32 — Horizon Strip — Verification

Date: 2026-07-18 · Branch: feature/32-horizon-strip · Suite: **290 tests / 101 suites green**

## Automated results

| Criterion | Result |
|---|---|
| upcomingEvents: pending key + density binds listed with next-bar tick and kinds; cleared after consumption | ✅ |
| Events sorted by bind tick (tension before density across bars) | ✅ |
| ArrangementStatus.barsUntilChange counts down one per bar | ✅ |
| VoiceSnapshot.active: held-back voice says so pre-build, all true after | ✅ |
| VoiceSnapshot.pendingRequest: blank surfaces with its bind tick, clears after | ✅ |
| Suite untouched by the read-only surface | ✅ (290/101) |
| App builds: HORIZON strip (arranger countdown + event chips + nearest-mutation), WAITS badges on held-back lanes, manual Voice On/Off in the context menu | ✅ |

## Design notes

- Pure exposure — zero new engine mechanics; the strip narrates queues the
  engine already kept (pendingChanges, pendingArrangementEnables,
  pendingAdvances, SM period counter, per-voice request slots).
- Mutation horizon computed UI-side from lifecycle × loop length (no engine
  duplication).
- The WAITS badge closes an honesty gap from phase 26: an arranger-held
  voice looked identical to a broken one.

## Human checklist (pending)

- [ ] AUTO jam: the strip narrates joins/mutations/changes before they land
- [ ] Manual jam: degree/density/B/T presses appear as chips until they bind
- [ ] WAITS badges read clearly; Voice On rescues a dropped bed after a
      manual B-part
