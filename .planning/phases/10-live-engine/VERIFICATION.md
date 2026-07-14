# Phase 10 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| No-action equivalence with OfflineRenderer (windows 1000 / 3840 / 777 ticks, 16 bars, full demo project) | ✅ |
| Chunk-independence with actions (transpose + regenerate + blank at fixed request ticks; windows 12 bars / 555 / 1 bar) | ✅ |
| Regenerate binds at first boundary ≥ request tick; new provenance seed; lifecycle restarts | ✅ |
| Blank cycle: one silent loop, verbatim resume, lifecycle frozen during the blank | ✅ |
| Transpose mid-bar → binds next bar (C → G at the boundary) | ✅ |
| Lock prevents auto-mutation indefinitely (seed pre-screened to mutate when unlocked) | ✅ |
| `swift test` | ✅ 114 tests / 36 suites |

## Notes

- Swift exclusivity: per-voice state is copied out, rendered, written back —
  `renderVoice`/`processBoundary` are non-mutating over `self`.
- Blank-cycle semantics decision: an unheard play does not count toward
  legitimization (lifecycle frozen), and a due blank freezes mutation/
  regeneration at that boundary too — deferred requests stay pending.
- Transpose events can never rewrite already-rendered bars (`renderedUpTo`
  clamp) — the live UI can enqueue freely.
- Voice materialization is shared with OfflineRenderer (single build path),
  which is what makes the equivalence test meaningful rather than tautological.
