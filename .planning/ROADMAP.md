# Berlinan — Roadmap

Milestones mirror `generative_sequencer_spec.md` §13. Status: ☐ pending · ◐ in progress · ✅ done.

## M1 — Headless engine (`BerlinanEngine` + CLI render)

Goal: `swift run berlinan-cli render project.json --bars 64 -o out.mid` produces a musically valid SMF. No UI beyond a skeleton window, no CoreMIDI.

| Phase | Scope | FR-IDs | Status |
|---|---|---|---|
| 01-package-skeleton | SPM package (3 targets), build.sh/run.sh (Sampio pipeline), Resources, DesignTokens, smoke tests | — | ✅ |
| 02-musical-state-and-scale | Tick/Meter/Scale/Key/DegreePitch, resolve + octave fold + chromatic quantize, SplitMix64 | FR-GS-1/2/6, FR-V-3 | ✅ |
| 03-pattern-model | Pattern/PatternNote/GateStep, Voice, loop cursors, degree-space invariants | FR-V-1/5, FR-P-2/3 | ✅ |
| 04-generators-1-3 | Seed procedure, High/Mid/Low, Pulsing 16th bass | FR-P-1(1–3) | ✅ |
| 05-phasing-and-lcm | Independent loop lengths, rotation, convergence LCM | FR-PH-1/2/4 | ✅ |
| 06-legitimizer | Lifecycle, mutation operators, no-per-step-chance guarantee | FR-L-1/2/3 | ✅ |
| 07-harmony-transposition | Global diatonic transposition, bar quantization | FR-H-1/2/3 | ✅ |
| 08-smf-export | SMF type-1 writer (960 PPQN, tempo/meter/markers, CC) | FR-IO-6 | ✅ |
| 09-cli-and-golden-masters | `render` command, velocity policy, golden-master suite, listening protocol | FR-MOD-1, FR-UX-1, FR-IO-8(engine) | ◐ (listening pending) |

## M2 — It plays (first usable jam tool)

Virtual MIDI out, clock master, transport, voice lanes UI, capture buffer + export, lock/regenerate/blank/mute, degree buttons. → v0.2.0

## M3 — Musical depth

Remaining generators, gate/pitch decoupling, accents & mutations complete, progressions + weighted harmony + bass reharm, CC lanes + gate ramps, MIDI delay + delay hints, pattern editor, snapshots, undo.

## M4 — Sync & integration

Clock slave, Ableton Link, MIDI learn, drag & drop clips, synth profiles, meter changes. → v1.0

## M5 — Arranger & polish

Arrangement state machine, ambient mode, melody engine, tension budget, chord layer.
