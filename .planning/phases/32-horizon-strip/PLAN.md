# Phase 32 — Horizon Strip

## Goal

The trust move: one timeline that answers "co se právě chystá?" — upcoming
transpositions, mutations coming due, the arranger's countdown and next
phase, and every pending bar-bound change (key, density, B-part, recall,
alternation, tension). Plus honest lane states: a voice the arranger holds
back shows "waiting", not silent-dark.

## Design decisions

- **Engine exposure, no new mechanics**: everything shown already exists in
  engine state. `Snapshot` gains:
  - `upcomingEvents: [UpcomingEvent]` — pending global changes with their
    bind ticks and a typed kind (key/recall/density/bPart/voiceActive/
    alternating/tension/advancePhase/arrangementToggle);
  - `ArrangementStatus.barsUntilChange: Int` (SM exposes its counter);
  - `VoiceSnapshot.active: Bool` (the arranger's engine-level flag) and
    `VoiceSnapshot.pendingRequest: PendingRequest?`
    (blank/regenerate/replace/melodyToggle with bind ticks).
  - Mutation horizon per voice is derivable in the UI from what the
    snapshot already carries (lifecycle remaining × loop length).
- **Runtime**: nothing new — the mirror flows through `latestSnapshot`.
- **UI `HorizonStripView`**: a compact strip between the harmony strip and
  the lanes — the next 16 bars as a grid with event chips (icon + bars-away)
  merged from upcomingEvents + per-voice horizons + arranger countdown
  ("BED · next change in ~4 bars"). Chips reuse the harmony-strip visual
  language (studio-dark, tangerine accents for arranger events).
- **Lanes**: engine-inactive voices dim the pattern strip and show a
  "WAITS" badge (tangerine outline) instead of looking broken.

## Acceptance criteria

- [ ] Snapshot: upcomingEvents lists a pending key change + density change
      with correct bind bars; arrangement mirror carries barsUntilChange;
      voice snapshots carry active + pending blank/regenerate
- [ ] Chunk-safe: snapshot surface does not alter render output (suite
      untouched)
- [ ] UI: strip renders events in bar order; countdown matches the SM;
      inactive lanes show the badge (build verified; human check for feel)
- [ ] Human: during an AUTO jam the strip narrates the piece before it
      happens; nothing feels like a black box

## Out of scope

Editing from the strip (it is read-only narration), capture browser (M7),
drone/slides (33).
