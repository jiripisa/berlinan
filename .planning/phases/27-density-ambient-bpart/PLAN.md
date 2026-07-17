# Phase 27 — Density, Ambient Mode, B-Part Bundle

## Goal

The arranger grows dynamics controls: a density macro that scales how much
music happens (FR-A-3), an ambient mode that stretches the change clock to
~1 event/minute with 16/32-play legitimization (FR-A-4), and the manual's S4
move — one trigger that starts a progression, swaps the bass, and optionally
drops the bed (FR-A-5).

## Design decisions

- **Density (0–1, default 1)** lives in the engine as a bar-quantized live
  value (`setDensity` action; `Project.density` seeds it). Its note effect is
  a **deterministic per-loop cap**: notes ranked accents-first, then
  beat-aligned, then by position; keep `ceil(count·d)`. No dice — Law 1
  holds. Density 1 is the identity (zero behavior change for 1.0 docs).
- **Arranger × density**: payoff raises density to 1.0; each subtract step
  scales it ×0.85; variation chooses its op by density (low → blank cycles,
  high → mutations). SM emits a `.setDensity` directive.
- **Ambient (FR-A-4)** is an `ArrangementConfig` flag: SM periods become
  `max(8, bars-per-minute at project BPM)` (no rng), and the engine scales
  legitimization repeats ×4 (default 4 → 16) while ambient — slow world,
  patterns earn much longer.
- **B-part (FR-A-5)**: `BPartConfig { progression preset, dropBed }`. The
  SM's bPart phase (or the manual "B" button → `fireBPart` action) emits one
  bundle directive; the engine appends the preset's degree walk to the
  transposition schedule from the fire bar, regenerates the bass at its next
  loop boundary, and blank-cycles bedPluck2 for one loop when `dropBed`.

## Deliverables

- Engine: density value + action + render cap; ambient legit scaling;
  `fireBPart` action + bundle application; SM: ambient periods, density
  directives, real bPart phase behavior (replaces the phase-26 placeholder).
- Runtime: nothing new (actions flow through the generic queue).
- UI: density slider + AMBIENT toggle in the ARR cluster; "B" button
  (MIDI-learnable macro `fireBPart`).
- Docs: this plan + verification.

## Acceptance criteria

- [ ] Density 1 → byte-identical output (existing suite green untouched)
- [ ] Density 0.4 → per-loop note count ≤ ceil(0.4·n); accents survive
      first; deterministic and chunk-safe; binds at the next bar
- [ ] Ambient: SM periods = bars/minute (≥ 8); repeats ×4 while ambient;
      switchable live at a bar boundary
- [ ] B-part fire: schedule gains the progression walk from the fire bar,
      bass regenerates, bed drops when configured; manual button ==
      SM-triggered bundle; MIDI-learnable
- [ ] Live == offline with all three features on; chunk-independence holds
- [ ] Human: B move audibly lands as one event; ambient jam breathes at
      ~1 change/min

## Out of scope

Melody engine (28/29), tension budget/chord layer/kick (30), density curves
over time (Follow-Actions automation — backlog).
