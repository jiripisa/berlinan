# The Berlin School Manual

**A technical reference on the theory and construction of Berlin School electronic music, written as a specification source for a generative MIDI sequencer.**

This manual is synthesized from ~225 video transcripts of the *Synth Seeker* YouTube channel (Luke), a practitioner focused on Berlin School composition and performance. Every technique below is stated in the most algorithm-ready form the source material allows: concrete step counts, intervals, probabilities, timings, and rule systems. Bracketed citations like `[Beginner Essentials]` refer to shortened source video titles (transcripts in `docs/synthkeeper/`).

---

## Table of Contents

1. [What Berlin School Is](#1-what-berlin-school-is)
2. [The Five Laws (Core Aesthetic Principles)](#2-the-five-laws-core-aesthetic-principles)
3. [Global Parameters: Tempo, Meter, Subdivision](#3-global-parameters-tempo-meter-subdivision)
4. [Tonality: Scales, Modes, and the Interval Tension Model](#4-tonality-scales-modes-and-the-interval-tension-model)
5. [Sequence Construction (The Pattern Layer)](#5-sequence-construction-the-pattern-layer)
6. [Note Phasing and Polymeter (The Variation Engine)](#6-note-phasing-and-polymeter-the-variation-engine)
7. [The Harmony Engine: Transposition, Reharmonization, Implied Chords](#7-the-harmony-engine-transposition-reharmonization-implied-chords)
8. [Melody Generation](#8-melody-generation)
9. [Rhythm, Delay-as-Rhythm, and Odd Meters](#9-rhythm-delay-as-rhythm-and-odd-meters)
10. [Voice Architecture and Layering](#10-voice-architecture-and-layering)
11. [Modulation as Part of the Sequence (Velocity, CC, LFO Doctrine)](#11-modulation-as-part-of-the-sequence-velocity-cc-lfo-doctrine)
12. [Structure and Arrangement](#12-structure-and-arrangement)
13. [Generative Systems: Complete Documented Algorithms](#13-generative-systems-complete-documented-algorithms)
14. [A Reference Pipeline for a Generative Berlin School Sequencer](#14-a-reference-pipeline-for-a-generative-berlin-school-sequencer)
15. [Sound Design Quick Reference (Patch Archetypes)](#15-sound-design-quick-reference-patch-archetypes)
16. [Parameter Defaults Cheat Sheet](#16-parameter-defaults-cheat-sheet)

---

## 1. What Berlin School Is

Berlin School is the sequencer-driven branch of 1970s German electronic music (Tangerine Dream, Klaus Schulze, Ashra). Its musical identity, distilled from the source material:

- **The unit of composition is the short repeating figure** ("ostinato", "musical shape"), not the song section or the melody. "Berlin School textures are small, very short clips, generally repeating over and over again, with a good delay and some reverb behind it." [Sound Design]
- **Several such figures run simultaneously in one key**, differing in length, register, and timbre. Their interaction — phasing, interlocking, implied harmony — *is* the music.
- **Harmonic movement comes from transposing the running patterns** (or moving only the bass), not from played chord changes.
- **Form is long and evolutionary**: layers enter and exit gradually over 5–20 minutes; the arrangement is the performance of the pattern pool.
- **Expression lives in the programming, not the playing**: velocity accents, gate lengths, and slow modulation are sequenced; the style is deliberately mechanical ("Berlin School is clockwork" [Odd Meters]).
- The defining sonic glue: **tempo-synced delay (dotted-eighth by default) and large reverb** on nearly every voice. "What really makes Berlin School Berlin School is repeating figures, some reverb and some delay." [Step By Step Guide]

Historically the style was built on 4/8/16-step analog sequencers — which is why every pattern rule below thinks in small step counts. [Beginner Essentials]

---

## 2. The Five Laws (Core Aesthetic Principles)

These recur across virtually every source video and should be treated as the axioms of any generative implementation.

### Law 1 — Repetition legitimizes

Raw randomness never ships. Any newly generated material must be **repeated verbatim several times (canonically 4×: generate once, repeat 3×)** so the listener's ear can predict it — only then does it read as intentional music rather than noise. "By the third time you loop it you can feel the groove — repetition validates." [Drunkard's Walk] [Follow Actions]

Corollary (explicitly tested and rejected by the author): **per-step note probability is a bad primitive** — "I don't actually like probability… it's too random… there's no repetition — it breaks the legitimization." Randomness should *persist across repeats* (accumulators, saved transposition snapshots, regenerate-then-loop) rather than re-roll every pass. [Exploring Berlin School Modular Jam]

### Law 2 — Constrain everything to one scale

Pick one key/mode and force every voice into it, mechanically: scale-quantizer devices, CV quantizers, scale-locked grids. All random or transposed output is folded back into the scale *after* mutation. "I literally can't play anything out of key." Out-of-scale notes are permitted only as deliberate, rare tension events (see §4, §7). [Idea Machine] [Follow Actions]

### Law 3 — Sparseness: gaps are where other voices sing

Do not fill all 16 steps. Patterns need rests ("play and breathe"); a 4-bar clip with a 2-bar hole at the end invites another voice to answer. Fewer notes per pattern is better, especially when many layers run. [Step By Step Guide] [Uncomplicated Approach]

### Law 4 — Simple patterns, simple sounds, complexity from layering

Each voice is trivially simple (3–7 notes, one oscillator is enough). Complexity emerges from layering figures that differ **in both length and pitch content**, then letting delay/reverb weave them together. "The best Berlin School patches are the boring ones." [Diary #14] [Synth Nerds]

### Law 5 — Variation over novelty

The style avoids new material; it *varies existing material*: transpose it, phase it, move its accents, mute notes, change the timbre, drop a layer. "Same feel, same groove, same implied progression, but different." A listener should never hear an exact duplication for too long, and never hear something entirely unrelated. [Music Making Diary #4]

---

## 3. Global Parameters: Tempo, Meter, Subdivision

### 3.1 Tempo

Observed tempos across the corpus: 77, 83, 85, 90 (×3), 94, 95 (×2), 96, 98, 100 (×2), 108, 121, 125 (×2), 130, 141 BPM (one 211 BPM double-time outlier).

- **Core Berlin School zone: 85–100 BPM.** [Jamuary 01] [Jamuary 25] [Cobalt 8M] [Odd Meters]
- 108–130 BPM appears for energetic/synthwave-leaning material.
- The author deliberately avoids the DAW default: "I try NOT to play at 120 BPM as often as I can." [Day 28]
- Long-form pieces may **change tempo (and key) between major sections/scenes**. [Diary #14]

### 3.2 Meter

- **Default: 4/4.** Odd meters are a documented, idiomatic option: 3/4, 5/4, 5/8, 6/8, 7/8 (see §9.3 for exact subdivision/accent math).
- **Meter changes happen only at bar ends** (quantized pattern launch) — never mid-bar. [Odd Meters]
- A common alternative to changing meter: stay in 4/4 but run loop lengths of 6 eighth-notes ("put a three feel on top of a four"). [Day 09]

### 3.3 Subdivision and swing

- **Default pulse: straight eighth notes**, played through a dotted-eighth delay (§9.1). [Metropolix] [Step Record]
- **16th notes** are the busier variant (pulsing basslines, energetic pluck patterns). 32nds appear only as a fix when a 16th part feels "plodding". [Pulsing Basslines] [Omnisphere 3]
- **No swing.** "Berlin School is quite mechanical… it is so metronomic, Berlin School is clockwork." Swing exists in the world but is rare in the style; a generative sequencer should default swing to 0. [Odd Meters]
- Constant, unvaried velocity is historically authentic (classic sequenced synth-pop had zero velocity variation) — but the modern practice documented here uses velocity structurally (§11.1). [Synth Nerds] [Ableton Move]

---

## 4. Tonality: Scales, Modes, and the Interval Tension Model

### 4.1 Scale as data structure

A scale is **a list of semitone offsets from a root** (e.g. natural minor = `0, 2, 3, 5, 7, 8, 10`; the author demonstrates inventing a scale as `0, 3, 5, 7, 10, 12`). Key = root + scale. Scale degrees are numbered 1–7 (8 = octave); chord progressions are lists of degree numbers. [Grid Controllers] [How To Get Started]

### 4.2 The mode palette (observed usage)

| Mode | Frequency in corpus | Stated character |
|---|---|---|
| **Natural minor** (C minor default, also A, Bb, D, Eb, F minor) | Dominant teaching/working default | "A little dark, a little sad, works for space music" |
| **Dorian** (C, D, E, F) | Very common | "Bottom half minor, top half major — ambiguous"; forced via scale device |
| **Phrygian** (C, D, F) | Common for dark/cosmic | "Minor feel… it just sounds spacey"; "dark space music, cosmic feel" |
| **Mixolydian** (G, A, Bb) | Common for brighter material | "Major with the 7th down a half step" — reads as 1985 synth-pop |
| **Lydian** (D, E) | Occasional | Bright, floating |
| **Lydian dominant** (Eb) | For sci-fi/space | "Raised 4th, lowered 7th — a lot of flat-five intervals; this makes space music" |
| **Harmonic minor** (A, C) | Occasional | Neoclassical/Bach tonality (≡ Phrygian dominant a 5th below) |
| **Minor pentatonic** (C) | For generative systems | "Really easy to get everything to not be dissonant" — the safe constraint scale for random output |
| **Locrian** (F) | Rare, deliberate | "Cthulhu school" — dark on the root; moving the tonal center off-root yields surprisingly pretty passages |
| **Major** | Rare (deliberate 80s-cheese outlier) | Happy |

Recommendation encoded in the corpus: default a generator to **natural minor**, offer Dorian/Phrygian/Mixolydian as first-class alternatives, and pentatonic as the safety mode for high-randomness settings.

### 4.3 The root is home base

- Every pattern **starts on the root** (its first *sounding* note; the pattern may begin with a rest). [Uncomplicated Approach]
- Voices "meander off the path but come back" — returning to the root itself functions as an accent. [Step By Step Guide] [Beginner Essentials]
- While other voices touch the root, the bass is freed to move away from it (and vice versa). [There Are No Wrong Notes]

### 4.4 The interval tension model ("there are no wrong notes")

All harmony is modeled as **semitone distance between simultaneous notes on a consonance–dissonance spectrum**. Music = deliberately riding tension up and releasing it. "There are no wrong notes, only tension added and relieved." [There Are No Wrong Notes] [Grid Controllers]

| Interval (semitones) | Name | Tension score (0 = max release) |
|---|---|---|
| 0 / 12 | unison / octave | 0 — always safe |
| 7 | perfect 5th | 0–1 — "like a power chord, almost always safe"; the workhorse |
| 5 | perfect 4th | 1 — mild |
| 3 / 4 | minor/major 3rd | 1–2 — consonant |
| 8 | minor 6th | 2 — fairly consonant |
| 9 | major 6th | 3 — adds tension in minor |
| 2 | major 2nd | 4 — tense |
| 10 | minor 7th | 4 — special: "wants to resolve up to the octave — standing on the edge of a cliff, then you fall back home" |
| 6 | tritone | 5 — dissonant ("devil's interval") |
| 1 | minor 2nd | 5 — maximum tension |

Usage rules:

1. **Scoring rule for a generator**: when two or more voices sound simultaneously, evaluate the vertical intervals against this table. Many stacked tense intervals ⇒ mutate one pattern's notes toward safer degrees. [Step By Step Guide]
2. **Sustained simultaneities matter most** — fast alternation relaxes the rules (even minor 2nds are fine when notes alternate quickly, e.g. the *Jaws* figure). [There Are No Wrong Notes]
3. **Cluster vs. spread**: clustered voicings = tension; spreading the same pitch classes across octaves dissipates it. Softening trick: move the most tense note **up an octave** — tension kept, harshness removed. [How To Get Started] [Music Making Diary #4]
4. **Worked tension-walk examples**: melody from root → leap minor 6th (mid tension) → perfect 5th (release) → perfect 5th (full release): "start, add a little tension, relieve it, relieve it again — that's why it sounds good." In A minor over an A pedal: F adds tension, E resolves it; hold the tense note slightly longer, then resolve down. [Grid Controllers] [Building Melodies]
5. **Out-of-key notes are budget items**: allowed "maybe once or twice" per piece as deliberate events. Extreme documented case: an entire piece in Bb minor with a single sustained A natural (minor 2nd against the root) as the one climax moment — it works *because* the piece trained the ear to the key first. [Step By Step Guide] [Plog #14]

---

## 5. Sequence Construction (The Pattern Layer)

This is the heart of the style. All recipes below produce **one voice's pattern**; §6 and §10 describe how patterns combine.

### 5.1 Pattern anatomy

- **Grid**: 1 bar of 16 sixteenth-note steps, mentally grouped 4×4, is the canonical frame ("most 16-step sequencers are 16th notes and you'll have four groups of four"). Historic sequencers had 4/8/16 steps — small is idiomatic. [Beginner Essentials]
- **Content lengths in practice**: 3-note minimum figures; 1.5-beat, 1-bar, 2-bar, 4-bar, 8-bar clips; pads use longer clips (4+ bars) than plucks (1–2 bars). [Step By Step Guide] [Sub 37]
- **Note pool per pattern**: root-heavy. Archetypes: root–5th–root-octave (the classic "group of three"); root + octave jumps; root + ONE other degree (a 3rd, 4th, or 5th, often displaced an octave up — e.g. root-root-root + 3rd-an-octave-up, a 10th). [Odd Meters] [Berlin/Prog Jam]
- **Register span**: a pluck line covers about **two octaves**, moving around with space left in it ("so it won't be constant arpeggiation"). [Day 30]
- **Gate length**: short by default. Sequencer step width 40–99%; raw generated notes should default very short (60–120 MIDI ticks) with note length applied as a separate post-processing parameter. Short gates + delay = the style; long/legato gates are reserved as a modulation lane (§11.4). [Step Sequencer] [Drunkard's Walk]
- **Bass ceiling / octave fold**: constrain each voice to a register window; notes exceeding the ceiling **wrap down an octave** (never clamp) — keeps wide arpeggios harmonically valid. [Day 24] [One Synth Minitaur]

### 5.2 The seed procedure (canonical beginner algorithm)

The corpus's most explicit pattern-generation algorithm [Beginner Essentials]:

```
1. Choose key (e.g. A minor), tempo, 1-bar 16-step grid.
2. SEED: place the root note on the downbeat of each group of four
   (steps 1, 5, 9, 13) — four quarter-note roots.
3. MUTATE, one edit at a time, auditioning continuously:
   a. Move one or two notes left/right in time (±1–2 steps).
   b. Move some notes to other scale degrees (stay in key).
   c. Add one note an octave above the root.
   d. Adjust velocities (accents — see §11.1).
4. KEEP what pleases; the root notes anchor the pattern
   (they may be moved or deleted later, but start from them).
```

### 5.3 The High/Mid/Low three-voice recipe

A complete three-voice starter system [High Mid Low]:

```
Three voices — high, mid, low — each a 1-bar, 16-step loop,
all seeded as quarter notes on steps 1, 5, 9, 13, all on the root (C in C minor).

HIGH: raise note 2 (step 5) up a 5th → G; drop note 4 (step 13) to the G below
      → contour C G C G. Later: shift the step-5 note forward in time and
      pitch it DOWN a 5th.
MID:  "stair steps" — raise the 2nd note up a 5th, drop the 4th note down a 5th
      (up-down contour). Keep steps 1 and 9 as the root, exactly on grid.
LOW (bass): DELETE the notes on beats 2 and 4; keep ONLY beats 1 and 3.
      The bass anchors the downbeat while other voices phase (§6).

TIMING RULE: steps 1 and 9 (beats 1 and 3) stay LOCKED to the grid;
the backbeats (steps 5 and 13) are the mutation zone — move them
forward/backward in time (~half a beat) and up/down in pitch.

All voices: dotted-8th delay + large reverb.
```

### 5.4 The "Uncomplicated Approach" (the distilled 7-step algorithm)

The author's business-card version of the whole style [Uncomplicated Approach]:

```
1. Pick a scale; use only its notes (any octave).
2. Make a simple repeating pattern STARTING ON THE ROOT
   (demo: 16 steps ≅ 4 beats; notes C, G, C, rest, C, Eb).
3. Put gaps in the pattern — fewer notes is better; the empty space
   is where other voices will sing.
4. Layer voices: a voice = one synth + small repeating pattern + delay + reverb.
   Use distinct timbres per voice ("two different people singing").
5. Use DIFFERENT PATTERN LENGTHS simultaneously (e.g. 4 beats vs 7 beats;
   mix even and odd lengths) → the layered voices form the phasing "BED".
6. Play bass and lead melodies over the bed (a bassline is just a very low
   melody; demo bass walks roots C → Ab → F).
7. Advanced: at any instant (bed + bass + lead) = an implied chord that adds
   or releases tension; change note choices per section to shift the mood.
```

### 5.5 The pulsing 16th-note bassline

For the driving synthwave-adjacent variant (Knight Rider / later Tangerine Dream) [Pulsing Basslines]:

```
1. One bar of 16 straight sixteenth-notes, ALL on the root.
2. Velocities low; gate slightly short (not clicky-staccato, not legato).
3. Mutate a FEW notes: up an octave, down an octave, or a few scale steps —
   the majority must stay on the root ("the groove is C").
4. Every note pulled off the root gets a RAISED velocity (accent).
5. Make 2–3 clip variations the same way; cycle them.
6. No dotted-8th delay on this one — it is straight 16ths (light delay+reverb ok).
7. Harmonic movement via global diatonic transposition on top (§7.1).
```

### 5.6 The staged 16th-note pluck build

For a denser, hand-written 4-bar pattern [Plog #14]:

```
1. Root only, syncopated, as "home base" (the emotional anchor).
2. Add octave jumps of that root.
3. Fill between the octaves with other scale notes.
4. Use the high register for "little micro-melodies" / short runs on top.
5. End the pattern with one distinctive closing note — "the signature".
Length: 4 bars of 16ths. Double the whole track +1 octave (unison layer).
Dotted-8th delay throughout.
```

### 5.7 Growth by duplication ("duplicate and tweak")

To extend any 1-bar pattern without losing identity [Beginner Essentials] [Building Melodies]:

- Replicate ×4 (or ×8) → a 4/8-bar pattern.
- **Leave repetitions 1–2 untouched; change only 1–2 notes in the 3rd and/or 4th repetition.** The variation now recurs every 4th/8th bar instead of every bar.
- Anti-repetition at production level: any loop repeated many times gets printed out and hand-varied on the 3rd/4th of every 4 phrase repeats — mute a few notes, hold one, tweak selection. [Music Making Diary #4]

### 5.8 Accents (velocity as pattern structure)

Accents are first-class pattern data [Odd Meters] [Beginner Essentials]:

- Accent = higher velocity (patch responds louder AND brighter — see §11.1); alternative accent mechanisms: modulation hit, or return-to-root.
- **Accent count changes the character**: 1 accent/bar = settled groove; 2 = "a little more urgent"; 3 = different feel again.
- Accents **on** beats = grounded; accents **between** beats = syncopation. Alternating on/off-beat accents is the classic Berlin feel (the root–5th–octave group-of-3 cycling over 4/4 does this automatically).
- **Variation operator: keep the notes identical, move only the accents** — "you get a completely different feel while still being related."

### 5.9 Arpeggiators as pattern generators

Documented arpeggiator configurations that produce idiomatic patterns:

- **Down, octave distance 12, 1 step, Retrigger = Note**: hold a chord; each new melody note retriggers the arp from that note, letting a played melody ring through the arpeggio. Retrigger-on-note is the crucial setting. [K-2 Arps]
- **One-note chord expansion chain**: single held note → chord device (+12, +19 semitones) → arpeggiator (rate, gate, octave range) → scale-force device (e.g. Dorian) → pluck. An entire in-key bed from a one-note clip. [Ableton Intro]
- **A whole bed in one chord**: arpeggiate D–E–F–A + low D + low A (D minor sus2 voicing) — "that for me is a Berlin School bed in one chord." [Diary #8]
- **Two arps at a 2:1 rate ratio** (quarter notes vs half speed) locked in sync. [Space Pad]
- **1-octave arp layered with a 3-octave arp** from the same held notes — interlocking registers. [Diary #9]
- **5 held notes against 4/4** = instant polymeter (the arp cycle runs contrary to the beat). [Berlin/Prog Jam]
- **Random arp across 3 octaves** on a fixed clip = shimmering in-key variation. [Idea Machine]
- Holding an interval (2 notes) through a 3-octave arp interleaves both notes into a compound pattern. [Day 08]
- Hand-played "arps" are preferred where possible — human variations, then quantize. [Day 15]

### 5.10 Cascaded sequencers ("sequencer math")

Small step counts multiply [Step Sequencer Math] [Sub 37]:

- A 4-step sequencer at a slow rate (half notes) feeding its pitch output as a **transposition offset** into a second 4-step sequencer at a faster rate = a 16-step composite (4×4). Shorten the slow one to 3 steps → a 12-step composite.
- Generalized: "sequence your sequencers — one sequencer controls the root note of a secondary looping sequencer."
- In modular: sum the pitch CVs. In a DAW: additive pitch devices.

---

## 6. Note Phasing and Polymeter (The Variation Engine)

Phasing — running near-identical patterns at different lengths or offsets — is the style's signature **deterministic generativity**: enormous variation with zero randomness. It is the single most documented technique in the corpus.

### 6.1 Length-mismatch phasing (Reich-style)

The master recipe [Timelord] [Beginner Essentials]:

- Duplicate a 16-step pattern; **shorten the copy to 15 steps**. Both start in unison, drift by 1 step per loop, traverse every offset, and re-sync — **15 automatic variations from one pattern**.
- A **14-step copy** gives 7 variations (steps through offsets twice as fast, skipping odd ones).
- Any length works; lengthening works too; cutting a note off mid-loop is fine.
- The composite repeats at the **LCM of the loop lengths** — choose lengths for the cycle duration you want.
- **Harmonic safety**: both layers use the same notes/key, so collisions stay musical. Caveat: long melodic sequences that traverse the key can produce clashes — audition and nudge individual offending notes. [Timelord]

Documented length pairings:

| Layer A | Layer B (C) | Source |
|---|---|---|
| 16 steps | 15 steps | [Timelord] |
| 16 steps | 14 steps | [Timelord] |
| 8 bars | 7 bars, 6 bars (trio) | [Day 06] |
| 4 beats | 7 beats | [Uncomplicated Approach] |
| 4 bars | 3.5 bars (all four clips truncated at once) | [Idea Machine] |
| 4 bars | 3 bars (half-density duplicate) | [One Synth Prophet 12] |
| 8 bars + 1 beat | 8 bars, start point moved to beat 4.5 | [Ambience Generator] |
| 8-step | 13-step | [Synth Stacking] |
| 6 eighth-notes | 4/4 context ("three feel on top of four") | [Day 09] |

Rule of thumb: **mix even and odd lengths**. [Uncomplicated Approach]

### 6.2 Start-point rotation

Duplicate a 16-step pattern, play both, **shift the copy's start point by 2 steps** (or start on step 3/5/7/9…). Hardware equivalent: the shift/rotate function. Gives phased counterpoint immediately, without the drift of length mismatch. If one specific pair of notes clashes, move one of them. [Timelord]

### 6.3 Chord-tone polymeter

Build three *different* simple patterns from the notes of a triad — pattern 1 = rhythmic root notes (C), pattern 2 = 3rds (E), pattern 3 = 5ths (G) — with lengths **16, 24, and 19 steps**, layered. Long-cycle syncopated counterpoint that "never sounds wrong" because the union is always the triad. [Timelord]

### 6.4 Gate/pitch decoupling

Run **two parallel sequences per voice: a pitch list and a gate list, with different lengths** [Gate and Pitch] [Gate+Pitch 2]:

- 8-step pitch + 6-step gate → re-sync every 24 steps (LCM).
- Demoed pairings: 7-vs-8, 3-vs-8, 6-vs-8; try gate lengths 3, 5, 7 against pitch 8 for long composite periods.
- Gate length 2 against a constant pitch = simple alternation.
- Result "sounds random but it's not — you get a repeating pattern so your ears won't get bored with pure randomness."
- **Layered-gate bass variant**: two bass voices share ONE pitch sequence but have different 8/16-step gate patterns. Rationale: layering different *pitches* in the bass register gets muddy; layering only gate patterns over shared pitches keeps the low end unified. [Diary #14]

### 6.5 Phasing in the modulation and effects domain

- **Delay-rate phasing**: voice 1 carries a quarter-note delay, voice 2 a dotted-8th delay; even if the voices never sound simultaneously, their echo tails weave a polyrhythmic texture. [Alternating Melody]
- **Two clock-synced LFOs at different divisions** (8ths vs dotted-8ths) on one filter = a syncopated composite rhythm with no notes at all (full recipe §11.3). [Rhythmic Patterns by Layering LFOs]
- **Slow-cycle modulation as long-period phasing**: LFO cycles of 16/32/64 bars against an eighth-note pattern (§11.2). [Microfreak LFOs]

### 6.6 The anchor rule

Phasing destroys the perceived downbeat. Therefore **the bass keeps beats 1 and 3 locked to the grid** (or a kick drum supplies a quarter-note "heartbeat") so the listener never loses the meter while upper voices drift. [High Mid Low] [Uncomplicated Approach]

### 6.7 What phasing does and doesn't do

The phased bed is quasi-endless background ("the illusion of repetition without being repetitive"), and micro-melodies emerge from the collisions — but **the bed does not create harmony or melody by itself**. A bass line must be added to "force a harmonic pattern, a chord progression, an implied melody" on top (§7.2), and a lead supplies the foreground (§8). [Day 06]

---

## 7. The Harmony Engine: Transposition, Reharmonization, Implied Chords

Berlin School harmony is **static/modal by default** — a pedal point on the root — with movement produced by three mechanisms, in order of prevalence:

### 7.1 Global diatonic transposition (the primary mechanism)

The architecture, identical in software and hardware [Key2Mod] [Chord Progressions] [Idea Machine]:

```
For every sequenced voice:
    [pattern] → [pitch shift (transpose), default 0] → [SCALE QUANTIZER (working key)] → synth

A single master control transposes ALL voices simultaneously
(±12 semitones typical range); the scale quantizer folds every
result back into the key = diatonic transposition.
Hardware equivalent: CV offset summed into a quantizer;
Metropolix "pitch pre-quantize" input; Teletype reading a held key.
```

Rules that make it work:

- **Patterns must be written root-heavy** ("play a lot of root notes… a fifth is totally safe; don't play long melodies and chord changes" in transposable patterns). Simplicity is what makes transposition sound like harmony instead of chaos. [Jamuary 25] [Idea Machine]
- Transposing the whole bed **reads to the listener as a chord change / new section**: "people think you've changed the patterns when you're only transposing them in real time." [Jam With Hardware]
- **Progressions = transposition sequences read as Roman numerals.** Documented sequences (degrees of the key):
  - `1 – 4 – 5 – 1` (i–iv–v–i) [Chord Progressions]
  - `1 – 7 – 6 – 5` [Chord Progressions]
  - `1 – 5 – 6 – 7` [Chord Progressions]
  - `1 – 6 – 4 – 7` [How To Get Started]
  - `1 – 6 – 4 – 1` (i–VI–iv–i), voiced in bare fifths, 108 BPM [Day 29]
  - `7 – 5 – 6` (very "80s") [Jamuary 01]
  - `1 – ♭7 – 6 – ♯5` (walk-down; the ♯5 pulls back to the root) [Day 04]
  - `6 – 5 – 4 – 1` walk-down as the B-part tear-jerker; a walk-**up** as the C-part tension builder [Day 20] [Four Tracks]
  - Published pop-progression lists (Hook Theory) are explicitly endorsed as transposition source material; borrowed/familiar progressions are legitimate ("the Four Chord Song phenomenon"). [Chord Progressions] [Ate Their Song]
- **Timing**: harmonic surprise budget ≈ "every 8 or 16 bars I want something new." Transposition targets are chosen from learned character ("which degrees sound sweet vs dark") — implementable as a weighted table over degrees 1–7. [Diary #3] [Berlin/Prog Jam]
- **Sequencer-follows-performer variant**: a script reads the held key each clock tick, takes the pitch class (mod 12), and re-roots the running sequence to it — the octave stays owned by the sequencer. [Matriarch]

### 7.2 Bass reharmonization (the second mechanism)

Keep every upper pattern static and **move only the bass root** — the bass forces the perceived chord [Metropolix] [Day 24] [Mellow Berlin School]:

- Classic use: a C-minor sequence made to feel major/"happier" for a B part purely by the bass note, then returned home.
- Documented bass walks under static beds: `C → F → Eb`; `C → Ab → F` (+ walk-up); `A → D → C` (coordinated across pattern layers while pad and lead stay in A minor). [Mellow Berlin School] [Beginner Essentials]
- Bass notes are **held long; no fast runs** while reharmonizing. [Day 24]
- This works because the upper patterns are root+5th-heavy: "because it's only roots and fifths within the key, we can play a lot of things over top of that."

### 7.3 Implied chords (the third mechanism)

Full comped chords are rare. Harmony is *implied* vertically by 2–3 monophonic lines [Music Making Diary #2] [Theory #5]:

- **Dyads over the ostinato**: pads play two-note intervals implying triads — e.g. an implied `i → III → VII` drift over an unchanging root–5th ostinato. [Mellow Berlin School]
- **Shell chords**: a second instrument plays only the 3rd + 7th; root implied by the bass, 5th omitted, the arpeggio fills in the rest. [Music Making Diary #2]
- **Favorite interval shape: the minor 10th** (minor 3rd + octave), moved diatonically through the scale degrees. [Jamuary 01]
- **Chord construction rule** (when triads are needed): stacked thirds — take the degree, skip one scale note, take the next, skip one, take the next. Voice-lead by octave-displacing chord tones so adjacent chords share pitches and stay in register. [How To Get Started]
- When comped stabs ARE used, they are thick — "a lot of sevenths and ninths." [Building Tracks #4]
- **Analysis trick**: merge all MIDI layers onto one piano track to inspect the composite implied chords; audit vertical intervals with the §4.4 table. [Theory #5]

### 7.4 Harmonic rhythm and form-level harmony

- Chord-generator layers change every ~7 bars (see §13.3); transpositions every 8–16 bars; sections may sit on a pedal far longer.
- **A-part = pedal on the root; B-part = the progression** (the emotional payoff). [Day 20]
- **Modal chains in long form**: successive themes each in a different mode/key (documented chain: G Mixolydian → G Phrygian → C minor → Bb Mixolydian → F Dorian → F minor → final key change up), meter changes marking the seams. [Production Log #6]
- **Minimal-change aesthetic**: one documented track's only harmonic event is the lead duplicated up a fifth and layered at the final crescendo. [PLOG #13]
- Escape-and-return: a bridge that walks down **out of the key** (ending on a non-diatonic note) creates a strong pull; resolve by re-entering on the root chord. [Mellow Berlin School]

---

## 8. Melody Generation

### 8.1 The velocity-accent extraction algorithm (melody from pattern)

The corpus's most mechanical melody generator [Building Melodies]:

```
1. Take a running 1-bar repeating figure on a velocity-sensitive pluck.
2. Drop ALL note velocities to near-mute.
3. Pick 3–4 notes and RAISE their velocities → an accented proto-melody emerges.
4. Curate:
   - Prefer accents ON the beat over adjacent syncopated positions.
   - If two accents are adjacent, move one in time to create space.
   - Hold a tense note slightly longer, then resolve down (A→F held, resolve to E).
   - Avoid accenting only root and 5th ("real safe… doesn't move me") —
     move some accents to the 7th and other degrees.
   - All edits scale-folded (stay in key).
5. Duplicate to 2 bars; in bar 2 INVERT the accent selection
   (lower what was raised, raise others), vary pitch/time,
   push one accent up an octave ("walk up").
6. Duplicate to 4 bars; change only 1–2 things
   (one pitch, one accent moved from off-beat to on-beat).
7. Optional promotion to a true lead: copy the clip to a lead instrument,
   DELETE all quiet notes, LENGTHEN the survivors (legato).
```

An emergent variant: place accents on a moving set of pitches (A, B, C, D across a bar) inside a repeating pattern — the accent path *is* the melody. [Odd Meters]

### 8.2 The conversation model

Melody = speech, with breathing [Mellow Berlin School] [Day 11] [How To Get Started]:

- An 8-bar melody is **two 4-bar phrases**, the second a near-repeat with a one-note variation. Within each phrase a short rhythmic cell repeats. Leave a gap ("breathe") around measure 4. "The space between notes and length of held notes is like breathing — you exhale when you speak, inhale when you stop."
- **Repeat the RHYTHM, not necessarily the pitches**: on new harmony, keep the phrasing contour and let the pitches follow the chords.
- **Repeat pitch-identical melodies with a timbre change** — "that's enough to drive interest."
- Phrase-end escalation devices: keep a syncopated pattern for ~3 of 4 measures, then break into a 16th-note run in measure 4; groups-of-three ascending cells (1-2-3, 1-2-3, mostly rising, flipped at phrase ends). [Music Making Diary #2] [Mellow Berlin School]
- Tension staging: held notes landing only on off-beats ("the ands") escalate; resolve with a wash-down run; switch the run's subdivision from 16ths to dotted-8ths for the final resolution. [Mellow Berlin School]

### 8.3 Alternating melody (two-voice conversation)

A core named technique [Alternating Melody] [Day 15] [Diary #5]:

- **Two timbrally distinct voices in the same key, arranged so they NEVER play simultaneously**: voice A speaks, gap, voice B answers in the gap, forever.
- Because they never overlap, vertical dissonance management is unnecessary; only their **delay tails** interact (give them different delay rates — quarter vs dotted-8th — so the tails weave, §6.5).
- Variant ("the twins"): one voice plays an energetic run then HOLDS; the other runs during the hold; swap; occasionally converge into counterpoint. Two leads alternate all song, then **play together only at the finale**. [Plog #14]
- Phrase source trick: hum the phrase, convert audio→MIDI; the pitches will be wrong but the conversational *rhythm* is captured — then drag notes to correct scale pitches. [Alternating Melody]

### 8.4 Bass melodies

"Bass lines are melody lines" [How To Get Started] [Metropolix] [Plog #14]:

- Start with bass = chord roots (e.g. degrees 1-6-4-7) an octave down; then add **scale passing tones between the sustained roots** (from 1 walk down through 7-and-6's neighbors to reach 6, etc.).
- The bass simultaneously does the reharmonization work (§7.2) — melody and harmony in one lane.
- "The interesting stuff happens in the intervals between the bass and the melody" — bass and high melody "talk to each other." Register rule: when upper layers get busy, the bass simplifies to roots only. [Music Making Diary #4]
- Bass accent idiom: a repeated root figure with **one lower-neighbor note (whole step below root) near the pattern end, resolving immediately back** — tension added and instantly resolved; also vary the rhythm slightly only at the very end of the pattern. [Mellow Berlin School]

### 8.5 Improvisation rules (for a lead-note picker)

- Stay in scale; chord tones an octave or two up **always** fit; non-chord scale tones "sort of work" or add usable tension; accidentals are strong events (budget: §4.4). [How To Get Started] [Beginner Essentials]
- Play in the **holes** of the sequenced patterns (the composed gaps). [Step By Step Guide]
- When the main line holds a long note, that is the counter-melody's slot. [Diary #3]
- Play less: thin the line out; "be a little circumspect." [One Synth Prophet 12]
- Repetition makes the hook: noodling without repetition is "the epitome of not doing anything repetitive enough to start an ear worm." Establish a figure, then vary. [Day 30]
- **Motif reuse for cohesion**: extract a strong melodic/rhythmic motif from one section and restate it (even in harmonically unrelated sections) later — callbacks are structural glue. [Music Making Diary #4] [Theory #5]
- 4-bar melody lengths over a transposing bed are typical; 8 bars preferred over 16 (a 16-bar melody was tried and rejected as too long). [Berlin/Prog Jam] [Day 05]

---

## 9. Rhythm, Delay-as-Rhythm, and Odd Meters

### 9.1 The delay IS the rhythm section

The single most idiomatic sound: **straight 8th notes through a dotted-8th (3/16) delay** = the "ducka-ducka" double-time bounce. [Step By Step Guide] [Metropolix] [everywhere]

- Delay time formula: `dotted_8th_ms = (60000 / BPM) / 4 × 3` (e.g. ≈ 478 ms at 94 BPM; per-16th ≈ 159 ms).
- Typical settings: ping-pong, ~50% feedback, ~50% wet, **high- and low-cut on the repeats** so echoes recede into the distance.
- Feedback semantics: 0 = single echo; near/above 100% = self-oscillation, usable as a playable tension parameter, or as a looper (feedback→0 empties the buffer — a natural voice-exit gesture). [Beginner Essentials] [Step By Step Guide]
- **Don't over-duck**: with two dotted-8th layers already running, give the bass a plain 8th-note delay instead — inaudible on static pitches, but note changes smear like glide. [Day 15]
- Other documented delay assignments: quarter-note delay on sustained tones; dual delays (dotted-8th + half-note-plus-dotted-quarter) stacked; L=16th / R=8th slightly offset stereo pair. [Ableton Intro] [Ambience Generator]

### 9.2 Percussion

Drums are minimal, functional, and late:

- **Kick as heartbeat**: four-on-the-floor or quarter-note kick purely as a downbeat anchor under phasing layers. [Step By Step Guide] [Odd Meters]
- Composition happens without drums ("I don't make beats first"); a single placeholder loop runs through the whole composing phase and is replaced per-section at production time; rhythm changes at every story/section change. [Diary #6] [Ableton Move]
- Alternatives to a kit: percussive/chug bass patches driving the pulse; rhythmic gating of pads; dual-LFO filter pulsing (§11.3); taiko-style single hits on downbeats ("heartbeat" under the bass); riser+boom sample pairs at section transitions. [Alternating Melody] [Plog #14]
- 4/4 drums may be deliberately laid over a 6/8 bassline as a cross-meter tension device (see below). [Building Tracks #4]

### 9.3 Odd meters (exact subdivision math, all at 96 BPM, 8th-note patterns, kick on quarters)

[Odd Meters]

| Meter | Grid | Groupings / accents | Character |
|---|---|---|---|
| 3/4 | six 8ths (16-step sequencer: last step = 12) | accents on 1 (or 1+3 quarters) | waltz, lurching |
| 6/8 | six 8ths | accents on **1 and 4** (equal halves); 2-bar unit: **3+3+6** (=3+3+2+2+2); alt: 1 and 5 | steady rolling gait, gallop ("at sea / riding a horse") |
| 7/8 | seven 8ths | **4+3** or **3+4** (or 2+2+3 / 3+2+2); 2-bar units: (3+4)+(4+3), or **3+3+3+5** across the two bars | limping drive |
| 5/4 | ten 8ths | **3+3+4**, or **6+4 / 4+6** | asymmetric flow |
| 5/8 | five 8ths | **3+2** ("1-2-3 1-2") | compact limp |

Rules:

- Accents go on group starts; the same notes with accents moved on-beat vs. syncopated = two different patterns (§5.8).
- **Meters can switch freely mid-piece (4/4 → 6/8 → 7/8 → 3/4 → 5/4 → …) as long as tempo and the kick pulse stay constant and the switch happens at a bar end.**
- Cross-meter layering: 6/8 gallop bass + 4/4 four-on-the-floor on top "turns the piece on its head"; removing the drums reverts the feel. A planned pairing: one jam in 7/8 and one in 6/8, same key, combined into a piece that alternates meters. [Building Tracks #3] [Day 06]

---

## 10. Voice Architecture and Layering

### 10.1 The canonical voice roles

Every documented jam/track reduces to these roles (4-voice minimum, expandable to 12+):

| Role | Function | Typical content | Register |
|---|---|---|---|
| **Bed pluck 1** | The sequence; the style's identity | 1–4-bar root-heavy pattern, 8ths, dotted-8th delay | mid |
| **Bed pluck 2** | Phasing partner | Same key, different length AND different timbre | mid, often +1 octave |
| **Bass** | Anchor + reharmonizer | Beats 1&3, or 8th/16th pulse; roots; long notes when reharmonizing | low (fold above ceiling) |
| **Pad / chords** | Implied harmony, slow layer | Dyads / shells; 4+ bar clips, longer than the plucks | mid-high, slow attack |
| **Lead** | The voice; melody / improv | Conversational phrases in the gaps | high, can be bone dry |
| **Drone** (optional) | Continuity job | One held/arpeggiated note or fifth, timbre-modulated | very low (or very high texture) |
| **Rhythm** (optional) | Heartbeat | Kick/hat, or percussive chug patch | — |

- **Minimum viable set**: 2 plucks + bass + lead ("four tracks is enough"); or even 2 textures ("slowly-modulating plucks + a slow swelling lead — with these two sounds you can do a lot of the groundwork"). [Four Tracks] [Sound Design]
- **The 4-register generative stack**: drone / low / mid / high — identical machinery per voice, only seed clips and loop lengths differ. [Follow Actions]
- **Pads are shapes, drones are jobs**: a pad = an envelope shape (soft attack, sustain, soft release); a drone = the *job* of holding continuity, typically low, slow attack, ~5 s release, heavy reverb, and mandatory slow timbre modulation. Anything can do the drone job. [Snark Time]
- **Orchestral-monophonic principle**: the ideal is 10–14 *monophonic* lines in different registers/timbres whose sum forms the polyphony — orchestral writing applied to synths. [Plog #15]

### 10.2 Register and timbre separation rules

- **One job per octave region**: "spread things out across the octaves and give something a job in each area — and sometimes leave areas sparse." Colliding parts get moved down/up an octave until each sits alone. [Diary #5] [D-Major Quicky]
- **Bass density inverse rule**: when the mid/high layers get busy, the bass simplifies to roots only. [Music Making Diary #4]
- **Timbral differentiation is mandatory between bed plucks**: hollow vs. brassy, square vs. saw, different filter darkness — "similar, not exactly the same, contrasting." Two similar plucks may instead be panned hard L/R. [Day 15] [One Synth Minimoog]
- **EQ enforces roles**: leads get lows rolled off; plucks live mid/upper (they get metallic up high — don't use them as bass); basses own the low end alone; sub layers forced to mono. [Plog #14]
- Depth staging: per-voice reverb amount = distance ("more room reverb = further away"); leads can be fully dry to sit in front. Delay = motion; big reverb = the shared space. [Day 15] [Beginner Essentials]

### 10.3 A full-scale case study (12-layer architecture)

One completed track's inventory, as a maximal reference [Plog #14 — "Cas X-1"]:

pad (constant harmonic pattern) · soft CS-80-style lead · hard PW-unison lead (+octave swell layer; alternates phrases with the soft lead, unison only at the finale) · pluck 1 (hand-written 16ths, doubled +1 octave) · pluck 2 (8th-note arpeggiation) · skitter pad (internal arp, huge reverb) · "chaos twins" texture (two identical synths hard-panned, one Haas-delayed 2.873 ms, small-room reverb — keeps running through breakdowns) · static low drone · drone + taiko downbeat heartbeat · main melodic bass (3-octave saw stack, loud, never ducked) · rhythm/chug bass acting as drums · sparkle arp (+5th, bridge only) · riser/boom FX at transitions.

### 10.4 Layer entry/exit order

Documented build orders converge on: **bed pluck 1 → bed pluck 2 → (pad) → bass → lead last**, with drums/rhythm inserted late if at all. Exits mirror entries (strip one voice at a time; end on the lone starting pattern). [Day 15] [Putting It All Together] [Berlin/Prog Jam]

---

## 11. Modulation as Part of the Sequence (Velocity, CC, LFO Doctrine)

A Berlin School sequencer emits more than notes: velocity, gate length, and CC lanes are compositional data. Rule zero: **timbre modulation is mandatory** — "the sounds you're using [should be] modulating their timbre over time… it's going to carry you a long way to that cosmic sound." [Beginner Essentials]

### 11.1 Velocity semantics

Velocity is the style's main per-step expressive channel:

- **Velocity → filter cutoff / brightness** is the canonical patch mapping: accent = louder AND brighter. A patch "dependent on velocity to open its filter up" makes the velocity lane the per-step filter automation. [Pulsing Basslines] [Diary #11] [Day 19]
- **Velocity → envelope attack time, inverted** (soft hit = slow swell, hard hit = snap) — the author's #1 expressivity mapping. [Use MIDI Velocity]
- **Velocity → wavetable position ("hocketing")**: each velocity picks a different timbre, so every note of an arpeggiation sounds like a different instrument; combine with velocity randomization. [3rd Wave]
- **Humanization numbers**: normalize all velocities (~100), then randomize within **±20** (documented range 80–100). Whole layers are velocity-lowered to sit back in the mix. Deliberately disabling velocity→amp on bass (level consistency) is also documented. [Building Tracks #3] [One Synth Blofeld]
- Accents are encoded purely as higher velocity values in the author's shared MIDI packs. [Odd Meters]

### 11.2 The slow-LFO doctrine

The characteristic Berlin School motion is **very slow modulation of timbre**, always tied to musical time scales:

| Rate | Cycle length | Documented target |
|---|---|---|
| ~0.02 Hz | minutes | wavetable position, wavefolding ("the effect of a riser without doing a filter sweep") [Super Slow LFOs] |
| 0.04 Hz | 32–64 bars | oscillator timbre CC sweep [Microfreak LFOs] |
| 0.07 Hz | ~15 s+ | effect amount (16th-note chopper fading in/out over a sustained pad) [Space Pad] |
| 0.1 Hz + 0.3 Hz pair | tens of seconds | drone: PW, sync, dual filter cutoffs [Drone] |
| ~10 s/cycle | phrase-scale | full wavetable travel on pads [Iridium] [Deep Space Pads] |
| 4–8 s envelope | phrase-scale | bandpass sweeps (attack 5–8 s, decay 9–11 s) on pad layers [Nord Wave 2] |

Principles:

- Modulation cycles should align with musical units — "hear the 3–4 repetitions of the eight-bar line have a changing timbre over the course of those 32 bars." [Synth Nerds]
- **Free-running (unsynced) slow LFOs are a feature**: each repeat of an identical pattern gets a slightly different attack timbre. [Jam With Hardware]
- **Modulate the modulator**: LFO2 → LFO1 rate (warble accelerates/decelerates); a falling saw/decaying envelope on an LFO's speed = starts fast, slows down; cycling envelopes (rise 5 s / fall 5 s) on LFO rate. [Modulation Examples] [Berlin Pads A1] [Cosmos Pad]
- Depth discipline: constrain LFO depth so the target never pegs at its rails; set depth first, then the center point. When auditioning any modulation target, always also try the slowest possible rate before rejecting it. [One Synth Minitaur] [Super Slow LFOs]

### 11.3 Rhythmic modulation recipes (sequencer-emittable)

- **Dual clock-synced saw LFOs on filter cutoff** — the pulsing-pad recipe [Rhythmic Patterns by Layering LFOs]: organ envelopes (0 attack/decay, full sustain, 0 release); cutoff low (~9 o'clock), env amount ~2 o'clock; LFO1 (falling saw, synced, **reset on note**) → cutoff at **8th notes**; LFO2 same → cutoff at **dotted 8ths**. The sum = a syncopated pulse that replaces percussion. Try other division pairs.
- **S&H stepping timed pre-strike**: a random/S&H LFO stepping a timbre CC **every 8th note, phase-offset so the value change lands just before each note attack** (never mid-note). [Microfreak LFOs]
- **Random pan per 8th note**, also phase-advanced ahead of the attack so position snaps before the note strikes; keep the reverb static where the note sounded. [Diary #10]
- **LFO start-phase control**: reset-on-note with start phase 45–90° so each note begins with the filter high. [One Synth Blofeld]
- **Square LFO → pitch** as a rhythmic figure ("fire engine"); **random LFO → osc2 pitch at 8th-note rate** for industrial sync-bass motion. [Diary #6] [Moog Minitaur]

### 11.4 Gate length as a modulation lane

With a slow-release (~0.5–1 s) filter envelope, **note duration alone sweeps the timbre** — no CC data needed [PLOG #9]:

```
Duplicate a 1-bar pluck pattern to 8 bars; program note lengths as a ramp:
bars 1–2 short gates (filter stays closed/dark) → bars 3–4 longer →
bars 5–6 longer still → bar 7 near-legato (filter fully opens) →
bar 8 back to short. The pattern's own gate lane is the filter sweep.
```

Related: legato/retrigger interaction — non-retriggered envelopes make held runs progressively quieter/darker (a designable behavior); gate width 40–99% as a live parameter. [Minimoog Part 3] [Step Sequencer]

### 11.5 CC automation as part of the clip

- Map a timbre knob (e.g. wavetable position) to a free CC (documented: **CC14**) and **draw the CC envelope inside the MIDI clip** so timbre motion loops with the pattern. [Iridium]
- Clips can carry device-state changes (the Follow-Actions engine sequences its own Looper record/play states via clip envelopes — arrangement-level state as clip data). [Follow Actions]
- Mod-wheel/aftertouch/pedal curves should be drawn into sequenced parts ("draw in your velocity curves, your mod wheel or pedal or aftertouch curves"); every panel knob on CC-rich synths is scriptable mid-song. [Nord Synths]
- Gain automation for sectional voice swaps (exact numbers): voice A rides at −3 dB, dips to −8 dB at the section midpoint, climbs back; voice B simultaneously pushed +4 dB — implemented on a utility gain stage, never the mixer fader. [Diary #6]
- Aftertouch: poly AT = per-note pressure; channel pressure = monophonic, **largest value wins**. Used for vibrato and filter expression, sometimes on only one of two layers so the layers phase against each other. [Poly AT] [Prog/Rick Bass]

---

## 12. Structure and Arrangement

### 12.1 The macro model

A Berlin School piece is **the performance of a pattern pool over time**. "The arrangement is deciding: am I going to build this up, go through them like clockwork, jump around, when do I change them, can I play over them — and how am I going to *generatively* move from pattern to pattern, what are the triggers." [Beginner Essentials]

- **Additive layering, then subtraction**: build layers until the urge to remove appears; then strip, introduce a new progression/section, re-add old material, and finally remove everything gradually to close. [Jam With Hardware]
- **Long-form scale**: sections/scenes last **5–10 minutes each** in performance, with **tempo and key changes between scenes**; complete pieces run 4–20 minutes; long pieces chain 8–10 themes with transitions. [Diary #14] [Production Log #6]
- **Change budget**: something should change every 8–16 bars ("the eight-bar rule"); for ambient-leaning Berlin School the author literally sets a 1-minute timer as a change prompt ("every 8 bars is a bit fast for me — Berlin School, slow it down"). [PLOG #13] [Exploring Modular Jam]

### 12.2 Section grammar

- **A part**: sits on the root (pedal harmony), bed + minimal voices.
- **B part**: the contrast/payoff — the progression enters (e.g. the 6-5-4-1 walk-down), or a syncopated bass hook replaces the ostinato.
- **C part / bridge**: walk-up or out-of-key walk-down; "takes us away from the root so that when we go back to the root it feels good."
- Alternate A/B (each scene played ~2× before switching); a bookend (restating the opening material) closes the form. [Four Tracks] [Day 20] [Mellow Berlin School]

### 12.3 A complete arrangement map (9-section case study)

[Mellow Berlin School] — a full deconstruction worth encoding as an arrangement template:

```
Intro: section-1 material pared down (pads + lead hint, no rhythm)
S1: ostinato + implied-chord dyad pads + soft conversational melody
S2: same ostinato/chords; soft lead OUT, bass IN (root pedal), bright lead IN
S3: same ostinato, NEW bassline implying new chords (C→F→Eb), driving rhythm;
    melody restated soft, then repeated with bright timbre + low counterpoint
S4 (B): ostinato and pads DROPPED; syncopated off-beat bass hook; both leads
    in unison building off-beat tension; drum change (phased hats);
    dotted-8th resolution run
S5 (C/bridge): walk-down progression LEAVING the key (ends outside);
    plucks step the chord roots downward; leads hold 4th-apart harmonies;
    established repetition deliberately falls apart at section end
S6: resolution — broken C7 chord; ostinato out; plucks mimic the melody;
    bass enters only in the final measure as a pickup
S7: same progression, rhythm section + driving bass return
S8: same again + rock drums + melody doubled with bright lead = the payoff
    (S6→S7→S8 = ADDITIVE REPETITION: same material, more instrumentation each pass)
S9: bookend — restatement of S2
Outro: ostinato thins to just the root; pads resolve; one final clean
    lead statement; fade
```

### 12.4 Live/generative arrangement models

- **Spiral evolution** (live looping): build 8–12 layered loops one instrument at a time (beat → bass → chords → harmony → lead); when full, return to slot 1 and record a *variation* while the rest keep playing; accumulate rows of variations in passes; finish by re-triggering **older patterns against newer ones** as motif callbacks. [Live Performance]
- **Scene-based**: prepare related-but-different scenes (intro/A/B/outro); changes should be "neither jarring full-stops nor unrelated new ideas." Pattern switches always quantized to bar ends; sequencer stage-count changes (§13.5) and bass-note changes mark sections. [Push 3] [Metropolix]
- **Transitions**: give entering loops a lead-in before the boundary and a tail with one final hit after it; riser + boom pairs at every transition; an "emotional drop" = one last drum hit, then the bass drops out entirely (a come-down, not an EDM drop). [Diary #5] [Plog #14]
- **Endings**: strip layers one at a time to the lone starting pattern; thin the ostinato until only the root remains; fade; or bookend. "End it while you're having fun with it." [Berlin/Prog Jam] [Mellow Berlin School] [Covid Sessions]

### 12.5 The idea pipeline (workflow, relevant to dataset design)

Capture-then-mine is the universal workflow: improvise freely with retrospective MIDI capture always on → extract 2/4/8-bar loops (keep odd-length fragments — "something in seven laid over something in four sounds pretty awesome") → assemble ~10 scenes mostly on one root → transpose scenes into progressions → arrange. Repetition inside the improvisation (velocities maxing out as flow sets in) marks the gems. [Diary #1] [Diary #3] [Mining]

---

## 13. Generative Systems: Complete Documented Algorithms

These are the corpus's fully specified generative engines, presented as implementable algorithms.

### 13.1 The Follow-Actions engine (generate → legitimize → regenerate)

The most complete generative arrangement system in the corpus [Follow Actions]:

```
SETUP (per voice; 4 voices: drone / low / mid / high, all pluck patches
       with heavy delay + reverb):
  - A stack of SEED clips: sparse 2–4-bar patterns, 3–5 notes each
    (some just 1–2 notes), all C minor pentatonic.
  - One completely BLANK clip (a legal "rest" choice → voice drops out
    for one cycle).
  - MIDI chain: Random device → Scale device (C minor pentatonic) → synth.
  - A Looper (or equivalent record/repeat buffer).

MUTATION: every incoming seed note has a 30% chance of being shifted by
  a random amount up to ±12 semitones; the scale device folds any result
  back into the key. Optional additional per-note play probability (e.g. 50%).

CYCLE (the "repetition legitimizes" loop):
  1. A seed clip plays ONCE through the mutation chain; the Looper records it.
  2. The recorded variation then loops 3 more times (4 total) —
     "it becomes a hook."
  3. Follow action: jump to a RANDOM OTHER clip in the stack
     (possibly the blank one). Repeat forever.

ARRANGEMENT EMERGES from:
  - Different loop lengths per voice (2-bar vs 4-bar seeds; 32/64-bar seeds
    for ambient; or short clips × 16/32 repeats) → §6 phasing at form level.
  - Stack ordering as a DENSITY CURVE: sparse/quiet clips at one end,
    busy at the other, so clip choice shapes intensity.
  - Optional harmonic labels on seed stacks (this stack = I, this = I-IV-V)
    so random choices stay compatible.
  - A human (or higher-level process) can override at any time by launching
    specific clips or soloing on top.
```

Follow-action vocabulary available as arrangement primitives: nothing / stop / play again / previous / next / first / last / any (incl. self) / other (not self) / jump-to-scene, each with two candidate actions + a probability slider + a loop-count trigger. [Follow Actions]

### 13.2 The Drunkard's Walk note generator

The author's own M4L device, hardware-equivalent to Teletype `drunk` / Wogglebug [Drunkard's Walk]:

```
PITCH RULE: next note constrained to ± scatter semitones from the previous
  note (scatter = 2 → from C only B♭, B, C♯, D reachable); direction random.
RHYTHM RULE: non-metronomic — play, pause a random-ish interval, play;
  bursts and rests cluster naturally (target the "pleasing distribution of
  slow and fast hit groups vs rests"; pure uniform randomness explicitly
  sounds bad — "large sections of nothing and sections of too much").
RANGE: lowest note (default C3) + octave span (default 3 → C3–C6).
OUTPUT: raw chromatic, very short notes (60–120 ticks).
POST-CHAIN: note-length processor → scale quantizer (e.g. minor pentatonic)
  → synth (simple sine/triangle pluck) → echo + reverb.
CHORD-FOLLOW MODE: held notes (e.g. C+G, or a D-minor triad) restrict output
  to exactly those pitch classes across the range — feed it a chord-progression
  clip and the walk follows the harmony.
HARVESTING (the human/curation stage): record the stream; select any slice
  ≥ 1 bar; loop it ("by the third loop you can feel the groove — repetition
  validates"); shorten overlapping notes; quantize to 16ths; keep the good ones.
```

### 13.3 The probabilistic chord generator (one note in, chord out)

A stochastic harmony layer over deterministic ostinatos [Ambience Generator]:

```
1. Source clip: a single root note (C) sounding ~4 bars, resting ~3 bars
   (≈ 7-bar harmonic rhythm).
2. 80% probability: transpose the note by a random +1..+12 semitones.
3. Scale-quantize the result to the working mode (C Phrygian).
4. Stack a chord on it: +4, +7, +12 semitones (root/M3/P5/octave shape).
5. Re-quantize all chord tones to the mode.
→ A different diatonic chord on every trigger, always compatible with the
  static ostinato layers underneath.
```

### 13.4 The layered slow-modulation generative bed

A complete hands-free bed with exact modulation math [Microfreak LFOs]:

```
1. Arpeggiator plays 8th-note plucks (latch/hold mode).
2. LFO1 (S&H/random) → oscillator SHAPE CC: steps to a new value every
   8th note, phase-offset to land just BEFORE each note strike.
3. LFO2 → oscillator TIMBRE CC: 0.04 Hz ≈ one cycle per 32–64 bars
   (a continuous slow timbral sweep).
4. LFO3 → ARP STYLE: cycles through ~4 styles on a fixed 16-bar period
   ("the styles change but not randomly").
5. Post-arp MIDI: 10% chance a note is shifted up 0–2 scale steps,
   then a scale quantizer (F minor) corrects everything.
6. Audio: chance-based beat-repeat micro-fills (slightly detuned stutters) →
   compressor (levels the timbre-driven loudness swings) → space echo →
   shimmer reverb.
```

### 13.5 The Metropolix bed (arrangement = active stage count)

Deterministic sequencer-level arrangement [Metropolix]:

```
- One 8-step, 8th-note sequence; the stage PITCHES are pre-tuned and NEVER change.
- The performance parameter is HOW MANY STAGES ARE ACTIVE: start with 2,
  then 3, 4 … 8. Each stage-count change = a new pattern from the same pitch
  data; used as the A/B section switch.
- Sequencer reset is driven by the master clock at the bar, so stage-count
  changes always re-lock cleanly at the next bar.
- Harmonic movement: bass reharmonization only (§7.2) — e.g. a C-minor
  pattern forced to feel major by the bass note.
- Further variation sources: accumulators (per-loop incremental pitch drift),
  intermittent ratchets (occasional per-step retriggers, not constant),
  and CV-recallable transposition snapshots.
```

### 13.6 Supporting generative principles

- **Interval-weighted transposition policy**: learn/encode which scale-degree transpositions sound "sweet" vs "dark", then choose targets from a weighted table over degrees 1–7 — effectively a Markov policy for §7.1. [Berlin/Prog Jam]
- **Euclidean sequencers inside clips**, constrained to the shared key, as unpredictable-but-safe pattern sources for live arrangement. [Live Performance]
- **Pattern scrambling across instruments**: rotate which voice plays which existing pattern (3 clips × 3 instruments = 9 combinations) — a cheap combinatorial variation generator. [Just Play Push] [Four Tracks]
- **Octave-fold and start-point/length sub-selection** (§5.1, §6.1–6.2) as legal mutation operators on any existing pattern.
- **Random octave displacement**: take a plain 8th-note line in a 2-octave range and shift quasi-random notes ±1 octave, spreading it across 3–4 octaves. [Microfreak]
- **Humanization policy**: quantize-on-record + hand-clean; velocity randomization ±20; slight off-grid timing is tolerated and even valued ("syncopation called bad timing") — but NO swing, and drums may be fully mechanical. [Building Tracks #3] [One Synth Blofeld]
- **Constraint philosophy**: a generative project needs *some* constraints (one scale, N voices, one oscillator each) — "no constraints = aimless wandering; too many = blocked." [Buy More and Innovate]

---

## 14. A Reference Pipeline for a Generative Berlin School Sequencer

A synthesis of everything above into one ordered pipeline — each stage cites the section that specifies it.

```
STATE
  key/root, mode (§4.2; default: natural minor)
  tempo (§3.1; default 85–100 BPM), meter (§3.2; default 4/4), swing = 0 (§3.3)
  voices: [bed1, bed2, bass, pad, lead, (drone), (rhythm)] (§10.1)
  scale_quantizer(key, mode) applied at the END of every voice's pipeline (§2 Law 2)

1. PATTERN GENERATION (per voice)
   seed = roots on beats (§5.2) | high/mid/low contours (§5.3) |
          pulsing 16ths (§5.5) | drunkard's walk + harvest (§13.2)
   mutate: move backbeats in time/pitch, octave jumps, scale-degree moves,
          sparsify (Law 3), accents (§5.8), velocity lane (§11.1)
   constraints: root-anchored, ≤2-octave span, octave-fold at register
          ceiling, short gates (§5.1)

2. PHASING LAYER (the variation engine, §6)
   assign UNEQUAL loop lengths across voices (mix even/odd; 16 vs 15/14;
   8/7/6 bars) or rotate start points; optionally decouple gate/pitch
   sequence lengths per voice; keep bass beats 1&3 (or kick) as the anchor

3. LEGITIMIZATION LOOP (Law 1, §13.1)
   any newly generated/mutated pattern plays 4× verbatim before the next
   mutation/regeneration; blank cycles are legal voice exits

4. HARMONY SCHEDULER (§7)
   default: pedal on root; events every 8–16 bars:
   - global diatonic transposition through a progression (weighted degree
     table; e.g. 1-7-6-5, 1-6-4-7) via pitch-shift → scale-quantize
   - OR bass-only reharmonization under static upper layers
   - optional stochastic chord layer on a ~7-bar cycle (§13.3)
   - out-of-key notes: budget ≤ 1–2 per piece, climax placement (§4.4)

5. MELODY (§8)
   velocity-accent extraction from a running pattern (§8.1), or
   conversational two-voice alternation (§8.3); phrase = 2×4 bars with
   breathing; tension-walk note choice scored by the §4.4 interval table;
   bass = roots + passing tones (§8.4)

6. MODULATION EMISSION (§11)
   velocity → filter/brightness per accent; gate-length ramps (§11.4);
   slow CC lanes (0.02–0.07 Hz equivalents; 16/32/64-bar cycles);
   S&H CC steps timed pre-strike; per-clip CC envelopes (e.g. CC14)

7. ARRANGEMENT STATE MACHINE (§12, §13.1, §13.5)
   additive build (bed1 → bed2 → pad → bass → lead) → variation passes
   (spiral evolution) → B-part event (progression/new bass/meter change,
   always at bar boundaries) → additive-repetition payoff → subtractive
   ending to a single voice; density curve controls intensity;
   change something every 8–16 bars (or ~1/minute for ambient)

RENDERING NOTES
   all voices: tempo-synced delay (dotted-8th default; plain 8th on bass)
   + reverb depth per role (§9.1, §10.2); drums minimal (§9.2)
```

---

## 15. Sound Design Quick Reference (Patch Archetypes)

Secondary to sequencing, but a generative system that addresses synths (via CC or presets) should know the target archetypes. "Do not agonize over sound design… creativity comes down to the notes you pick and how you arrange them." [Uncomplicated Approach] [Snark Time]

- **Berlin pluck (the fundamental patch)**: 1–2 saws (or thin square), slight detune (~0.03 / 5 cents); low-pass with cutoff down, envelope amount up; filter env: 0 attack, ~250 ms–1.3 s decay, 0 sustain; a touch of resonance. Always into dotted-8th delay + large reverb. Variants: hollow (square) vs brassy (saw) for the two bed voices. [Sound Design] [Roland Bass Pluck]
- **Pad framework** (~80% of pads): slow attack, slow decay, long release on BOTH amp and filter envelopes; 2 detuned saws; big hall reverb. Variants: string pad (LP12, no resonance, filter never fully opens); horn pad (LP24 + resonance "wah"); Jarre ensemble strings (bandpass + ensemble chorus); modern evolving pad (wavetable scanned ~10 s/cycle). Bandpass filters are favored "especially for Berlin pads". [Deep Space Pads] [Berlin Pads A1]
- **Bass**: Moog-style — 3 saws stacked 16'/8'/4' (top one +7 semitones for a power-chord stack), overdriven mixer, low cutoff, slow triangle LFO on cutoff; or sampled Rickenbacker + Taurus-style 2-osc sub one octave below (sub slow-attack, mono, swells under held notes). Chorus + plain 8th delay, little/no reverb. [Minimoog Breakdowns] [Prog/Rick Bass]
- **Lead**: soft CS-80-style swell (lows EQ'd out) vs hard PW-unison lead with glide — a pair that alternates phrases; sync-osc leads with envelope→sync pitch; leads may be fully dry. [Plog #14] [Day 15]
- **Drone**: sub pair an octave (or two) down, slightly detuned; or one held/arpeggiated note through heavy delay+reverb; mandatory slow timbre modulation (LFO breathing a mostly-closed filter). [One Synth Minitaur] [Snark Time]
- **Effects doctrine**: chorus/ensemble (width) → tempo-synced delay (dotted-8th default; band-limited repeats so echoes recede) → stacked reverbs (room = placement/depth, hall = the stage, "black-hole"/shimmer = the cosmos). This chain "turns a dry mono pluck into a Berlin voice." Modulating the reverb tail itself (chorus/phaser after reverb) is idiomatic. [Microfreak] [ESQ-1] [Ambience Generator]
- **Signature space gestures**: ring-mod frequency swept by hand from 0 Hz into audio rate and back ("space whales"); pitch-bend dives through shimmer reverb; PPG-style wavetable sweeps ("those Tangerine Dream sounds"); hard-synced saw = the mid-80s TD lead identifier. [Space Whales] [3rd Wave] [Nord Wave 2 TD Patch]

---

## 16. Parameter Defaults Cheat Sheet

| Parameter | Default | Range / alternatives | Source |
|---|---|---|---|
| Tempo | 90 BPM | 77–141; core 85–100 | §3.1 |
| Meter | 4/4 | 3/4, 5/4, 5/8, 6/8, 7/8; switch at bar ends only | §3.2, §9.3 |
| Swing | 0 (none) | — ("Berlin School is clockwork") | §3.3 |
| Subdivision | 8th notes | 16ths (pulsing variant) | §3.3 |
| Key/mode | C natural minor | Dorian, Phrygian, Mixolydian, Lydian (dom.), pentatonic for high randomness | §4.2 |
| Pattern grid | 1 bar / 16 steps | 3-note minimum figures up to 8-bar clips | §5.1 |
| Notes per pattern | 3–7 (sparse) | blank clips are legal | §5.1, Law 3 |
| Pattern pitch pool | root-heavy; root+5th+octave; +one interval | ≤2-octave span; octave-fold at ceiling | §5.1 |
| Gate length | short (40–60%) | 40–99%; gate ramps as modulation | §5.1, §11.4 |
| Phasing lengths | 16 vs 15 steps | see §6.1 table; mix even/odd | §6.1 |
| Repeats before regeneration | 4 (1 generate + 3 repeats) | 16/32 for short clips | Law 1, §13.1 |
| Mutation probability | 30% chance, ±12 st, scale-folded | + optional per-note chance; NO bare per-step probability | §13.1, Law 1 |
| Random-walk scatter | ±2 semitones | range C3 + 3 octaves | §13.2 |
| Harmonic event period | every 8–16 bars | ~7-bar chord layer; ~1/min ambient | §7.4, §12.1 |
| Transposition targets | weighted degrees 1–7 | documented progressions §7.1 | §7.1 |
| Out-of-key budget | 1–2 notes per piece | m2 against root as climax | §4.4 |
| Velocity | normalize ~100, randomize ±20 | accents = velocity + brightness | §11.1 |
| Accents per bar | 1–2 | 1 = settled, 2 = urgent, 3 = different feel | §5.8 |
| Delay | dotted-8th, ping-pong, ~50% fb/wet, filtered repeats | plain 8th on bass; quarter on sustained | §9.1 |
| Slow-mod cycle | 32–64 bars (≈0.04 Hz) | 0.02–0.3 Hz family; 10 s wavetable travel | §11.2 |
| Voice count | 4 (bed×2, bass, lead) | up to 12+; drone/pad/rhythm optional | §10.1 |
| Section length | 8–16-bar changes; 5–10-min scenes | tempo+key change between scenes | §12.1 |

---

*Compiled 2026 from Synth Seeker channel transcripts (`docs/synthkeeper/`, ~225 files). Citation tags reference shortened video titles; consult the transcript filenames for the full titles and YouTube IDs.*
