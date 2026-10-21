# Berlin School Generative Sequencer — Software Specification

**Native macOS application. Requirements, architecture, and data model.**

| | |
|---|---|
| Status | Draft v1.0 |
| Platform | macOS 14+ (Apple Silicon + Intel), Swift |
| Related documents | `berlin_school_manual.md` (style theory — the normative musical reference), `basic_concept.md` (product vision), `design_language.md` (visual design tokens), `development_workflow.md` (build, distribution & methodology) |
| Working name | **Berlinan** |

Citations of the form **[M §5.2]** refer to sections of `berlin_school_manual.md`. Every musical rule in this spec is traceable to the manual; where this spec makes an engineering choice not dictated by the manual, it is marked **[design decision]**.

---

## Table of Contents

1. [Purpose, Scope, Non-Goals](#1-purpose-scope-non-goals)
2. [Glossary](#2-glossary)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [System Architecture](#5-system-architecture)
6. [Core Data Model](#6-core-data-model)
7. [Engine Algorithms](#7-engine-algorithms)
8. [Timing, Transport & Synchronization](#8-timing-transport--synchronization)
9. [MIDI I/O & Export](#9-midi-io--export)
10. [Persistence & Project Format](#10-persistence--project-format)
11. [User Interface Specification](#11-user-interface-specification)
12. [Testing Strategy](#12-testing-strategy)
13. [Roadmap & Milestones](#13-roadmap--milestones)
14. [Traceability Matrix (Manual → Requirements)](#14-traceability-matrix-manual--requirements)
15. [Open Questions & Risks](#15-open-questions--risks)

---

## 1. Purpose, Scope, Non-Goals

### 1.1 Purpose

A native macOS application that **performs Berlin School music as a stream of MIDI events**: it maintains a pool of short, rule-generated patterns across 4–7 voices, phases them against each other, transposes them harmonically over time, and emits the result as timestamped MIDI (live, over virtual ports) and as Standard MIDI Files — so the output can be recorded into Ableton Live or any hardware/software sequencer.

The app is a **state machine that plays, with a human in the loop** — not a "render a song" batch generator [basic_concept.md, Core Concept].

### 1.2 Scope

- Generation of note data, velocity, gate lengths, and CC automation for all voices.
- Real-time playback over CoreMIDI virtual ports with MIDI clock (master and slave) and, in a later phase, Ableton Link.
- Export: multitrack SMF, per-pattern MIDI clips (drag & drop), rolling performance capture.
- Producer controls: seeds, per-voice locking, regeneration, performance macros, MIDI learn.

### 1.3 Non-goals

- **No audio synthesis.** The app produces MIDI only. (A built-in preview synth is an explicitly deferred nice-to-have; see §15.)
- **No audio recording/rendering.**
- No notation display, no general-purpose DAW features (no audio tracks, no plugin hosting).
- No iOS version in v1 (architecture must not preclude it — see §5.1).
- `.als` (Ableton Live Set) export is out of scope for v1 (§13, backlog).

---

## 2. Glossary

| Term | Definition |
|---|---|
| **Voice** | One monophonic-by-convention output lane with a fixed musical role (bed pluck, bass, pad, lead, drone, rhythm) and its own MIDI route [M §10.1]. |
| **Pattern** | A short repeating figure owned by a voice: notes with position, degree-based pitch, velocity, gate [M §5]. |
| **Bed** | The composite texture formed by ≥2 phasing patterns [M §6.7]. |
| **Phasing** | Running patterns of unequal loop lengths (or rotated start points) simultaneously [M §6]. |
| **Legitimization** | The rule that newly generated material repeats verbatim N times (default 4) before the next mutation [M Law 1]. |
| **Mutation** | A constrained random edit of an existing pattern (pitch shift folded to scale, accent move, note drop…) [M §13.1, §5.7]. |
| **Scale quantizer** | The mandatory final pitch stage folding any pitch into the working key/mode [M Law 2]. |
| **Transposition event** | A global diatonic transposition of all (participating) voices, expressed as a scale degree offset [M §7.1]. |
| **Bass reharmonization** | Changing only the bass root under static upper layers [M §7.2]. |
| **Tension budget** | The explicit allowance of 1–2 out-of-key notes per piece [M §4.4]. |
| **Blank cycle** | One loop iteration in which a voice is intentionally silent [M §13.1]. |
| **Tick** | Internal time unit; 960 PPQN (pulses per quarter note) **[design decision]**. |
| **Engine** | The deterministic, UI-free Swift package that computes all musical events (§5). |

---

## 3. Functional Requirements

Requirements are numbered `FR-<group>-<n>`. Priority: **P1** = MVP (Milestone M1–M2), **P2** = v1.0, **P3** = post-1.0.

### 3.1 Global musical state (GS)

- **FR-GS-1 (P1)** — The project has exactly one global musical state: key root (pitch class), mode, tempo (BPM, float), meter, and a master seed. Defaults: C, natural minor, 90 BPM, 4/4 [M §16].
- **FR-GS-2 (P1)** — Supported modes at minimum: natural minor, Dorian, Phrygian, Mixolydian, Lydian, Lydian dominant, harmonic minor, minor pentatonic, Locrian, major — each defined as a list of semitone offsets from the root [M §4.1, §4.2]. The mode list must be data-driven (user-definable custom scales, P3).
- **FR-GS-3 (P1)** — **Swing is not a parameter.** The engine has no swing facility [M §3.3].
- **FR-GS-4 (P2)** — Meter is changeable at runtime; a meter change takes effect **only at the next bar boundary** [M §3.2, §9.3]. Supported meters: 4/4, 3/4, 5/4, 6/8, 7/8, 5/8, with the manual's accent groupings available as presets (e.g. 7/8 = 4+3 | 3+4 | 2+2+3; 5/4 = 3+3+4 | 6+4) [M §9.3].
- **FR-GS-5 (P2)** — Tempo and key are changeable at runtime; changes quantize to the bar. Key changes re-quantize all sounding state at the boundary (no hanging out-of-key notes — see FR-IO-8).
- **FR-GS-6 (P1)** — Every pitch produced by any module passes through the **scale quantizer as the final pitch stage**; there is no code path that emits an unquantized note. The only exception is a note explicitly flagged by the tension-budget mechanism (FR-H-6) [M Law 2].

### 3.2 Voices (V)

- **FR-V-1 (P1)** — A project contains 1–8 voices. Each voice has: a role (`bedPluck1`, `bedPluck2`, `bass`, `pad`, `lead`, `drone`, `rhythm`, `aux`), a register window, a MIDI route (port + channel), a CC map, a generator configuration, and an independent loop length [M §10.1].
- **FR-V-2 (P1)** — Default project template: bedPluck1, bedPluck2, bass (MVP); v1.0 template adds pad, lead, drone [M §10.1].
- **FR-V-3 (P1)** — **Register window + octave fold**: each voice has `lowNote`/`highNote`; any note outside the window is folded by octaves into the window (never clamped, never dropped) [M §5.1].
- **FR-V-4 (P1)** — Per-voice controls: mute, solo, **lock** (freeze pattern against all mutation/regeneration), **regenerate** (new pattern from a new seed, entering the legitimization cycle), **blank cycle** (silence for exactly one loop iteration, re-entering automatically) [M §13.1; basic_concept §Producer-Facing Controls].
- **FR-V-5 (P1)** — The **bass anchor rule**: while phasing is active, the bass voice guarantees onsets on beats 1 and 3 (configurable to "beat 1 only" and "off") [M §6.6].
- **FR-V-6 (P2)** — Per-voice note-density parameter (sparseness), enforcing the manual's sparsity law as a hard cap of notes per bar for that role [M Law 3].
- **FR-V-7 (P3)** — Optional rhythm voice emitting a quarter-note "heartbeat" kick on a dedicated channel/note [M §9.2].

### 3.3 Pattern generation (P)

- **FR-P-1 (P1)** — Pattern generators are pluggable per voice. v1 generators:
  1. **Seed procedure** (roots on beats → mutations) [M §5.2] — default for bed voices.
  2. **High/Mid/Low contour** [M §5.3].
  3. **Pulsing 16th bassline** [M §5.5] — default alternative for bass.
  4. **Drunkard's walk** (with harvest) [M §13.2] — P2.
  5. **Staged 16th pluck build** [M §5.6] — P2.
  6. **Arpeggiator expansion** (held chord → arp pattern; down/up/random, octave range, 2:1 rate pairs, retrigger-on-note) [M §5.9] — P2.
- **FR-P-2 (P1)** — All generators respect the pattern invariants and MUST be property-tested against them (§12): first sounding note = root; all pitches in scale; span ≤ 2 octaves before register fold; default gates short (40–60%); pattern may start with a rest [M §5.1, §5.4].
- **FR-P-3 (P1)** — Pattern lengths are freely settable in steps/beats/bars, including non-power-of-two lengths (15 steps, 7 beats, 3.5 bars, 19 steps…) [M §6.1].
- **FR-P-4 (P2)** — **Gate/pitch decoupling**: a pattern may define its pitch cycle and gate cycle with independent lengths (e.g. pitch 8 / gate 6); the engine renders the combination and reports the LCM period [M §6.4].
- **FR-P-5 (P2)** — **Accent model**: each pattern carries an accent mask; accent count per bar (1–3) is a generator parameter; accents map to velocity (FR-MOD-1). Variation operator "keep notes, move accents" must exist as a one-click/one-call mutation [M §5.8].
- **FR-P-6 (P2)** — **Duplicate-and-tweak growth**: extend a 1-bar pattern to 4/8 bars, mutating only repetitions 3–4 [M §5.7].
- **FR-P-7 (P2)** — Patterns are editable by hand in a step/piano-roll editor; hand edits mark the pattern `locked` by default (producer curation) [basic_concept].

### 3.4 Phasing (PH)

- **FR-PH-1 (P1)** — Voices run independent loop lengths against a shared bar grid; the engine supports simultaneous loops of any lengths from FR-P-3 [M §6.1].
- **FR-PH-2 (P1)** — One-action phasing setup: "phase this voice" duplicates a pattern to another voice (or itself) with a chosen length delta (−1 step, −2 steps, −1 bar, +1 beat, …) [M §6.1].
- **FR-PH-3 (P2)** — Start-point rotation as a non-destructive per-pattern offset (rotate by k steps) [M §6.2].
- **FR-PH-4 (P1)** — The engine computes and exposes the **convergence period** (LCM of all active loop lengths, in bars and minutes at current tempo); the UI displays it and a "distance to convergence" indicator [M §6.1; basic_concept §4].
- **FR-PH-5 (P3)** — Chord-tone polymeter preset: generate 3 patterns from root/3rd/5th with lengths 16/24/19 [M §6.3].

### 3.5 Legitimization & mutation (L)

- **FR-L-1 (P1)** — Pattern lifecycle: `generated → repeating(n) → established`. A pattern plays **N verbatim repetitions (default 4, configurable 2–32)** before it is eligible for mutation or regeneration [M Law 1, §13.1].
- **FR-L-2 (P1)** — Mutation operators (constrained, always scale-folded): pitch shift (default 30% of notes, up to ±12 semitones, folded) [M §13.1]; move a backbeat note in time ±½ beat [M §5.3]; octave displacement of a note [M §13.6]; drop/restore a note; move accents (FR-P-5); truncate/extend loop length [M §6.1].
- **FR-L-3 (P1)** — **Prohibition**: the engine offers no per-step "chance this note plays" parameter. Randomness persists across repeats: an applied mutation stays applied for its whole legitimization cycle [M Law 1, corollary].
- **FR-L-4 (P2)** — **Accumulator**: an optional per-voice slow drift (per-cycle incremental transposition of one designated step, Metropolix-style), scale-folded [M §13.5].
- **FR-L-5 (P2)** — **Intermittent ratchet**: a mutation that adds a 2–3× retrigger to one step for the duration of one legitimization cycle (not a permanent per-step probability) [M §13.5].
- **FR-L-6 (P1)** — **Snapshots**: the complete generative state (all patterns, seeds, lifecycle counters, harmony state) can be captured and recalled instantly; recall quantizes to the bar [M §13.5; basic_concept].

### 3.6 Harmony (H)

- **FR-H-1 (P1)** — Default harmonic state: pedal on the root (transposition 0) [M §7].
- **FR-H-2 (P1)** — **Global diatonic transposition**: a single degree-offset (−7…+7 diatonic steps, ±2 octaves chromatic offset optional) applied to all participating voices, then scale-quantized per voice. Per-voice opt-out flag (e.g. lead stays put while the bed transposes) [M §7.1, M §13.6].
- **FR-H-3 (P1)** — Transposition changes quantize to the next bar (configurable to 2/4/8 bars).
- **FR-H-4 (P2)** — **Progression player**: a progression = ordered list of (degree, duration-in-bars). Ships with manual presets: 1-4-5-1, 1-7-6-5, 1-5-6-7, 1-6-4-7, 1-6-4-1, 7-5-6, 1-♭7-6-♯5, 6-5-4-1 [M §7.1]. Progressions can be user-defined and looped.
- **FR-H-5 (P2)** — **Weighted-random transposition mode**: targets drawn from a weight table over degrees 1–7 (editable; ships with "sweet vs dark" defaults), one event per configurable period (default 8–16 bars) [M §7.1, §13.6].
- **FR-H-6 (P2)** — **Bass reharmonization mode**: upper voices static; only the bass root moves (its own progression/weight table); bass notes lengthen automatically in this mode (held roots, no runs) [M §7.2].
- **FR-H-7 (P3)** — **Tension budget**: a per-project counter (default 2) of out-of-key events; spending one inserts a flagged non-diatonic note (default: minor 2nd against the root, sustained) that bypasses the scale quantizer exactly once [M §4.4].
- **FR-H-8 (P3)** — **Stochastic chord layer** (the §13.3 generator): a pad-voice mode producing one chord per ~7 bars via the 80%/+1..12/quantize/stack(+4,+7,+12)/re-quantize algorithm [M §13.3].
- **FR-H-9 (P2)** — A **harmony timeline strip** shows current degree, next scheduled event, and the active progression (§11).

### 3.7 Melody (MEL) — all P2/P3

- **FR-MEL-1 (P2)** — **Velocity-accent melody extraction** on any running pattern: mute-all → raise 3–4 accents → curated per the manual's rules (prefer on-beat, separate adjacent accents, avoid root+5th-only, resolve tension notes down) → 2-bar accent inversion → 4-bar single-change growth [M §8.1].
- **FR-MEL-2 (P3)** — Lead promotion: copy an accent-extracted clip to the lead voice, delete quiet notes, lengthen survivors to legato [M §8.1 step 7].
- **FR-MEL-3 (P3)** — **Alternating melody scheduler**: two voices assigned complementary 4-bar phrase slots; the engine guarantees they never sound simultaneously; each voice gets a different delay-hint metadata tag (see FR-IO-9) [M §8.3].
- **FR-MEL-4 (P3)** — Melody note-choice scoring uses the **interval tension table** [M §4.4] against currently sounding notes; the tension-walk pattern (tense → release → release) is the default contour policy [M §8.2].
- **FR-MEL-5 (P3)** — Bass-melody mode: roots of the active progression + scale passing tones between them [M §8.4].

### 3.8 Modulation output (MOD)

- **FR-MOD-1 (P1)** — **Velocity semantics**: baseline velocity per voice (default 100); accents = baseline + accentBoost (default +20); optional humanization = uniform random within ±range (default ±10, i.e. the manual's 80–100 window) applied once per legitimization cycle, not per repeat [M §11.1, Law 1].
- **FR-MOD-2 (P2)** — **Gate-length ramp lane**: per-voice program that scales gate lengths over a multi-bar arc (e.g. 8-bar ramp short→legato→short) [M §11.4].
- **FR-MOD-3 (P2)** — **CC LFO lanes**: per voice, up to 4 lanes; each lane = target CC number, shape (sine/tri/saw/square/S&H), **cycle length in musical time (bars: 0.5…64)**, depth, center, phase. S&H steps are emitted **a configurable offset before the step onset** (default 10 ticks) so value changes land pre-strike [M §11.2, §11.3, §13.4].
- **FR-MOD-4 (P2)** — CC emission rate limiting: ≤ one CC value per lane per tick-quantum (default 1/96 note) and only on value change (delta filtering), to avoid MIDI flooding.
- **FR-MOD-5 (P2)** — Per-voice **CC map**: named targets ("filter", "timbre", "shape", "pan") → CC numbers, savable as synth profiles (e.g. "Microfreak: shape=CC12, timbre=CC13") [M §13.4; basic_concept §8].
- **FR-MOD-6 (P3)** — LFO-on-LFO: a lane's rate modulated by another slow source [M §11.2].
- **FR-MOD-7 (P2)** — **MIDI delay (echo notes), per voice, toggleable on/off**: an optional post-processing stage that emits each note's echoes as real MIDI notes, emulating the style's signature audio delay [M §9.1] for setups without an audio delay effect. Parameters: division (default dotted-8th; also 8th, quarter), repeat count (default 3, range 1–8), velocity decay per repeat (default ×0.55, emulating ~50% feedback), gate scaling per repeat (default ×0.9). Rules: echo notes are folded into the voice's register window, tagged internally as echoes (they never feed back into generators, mutation, or the capture-driven melody tools — only into MIDI output and export), and are cancelled with proper Note Offs when the source voice is muted or the toggle is switched off (bar-quantized). Default: **off** (an audio delay in the DAW/synth remains the recommended path).
- **FR-MOD-8 (P2)** — **Delay hint**: for every voice the app computes and displays the recommended *audio* delay settings — division per role (dotted-8th for bed/plucks, plain 8th for bass, quarter for sustained voices [M §9.1]), the exact millisecond value from the manual's formula `(60000 / BPM) / 4 × 3` (recomputed live on tempo change), feedback ≈ 50%, wet ≈ 50%, ping-pong, low/high-cut on repeats. The hint is (a) shown in the voice inspector and a "Delay Cheat Sheet" panel, (b) embedded in SMF track names and clip metadata (extends FR-IO-9), and (c) copyable as text. When MIDI delay (FR-MOD-7) is ON for a voice, its hint switches to a warning: "disable audio delay on this channel or reduce wet — echoes are already in the MIDI."

### 3.9 Arrangement (A) — P2/P3

- **FR-A-1 (P2)** — **Arrangement state machine** with phases: `Intro/Build → Bed → Variation → B-Part → Payoff → Subtract → End`. Transitions fire on bar counts (default: something changes every 8–16 bars) or manual trigger; all transitions quantize to bar boundaries [M §12.1–12.4].
- **FR-A-2 (P2)** — **Additive build order** default: bedPluck1 → bedPluck2 → pad → bass → lead; Subtract reverses it down to a single voice [M §10.4, §12.4].
- **FR-A-3 (P2)** — **Density macro** (0–1): scales number of active voices, notes-per-bar caps, and mutation frequency; the seed-clip/density-curve concept from the Follow-Actions engine [M §13.1].
- **FR-A-4 (P3)** — **Ambient mode**: the change clock stretches to ~1 event/minute; legitimization repeat counts scale up (16/32) [M §12.1, §13.1].
- **FR-A-5 (P3)** — **B-part event bundle**: one trigger that simultaneously starts a progression, swaps the bass pattern, and optionally drops the bed (the manual's S4 move) [M §12.3].
- **FR-A-6 (P2)** — Full **manual override at all times**: the state machine is advisory; every action it can take is also a button/MIDI-mappable command, and it can be disabled entirely ("performance mode" = human is the arranger) [M §12.4; basic_concept].

### 3.10 MIDI I/O, sync, export (IO)

- **FR-IO-1 (P1)** — The app publishes CoreMIDI **virtual sources**. Routing modes: (a) single source, voices on channels 1–8 (default); (b) one virtual source per voice (named `Berlinan – Bass` etc.). Also routable to any existing destination (IAC, DIN interface) per voice.
- **FR-IO-2 (P1)** — All events are sent **timestamped** (CoreMIDI host-time timestamps from the lookahead scheduler, §8) — never "send now" from a UI thread.
- **FR-IO-3 (P1)** — **MIDI clock master**: 24 PPQ clock, Start/Stop/Continue, Song Position Pointer on transport actions.
- **FR-IO-4 (P2)** — **MIDI clock slave**: lock tempo/phase to incoming clock on a selectable source, with jitter smoothing (§8.4); transport follows Start/Stop/Continue.
- **FR-IO-5 (P2)** — **Ableton Link** (LinkKit): shared tempo + bar/beat phase alignment; Link and clock-slave are mutually exclusive.
- **FR-IO-6 (P1)** — **SMF export**: type 1, 960 PPQN; track 0 = tempo map + meter + section markers; one track per voice (notes, velocity, CC lanes). Export scopes: (a) rolling performance capture, (b) N bars of future render from current state ("bounce ahead"), (c) the whole pattern pool as separate clips.
- **FR-IO-7 (P1)** — **Rolling performance capture**: every emitted event is logged with musical + wall time into a ring buffer (default 60 min); "Export last N minutes/bars" at any time [design decision; supports the record-the-jam workflow, basic_concept §Output].
- **FR-IO-8 (P1)** — Note-off integrity: every Note On has a guaranteed matching Note Off across pattern swaps, transposition, mute, blank cycles, transport stop (all-notes-off + per-note tracking), and key changes.
- **FR-IO-9 (P2)** — **Drag & drop**: any pattern, any voice's current composite, or the capture buffer can be dragged out as a `.mid` file (file promise) directly into Ableton's Session View. Clip metadata (suggested delay: "dotted 8th", role, key) goes into the SMF track name — the manual's delay is an audio effect the app cannot apply, so it ships as a **hint** [M §9.1].
- **FR-IO-10 (P2)** — **MIDI learn**: all performance macros (FR-UX-3) mappable to incoming CC/notes on a control port.

### 3.11 Producer UX & performance controls (UX)

- **FR-UX-1 (P1)** — **Determinism & seeds**: the project has a master seed; every generated object records its own seed + generator version. Same project file + same user actions ⇒ identical MIDI output (§12).
- **FR-UX-2 (P1)** — Per-voice **lock / regenerate / blank-cycle / mute** as single-click actions (FR-V-4); "re-roll all unlocked."
- **FR-UX-3 (P2)** — **Performance macro panel**: 7 degree buttons (global transposition), density knob, active-step-count knob (2→8, Metropolix model [M §13.5]), per-voice regenerate buttons, blank-cycle buttons, snapshot slots (≥8). All MIDI-learnable.
- **FR-UX-4 (P1)** — All state changes are audition-while-running; no operation requires stopping the transport [basic_concept].
- **FR-UX-5 (P2)** — Undo/redo across generative actions (regenerate, mutate, harmony edits) — implemented on the engine's value-type state (§5.3).
- **FR-UX-6 (P1, added 2026-07-14 from user feedback)** — **Seed freshness**: determinism (FR-UX-1) is an engine property and must never make the app feel repetitive across sessions. (a) Unsaved/built-in projects get a random master seed per app session; saved documents keep their stored seed. (b) A one-action **New Seed** control produces a whole new musical universe — while playing it binds at the next bar (fresh engine state recalled via FR-L-6 machinery) and is undoable.
- **FR-UX-7 (P1, added 2026-10-22 from user feedback)** — **Musician-facing voice names**: the UI names voices by role (Pluck 1, Pluck 2, Bass, Pad, Lead, Drone, Heartbeat, Aux), never by internal id; a role used by several voices is numbered. Ids remain the document/export key.

---

## 4. Non-Functional Requirements

- **NFR-1 Timing accuracy**: emitted MIDI jitter ≤ 1 ms relative to the ideal grid (achievable via CoreMIDI timestamping + ≥ 50 ms lookahead), independent of UI load.
- **NFR-2 Latency of intent**: a quantized action (transpose, snapshot recall) fires exactly on the next boundary; an unquantized action (mute) takes effect ≤ 20 ms.
- **NFR-3 CPU**: < 5% of one core during steady-state playback of 8 voices (the engine is event-sparse; this is easily achievable and keeps the app credible alongside a DAW).
- **NFR-4 Determinism**: the engine is a pure function of (state, seed, action log) — no wall-clock, no `SystemRandomNumberGenerator` (§5.3).
- **NFR-5 Robustness**: MIDI device hot-plug safe; engine state survives destination disappearance (events dropped, not crashed).
- **NFR-6 Offline**: fully functional without network.
- **NFR-7 Distribution & signing**: v1 ships **unsandboxed** (Sampio policy — see `development_workflow.md` §2.4): Developer ID Application signature with **hardened runtime**, notarized and stapled DMG; entitlements kept minimal. App Sandbox is a backlog goal (required only for App Store distribution).
- **NFR-8 Accessibility/UI**: standard macOS conventions (menu bar, shortcuts, dark/light); resizable single-window design.
- **NFR-9 Testability**: engine buildable and testable headless (CLI target renders SMF from a project file — this is also Milestone M1's deliverable, §13).

---

## 5. System Architecture

### 5.1 Layering

Three strictly separated layers **[design decision]**:

```
┌──────────────────────────────────────────────────────────────┐
│  App layer (SwiftUI + AppKit)                                │
│  Document management, views, macro panel, MIDI-learn UI     │
│  — talks to Engine via value-type snapshots + action enum   │
├──────────────────────────────────────────────────────────────┤
│  Runtime layer (Swift, CoreMIDI, real-time discipline)       │
│  Transport & Clock (host-time ↔ musical-time mapping)        │
│  Lookahead Scheduler (pulls events, timestamps, sends)      │
│  MIDIService (virtual sources, routing, clock in/out, Link) │
│  CaptureBuffer (event log ring)                              │
├──────────────────────────────────────────────────────────────┤
│  Engine (pure Swift package "BerlinanEngine", no CoreMIDI,   │
│  no Foundation-dates, no UI — deterministic & headless)      │
│  MusicalState · Generators · PhasingEngine · Legitimizer     │
│  HarmonyScheduler · MelodyEngine · ModulationEngine          │
│  ArrangementSM · ScaleQuantizer · SMF read/write             │
└──────────────────────────────────────────────────────────────┘
```

Rules:

- The **Engine** is an SPM package with zero Apple-framework dependencies beyond Swift stdlib (SMF I/O included — it is just bytes). It can later be reused on iOS or in an AUv3/M4L context.
- The **Runtime** owns real time. The Engine never sees wall-clock time — only ticks.
- The **App** layer holds no musical logic. It renders Engine snapshots and dispatches actions.

### 5.2 The pull model

The Engine exposes one hot API:

```swift
/// Deterministically produce all events in [range.start, range.end) ticks.
/// Mutates internal counters (loop positions, lifecycle, harmony clock).
mutating func render(range: Range<Tick>) -> [EngineEvent]
```

The Scheduler wakes every ~25 ms, computes the tick window `[now+lookahead_lo, now+lookahead_hi)` (default lookahead 50–150 ms), calls `render`, converts ticks → host time via the Clock, and enqueues timestamped MIDI packets. Actions (user or MIDI-learned) are enqueued with a target tick (bar-quantized where required) and consumed by `render` at exactly that tick — this is what makes runtime behavior deterministic and replayable.

`EngineEvent` covers: `noteOn`, `noteOff`, `cc`, `marker(section/harmony)`, `clockMeta`. Note pairing is generated inside the Engine (a note is emitted as on+off pair with explicit gate), so FR-IO-8 reduces to transport-edge handling in the Runtime.

### 5.3 Determinism & randomness

- One master seed (UInt64). Each module gets a **named seed stream**: `stream = SplitMix64(master ⊕ hash(moduleName, voiceID, generationIndex))` **[design decision]**.
- RNG: `SplitMix64`/PCG32 implemented in-package (stable across OS versions, unlike `SystemRandomNumberGenerator`).
- Every generated `Pattern` stores `(generatorID, generatorVersion, seed, params)` — enough to regenerate it bit-identically and to display "what made this."
- The Engine's whole state is a value type (`struct EngineState`) → snapshots (FR-L-6), undo (FR-UX-5), and golden-master tests (§12) come nearly for free.

### 5.4 Threading model

| Thread | Owns | Never does |
|---|---|---|
| Main | SwiftUI, document I/O | MIDI send, engine render |
| Scheduler thread (high QoS, `Thread` with explicit priority) | Clock math, `render`, packet timestamping, send via `MIDISendEventList` | Allocation-heavy work is fine (not an audio thread), but no blocking I/O |
| CoreMIDI notify/input callbacks | clock-in parsing → lock-free FIFO to Scheduler | Engine access |

Engine state is owned exclusively by the Scheduler thread; the UI receives read-only published snapshots (`@Observable` mirror updated ≤ 30 Hz) and communicates via the action queue. No locks around musical state **[design decision]**.

### 5.5 Module map (Engine)

| Module | Responsibility | Manual |
|---|---|---|
| `MusicalState` | key/mode/tempo/meter, tick math, bar grid | §3, §4.1 |
| `ScaleQuantizer` | degree↔MIDI resolution, folding, tension-budget bypass | Law 2, §4.4 |
| `PatternGenerators` | protocol + the six generators | §5, §13.2 |
| `PhasingEngine` | per-voice loop cursors, rotation, gate/pitch decoupling, LCM | §6 |
| `Legitimizer` | pattern lifecycle, mutation operators, accumulators, ratchets | Law 1, §13.1, §13.5 |
| `HarmonyScheduler` | transposition state, progressions, weighted mode, bass-reharm, chord layer | §7, §13.3 |
| `MelodyEngine` | accent extraction, alternating scheduler, tension scoring | §8, §4.4 |
| `ModulationEngine` | velocity policy, gate ramps, CC LFO lanes, S&H pre-strike | §11 |
| `MIDIDelay` | per-voice echo-note post-processor + delay-hint computation | §9.1 |
| `ArrangementSM` | phase machine, density macro, change clock, ambient mode | §12, §13.1 |
| `SMFCodec` | SMF type-1 read/write | — |

---

## 6. Core Data Model

Sketched as Swift; all types `Codable`, value semantics. Names are normative for implementation.

### 6.1 Time & tonality

```swift
typealias Tick = Int64                 // 960 PPQN
let ppqn: Int64 = 960

struct Meter: Codable {
    var beatsPerBar: Int               // 4, 3, 7...
    var beatUnit: Int                  // 4 or 8
    var grouping: [Int]                // accent groups, e.g. [3,4] for 7/8  [M §9.3]
    var ticksPerBar: Tick { ... }
}

enum ModeID: String, Codable { case naturalMinor, dorian, phrygian, mixolydian,
    lydian, lydianDominant, harmonicMinor, minorPentatonic, locrian, major, custom }

struct Scale: Codable {
    var mode: ModeID
    var offsets: [Int]                 // semitones from root, e.g. [0,2,3,5,7,8,10]
}

struct Key: Codable {
    var root: Int                      // pitch class 0–11 (C=0)
    var scale: Scale
}
```

### 6.2 Pitch: degree-based representation **[design decision, load-bearing]**

Notes are stored as **scale degrees, not MIDI numbers**. This makes diatonic transposition (the style's primary harmony mechanism, M §7.1) a trivial integer add, and makes Law 2 structurally unbreakable — a `DegreePitch` cannot even express an out-of-key note without the explicit accidental field.

```swift
struct DegreePitch: Codable, Hashable {
    var degree: Int          // 0-based index into scale.offsets, may exceed count
    var octave: Int          // octaves relative to voice's reference octave
    var accidental: Int = 0  // semitone offset; non-zero ONLY via tension budget [M §4.4]
}

// Resolution (the ONLY place degrees become MIDI numbers):
// midi = voice.refC + 12*octave + key.rootOffset
//        + scale.offsets[degree mod count] + 12*(degree / count) + accidental
// then RegisterWindow.fold(midi)                                  [M §5.1]
```

Chromatic generators (drunkard's walk) quantize to the nearest degree **at generation time**, so everything downstream is degree-space.

### 6.3 Patterns & voices

```swift
struct PatternNote: Codable {
    var position: Tick                 // 0..<length
    var pitch: DegreePitch
    var velocity: UInt8                // post-policy baseline; accents applied by ModulationEngine
    var gate: Tick
    var accent: Bool
    var ratchet: Int = 1               // 1 = normal; 2–3 = intermittent ratchet [M §13.5]
}

struct GateStep: Codable { var on: Bool; var width: Double /* 0.4–0.99 */ }

struct Pattern: Codable, Identifiable {
    var id: UUID
    var length: Tick                   // loop length — free-form [M §6.1]
    var startOffset: Tick = 0          // rotation [M §6.2]
    var notes: [PatternNote]
    // Optional decoupled mode [M §6.4]: if set, `notes` holds the pitch cycle
    // (positions ignored) and gates come from this cycle of independent length.
    var gateCycle: [GateStep]?
    var gateCycleLength: Tick?
    var provenance: Provenance         // generatorID, version, seed, params
    var locked: Bool = false
    var lifecycle: Lifecycle           // .repeating(remaining: Int) / .established
}

enum VoiceRole: String, Codable { case bedPluck1, bedPluck2, bass, pad, lead, drone, rhythm, aux }

struct RegisterWindow: Codable { var low: UInt8; var high: UInt8
    func fold(_ note: Int) -> UInt8 { /* octave fold, never clamp [M §5.1] */ } }

struct Voice: Codable, Identifiable {
    var id: UUID
    var role: VoiceRole
    var register: RegisterWindow
    var refOctave: Int
    var route: MIDIRoute               // destination + channel
    var ccMap: CCMap                   // named targets → CC numbers (synth profile)
    var generator: GeneratorConfig
    var pattern: Pattern
    var participatesInTransposition: Bool = true      // [M §7.1 per-voice opt-out]
    var anchorPolicy: AnchorPolicy     // .beats1and3 (bass default) / .beat1 / .none [M §6.6]
    var densityCap: Int?               // max notes/bar [M Law 3]
    var modLanes: [CCLane]             // ≤ 4
    var gateRamp: GateRampProgram?     // [M §11.4]
    var midiDelay: MIDIDelayConfig     // FR-MOD-7 (echo notes; default off)
    var state: VoiceRuntime            // mute/solo/blankCyclePending, loop cursor
}
```

### 6.4 Modulation

```swift
enum LFOShape: String, Codable { case sine, triangle, sawDown, sawUp, square, sampleHold }

struct CCLane: Codable {
    var target: CCTarget               // resolved via voice.ccMap
    var shape: LFOShape
    var cycleBars: Double              // MUSICAL time: 0.5–64 bars [M §11.2]
    var depth: Double; var center: Double; var phase: Double
    var preStrikeTicks: Tick = 10      // S&H lands before the note [M §11.3]
}

struct GateRampProgram: Codable {      // [M §11.4]
    var arcBars: Int                   // e.g. 8
    var profile: [Double]              // gate multipliers per bar, e.g. [0.4,0.4,0.6,0.6,0.8,0.8,0.95,0.4]
}

struct VelocityPolicy: Codable {       // [M §11.1]
    var baseline: UInt8 = 100
    var accentBoost: Int = 20
    var humanizeRange: Int = 10        // re-rolled once per legitimization cycle
}

enum DelayDivision: String, Codable { case dotted8th, eighth, quarter }

struct MIDIDelayConfig: Codable {      // FR-MOD-7; emulates the audio delay [M §9.1]
    var enabled: Bool = false          // default OFF — audio delay is the primary path
    var division: DelayDivision = .dotted8th
    var repeats: Int = 3               // 1–8
    var velocityDecay: Double = 0.55   // per-repeat multiplier (~50% feedback)
    var gateScale: Double = 0.9        // per-repeat gate multiplier
}

struct DelayHint: Codable {            // FR-MOD-8; computed, not stored per-project
    var division: DelayDivision        // by role: bed→dotted8th, bass→eighth, pad/lead→quarter
    var milliseconds: Double           // (60000 / bpm) / 4 * 3 for dotted8th [M §9.1]
    var feedback: Double = 0.5
    var wet: Double = 0.5
    var pingPong: Bool = true
    var filterRepeats: Bool = true     // low+high cut on echoes [M §9.1]
}
```

### 6.5 Harmony & arrangement

```swift
struct ProgressionStep: Codable { var degreeOffset: Int; var bars: Int }
struct Progression: Codable { var name: String; var steps: [ProgressionStep]; var loop: Bool }

enum HarmonyMode: Codable {
    case pedal
    case progression(Progression)
    case weightedRandom(weights: [Int: Double], periodBars: ClosedRange<Int>)  // [M §7.1, §13.6]
    case bassReharm(Progression)                                              // [M §7.2]
}

struct HarmonyState: Codable {
    var mode: HarmonyMode
    var currentOffset: Int = 0          // diatonic degree offset
    var nextEventBar: Int
    var tensionBudget: Int = 2          // [M §4.4]
}

enum ArrangementPhase: String, Codable {
    case intro, build, bed, variation, bPart, payoff, subtract, ending }

struct ArrangementConfig: Codable {
    var enabled: Bool
    var changePeriodBars: ClosedRange<Int> = 8...16   // [M §12.1]
    var ambientMode: Bool = false                     // ~1 change/min [M §12.1]
    var buildOrder: [VoiceRole]                       // [M §10.4]
    var density: Double = 0.5
}
```

### 6.6 Project root

```swift
struct Project: Codable {
    var formatVersion: Int
    var masterSeed: UInt64
    var key: Key; var tempo: Double; var meter: Meter
    var voices: [Voice]
    var harmony: HarmonyState
    var arrangement: ArrangementConfig
    var snapshots: [Snapshot]           // full EngineState captures [M §13.5]
    var midiSetup: MIDISetupConfig      // routing mode, clock mode, control port
    var legitimizationN: Int = 4        // [M Law 1]
}
```

---

## 7. Engine Algorithms

Normative pseudocode for the non-obvious parts. All `rand` calls draw from the module's named seed stream (§5.3).

### 7.1 Scale quantizer & fold

```
resolve(pitch: DegreePitch, key, voice) -> UInt8:
    d = pitch.degree mod key.scale.count ; oct = pitch.degree div key.scale.count
    midi = voice.refC + 12*(pitch.octave + oct) + key.root + key.scale.offsets[d]
           + pitch.accidental        // ≠ 0 only when tension budget spent
    return voice.register.fold(midi) // shift by ±12 until inside window

quantizeChromatic(midi) -> DegreePitch:
    // nearest scale tone; ties resolve DOWNWARD [design decision — darker
    // resolution suits the style's minor-mode default]
```

### 7.2 Seed-procedure generator [M §5.2, §5.3]

```
generate(voice, params, rng):
    grid = 16 steps per bar; pattern.length = params.bars * bar
    notes = [root@steps 1,5,9,13 (quarter notes)]      // seed
    for i in 1..params.mutationCount (default 4):
        op = rng.pick([moveTime(±1..2 steps, backbeats only if role==bed),
                       moveDegree(±1..2 in scale),
                       addOctaveJump(root+1oct),
                       toggleAccent])
        apply(op)  // steps 1 & 9 stay LOCKED in time  [M §5.3 timing rule]
    if role == bass && anchorPolicy != .none:
        keep onsets at beats 1,3; delete beats 2,4     [M §5.3 step 5]
    enforce: first sounding note is root; densityCap; gates = 40–60%
```

### 7.3 Phasing cursor & LCM [M §6.1]

```
Each voice keeps loopCursor advancing on the global tick stream:
    localTick = (globalTick + pattern.startOffset) mod pattern.length

convergencePeriod = LCM(all active pattern.length) / ticksPerBar   // shown in UI
// LCM over Int64 with overflow guard; if > 10_000 bars display "∞ (practically)"
```

### 7.4 Legitimizer cycle [M Law 1, §13.1]

```
on pattern loop boundary:
    switch pattern.lifecycle:
      .repeating(n>1): lifecycle = .repeating(n-1)      // verbatim replay
      .repeating(1):   lifecycle = .established
      .established:
        if voice.locked: continue
        if blankCyclePending: emit nothing this cycle; clear flag
        else if arrangement/density asks for change OR user hit regenerate:
            newPattern = regenerate OR mutate(pattern):
                mutate: for each note: if rng() < 0.30:
                            note.degree += rng(-scaleSteps(12)..scaleSteps(12))
                        (scale-fold implicit in degree space)
                        optionally: one accent-move, one time-nudge, one ratchet
            newPattern.lifecycle = .repeating(N-1)       // N=4 default
// NOTE: no evaluation happens mid-cycle; mutations bind at loop boundaries only.
```

### 7.5 Harmony scheduler [M §7]

```
at bar boundary:
    if bar == harmony.nextEventBar:
        switch mode:
          progression: currentOffset = next step.degreeOffset; schedule += step.bars
          weightedRandom: currentOffset = sample(weights); schedule += rng(periodBars)
          bassReharm: bassOffset = next; upper voices untouched; bass gates → held
    effectiveDegree(voice) = pattern degree + (voice.participates ? currentOffset : 0)
// Transposition is an ADD in degree space, applied at resolve() time —
// running notes are unaffected until their next onset; sounding notes keep
// their noteOff as originally scheduled (no retuning mid-note).
```

### 7.6 Modulation engine [M §11]

```
velocities: baseline + (accent ? boost : 0) + humanize(perCycleRoll)
gate ramp: gate *= profile[barIndexInArc]
CC lanes per render window:
    for each lane: sample shape at musical phase = (bar + barFrac)/cycleBars
                   S&H: step value changes at (stepOnset - preStrikeTicks)
    emit only on value delta; max rate 1 per 1/96 note
```

### 7.7 MIDI delay post-processor (FR-MOD-7)

```
postProcess(events, voice) -> events:
    if !voice.midiDelay.enabled: return events
    dt = ticks(voice.midiDelay.division)        // dotted8th = 720 ticks @ 960 PPQN
    for note in events.notes where !note.isEcho:
        v = note.velocity; g = note.gate
        for r in 1...voice.midiDelay.repeats:
            v = round(v * velocityDecay); g = g * gateScale
            if v < 8: break                     // inaudible tail cutoff
            emit echoNote(position: note.position + r*dt,
                          pitch: note.pitch,    // register-folded as usual
                          velocity: v, gate: g, isEcho: true)
// Echo notes exist ONLY at the output/export boundary: they are invisible to
// generators, the Legitimizer, phasing math, and the convergence display.
// Toggling the delay off cancels future echoes at the next bar; already
// sounding echoes finish with their scheduled Note Offs (FR-IO-8).
```

### 7.8 Arrangement state machine [M §12]

```
tick per bar:
    barsInPhase += 1
    if !config.enabled: return                         // performance mode
    period = ambientMode ? barsPerMinute(tempo) : rng(changePeriodBars)
    if barsInPhase >= period: advance()

advance():
    build:     activate next voice in buildOrder; if all active → bed
    bed:       schedule a mutation on one unlocked voice (round-robin)
    variation: alternate mutations / accent-moves / blank cycles by density
    bPart:     fire B-bundle (progression start + bass swap [+ bed drop])
    payoff:    re-add all voices + raise density (additive repetition [M §12.3 S6–S8])
    subtract:  deactivate voices in reverse buildOrder; last voice → ending
    ending:    thin final pattern to roots only; stop at bar boundary [M §12.4]
```

---

## 8. Timing, Transport & Synchronization

### 8.1 Clock domains

- **Musical time**: ticks (960 PPQN), bars via `Meter`. Owned by the Engine.
- **Host time**: `mach_absolute_time()` via `CAHostTimeBase`-style conversion. Owned by the Runtime.
- The **Clock** object maintains the mapping `hostTime(tick)` as a piecewise-linear function anchored at the last tempo change (or continuously re-estimated in slave/Link modes).

### 8.2 Lookahead scheduler

```
every 25 ms (scheduler thread):
    windowStart = lastRenderedTick
    windowEnd   = tick(hostNow + 150 ms)
    events      = engine.render(windowStart..<windowEnd)   // + consume due actions
    for e in events: send MIDIEventList with timestamp hostTime(e.tick)
    lastRenderedTick = windowEnd
```

- Lookahead 150 ms / wake 25 ms gives ≥ 5 wakes of slack; jitter is absorbed by CoreMIDI timestamps (NFR-1).
- **Action latency vs. lookahead**: unquantized actions (mute) must beat the lookahead. Solution: mutes/solos are applied in the Runtime as a post-render gate (event filter) so they act ≤ 20 ms; all *musical* actions are bar-quantized anyway and flow through the engine action queue **[design decision]**.

### 8.3 Clock master (FR-IO-3)

24 PPQ clock derived from the same `hostTime(tick)` map (1 clock = 40 ticks at 960 PPQN); Start sent at transport start, SPP+Continue on relocate.

### 8.4 Clock slave (FR-IO-4)

Incoming F8 timestamps feed a **PLL-style estimator**: tempo = smoothed inter-pulse rate (median-of-9 window + exponential smoothing); phase corrections are applied by micro-warping the tick→hostTime map (never by jumping ticks). Start/Continue align the bar grid; if no clock for > 500 ms, freewheel at last tempo and surface a UI warning.

### 8.5 Ableton Link (FR-IO-5, P2)

LinkKit (C++ static library) wrapped in an Objective-C++ shim exposed to Swift. Link provides tempo + beat phase; the app maps Link's beat 0 to bar 1 with a user "re-anchor" button. Transport start quantizes to Link quantum (default 4 beats).

---

## 9. MIDI I/O & Export

### 9.1 Ports & routing

- `MIDIClientCreateWithBlock` + `MIDISourceCreate` for virtual sources (UMP/MIDI-1.0 protocol negotiated; events sent as MIDI 1.0 channel voice messages for maximum DAW compatibility **[design decision]**).
- Routing table: `VoiceID → (endpointRef | virtualSourceIndex, channel 1–16)`. Default: single virtual source "Berlinan Out", voice n → channel n.
- A separate virtual destination "Berlinan Control" receives MIDI-learn input and clock-in (selectable).

### 9.2 Event hygiene

- Per-(endpoint, channel, note) active-note registry in the Runtime; transport stop / voice mute / route change flushes matching Note Offs, then CC 123 as belt-and-braces (FR-IO-8).
- CC lanes emit a fresh value on transport start and on route change (synth state re-sync).

### 9.3 SMF export (FR-IO-6)

- Type 1, 960 PPQN. Track 0: tempo map, time signatures, markers (`SECTION:B-Part`, `HARM:+4`, snapshot recalls). Tracks 1..n: one per voice, named `"<role> | ch<n> | delay-hint: dotted8 | key: C minor"`.
- Note events carry the exact velocities/gates as played; CC lanes are written at their emission resolution.
- Export scopes: capture buffer slice (bars or minutes), forward render (engine cloned, rendered N bars ahead — determinism makes this exact), pattern-pool clips (each pattern rendered for `LCM(1, legitimizationN)` loops as a 1-clip SMF).

### 9.4 Drag & drop (FR-IO-9)

`NSFilePromiseProvider` per draggable entity; file written to a temp location on drop. Clip length rounded up to whole bars so Ableton clip launch quantization works out of the box.

---

## 10. Persistence & Project Format

- **Document-based app** (`.berlinan` package): `project.json` (the `Project` struct, §6.6, pretty-printed, versioned with explicit `formatVersion` + migration functions), `capture/` (optional saved capture buffers as SMF), `snapshots/` embedded in JSON.
- JSON over binary: diff-able, debuggable, and the data volumes are trivial **[design decision]**.
- Autosave via standard `NSDocument` machinery; snapshots are part of undo history.
- Synth CC profiles stored globally (`~/Library/Application Support/Berlinan/profiles/*.json`) and referenced by name from projects.

---

## 11. User Interface Specification

Visual language (colors, typography, component styles) is defined in `design_language.md` — studio-dark with a tangerine primary accent, derived from Sampio's design system. This section specifies structure and behavior only.

Single main window, four zones (top→bottom):

### 11.1 Transport & global bar

Play/Stop · tempo · key root + mode pickers · meter picker · sync mode (Internal / Clock-Slave / Link) · master seed (visible, copyable) · CPU/MIDI activity indicators. Key/meter changes show a "pending at next bar" badge until applied (FR-GS-4/5).

### 11.2 Voice lanes (the core view)

One horizontal lane per voice:

- Role badge + route (channel) + register window.
- **Pattern strip**: step/piano-roll rendering of the current pattern; loop length drag-handle (snaps to steps/beats/bars, allows odd lengths); rotation handle; playhead.
- Lifecycle indicator: `●●●○` repeats remaining in the legitimization cycle (FR-L-1) — the producer must *see* when a pattern becomes mutable.
- Buttons: 🔒 lock · ♻ regenerate · ⊘ blank cycle · M/S.
- Lane inspector (right panel when selected): generator + params + seed (re-roll / paste seed), velocity policy, CC lanes, gate ramp, density cap, anchor policy, **MIDI delay toggle + parameters (FR-MOD-7)**, and the voice's **delay hint** (FR-MOD-8) with a copy button — including the "echoes already in MIDI" warning state when the toggle is on.
- Editing gestures directly in the strip (drag note pitch/position, ⌥-drag velocity) mark the pattern locked (FR-P-7).

### 11.3 Phasing & harmony strip

- **Convergence display**: `LCM = 105 bars ≈ 4:40 @ 90 BPM`, with a progress ring "distance to convergence" (FR-PH-4).
- **Harmony timeline**: current degree offset (big), active progression as a chip row, next-event countdown in bars; mode switcher (pedal / progression / weighted / bass-reharm); tension-budget counter (P3).

### 11.4 Performance panel (bottom, collapsible)

- 7 degree buttons (1–7) + "home" — global transposition, bar-quantized, MIDI-learnable.
- Density knob · active-steps knob (2→8) · "re-roll all unlocked" · 8 snapshot slots (save = ⌥-click).
- Arrangement automaton: phase display + enable toggle + "advance now" (FR-A-6).
- MIDI-learn mode: click a control, move a CC on the control port, done.

### 11.5 Menus & shortcuts

Standard File/Edit plus: Export ▸ (Capture… / Forward render… / Pattern pool…), MIDI Setup…, Synth Profiles…, **Window ▸ Delay Cheat Sheet** (a panel listing every voice's recommended audio-delay settings at the current tempo — division, ms, feedback, wet, ping-pong, filtered repeats — updating live with tempo; FR-MOD-8). Space = play/stop, 1–7 = transpose, R = regenerate selected voice, B = blank cycle selected, ⌘1–8 = select voice.

---

## 12. Testing Strategy

1. **Golden-master determinism** (the backbone): fixture projects + scripted action logs → rendered SMF → byte-compare against committed goldens. Any engine change that alters output is a *visible* diff (NFR-4, FR-UX-1).
2. **Musical invariant property tests** (randomized seeds, thousands of cases):
   - every emitted note resolves inside the key (unless tension-flagged) [Law 2];
   - first sounding note of every generated pattern = root [M §5.1];
   - all notes inside register windows post-fold [M §5.1];
   - bass onsets present at beats 1 & 3 when anchored [M §6.6];
   - pattern replays are byte-identical for exactly N−1 repeats after generation [Law 1];
   - no per-step chance parameter exists (compile-time: the type doesn't exist) [Law 1];
   - meter/key/transposition changes only ever bind at bar boundaries [M §3.2].
3. **Note-off integrity fuzz**: random mute/stop/retranspose/blank storms → assert active-note registry empties (FR-IO-8).
4. **Timing tests** (Runtime): loopback virtual destination capturing timestamps; assert jitter ≤ 1 ms and clock-out stability (NFR-1).
5. **SMF round-trip**: export → parse → semantic equality.
6. **Manual listening protocol** (per milestone): the M1 CLI renders the manual's reference configurations (e.g. §14 pipeline defaults) to SMF; import into Ableton against the style checklist — does it *sound* Berlin School? This is a release gate, not a nicety.

---

## 13. Roadmap & Milestones

| Milestone | Deliverable | Requirement scope |
|---|---|---|
| **M1 — Headless engine** | `BerlinanEngine` SPM package + CLI (`berlinan render project.json --bars 64 -o out.mid`). No UI, no CoreMIDI. | FR-GS-1/2/3/6, FR-V-1/3/5, FR-P-1(gen 1–3)/2/3, FR-PH-1/4, FR-L-1/2/3, FR-H-1/2/3, FR-MOD-1, FR-IO-6(a-forward)/8(engine part), FR-UX-1 · §12 tests 1/2/5/6 |
| **M2 — It plays** | Minimal app: transport, voice lanes (read-only patterns), virtual MIDI out, clock master, capture buffer + export, lock/regenerate/blank/mute, degree buttons. **First usable jam tool.** | FR-IO-1/2/3/7, FR-V-4, FR-UX-2/4, UI §11.1/11.2(partial)/11.4(partial) |
| **M3 — Musical depth** | Remaining generators, gate/pitch decoupling, accents & mutations complete, progressions + weighted harmony + bass reharm, CC lanes + gate ramps, delay hints, pattern editor, snapshots, undo. | FR-P-4/5/6/7, FR-PH-2/3, FR-L-4/5/6, FR-H-4/5/6/9, FR-MOD-2/3/4/5/8, FR-UX-3/5 |
| **M4 — Sync & integration** | Clock slave, Ableton Link, MIDI learn, drag & drop clips, synth profiles, meter changes + odd-meter presets, MIDI delay (deferred from M3). | FR-IO-4/5/9/10, FR-GS-4/5, FR-MOD-5/7 |
| **M5 — Arranger & polish** | Arrangement state machine, ambient mode, melody engine (accent extraction, alternating), tension budget, chord layer, B-part bundle. | FR-A-*, FR-MEL-*, FR-H-7/8, FR-V-7 |
| Backlog | `.als` export with scenes; built-in preview synth (AVAudioUnitSampler); AUv3/M4L companion; MPE; custom scales UI. | — |

M1 before any UI is deliberate: the style validation loop (render → import into Ableton → listen) must work before investing in interface **[design decision; NFR-9]**.

---

## 14. Traceability Matrix (Manual → Requirements)

| Manual section | Requirements |
|---|---|
| Law 1 (repetition legitimizes) | FR-L-1/3, FR-MOD-1(humanize-per-cycle), §7.4 |
| Law 2 (scale constraint) | FR-GS-6, §6.2 degree model, §7.1 |
| Law 3 (sparseness) | FR-V-6, FR-P-2 |
| Law 4 (layered simplicity) | FR-V-1/2, §10.1 roles |
| Law 5 (variation over novelty) | FR-L-2/4/5, FR-P-5/6 |
| §3 tempo/meter/swing | FR-GS-1/3/4, FR-A-4 |
| §4 modes & tension model | FR-GS-2, FR-MEL-4, FR-H-7 |
| §5 sequence construction | FR-P-1/2/3/5/6, FR-V-3 |
| §6 phasing | FR-PH-1..5, FR-P-4, FR-V-5 |
| §7 harmony engine | FR-H-1..8 |
| §8 melody | FR-MEL-1..5 |
| §9 rhythm & delay | FR-MOD-7 (MIDI delay), FR-MOD-8 (delay hints), FR-IO-9, FR-V-7, FR-GS-4 (odd meters) |
| §10 voice architecture | FR-V-1/2/3, FR-A-2 |
| §11 modulation | FR-MOD-1..6 |
| §12 structure | FR-A-1..6 |
| §13 generative systems | FR-L-*, FR-H-5/8, FR-P-1(walk), FR-A-3 |
| §14 reference pipeline | Engine module map §5.5, ArrangementSM §7.7 |
| §16 defaults | All default values in §6 types |

---

## 15. Open Questions & Risks

| # | Question / risk | Current position |
|---|---|---|
| 1 | **No built-in sound** hurts first-run experience (app is silent without a routed synth). | Accept for M2 (target users have synths ready); backlog a tiny preview sampler. |
| 2 | ~~Delay ("ducka-ducka") is an *audio* effect the app cannot produce.~~ **Resolved**: per-voice toggleable **MIDI delay** (FR-MOD-7, default off) + always-on **delay hints** with concrete settings (FR-MOD-8, Delay Cheat Sheet). | Implemented in M3. Residual risk: MIDI echoes cannot reproduce filtered/darkening repeats — the hint warns that audio delay remains the higher-fidelity path. |
| 3 | LinkKit is C++; licensing (GPL for open distribution / commercial license) must be checked before M4. | Investigate before M4; clock-slave is the fallback. |
| 4 | Gate/pitch decoupling + rotation + transposition interacting with the legitimization cycle could create hard-to-reason states. | Mitigated by determinism + golden masters; keep mutation binding strictly at loop boundaries (§7.4). |
| 5 | Should the lead voice ever be generated by default, or is it human-only? | Default: lead lane exists but generator off (manual favors human leads over beds [M §8.5]); MEL engine is opt-in. |
| 6 | MIDI 2.0 / UMP native output? | Not for v1; MIDI 1.0 channel messages maximize compatibility. |
| 7 | ~~Sandboxing + virtual MIDI + file promises need entitlement verification early.~~ **Resolved**: v1 is unsandboxed with Developer ID + hardened runtime + notarized DMG (Sampio's proven pipeline, adopted in `development_workflow.md`). | Sandbox deferred to backlog (App Store only). |

---

*Spec compiled 2026-07 against `berlin_school_manual.md` v1 and `basic_concept.md`. The manual is the normative musical authority; where implementation forces a deviation, update the traceability matrix and flag the deviation in this document.*
