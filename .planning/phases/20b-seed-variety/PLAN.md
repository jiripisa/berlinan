# Phase 20b — Seed Variety (user feedback)

## Goal

Kill the "it plays the same melody every time" problem (user feedback 2026-07-14): determinism stays an ENGINE property (goldens, undo, reproducibility of saved files), but the app layer stops recycling entropy.

## Deliverables

- **Fresh seed at launch**: the built-in demo project gets a random `masterSeed` per app session; opened `.berlinan` documents keep their stored seed ("that Friday jam" stays replayable). `Project.demo` itself is untouched (goldens).
- **🎲 New Seed button** (transport bar, always enabled):
  - stopped → new master seed + transport rebuild;
  - **playing → live universe swap at the next bar**: a fresh engine's `captureState()` is enqueued as `recallSnapshot` (reuses the phase-18 machinery — no engine changes), the project seed updates, and the stopped-transport rebuild picks it up (stale flag).
  - Undo returns to the previous material (undo point pushed before reseed).
- Engine test: cross-seed recall — recalling a fresh engine's state swaps patterns and schedule to the new seed's material.
- Simplification vs the original 3-point proposal: the **session nonce is dropped** — a random per-session master seed already freshens every derived stream (regens, mutations, weighted harmony); documented here.
- Spec: new **FR-UX-6** (seed freshness UX) appended to §3.11.

## Acceptance criteria

- [ ] Cross-seed recall test: post-recall snapshot patterns + schedule equal the fresh engine's (engine-level)
- [ ] Launch seed differs between app sessions (code inspection — nondeterministic by design); opened documents keep their seed
- [ ] 🎲 works stopped and mid-play (next-bar swap), pushes an undo point
- [ ] Goldens + full suite untouched/green
- [ ] Human: play → 🎲 → a genuinely different bed arrives at the next bar; play/stop/play repeats the current universe until 🎲 or relaunch

## Out of scope

Explore-mode re-roll (generator param variation — M5), wider mutation palette (M5).
