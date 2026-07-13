# Berlin School Generative Sequencer — Basic Concept

**Founding concept note.** This document captures the initial product vision for a generative MIDI sequencer for Berlin School music, from the perspective of a music producer who would use it daily. It is grounded in `berlin_school_manual.md` (the style theory reference derived from ~225 Synth Seeker transcripts). The detailed engineering specification lives in `generative_sequencer_spec.md`.

---

## Core Concept

The most important decision: the application is **not a generator of finished tracks, but a living "pattern pool" plus rules for moving through it**. Berlin School is not linear composition — it is a set of simple layers that phase, transpose, and get added/removed over time. The app should therefore work as a **state machine that plays**, not as "generate and done."

The producer intervenes continuously (**human-in-the-loop**): the curation step ("keep this, discard that") is documented in the style as a hard requirement — raw randomness never ships (Manual, Law 1).

## What the Application Must Do

### 1. Global musical state

- Key + mode (default C minor; Dorian/Phrygian/Mixolydian as first-class alternatives, pentatonic for high-randomness settings), tempo (default ~90 BPM), meter (4/4 + odd meters with switching only at bar ends), swing hard-locked to 0.
- Everything any module produces passes through a **scale quantizer** at the end of its pipeline — Manual Law 2, and it should be architecturally impossible to bypass (except via the explicit "tension budget", see Harmony below).

### 2. Voices with roles

4–7 slots with fixed roles: bed pluck 1, bed pluck 2, bass, pad, lead, optionally drone and rhythm. Each voice has:

- its own MIDI channel / port,
- a register window with the **octave-fold** rule (a note above the ceiling wraps down an octave, never clamps),
- its own pattern generator and its own loop length.

### 3. Pattern generators (per voice)

The manual's recipes implemented as selectable algorithms:

- seed procedure (roots on beats → mutate positions/pitches/velocities),
- high/mid/low contours,
- pulsing 16th-note bassline,
- drunkard's walk with a harvest step,
- arpeggiator modes (down + retrigger-on-note, 2:1 rate pairs).

Every pattern maintains the invariants: first sounding note = root, sparseness (gaps are a feature), short gates, ≤ ~2 octave span.

### 4. Phasing engine — the heart of the app

This is what no ordinary sequencer does comfortably: assigning **unequal loop lengths** across voices (16 vs 15 steps, 8/7/6 bars, even × odd), start-point rotation, decoupled gate/pitch sequences of different lengths with LCM computation. The UI should display **how long until the composite re-converges** (LCM in bars) — key information for the producer. Plus the anchor rule: the bass holds beats 1 and 3 no matter what happens above.

### 5. Legitimization loop

Every newly generated/mutated pattern plays **4× verbatim** before the next mutation is allowed. Mutation = 30% chance of ±12 semitones → fold into scale. Deliberately **no per-step note probability** — instead accumulators, intermittent ratchets, and savable snapshots. This is exactly what separates "sounds like Berlin School" from "sounds like a random generator."

### 6. Harmony scheduler

- Default: pedal on the root. One event every 8–16 bars.
- **Global diatonic transposition** of all voices at once, following a progression given as degree numbers (1-7-6-5, 1-6-4-7, …), with a weighted table of targets ("sweet" vs "dark" degrees).
- Alternatively **bass-only reharmonization** under static upper layers.
- Tension budget: 1–2 out-of-key notes per piece as an explicit, manually unlocked event (climax).

### 7. Melody layer

Velocity-accent extraction (mute everything, raise 3–4 accents, invert in bar 2, …) + the conversation model (2×4 bars, breathing, alternating melody between two voices that never play simultaneously). The lead can also be "advisory only" — the producer will often play it by hand anyway.

### 8. Modulation as part of the output

The sequencer must emit more than notes: a velocity lane (accents, randomization ±20), **gate-length ramps** (timbral sweep without CC), slow CC LFOs (cycles of 16/32/64 bars!), S&H CC steps timed just **before** the note strike. CC number mapping configurable per voice (to match specific synths).

### 9. Arrangement state machine

Additive build (bed1 → bed2 → pad → bass → lead) → variations → B-part (progression/new bass) → additive repetition as the payoff → subtractive ending down to a single voice. Density curve as a macro control. In "ambient mode", change ~1× per minute instead of every 8 bars.

## Getting the Output into Ableton / Hardware

Both paths, ideally simultaneously:

1. **Live MIDI output**: virtual MIDI ports (macOS IAC / virtual source), each voice on its own channel, the app as **MIDI clock slave** (or master) + ideally **Ableton Link**. In Ableton you then just arm 6 tracks and record the app's entire "performance." This is the authentic workflow — record the jam, then mine it in the DAW.
2. **.mid file export**: multitrack MIDI file (one track per voice, including velocity and CC lanes), plus **drag-and-drop of individual patterns** as clips. Practical detail: also export the "pattern pool" as a set of clips (not just a linear render), because in Ableton you want to work with them in Session View.
3. Later bonus: export as an Ableton Live Set (.als is gzipped XML) with scenes matching the sections — nice-to-have; MIDI files are sufficient.

## Producer-Facing Controls

- **Seeds + reproducibility**: every generation has a seed; anything I like I can lock (per-voice lock) and re-roll only the rest.
- **Performance macros**: one keyboard row / button row = transposition (degrees 1–7), knob = density, knob = active step count (the Metropolix model, 2→8), button = "regenerate voice X", button = blank cycle (a voice drops out for one cycle).
- **Everything auditionable while running** — mutations happen while it plays, never stop-edit-play.

## MVP

Phase 1 = global state + 3 voices (2 bed plucks + bass) + seed generator + loop-length phasing + legitimization loop + global transposition + live MIDI out with clock. That alone already produces an authentic Berlin School bed to play a lead over by hand. Melody engine, the arrangement automaton, and .als export come later.

---

*Written 2026-07. Target platform decided after this note was written: native macOS application (see `generative_sequencer_spec.md`).*
