# Changelog

## 1.2.5 — 2026-10-24

- Per-voice MIDI channel (user request): click the **ch N** label in a
  voice lane and pick channel 1–16 — also while playing (what still sounds
  on the old channel is silenced). Channels already used by another voice
  show its name. Saved with the project; capture export follows.

## 1.2.4 — 2026-10-22

- Fixes from a project audit:
  - Stop, mute and switching the MIDI output now silence long notes (a
    drone kept sounding until its planned end).
  - EXT clock and Link keep working after a project change or template
    load (EXT could stop following until the app was restarted).
  - Capture export after a second, shorter take no longer returns the old
    take or a mix of both.
  - Opening a broken document (two voices with the same id, impossible
    meter or tempo) shows why instead of crashing the app.
  - `berlinan-cli render` of a project with the arranger on now exports
    what the app plays (voice entries, B-part, ending).
- MIDI output device (user request): the output label in the transport
  bar is now a menu — keep the virtual source "Berlinan Out" or send notes,
  CC and clock straight to a connected device (DIN interface, USB synth,
  IAC bus). The choice is remembered; an unplugged device shows
  "disconnected" and resumes when plugged back in.
- Fix: the templates menu was disabled while playing, so 1.2.3's
  "templates load while playing" could not actually be used. The menu now
  opens mid-jam.

## 1.2.3 — 2026-10-22

- Templates load while playing (user feedback): pick one from the
  templates menu mid-jam and it takes over at the next bar — the clock
  keeps running (MIDI clock, Link and EXT stay in phase) and the new piece
  starts from its beginning. The horizon strip announces it. Before, the
  menu silently did nothing while the transport ran.

## 1.2.2 — 2026-10-22

- Voices are named by role in the UI (user feedback): lanes, menus, the
  horizon strip, the Delay Cheat Sheet and the pattern editor say
  Pluck 1, Pluck 2, Bass, Pad, Lead, Drone, Heartbeat instead of internal
  ids like "bedPluck1". Exported MIDI track names are unchanged.
- "1 bar" instead of "1 bars" in the horizon strip and the LCM readout.

## 1.2.1 — 2026-10-21

- Bass melody walks are seeded now (user feedback): regenerate and New
  Seed produce a NEW walk telling the SAME harmony — downbeat roots stay
  the progression's law; the seed shapes the path, syncopation and octave
  dips. Deterministic voices (drone, heartbeat) disable their regenerate
  button and say why.
- Distribution: the DMG is notarized again, and the app inside it is
  notarized and stapled on its own too (timestamped Developer ID signature,
  pipeline aligned with MDPre).

## 1.2.0 — 2026-07-18 (M6 — the long piece)

Trust and dramaturgy: the app narrates what it is about to do, and a piece
can carry the genre's long-form arc.

- Horizon strip: one timeline of everything coming — pending key/density/
  B-part/tension binds, the arranger's phase countdown, the nearest
  mutation due; lanes the arranger holds back say WAITS instead of going
  silently dark (plus manual engine-level voice on/off)
- Drone intro: a `.drone` voice opens the arranger's build — the piece
  starts as a plateau, sequences enter over it
- Slides: tie steps stretch to legato at render (mono synth + portamento =
  the classic glide); opt-in per project so 1.1 documents render
  byte-identically; glide hints in the Delay Cheat Sheet
- CC scenes: named timbre destinations morphed over bars — manually
  (SCENE menu) or by the arranger's phases (Build closed → Payoff open);
  stateless, chunk-safe, silent once settled
- Form presets (right-click AUTO): classic arc, slow build, ambient
  plateau — and the reprise: the bed-entry theme returns at the payoff,
  progression resolving home with it (M §12.3 additive repetition)
- Template gallery: Demo trio / Full ensemble / Ambient drift one click
  away (always a fresh seed), plus Save as Template…
- New example: `examples/full_ensemble.berlinan` — the whole 1.1 palette

## 1.1.0 — 2026-07-18 (M5 — arranger & polish)

The app learns to arrange a whole piece by itself — and to grow melodies.

- Arranger autopilot (ARR · AUTO): a state machine walks Build → Bed →
  Variation → B-Part → Payoff → Subtract → End, orchestrating voice entries
  (additive build order), mutations, blank cycles, the closing roots-only
  bar, and a clean self-stop. Advisory by design: OFF by default, every move
  is also a button, ">>" advances by hand (MIDI-learnable), and it adopts a
  running jam without restarting it
- Density macro (DENS): a deterministic per-loop note cap — accents survive
  first, then on-beat notes; the arranger raises it at the payoff and thins
  on the way out
- Ambient mode: ~1 change per minute and 16-play legitimization — the
  patient, generative-radio variant (set while stopped)
- B-part (B): the manual's S4 move as one trigger — a progression walk
  lands in the schedule, the bass regenerates, the bed optionally drops
- Melody extraction (♪ on a lane): mute all, raise 3–4 curated accents
  (on-beat preferred, never adjacent, never root+fifth-only), then the
  manual's clock — 2-bar accent inversion, one-note growth every 4 bars
  scored by the interval tension table (tense → release → release);
  toggle off restores the groove verbatim. "Promote Melody to Lead" copies
  the line to a lead voice, legato and locked
- Alternating scheduler: two voices in complementary 4-bar phrase slots,
  guaranteed never simultaneous (echoes included); call and answer get
  different delay-hint divisions
- New generators: bassMelody (progression roots + stepwise passing tones),
  chordLayer (§13.3 — one sustained in-key chord per ~7 bars), heartbeat
  (quarter-note kick)
- Tension budget (T·n): 2 out-of-key allowances per piece — a sustained
  minor 2nd against the root through the engine's only quantizer bypass

## 1.0.0 — 2026-07-15 (M4 — sync & integration)

First release. Berlinan is open source under GPL-2.0-or-later.

- MIDI delay: engine-side echo notes per voice (toggle live, next-bar bound),
  with the Delay Cheat Sheet warning when both digital echoes and an audio
  delay would stack
- Seed freshness: every session opens a new musical universe; the dice
  button (new seed) swaps universes at the next bar, undoable
- Runtime tempo and key changes while playing, bar-quantized (piecewise
  clock segments; degree-space re-rooting keeps every voice in scale)
- MIDI clock slave (EXT): follows Start/Stop and tempo of incoming MIDI
  clock — median-of-9 + EMA tempo estimator, per-wake segment re-anchor
- Ableton Link (LINK): tempo and bar-phase lock to the local-network
  session via the vendored GPLv2+ abl_link wrapper; peer count in the
  transport bar; joins the network only while LINK is selected
- MIDI learn: "Berlinan Control" virtual destination; LEARN mode binds a
  controller CC/note to play/stop, degrees 1-7, re-roll, new seed, and
  snapshot slots; bindings persist in Application Support
- Drag & drop: a voice lane's pattern strip drags into Ableton (or Finder)
  as a bar-aligned, LCM-looped .mid clip
- Synth CC profiles: built-in Generic and Microfreak maps plus user JSON
  profiles; applied per voice from the lane context menu
- App icon, README, GPL licensing (mirrors Ableton Link's dual license)

## 0.3.0 — 2026-07-14 (M3 — musical depth)

The full manual toolkit lands in the engine and the UI.

- Harmony modes: progression player with the manual's preset walks,
  weighted-random transposition ("sweet vs dark"), bass reharmonization
  with held roots; harmony strip with upcoming-event chips
- Generators 4-6: drunkard's walk, staged pluck (signature closing note),
  arpeggiator expansion with cycle-length loops (native polymeter);
  decoupled gate/pitch patterns (8v6 -> re-sync at 24)
- Modulation output: CC LFO lanes in musical time (bars, not Hz) with
  stateless delta filtering, S&H pre-strike, gate ramps, per-voice CC maps;
  Delay Cheat Sheet window (per-voice audio-delay settings at live tempo)
- Legitimizer plus: Metropolix accumulators, configurable ratchet policy
  (+ live/export ratchet consistency fix), state snapshots with 6 UI slots
  (recall at next bar), undo (Cmd-Z) over generative actions
- Pattern editor (hand edits lock and persist), project settings sheet
  (key/mode/BPM/meter presets), .berlinan documents (open/save incl.
  snapshot slots and hand edits)
- Deferred by user decision: MIDI delay echo notes (FR-MOD-7 -> M4)

## 0.2.0 — 2026-07-14 (M2 — "it plays")

First usable jam tool. Berlinan publishes a virtual MIDI source ("Berlinan
Out"), plays the built-in demo project live with sample-accurate timestamps,
and acts as MIDI clock master.

- Live engine: pull-model renderer with quantized actions (transpose,
  regenerate, blank cycle, lock); byte-equivalent to the offline renderer
- CoreMIDI runtime: virtual source, timestamped sends, note registry + flush
  (nothing ever hangs), MIDI clock 24 PPQ + Start/Stop
- Scheduler: 25 ms wake / 150 ms lookahead / clock-timestamp jitter ≤ 1 ms
- UI: transport bar (POS/BPM/KEY/DEG), voice lanes with live pattern strips,
  per-voice playheads (phasing visible), lifecycle dots, mute/lock/
  regenerate/blank, degree buttons 1–7, re-roll, convergence readout
- Capture: rolling ~60 min buffer; export the last 8/16/32/64 whole bars as
  a bar-aligned multitrack .mid

## 0.1.0 — 2026-07-14 (M1 — headless engine)

- Degree-based musical core (scales, resolution, octave fold, quantize)
- Generators: seed procedure, high/mid/low, pulsing bass
- Phasing ops + LCM convergence; legitimizer (Law 1); diatonic transposition
- SMF type-1 writer; `berlinan-cli render` with golden-master suite
