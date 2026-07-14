# Phase 06 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Lifecycle countdown, established stability | ✅ |
| Fresh pattern = exactly 4 total plays before mutable (Law 1) | ✅ |
| `mutate` identity for locked / still-repeating patterns | ✅ |
| Determinism per seed; effective for some seed in 1…10 | ✅ |
| Post-mutation invariants, 50 seeds, bed + bass (root anchor, span, accidentals, in-loop, ≤1 ratchet) | ✅ |
| Lifecycle reset to `.repeating(remaining: N)`; custom N honored | ✅ |
| Loop-stability: mutated pattern renders identically every repeat (FR-L-3) | ✅ |
| TDD red → green | ✅ |
| `swift test` | ✅ 73 tests / 24 suites |

## Notes

- **Semantics fix caught by TDD**: the first red run revealed an off-by-one in
  the lifecycle counter (fresh pattern became mutable after 3 plays, not 4).
  Resolved by defining `remaining` = total verbatim plays left before mutable;
  fresh and post-mutation state both start at N (default 4). Pattern's default
  lifecycle updated accordingly.
- Ratchets clear on every mutation and may re-arm on one note only — the
  "intermittent, never persistent" behavior FR-L-5 will build on.
- FR-L-3 is enforced structurally (no chance field exists) and behaviorally
  (loop-stability test: randomness binds at mutation, never at render).
