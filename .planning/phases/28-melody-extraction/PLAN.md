# Phase 28 — Melody Extraction & Lead Promotion

## Goal

The manual's §8.1 technique as one gesture (FR-MEL-1): turn any running
pattern into a melody — mute all, raise 3–4 curated accents — then let it
evolve on the manual's schedule (2-bar accent inversion, 4-bar single-change
growth). Plus step 7 (FR-MEL-2): promote the extracted melody to the lead
voice as a legato line.

## Design decisions

- `Melody` engine module: `selectAccents(pattern:key:meter:seed:)` picks 3–4
  note indices by the curation rules — prefer on-beat, never adjacent steps,
  never root+fifth-only when alternatives exist; deterministic per seed.
- Live action `.extractMelody(voiceID)` (toggle): at the voice's next loop
  boundary the pattern swaps to the extraction (selected notes only, accented,
  locked against the Legitimizer — the melody engine owns its evolution);
  toggling again restores the stored source pattern and unlocks.
- Evolution (engine-owned, exempt from Law 1 like accumulators — the manual
  prescribes its clock): at ≥2 bars an accent INVERSION (fresh curated pick
  from the unselected notes); at ≥4/8/12… bars growth by exactly one source
  note per stage, capped at the source's note count.
- `.promoteToLead(voiceID)` (FR-MEL-2): copies the current extraction to the
  first `.lead` voice via the replace-pattern path (locked + established),
  gates stretched legato (to the next melody onset, min one beat). No lead
  voice → no-op (demo has none; tests build one).
- Melody state lives in `VoiceState`, cleared by snapshot recall.

## Acceptance criteria

- [ ] selectAccents: 3–4 picks, pairwise non-adjacent, on-beat preferred,
      not root+fifth-only when avoidable, deterministic
- [ ] Extraction at the loop boundary: only selected notes sound; toggle off
      restores the source verbatim
- [ ] Inversion at 2 bars changes the sounding note set; growth at 4/8 bars
      adds exactly one note each
- [ ] Promotion: lead pattern = melody notes with legato gates, locked
- [ ] Chunk-safety with an active extraction
- [ ] Human: extraction is musical on a running bed; promotion lands as a
      playable lead line

## Out of scope

Alternating scheduler, tension scoring, bass-melody (29); harmony color (30).
