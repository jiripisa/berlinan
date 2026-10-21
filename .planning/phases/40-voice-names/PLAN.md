# Phase 40 — Musician-facing Voice Names (user feedback)

## Goal

User feedback (2026-10-22): lane headers say "BEDPLUCK1" — the internal
voice id, a code identifier, not a name a musician reads. Every UI surface
that names a voice now shows a name derived from its ROLE (user decision:
role-based names): Pluck 1, Pluck 2, Bass, Pad, Lead, Drone, Heartbeat, Aux.
Ids stay the internal key (documents, scenes, alternation, MIDI export
track names, goldens) — only display text changes.

## Design decisions

- `VoiceRole.displayName` (engine, pure) is the single source of the names.
- `VoiceLabels.make(_:)` maps id → label for a voice list; a role that
  occurs more than once (user projects/templates) is numbered in document
  order ("Lead 1", "Lead 2") so labels never collide.
- Horizon events carry the voice id in a structured `voiceID` field instead
  of being baked into `detail`; `voiceActive.detail` becomes plain "on"/"off".
- Out of scope: track names inside exported .mid files (capture, offline
  render, lane drag) and CLI output stay id-based — they are stable machine
  identifiers and the demo16 golden pins them byte-for-byte.

## Surfaces (app)

- Lane header (VoiceLaneView), "Alternate With" menu
- Horizon strip: nearest-mutation chip, VOICE on/off, LEAD ← promotion
- Delay Cheat Sheet rows + copy-to-clipboard text
- Pattern editor sheet title

## Acceptance criteria

- [ ] Every role has a display name; duplicates numbered, singles not
- [ ] Horizon events for voiceActive / promoteToLead / tension expose `voiceID`
- [ ] Goldens untouched; full suite green
- [ ] App builds; the surfaces above show role names
- [ ] Website routing list uses the app's names (Full ensemble template)
- [ ] Human: lanes read "PLUCK 1 / PLUCK 2 / BASS" in the demo trio
