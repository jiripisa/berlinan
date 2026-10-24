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
| 09-cli-and-golden-masters | `render` command, velocity policy, golden-master suite, listening protocol | FR-MOD-1, FR-UX-1, FR-IO-8(engine) | ✅ (listening provisional) |

## M2 — It plays (first usable jam tool) → v0.2.0 ✅ (tagged 2026-07-14)

| Phase | Scope | FR-IDs | Status |
|---|---|---|---|
| 10-live-engine | Pull-model incremental renderer (window seams), engine action queue (lock/regenerate/blank/transpose, quantized binding), OfflineRenderer equivalence | FR-UX-2/4(engine), FR-V-4 | ✅ |
| 11-midi-service | CoreMIDI virtual source, timestamped sends, active-note registry + flush | FR-IO-1/2, FR-IO-8(runtime) | ✅ |
| 12-transport-scheduler | Clock (hostTime↔tick), lookahead loop, MIDI clock master, start/stop | FR-IO-3, NFR-1/2 | ✅ |
| 13-ui-shell | Transport bar, voice lanes (pattern strips, lifecycle dots), per-voice controls, runtime mute/solo | FR-UX-2/4, UI §11.1/11.2 | ✅ |
| 14-capture-export | Rolling capture ring, export last N bars/minutes, degree-button panel | FR-IO-7, FR-IO-6(a), FR-UX-3(partial) | ✅ |

## M3 — Musical depth → v0.3.0 ✅ (tagged 2026-07-14)

| Phase | Scope | FR-IDs | Status |
|---|---|---|---|
| 15-harmony-engines | Progression player (+ manual presets), weighted-random transposition, bass reharmonization, harmony strip UI | FR-H-4/5/6/9 | ✅ |
| 16-generators-4-6 | Drunkard's walk, staged pluck, arpeggiator expansion; gate/pitch decoupling render; duplicate-and-tweak + accent ops | FR-P-1(4–6)/4/5/6 | ✅ |
| 17-modulation | CC LFO lanes (musical time, S&H pre-strike), gate ramps, per-voice CC maps, delay hints + cheat sheet | FR-MOD-2/3/4/5/8 | ✅ |
| 18-legitimizer-plus | Accumulators, ratchet policy, snapshots + slots UI, undo | FR-L-4/5/6, FR-UX-3/5 | ✅ |
| 19-editor-and-documents | Pattern editor (hand edits lock), project settings (key/tempo/meter, bar-quantized), .berlinan documents | FR-P-7, FR-GS-4/5, spec §10 | ✅ |

## M4 — Sync & integration → v1.0.0 ✅ (tagged 2026-07-15)

| Phase | Scope | FR-IDs | Status |
|---|---|---|---|
| 20-midi-delay | Echo-note post-processor (per-voice toggle, live action, cheat-sheet warning) | FR-MOD-7 (+8 interplay) | ✅ |
| 20b-seed-variety | Random session seed, 🎲 New Seed (live next-bar swap), FR-UX-6 | FR-UX-6 (user feedback) | ✅ |
| 21-runtime-changes | Tempo + key changes while playing, bar-quantized (clock re-anchoring; degree-space re-rooting). Runtime METER descoped to backlog (needs a piecewise meter map for bar-indexed harmony; stopped-only stays) | FR-GS-5 (+4 partial) | ✅ |
| 22-clock-slave | MIDI clock in with PLL smoothing; transport follows Start/Stop | FR-IO-4 | ✅ |
| 23-link | Ableton Link — vendored GPLv2+ abl_link, LinkService, .link sync mode (tempo + bar phase) | FR-IO-5 | ✅ |
| 24-learn-dnd-profiles | MIDI learn for macros, drag & drop clips (pattern pool + capture), global synth CC profiles | FR-IO-9/10, FR-MOD-5 | ✅ |
| 25-v1-release | AppIcon, dist smoke (Developer ID + notarized DMG), README, release checklist | NFR-7, workflow §4.5 | ✅ |

## M5 — Arranger & polish → v1.1.0 ✅ (tagged 2026-07-18)

Goal: the app can arrange a whole piece by itself (advisory autopilot, OFF by
default — performance mode stays the first-run experience) and grow melodies.
Full scope (P2 + P3) per user decision 2026-07-17; vertical feature slices.

| Phase | Scope | FR-IDs | Status |
|---|---|---|---|
| 26-arranger-core | Arrangement state machine (Build→Bed→Variation→B-Part→Payoff→Subtract→End), additive build order, engine-level voice activation, manual override (AUTO toggle + advance-now, MIDI-learnable), arranger UI | FR-A-1/2/6 | ✅ |
| 27-density-ambient-bpart | Density macro 0–1 (voices, note caps, mutation rate), ambient mode (~1 change/min, legitimization 16/32), B-part event bundle | FR-A-3/4/5 | ✅ |
| 28-melody-extraction | Velocity-accent melody extraction (curation rules, 2-bar inversion, 4-bar growth), lead promotion | FR-MEL-1/2 | ✅ |
| 29-melody-scheduler | Alternating 4-bar phrase scheduler (never simultaneous), interval tension table + tension-walk scoring, bass-melody mode | FR-MEL-3/4/5 | ✅ |
| 30-harmony-color | Tension budget (flagged quantizer bypass), stochastic chord layer (pad-voice mode), heartbeat kick voice | FR-H-7/8, FR-V-7 | ✅ |
| 31-v1.1-release | CHANGELOG, README refresh, version 1.1.0, tag | — | ✅ |

## M6 — The Long Piece → v1.2.0 ✅ (tagged 2026-07-18)

Goal: trust and dramaturgy — the app SHOWS what it is about to do, and a
piece can carry the genre's long-form arc (drone opening, gliding lines,
timbre journey, returning themes). Scoped 2026-07-18 from the
musician + UX designer review (user-approved).

| Phase | Scope | FR-IDs | Status |
|---|---|---|---|
| 32-horizon-strip | Horizon timeline (upcoming transpositions, mutations-due, arranger countdown + next change, pending binds), arranger voice states on lanes ("waiting" instead of silent-dark) | FR-UX-2 (deepened), FR-A-6 | ✅ |
| 33-drone-slides | Drone generator + arranger intro-on-a-drone; tie/slide steps (legato overlap + portamento hint) as pattern ops and mutation operator | FR-P-1(+), FR-A-2(+), M §5/§9 | ✅ |
| 34-cc-scenes | CC scenes: named CC target sets morphed over bars, driven by arranger phases (Build closed → Payoff open) or manually | FR-MOD-3(+) | ✅ |
| 35-form-templates | Arrangement form presets (classic arc, slow build, ambient plateau) + reprise: bed-entry theme returns at the payoff | FR-A-1(+), FR-L-6(+) | ✅ |
| 36-template-gallery | Startup template picker (Demo / Full ensemble / Ambient), save-as-template | FR-UX (new) | ✅ |
| 37-v1.2-release | CHANGELOG, README, version 1.2.0, tag | — | ✅ |

Deferred to M7: capture browser, runtime meter changes (backlog).

## Interim (post-1.2 user feedback)

| Phase | Scope | FR-IDs | Status |
|---|---|---|---|
| 38-bass-walk-variety | Seeded bassMelody walks (roots stay the harmony's law; seed shapes path/syncopation/dips); regenerate tooltips for deterministic voices | FR-MEL-5(+), FR-UX-6 | ✅ |
| 47-voice-channel | Per-voice MIDI channel picked in the lane ("ch N" menu), live: Transport.setChannel flushes the old channel, carries a pending template load, updates capture export; stored in the project | FR-IO-1 (channel part) | ✅ |
| 46-v1.2.4-release | Version 1.2.4 (templates menu fix, MIDI output device, audit fixes), notarized DMG, website — tagged 2026-10-22 | — | ✅ |
| 45-audit-fixes | Codex audit: flush until scheduled note-off, EXT/Link survive transport rebuild, capture takes on one timeline, document validation, arranged SMF export via LiveEngine | FR-IO-7/8, FR-IO-4/5, FR-A-1, NFR-5 | ✅ |
| 44-midi-output-device | Choose the MIDI output: virtual source or a connected destination (notes/CC/clock), unique-ID persistence, hot-plug safe, flush on switch; transport-bar menu. Also fixed: templates menu disabled while playing (1.2.3 regression of phase 42) | FR-IO-1 (app-wide part) | ✅ |
| 43-v1.2.3-release | Version 1.2.3 (live template load), notarized DMG, website links + screenshot — tagged 2026-10-22 | — | ✅ |
| 42-live-template-load | Templates load while playing: Transport.loadProject swaps the whole project at the next bar (engine origin, clock continuity, tempo adopt in INT); horizon chip | FR-UX-4 | ✅ |
| 41-v1.2.2-release | Version 1.2.2 (voice names + "1 bar" fix), notarized DMG, website links — tagged 2026-10-22 | — | ✅ |
| 40-voice-names | Role-based voice names in the UI (Pluck 1/2, Bass, Pad, Lead, Drone, Heartbeat); horizon events carry voice ids; website routing aligned | FR-UX-7 | ✅ |
| 39-v1.2.1-release | Version 1.2.1, CHANGELOG, notarized DMG (dist pipeline aligned with MDPre) — tagged 2026-10-21 | — | ✅ |
