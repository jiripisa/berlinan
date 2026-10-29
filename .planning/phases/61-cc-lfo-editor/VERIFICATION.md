# Phase 61 — CC LFO editor — Verification

Date: 2026-10-29 · Branch: feat/61-cc-lfo-editor

| Check | Result |
|---|---|
| `swift test` | ✅ 359 tests / 119 suites (new: CC lane editing ×9, live lane swap ×4, midi.guide catalog ×7, lanes survive a pending template load ×1) |
| Mutation check: live swap without the sync tick | ✅ 2 of 4 live tests fail (forced emission is what they pin) |
| Goldens (old documents render identically) | ✅ unchanged |
| `./build.sh debug`; bundle contains `MIDIGuide/` + `Credits.rtf` | ✅ |
| Debug app: demo Pluck 1 shows its 16-bar filter LFO as CC 74 "filter", 57–95, curve + playhead | ✅ screenshot |
| Strip sits inside the lane frame (first build had it outside — fixed) | ✅ screenshot |
| 🔍 browser: three columns, "digi" → Elektron with Digitakt, Digitakt II, Digitone, Digitone II; selecting a model fills the parameter column | ✅ screenshot |
| Pick Digitone › Ratio C → CC 91, name "Elektron Digitone › Ratio C", range 0–127 | ✅ screenshot (name field widened from 150 to 220 pt so it is not cut) |
| Lane menu without CC Profile | ✅ screenshot (menu-lane.png) |
| About panel credit readable on the dark panel (RTF, no fixed colour) | ✅ screenshot |
| Manual EN + CS: CC LFO section with marked figures, header mark 5 (∿), lane menu; checked in Safari | ✅ |
| Whole-branch review (fresh reviewer) | ✅ "with fixes" → 3 fixed with tests (pending template load, channel-mode/command rows in the data, About credit colour) |

Not checked by the developer (owner, by ear / hardware): an LFO audibly
moving a real synth's filter, CC behaviour in Live, knob feel.

Deferred minors (from the review): leaving a number field unchanged still
commits; an old map lane's target name disappears after its first edit; an
old lane with an unmapped target shows CC 0; the browser does not scroll to
the remembered model and recomputes its filter per row; the S&H preview does
not use the voice's real random sequence; the disabled phase knob hides its
tooltip.
