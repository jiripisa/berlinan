# Phase 24 — MIDI Learn, Drag & Drop, Synth Profiles

## Goal

Hands off the laptop (FR-IO-10), patterns into Ableton by mouse (FR-IO-9 subset), and named CC profiles (FR-MOD-5 global half).

## Deliverables

- **MIDI learn** (FR-IO-10):
  - `MIDIService.connectControlInput(handler:)` — a virtual destination "Berlinan Control" receiving CC (+ note-on) from controllers.
  - Runtime `ControlMap` (pure, tested): macro id ↔ (kind cc/note, number, channel); JSON persistence in `~/Library/Application Support/Berlinan/midimap.json`.
  - Macros: play/stop, degrees 1–7, re-roll, new seed, per-slot recall 1–6.
  - UI: LEARN toggle in the performance panel — armed control highlights, next incoming CC/note binds; mappings dispatch on the main actor.
- **Drag & drop** (FR-IO-9 subset): drag a voice lane's pattern strip → bar-aligned single-track `.mid` (temp file via NSItemProvider); one full legitimization cycle of the current pattern.
- **Synth profiles** (FR-MOD-5): `CCProfileStore` (runtime, tested) — built-ins (Generic filter=74; Microfreak shape=12/timbre=13 [M §13.4]) + user JSON files in Application Support; lane context menu "CC Profile ▸" applies to the voice (project update + stale rebuild).

## Acceptance criteria

- [ ] ControlMap: bind/lookup/persist round-trip; duplicate binding replaces
- [ ] Control input loopback: a CC sent to "Berlinan Control" fires the mapped macro handler
- [ ] CCProfileStore: built-ins present; user file loads; apply rewrites voice ccMap
- [ ] Lane drag exports a valid bar-aligned .mid (manual: lands in Ableton Session View)
- [ ] `swift test` green; build clean; smoke launch
- [ ] Human: map a hardware knob/button to degree buttons via LEARN; drag a lane into Ableton

## Out of scope

MIDI learn for lane-level buttons (mute/lock per voice — post-v1), capture-buffer drag (menu export exists), profile editor UI (JSON files documented).
