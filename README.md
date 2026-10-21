# Berlinan

A generative MIDI sequencer for macOS in the **Berlin School** tradition —
Tangerine Dream, Klaus Schulze, Michael Rother-era motorik patience. Berlinan
does not play notes for you to audition; it runs a small ensemble of
sequencer voices that repeat, phase against each other, and earn their
mutations over time, exactly the way a hardware modular jam does.

Berlinan is a MIDI instrument, not a DAW: it publishes a virtual MIDI source
(**Berlinan Out**) and you point synths — hardware or Ableton Live tracks —
at its channels. Audio never touches it.

Website and download: https://jiripisa.github.io/berlinan/

![Berlinan](Resources/AppIcon.png)

## The style laws (why it sounds right)

The engine encodes the genre's rules from `berlin_school_manual.md`, distilled
from ~225 hours of synthesist interviews and breakdowns:

- **Repetition legitimizes.** A pattern must play verbatim before it may
  mutate; every mutation re-earns its place.
- **Scale-lock.** All voices speak one scale; transposition is degree-based,
  so harmony moves as a single organism.
- **Phasing.** Voices run unequal loop lengths (7 vs 5 vs 6 steps) and drift
  against each other, converging on the LCM — the "same but never the same"
  shimmer.
- **Sparseness, no dice-rolls.** No per-step probability, no swing. Change is
  scheduled and quantized to bars, never random per note.

## Quick start (musician)

1. `./run.sh` (or open the built app). Press **space / ▶**. Berlinan plays
   its demo ensemble immediately — every session in a fresh musical universe.
   The **templates menu** (grid icon) offers starting points: *Demo trio*,
   *Full ensemble* (chord-layer pad, bass-melody walk, heartbeat kick, a
   lead ready for melody promotion — channels 1–5 + 10) and *Ambient drift*
   (drone-led, ~1 change/min, a filter journey mapped to the arranger).
2. In Ableton Live: create MIDI tracks, set input to **Berlinan Out**,
   channels 1–3 (Pluck 1, Pluck 2, Bass — the built-in ensemble; your own
   projects can add pad, lead, rhythm voices), arm + monitor In.
3. Jam surface:
   - **Degrees 1–7** — diatonic transposition at the next bar.
   - **Dice** — new seed, new universe (undoable, ⌘Z).
   - **Re-roll** — regenerate every unlocked voice.
   - **B** — the B-part move: progression + new bass (+ bed drop), one press.
   - **T·n** — spend a tension allowance: one sustained out-of-key stab.
   - **Slots 1–6** — snapshots (⌥-click saves, click recalls at next bar).
   - **ARR · AUTO** — the arranger autopilot: builds the piece voice by
     voice (a drone opens it when present), varies it, fires the B-part,
     returns the theme at the payoff (reprise), subtracts, and ends on a
     roots-only bar — advisory, so every move stays yours (">>" advances by
     hand; right-click AUTO picks the form: classic arc / slow build /
     ambient plateau). **DENS** thins or fills the whole mix; the moon
     toggles ambient mode; **SCENE** morphs the mapped CCs toward a named
     timbre over 8 bars.
   - The **HORIZON strip** narrates what is coming — pending changes, the
     arranger's countdown, the nearest mutation due; held-back lanes say
     WAITS.
   - Per lane: mute, lock, regenerate, blank cycle, pencil (hand edit),
     echo (MIDI delay), **♪ melody extraction** (3–4 curated accents that
     evolve; right-click promotes the line to a lead voice, or sets two
     voices alternating in 4-bar call-and-answer).
4. **Delay is the genre's reverb**: open the **Delay Cheat Sheet** (Window
   menu) and set your audio delays to the printed times, or toggle the lane's
   echo button for engine-side MIDI echoes — the sheet warns when both stack.
5. Sync: **INT** (Berlinan is clock master), **EXT** (follows MIDI clock —
   enable Live's Sync OUT to Berlinan), or **LINK** (Ableton Link over the
   local network; tempo and bar phase lock both ways).
6. **Capture**: the last hour is always recorded — export the last N bars as
   a multi-track `.mid`, or drag a lane's pattern strip straight into a Live
   clip slot.
7. Hands off the laptop: **LEARN** binds controller CCs/notes (aim them at
   the **Berlinan Control** input) to play/stop, degrees, dice, re-roll and
   slots.

## Build & run (no Xcode IDE)

Requires the Xcode command-line toolchain (`xcode-select --install`) on
macOS 14+.

```sh
./build.sh            # debug build -> build/debug/Berlinan.app
./run.sh              # build + launch
./build.sh release    # optimized bundle
./build.sh dist       # release + codesign + notarized DMG (needs Developer ID)
swift test            # 311 tests
swift run berlinan-cli render examples/demo_project.json --bars 64 -o out.mid
```

`dist` requires a Developer ID identity and the `notary` keychain profile
(see `development_workflow.md` §2.3); without the identity it aborts.

## Documentation map

| Document | What it is |
|---|---|
| `berlin_school_manual.md` | The style bible — normative theory the engine implements |
| `basic_concept.md` | Product concept from the musician's chair |
| `generative_sequencer_spec.md` | Requirements (FR-IDs), architecture, data model |
| `design_language.md` | Studio-dark visual system, tangerine accent |
| `development_workflow.md` | Build pipeline, branch/TDD methodology, release |
| `.planning/` | Roadmap, per-phase plans and verifications |
| `CHANGELOG.md` | Release history |
| `docs/` | Product website (GitHub Pages) |

## Architecture (short version)

Three strict layers: **BerlinanEngine** (pure Swift, deterministic,
tick-based, zero Apple frameworks — golden-master tested), **BerlinanRuntime**
(CoreMIDI, scheduler with 150 ms lookahead and timestamped sends, clock
master/slave, Link), **Berlinan** (SwiftUI, a 30 Hz read-only mirror of the
engine plus action dispatch). The same engine renders live and offline, so
what you export is what you heard.

## License

GPL-2.0-or-later — see `LICENSE`. The vendored
[Ableton Link](https://github.com/Ableton/link) library (`Vendor/link`,
git submodule) is GPLv2+; Berlinan mirrors its license.
