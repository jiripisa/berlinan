# Phase 15 — Harmony Engines

## Goal

The manual's three harmony mechanisms as first-class modes (FR-H-4/5/6): the progression player with the documented presets, weighted-random transposition, and bass reharmonization — plus the harmony strip in the UI (FR-H-9). All modes materialize deterministically into the existing `TranspositionSchedule`, so the render pipeline stays untouched.

## Deliverables

- Engine `HarmonyModes.swift`:
  - `ProgressionStep` / `Progression` (+ `Progression.presets` from manual §7.1: i-iv-v-i, 1-7-6-5, 1-5-6-7, 1-6-4-7, 1-6-4-1, 7-5-6, 1-♭7-6-♯5, 6-5-4-1; 4 bars/step defaults);
  - `HarmonyModeConfig` (Codable): `.schedule` (legacy) / `.progression(name or custom, loop)` / `.weightedRandom(weights, periodBars)` (+ default "sweet vs dark" weight preset) / `.bassReharm(progression)`;
  - `HarmonyScheduler.resolve(project:)` → `(schedule: TranspositionSchedule, bassOnly: Bool)` — progression unrolled from bar 0 (looped or held), weighted mode drawn deterministically from a named seed stream to a 1024-bar horizon (documented limit).
- Engine integration: `Project.harmony: HarmonyModeConfig?` (nil = legacy `transposition` field — old JSON stays valid, goldens untouched); both renderers use the resolved schedule; **bass-reharm participation mask** (only the bass transposes, uppers frozen) + bass gates stretched to ≥ 1 beat (held roots, M §7.2).
- Snapshot: `scheduleEvents` exposed for the UI.
- App `HarmonyStripView` (FR-H-9): mode label, active progression chips, next-event countdown ("+5 in 3 bars"); mode picker (pedal / legacy schedule / progression presets / weighted / bass reharm) — **enabled while stopped**, rebuilds the transport (documented M3 limitation).

## Acceptance criteria

- [x] Progression unroll: looped steps repeat with correct bars/offsets; non-looped holds the last offset
- [x] Presets match manual §7.1 degree sequences
- [x] Weighted mode: deterministic per master seed; offsets only from the weight table; gaps within periodBars; horizon covered
- [x] Bass reharm: upper-voice pitches identical across event bars while bass follows the progression; bass gates ≥ 1 beat
- [x] Backward compat: 0.2.0 project JSON (no `harmony` field) renders byte-identically (golden master stays green)
- [x] Snapshot exposes schedule events; UI strip shows next event
- [x] `swift test` green; `./build.sh debug` clean; visual check of the strip
- [ ] Human: pick "1-7-6-5" progression, play — the bed walks the degrees every 4 bars; pick bass reharm — bed static, bass re-roots

## Out of scope

Runtime mode switching while playing (M4 polish), tension budget (P3), editable custom progressions UI (only presets + project JSON for now).
