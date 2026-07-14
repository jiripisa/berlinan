# Phase 18 — Legitimizer Plus

## Goal

The manual's persistent-variation devices and state control (FR-L-4/5/6, FR-UX-5): Metropolix-style accumulators, configurable ratchet policy (+ a live-render ratchet bug fix), snapshot capture/recall with UI slots, and undo over generative actions.

## Deliverables

- Engine:
  - `AccumulatorConfig` (degreeStep ±1–2, wrap 2–16) on `VoiceConfig` (FR-L-4, M §13.5): at every loop boundary the LAST sounding note drifts `+degreeStep` degrees, wrapping after `wrap` cycles; base recaptured after mutation/regeneration; span-guarded. **Deterministic drift is exempt from the verbatim rule** — it is the Metropolix behavior the manual endorses (documented).
  - `Legitimizer.Config.ratchetProbability` (optional, default 0.15; 0 disables) — FR-L-5 policy knob; old JSON stays valid.
  - **Snapshots** (FR-L-6): `LiveEngine.StateSnapshot` (voices + generations + schedule, Codable), `captureState()`, `Action.recallSnapshot` — bound at the next bar; the render window splits at the recall tick, all loops re-align there.
- Runtime:
  - **Bug fix**: `NoteEventConverter` now expands ratchets into retriggers (live and SMF were inconsistent — ratchets only sounded in exports).
  - `Transport.captureState()` (lock-protected mirror of the full engine state, refreshed each wake; available pre-play).
- App: snapshot slot row (6 slots: click = recall, ⌥-click = save) in the performance panel; **Undo (⌘Z)** = automatic state snapshot pushed before each destructive action (regenerate / re-roll / recall), popped via Edit ▸ Undo (FR-UX-5).

## Acceptance criteria

- [x] Accumulator: bar k carries drift (k mod wrap)·degreeStep on the last note; base resets after mutation; Live ≡ Offline with an accumulator project
- [x] Ratchet policy: probability 0 → no ratchets across 50 seeds; 0.5 → ratchets appear; ≤ 1 ratcheted note invariant holds
- [x] Live ratchet expansion: converter emits retriggers matching the SMF writer's math
- [x] Snapshot: recall bound at the next bar — pre-recall bars untouched, post-recall content equals the captured patterns and schedule (transposition reverts)
- [x] Recall is chunk-independent (window sizes don't change the output)
- [x] `swift test` green; goldens untouched
- [ ] Human: save a snapshot mid-jam, mutate away, recall — the bed returns at the next bar; ⌘Z undoes a regenerate

## Out of scope

Snapshot persistence into `.berlinan` documents (phase 19), undo of mute (non-destructive), redo (backlog).
