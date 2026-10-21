# Phase 42 — Load a Template While Playing (user feedback)

## Goal

User feedback (2026-10-22): picking a template while the transport runs
silently does nothing (`AppServices.applyTemplate` returns early). Users
reasonably expect the jam to switch. Now a template picked while playing
loads at the next bar: the clock keeps running (MIDI clock / Link / EXT
phase intact), the new piece starts from its beginning on that bar.

## Design decisions

- The swap lives in `Transport` (runtime), not the engine: a template
  replaces the WHOLE project (voice set, channels, CC maps, meter, tempo,
  arrangement) — the snapshot/recall machinery only updates existing voices.
- `Transport.loadProject(_:)` (playing only) arms a swap that binds at the
  next bar boundary, like runtime tempo: the render window clamps to the
  boundary, then a fresh `LiveEngine(project:)` takes over with an engine
  origin at that tick. Engine ticks = transport ticks − origin, so the new
  engine starts at its tick 0 (arranger Build, harmony bar 1, loops at 0).
- Notes already sounding end on their own (note-offs are scheduled ahead
  with timestamps), so nothing hangs. Mutes are cleared (ids may differ).
- Tempo: internal clock adopts the template's tempo at the boundary
  (segment continuity); EXT/LINK keep following the external tempo.
- `currentTick` reports engine-local ticks, so position, playheads and the
  horizon restart with the new piece.
- The horizon strip shows "TEMPLATE <name> · next bar" while armed.
- Out of scope: snapshot slots / undo history recorded before the swap
  still recall into the new piece by matching voice ids (as today when
  switching while stopped).

## Acceptance criteria

- [ ] Playing: loadProject leaves the old piece sounding until the next bar,
      then the snapshot shows the new voice set; transport keeps running
- [ ] After the swap the position restarts within the first bar
- [ ] Stopped: template behaves as before (rebuild)
- [ ] Full suite green; app builds
- [ ] Human: Demo trio → Full ensemble while playing switches on the bar,
      no hanging notes in Live
