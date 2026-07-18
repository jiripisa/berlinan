# Phase 34 — CC Scenes

## Goal

The timbre journey (M §11): named CC scenes — per-voice target values —
morphed over bars, fired manually or by the arranger's phase transitions
(Build closed → Payoff open). The arranger starts steering SOUND, not just
notes.

## Design decisions

- **Model**: `CCScene { name, values: [voiceID: [target: 0–1]] }` in
  `Project.ccScenes`; `Project.sceneByPhase: [phase: sceneName]` maps
  arranger phases to scenes (both optional — fully opt-in).
- **Morphing is stateless emission** (the ModulationEngine trick): a morph
  descriptor (start/end value, startTick/endTick) set by a bar-quantized
  action; `renderCC` interpolates on the 1/96 grid and emits only where the
  quantized value differs from the previous grid point — chunk-safe, no
  per-window mutation, silence after the morph settles.
- New morphs read their start from the outgoing morph's value at the switch
  tick (unknown targets start at 0.5). CC numbers resolve through the
  voice's `ccMap`; unmapped targets are skipped.
- **Arranger hook**: on a phase transition, `sceneByPhase[newPhase]` starts
  an 8-bar morph. Manual: `.morphToScene(name:bars:)` action + a SCENE menu
  in the performance panel.

## Acceptance criteria

- [ ] Morph action: CC values ramp monotonically start→end across the bars,
      endpoints correct, ≤ one emission per 1/96 quantum, silent after
- [ ] Chunk-independent emission
- [ ] Re-morph mid-flight starts from the interrupted value
- [ ] Arranger transition with a mapped scene fires the morph
- [ ] Suite untouched without scenes; app builds with the SCENE menu
- [ ] Human: Build→Payoff audibly opens the filter over bars

## Out of scope

Scene editing UI (scenes come from the document; gallery templates in 36),
LFO-vs-scene conflict resolution (documented: don't target one CC twice).
