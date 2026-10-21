# Phase 45 — Audit Fixes (Codex adversarial review, 2026-10-22)

## Goal

Fix the five findings of the project audit; each was verified against the
code before fixing.

1. **[high] Document validation** — a decodable but invalid project (two
   voices with the same id, beatUnit 0, bpm 0) crashed the app
   (`Dictionary(uniqueKeysWithValues:)`, division by zero); synthesized
   Codable bypasses `Meter.init`'s preconditions. Fix: `Meter` validates on
   decode; `Project.load(from:)` = decode + `validate()` (unique voice ids,
   tempo 40–220, channels 0–15) used by document open, user templates and
   the CLI. Invalid documents are rejected with a message; the current
   project stays.
2. **[high] Stop/mute leave long notes sounding** — the note-off of a note
   is sent (timestamped in the future) together with its note-on, and the
   registry dropped the note immediately, so flush found nothing (no
   note-off, no CC 123). Fix: the registry tracks each note until its
   scheduled note-off time; flush silences everything still sounding or
   scheduled, now and once more after the lookahead (notes whose note-on
   was already queued).
3. **[high] EXT sync lost after a transport rebuild** — the clock input
   port is created once and its handler kept a weak reference to the first
   Transport; a rebuilt Transport could never reconnect. Fix: the clock
   handler is replaceable; a rebuild carries the sync mode (and Link) over.
4. **[high] Capture mixes takes** — every play restarted ticks at 0 on the
   same buffer. Fix: each take continues the capture timeline from the
   next bar after the previous take's head.
5. **[medium] CLI export ignored the arranger** — `OfflineRenderer.render`
   always rendered voices independently. Fix: arranged projects render
   through `LiveEngine` (notes + CC), like `renderNotes`; unarranged output
   stays byte-identical (goldens).

## Acceptance criteria

- [ ] Each finding has a regression test that failed before the fix
- [ ] Goldens unchanged; full suite green; app builds
