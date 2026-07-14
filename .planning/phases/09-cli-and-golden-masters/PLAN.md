# Phase 09 — CLI Render, Velocity Policy & Golden Masters

## Goal

Close M1: `berlinan-cli render project.json --bars N -o out.mid` produces a musically valid, byte-deterministic SMF from a JSON project — generators + phasing + legitimizer-driven mutation + transposition + velocity policy, end to end. Golden-master suite pins the output; the listening protocol (import into Ableton) is the M1 exit gate.

## Deliverables

- `Sources/BerlinanEngine/VelocityPolicy.swift` (FR-MOD-1): accentBoost (default +20), humanizeRange (default ±10). Humanization is keyed on (pattern generation seed, local note position) — **constant across the verbatim repeats of one legitimization cycle, re-rolled only when the pattern mutates** (Law 1).
- `Sources/BerlinanEngine/Project.swift`: `Project` + `VoiceConfig` (id, role, register, referenceC, generator config, channel; optional anchorPolicy / participatesInTransposition / **phaseSteps** — FR-PH-2 in the document format: truncate the generated loop by k 16th steps).
- `Sources/BerlinanEngine/OfflineRenderer.swift`: per-voice segment loop — render one pattern loop at a time via `HarmonyEngine.render`, advance the lifecycle at each boundary, mutate when established (seeds derived from master seed + voice id + generation index), apply velocity policy; SMF markers `HARM:+n` from the transposition schedule; encode via `SMFWriter`.
- `Sources/BerlinanCLI/main.swift`: `render` command (JSON in, .mid out, prints voices/key/BPM/convergence summary).
- `examples/demo_project.json`: 3-voice Berlin School demo (2 phasing bed plucks 16/15 steps, pulsing bass, i→VI→iv→i→v→i schedule, 90 BPM C minor).
- Golden masters: `Tests/.../Goldens/{demo_project.json, demo16.mid}` + byte-compare test; test-target resources wired in Package.swift.

## Acceptance criteria

- [x] VelocityPolicy: accent adds boost (clamped 1–127); humanization within ±range; identical across repeats within a cycle; changes when the pattern seed changes
- [x] Renderer Law-1 behavior: bars 0–3 identical note content (pedal schedule); some seed mutates content from bar 4 on
- [x] phaseSteps −1 → 15-step loop audible in onsets (drift against the bar grid)
- [x] Transposition schedule reflected in rendered pitches (bar 8 bass sits on Ab) and as `HARM:` markers
- [x] Project JSON round-trip + decode from the committed demo file (documents the format)
- [x] Golden master: render(demo, 16 bars) byte-equals the committed `demo16.mid` (FR-UX-1)
- [x] CLI: `render examples/demo_project.json --bars 64 -o build/demo64.mid` succeeds; `--version`/`--help` intact
- [x] `swift test` green
- [x] **Listening protocol**: PROVISIONALLY passed 2026-07-14 — user imported the render, judged it "OK for now" without confident assessment; full musical sign-off deferred to M2 live jamming (better sounds, real-time context). No defects reported.

## Out of scope

Live MIDI (M2), CC lanes in render (M3), arrangement state machine (M5), progression player (M3 — the demo uses a hand-written schedule).
