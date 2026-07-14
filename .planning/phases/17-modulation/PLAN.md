# Phase 17 — Modulation Output

## Goal

The sequencer emits more than notes (M §11): CC LFO lanes in musical time with S&H pre-strike timing (FR-MOD-3), stateless delta-filtered emission (FR-MOD-4), per-voice CC maps (FR-MOD-5), gate-length ramps (FR-MOD-2), and delay hints + the Delay Cheat Sheet window (FR-MOD-8). **MIDI delay (FR-MOD-7) deferred to M4 by user decision.**

## Deliverables

- Engine `Modulation.swift`:
  - `LFOShape` (sine/triangle/sawUp/sawDown/square/sampleHold), `CCLane` (target name, shape, `cycleBars` 0.5–64 — musical time per M §11.2, depth, center, phase, preStrikeTicks), `GateRampProgram` (arcBars + per-bar gate multipliers, M §11.4), `RenderedCC`.
  - `ModulationEngine.render(lanes:ccMap:in:meter:seed:)` → `[RenderedCC]`:
    - continuous shapes sampled on the 1/96-note grid (40 ticks), **stateless delta filter** (emit iff value differs from the previous grid point, always emit at t = 0) — chunk-safe by construction;
    - `sampleHold`: new deterministic value per 8th-note step, emitted `preStrikeTicks` before the step onset (M §11.3);
    - lanes with targets missing from the CC map are skipped.
- `VoiceConfig` gains optional `ccLanes`, `ccMap`, `gateRamp` (old JSON valid).
- Renderer integration: gate ramp multiplies note gates by bar index; `OfflineRenderer` merges CC into SMF tracks (`SMFTrack.ccs` + 0xB0 emission); `LiveEngine.renderCC(range:)`.
- `DelayHint.swift` (FR-MOD-8): role → division (bed = dotted 8th, bass = 8th, pad/lead = quarter), live ms from `(60000/BPM)` math, feedback/wet 50%, ping-pong, filtered repeats.
- Track names extended with the delay hint (**goldens regenerated** — justified: FR-MOD-8b metadata).
- Demo project: one slow sine lane on bedPluck1 (filter CC74, 16-bar cycle) so the feature is audible.
- Runtime: `NoteEventConverter.ccEvents` + Transport sends CC alongside notes (capture stays notes-only — documented).
- App: **Delay Cheat Sheet** panel (Window menu) — per voice division/ms/settings at the project tempo, copyable.

## Acceptance criteria

- [ ] Sine lane: correct values at known phases, 0–127 clamp, 40-tick grid, delta-filtered (constant lane emits only t=0)
- [ ] Chunk-safety: renderCC windows chained == whole range
- [ ] S&H: 8th-note steps, pre-strike offset, deterministic per seed, bounded by depth/center
- [ ] Gate ramp: profile multipliers audible in note gates per bar
- [ ] CC map: named target resolves; unmapped target → lane skipped
- [ ] SMF: CC events land on voice tracks; goldens regenerated once with justification
- [ ] DelayHint: dotted 8th @ 90 BPM = 500 ms; 8th = 333 ms; quarter = 667 ms
- [ ] Runtime loopback: a project with a lane produces 0xB0 words live
- [ ] `swift test` green; Delay Cheat Sheet renders (visual check)

## Out of scope

MIDI delay echo notes (FR-MOD-7 → M4), CC lane editor UI (M4; lanes come from project JSON + demo), LFO-on-LFO (FR-MOD-6, P3), CC in capture export (M4).
