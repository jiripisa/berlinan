# Phase 20b — Verification

Date: 2026-07-15

| Criterion | Result |
|---|---|
| Cross-seed recall: post-recall patterns + provenance seeds + schedule equal the fresh engine's; differ from the old universe | ✅ (engine test) |
| Launch seed: built-in project randomized per session; `.berlinan` documents keep their stored seed (applyProject path untouched) | ✅ (code inspection — nondeterministic by design) |
| 🎲 New Seed: stopped → rebuild; playing → next-bar universe swap via recallSnapshot + stale rebuild on stop; undo point pushed | ✅ wiring |
| Goldens + full suite | ✅ 202 tests / 72 suites |
| Build clean, smoke launch | ✅ |
| Spec: FR-UX-6 appended (§3.11) | ✅ |

## Human checklist (user)

- [ ] Play → press 🎲 (or N) — a genuinely different bed arrives at the next bar; ⌘Z brings the old one back
- [ ] Quit + relaunch — the demo jam differs from the last session
- [ ] Save a project, reopen it — THAT jam is unchanged (stored seed)

## Notes

- Session-nonce idea dropped as redundant: a per-session random master seed
  freshens every derived stream (regens, mutations, weighted harmony).
- After a live reseed, undo restores the previous MATERIAL; once stopped, the
  transport rebuilds on the new seed (undo stack does not survive the rebuild)
  — acceptable, documented.
