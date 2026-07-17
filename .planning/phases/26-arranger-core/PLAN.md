# Phase 26 — Arranger Core

## Goal

The arrangement state machine (FR-A-1): an advisory autopilot that walks a
piece through `Build → Bed → Variation → B-Part → Payoff → Subtract → End`,
orchestrating only actions the engine already knows (voice activation,
mutations, blank cycles, progression start, stop). OFF by default — enabling
AUTO is the user's move (FR-A-6); performance mode stays untouched.

## Design decisions (from brainstorming, 2026-07-17)

- `ArrangementSM` lives in **BerlinanEngine**: ticks at bar boundaries inside
  the render path, draws its random change periods (8–16 bars) from a
  SplitMix64 stream derived as `("arrangement")` off the master seed — live
  and offline renders stay byte-equivalent, golden-master testable.
- Voice activation is a new **engine-level** per-voice flag (deterministic,
  affects export). Runtime mute stays a separate post-render gate.
- Play with AUTO enabled starts in `build` with only the first build-order
  voice active; enabling AUTO mid-play adopts the current state (all voices
  already active → enter `bed`).
- `bPart` fires the full B-bundle only from phase 27; in this phase it
  behaves like `variation` (documented placeholder). `payoff` re-adds all
  voices; the density raise arrives with FR-A-3 in phase 27.
- `ending` thins the last voice's pattern to roots and requests a transport
  stop at the next bar boundary (engine surfaces the stop bar; the Runtime
  obeys it).

## Deliverables

- Engine `ArrangementSM` (pure, unit-tested): `ArrangementPhase` enum,
  `ArrangementConfig` (enabled=false default, buildOrder derived from roles
  bedPluck1 → bedPluck2 → pad → bass → lead → rest, changePeriodBars 8...16),
  per-bar tick + `advance()` per spec §7.8.
- `Project.arrangement: ArrangementConfig?` (nil = disabled; 1.0 documents
  stay valid).
- `LiveEngine` integration: SM consulted at every bar boundary; emits
  activate/deactivate, mutation nudges (round-robin over unlocked voices),
  blank cycles, root-thinning + stop request. All bar-quantized.
- New actions: `setArrangementEnabled(Bool)` (immediate), `advancePhase`
  (binds at next bar). ControlMap macro `advancePhase` (MIDI-learnable).
- Offline parity: `OfflineRenderer` runs the same SM — live/offline
  equivalence holds with arrangement enabled.
- UI: arranger strip (phase name, bars-in-phase, AUTO toggle, "advance now"
  button); UIState mirror fields.

## Acceptance criteria

- [ ] SM unit: fixed seed → deterministic phase timeline; periods always in
      8...16 bars; build activates voices in build order; subtract reverses
      down to one; ending thins to roots and requests stop at a bar boundary
- [ ] Enabling mid-play with all voices active enters `bed` (no re-intro)
- [ ] `advancePhase` fires the transition at the next bar
- [ ] Live render == offline render with arrangement enabled (equivalence)
- [ ] Arrangement disabled/nil → whole existing suite green, zero behavior
      change; new projects default to performance mode
- [ ] UI shows phase + bars count; AUTO off on launch; macro learnable
- [ ] Human: AUTO from stopped → voices enter one by one, piece evolves,
      subtracts, and ends on its own

## Out of scope

Density macro + payoff density raise (27), ambient mode (27), B-part bundle
wiring (27), melody engine (28/29), tension budget & chord layer & kick (30).
