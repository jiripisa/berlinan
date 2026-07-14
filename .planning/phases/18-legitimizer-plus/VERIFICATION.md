# Phase 18 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Accumulator: bar-k drift (k mod wrap)·step on the last note (register-folded), base reset after mutation | ✅ |
| Live ≡ Offline with an accumulator project (chunked windows) | ✅ |
| Ratchet policy: probability 0 → none across 50 seeds; 0.5 → present; ≤ 1 note invariant | ✅ |
| Config back-compat: {"repeats": 8} decodes (probability optional) | ✅ |
| Snapshot recall: bound at next bar, pre-recall bars untouched, patterns + schedule restored (transposition reverts) | ✅ |
| Recall chunk-independence (7-bar / 611-tick / 1-bar windows) | ✅ |
| StateSnapshot JSON round-trip (persistence-ready for phase 19) | ✅ |
| Live ratchet fix: converter retriggers match SMF math (0/54/60/114 for gate 120 ×2) | ✅ |
| UI: 6 snapshot slots (click recall / ⌥-click save), Undo ⌘Z over regenerate/re-roll/recall; build clean, smoke launch OK | ✅ |
| `swift test` | ✅ 185 tests / 66 suites |
| TDD red → green | ✅ |

## Human checklist (user)

- [ ] Mid-jam: ⌥-click SNAP 1, mutate/regenerate away, click SNAP 1 — the bed returns at the next bar
- [ ] ⌘Z after a regenerate restores the previous pattern

## Notes

- Accumulator drift is deterministic and exempt from the verbatim rule —
  documented as the manual-endorsed Metropolix behavior (M §13.5).
- Process slip caught: one commit briefly landed with a red test (shell
  chaining swallowed the failure); amended to green immediately. Lesson noted.
