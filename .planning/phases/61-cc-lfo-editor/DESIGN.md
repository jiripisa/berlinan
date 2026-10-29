# Phase 61 — CC LFO editor (design)

Approved in conversation with the user on 2026-10-29. Mockups (not shipped):
`.superpowers/brainstorm/45425-1793102725/content/cc-lfo-strip-v3.html` and
`cc-lfo-browser-v4.html`.

## Intent and why

The engine already plays CC LFOs (`CCLane`, `ModulationEngine`, FR-MOD-3) —
slow, bar-length timbre cycles are core to the Berlin School sound — but the
app has no way to create or change them. Lanes exist only in the built-in
demo/templates or by hand-editing the project JSON. The user wants to shape
LFOs **both while preparing a project and live**, listening to the synth, so
every change must be heard during playback, not after Stop.

The user also wants a friendly way to find *which* CC a parameter of their
synth listens to, using the midi.guide database, while always being able to
type a CC number directly.

## Goals

1. **Per-voice LFO strip under the voice lane** (main window, layout "B").
   - A voice without LFOs shows only a small `∿ ＋` in its header and takes
     no extra height.
   - `∿ ＋` adds an LFO; "＋ add LFO" adds more (up to 4 per voice, FR-MOD-3);
     ✕ removes one. Usually a voice has one LFO.
   - The header toggle (`∿ n ▾`) collapses / expands the strip.
2. **One LFO row** contains:
   - **CC number field** — always editable by typing, 0–127, no instrument
     needed.
   - **Magnifier button 🔍** next to it — opens the parameter browser (goal 3).
     After a pick, the row shows the parameter's name next to the number
     (e.g. "Arturia MicroFreak › Cutoff"); the name is saved in the project so
     it shows after reopening. Typing a different number by hand clears the
     name.
   - **Shape**: sine, triangle, saw up, saw down, square, S&H.
   - **Cycle length** in bars, menu 1, 2, 4, 8, 16, 32, 64 (engine allows
     0.5–64; the menu is the UI subset).
   - **Min** and **Max** — the range the LFO swings between, in real CC
     values (0–127).
   - **Depth** knob — a performance control that widens/narrows the range
     symmetrically around its middle; Min/Max update as it turns, so the
     range is always visible. *(Settled after the builder check — my call:)*
     the knob edits `CCLane.depth` directly, i.e. its value is the span as a
     share of the full CC range ((Max−Min)/127); no extra stored field. The
     middle stays fixed; at 0 or 127 the range is clamped. Typing Min/Max
     moves both middle and span. (The "100 %" in the v3 mockup was wrong.)
   - **Phase** knob.
   - *S&H (my call):* the engine steps S&H on 8th notes and ignores cycle
     length and phase, so for S&H those two controls are disabled and the
     preview shows a stepped curve. No engine change.
   - **Curve preview** with the Min/Max bounds dashed and a playhead showing
     where in the cycle the LFO is now.
3. **Parameter browser** (dialog opened by 🔍):
   - Three scrollable columns: **Manufacturer › Model › Parameter**. Selecting
     in one column replaces the content of the column to its right.
   - Parameters are grouped by the instrument's section (Filter, Oscillator…)
     and show their CC number.
   - **Search field**: typing part of a name keeps, in the manufacturer
     column, every manufacturer whose name *or any of whose model names*
     contains the text (case-insensitive). Example: "digi" → Elektron
     (Digitakt, Digitakt II, Digitone, Digitone II). The model column then
     shows only matching models, unless the manufacturer name itself matched
     — then all its models. Parameter names are not searched.
   - Confirm with **Select** or double-click on a parameter; **Cancel**
     closes without change.
   - The dialog remembers the last chosen model (per app run is enough), so
     the next LFO opens at the same instrument.
   - Footer credit: "Data: midi.guide (CC BY-SA 4.0)".
   - Picking a parameter sets the CC number and the name; when the database
     gives the parameter's min/max, Min/Max are set to that range, otherwise
     0–127.
4. **Defaults**: the first LFO of a voice gets CC 74 (filter), the second
   CC 71 (resonance); further ones CC 74 again. Shape sine, 16 bars, full
   range per the builder (e.g. the demo's 0.45–0.75 → Min 57 / Max 95),
   phase 0.
5. **Live**: every edit reaches MIDI output immediately while playing (within
   the scheduler's lookahead), without Stop/restart. Edits are saved in the
   project (dirty state, ⌘S) like other project edits.
   *Decided by the user after the builder check:*
   - Changing cycle length or phase while playing may make the LFO jump to
     a new point of its curve (position stays a function of the absolute
     tick; no smoothing, no extra engine state).
   - Removing an LFO or changing its CC number while playing leaves the
     previously driven parameter where it is (no reset emission).
   - *(my call)* A changed/added lane emits its current value once right
     away, so the new target is set without waiting for the value to change.
6. **midi.guide data bundled in the app** as a snapshot (works offline),
   refreshed by a script in `scripts/` before a release. Source:
   github.com/pencilresearch/midi (CSV per device; 468 devices, 133
   manufacturers, ~25 500 CC rows as of 2026-10-27). Only rows with a CC
   number are kept; NRPN-only rows and `*.triggers.csv` files are skipped.
7. **Credit and licence**: midi.guide data is CC BY-SA 4.0 — credit it in the
   app (browser footer and About/credits), in both manuals (EN + CS, per
   project CLAUDE.md), and in README. The bundled data file stays under
   CC BY-SA 4.0 (note it in a LICENSE/NOTICE next to the data). App code is
   unaffected.
8. **Remove the "CC Profile" submenu** from the voice context menu; the
   browser replaces it. Fix the swapped MicroFreak numbers wherever they
   remain (midi.guide: Timbre = CC 12, Shape = CC 13; the built-in profile
   has them the other way round).

## Non-goals

- No per-voice instrument selection in the voice header (considered, then
  dropped by the user in favour of the per-LFO magnifier).
- No search in parameter names.
- No online download of the database at runtime.
- No MIDI learn of LFO knobs, no CC pass-through, no recording CC into takes.
- No editor for CC scenes (`CCScene`) — scenes keep working from existing
  `ccMap` data.
- No editing of the S&H pre-strike offset (stays at its default 10 ticks).
- No undo for LFO edits: the app's undo (`UIState.undo`) restores engine
  state snapshots only and does not cover voice configuration (the MIDI
  channel is not undoable either). Consistent with that, LFO edits are not
  undoable.

## Anti-goals (would be a failure even if it works)

- Changes only audible after Stop/Play.
- Having to pick an instrument before you can set a CC number.
- Breaking existing projects/templates: old documents with
  `ccLanes` + `ccMap` (target names like "filter") must load and sound
  exactly as before (golden tests stay green).
- The strip making the main window cramped for voices that have no LFO.
- Illegible text — follow design_language.md (labels ink3 or brighter, ink4
  only for disabled states).

## Constraints

- Layers: data model and modulation math in `BerlinanEngine` (pure, no
  Foundation); midi.guide loading/search in `BerlinanRuntime` or the app;
  UI in `Berlinan` (SwiftUI). Swift Testing.
- `CCLane` currently addresses a CC through a *name* (`target`) resolved via
  `VoiceConfig.ccMap`; ranges are `center`/`depth` in 0–1. The editor needs a
  direct CC number and an optional display name. The document format must
  stay backward compatible (new fields optional). Min/Max are a view of
  center/depth: center = (min+max)/2/127, depth = (max−min)/127.
- The running transport today only hot-swaps channels (`Transport.setChannel`);
  `ccMap` edits mark the transport stale until restart. Live LFO edits need
  a new path into the running engine (e.g. a `LiveEngine.Command` or a
  Transport setter like `setChannel`). `renderCC` is stateless per window,
  so swapping lanes mid-play is safe.
- The app bundle is assembled by `build.sh` (no Xcode); a bundled data file
  must be copied there and be found both in the app and in tests.
- Phase workflow per development_workflow.md: PLAN.md + VERIFICATION.md in
  this folder, feature branch, `--no-ff` merge, conventional commits,
  ROADMAP/STATE updates; spec updates (FR-MOD-3/5, new FR for the browser)
  in generative_sequencer_spec.md; CHANGELOG "Unreleased"; manual
  screenshots/sections EN + CS for the new strip and dialog.

## Left to the builder

- Exact data-model shape (e.g. optional `controller` + `label` on `CCLane`
  vs. writing a `ccMap` entry), as long as old documents keep working.
- Data file format and size optimisation for the bundled snapshot.
- Knob/field controls and exact layout, following design_language.md and
  the existing lane look.
- How the curve playhead is driven (UI refresh rate).
- Default Min/Max for a fresh LFO (see goal 4).
- Whether `CCProfileStore` and user JSON profiles are deleted or kept
  internally once the menu is gone (scenes still need `ccMap`).
