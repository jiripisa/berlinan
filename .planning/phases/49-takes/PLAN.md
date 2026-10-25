# Phase 49 — Takes (capture browser, M7)

## Goal

M7 candidate "capture browser", user decisions 2026-10-25: every
Play→Stop pass becomes a **take** in a **Takes** window. A take can be
saved as `.mid`, dragged into Ableton Live, renamed and deleted. Takes are
stored on disk and survive quitting (and crashes). New requirement
**FR-IO-11** (spec §3.10).

Today: one rolling `CaptureBuffer` (≈ 60 min, memory only) and "Export
capture ▸ Last N bars". That stays as it is.

## Design decisions

- **Take** (`Take`, BerlinanRuntime, Codable): id, name, start date, tempo
  at start, meter, voices (id, role, channel, display name), the notes the
  engine played (pre-mute, like the capture) rebased to the take's first
  bar, length rounded up to whole bars.
- Recording lives in `Transport`: the scheduler starts a take with the
  first rendered window and finishes it when the loop ends (stop, EXT stop,
  arranger ending). `onTakeFinished` hands the finished take out;
  `liveTake()` returns the take in progress (UI + autosave).
- A template loaded while playing (phase 42) **splits** the take at its
  bar line: a take is one piece with one meter and voice set; mixing two
  templates in one SMF would mislabel tracks.
- Takes without notes are dropped (Play → immediate Stop).
- Tempo changes inside a take: the SMF carries the tempo at take start
  (notes keep their musical positions; same as the existing export).
- Storage: `TakeLibrary` (runtime, Foundation, testable) — one JSON file
  per take in `~/Library/Application Support/Berlinan/takes/` (next to `templates/`). The app's
  `TakeStore` (@Observable) wraps it, names new takes "Take N", saves the
  live take every 10 s (crash safety) and on finish.
- `.mid` export: type 1, one track per voice ("bass | ch3 | bass | delay:
  …" like the capture export), bar-aligned from tick 0.
- Drag & drop: a temp `.mid` named after the take (as the voice-lane drag).
- UI: `Window("Takes")` (Window menu, plus "Takes…" in the Export Capture
  menu). Rows: name (editable), date + time, bars and m:ss, BPM, voices;
  the take in progress on top with a red dot, growing. Save .mid… and
  Delete (with confirmation — deleting a file is irreversible).

## Acceptance criteria

- [ ] Play→Stop produces one take: notes rebased to 0, bar-rounded length,
      tempo/meter/voices recorded; a second pass is a separate take
- [ ] Play→Stop without notes produces no take
- [ ] Template load while playing splits the take at the bar line
- [ ] `liveTake()` grows while playing, nil when stopped
- [ ] `Take` JSON round trip; `.mid` has one track per voice on its channel
- [ ] `TakeLibrary`: save, load sorted newest first, rename, delete; broken
      files skipped
- [ ] Takes window: list, rename, save .mid, drag into a Finder folder,
      delete; survives relaunch; full suite green; app builds
- [ ] Human: drag a take into Ableton Live's arrangement

## Files

- `Sources/BerlinanRuntime/Take.swift` (Take, TakeLibrary)
- `Sources/BerlinanRuntime/Transport.swift` (recording)
- `Sources/BerlinanEngine/Harmony.swift` (`RenderedNote: Codable`)
- `Sources/Berlinan/TakeStore.swift`, `Views/TakesView.swift`,
  `BerlinanApp.swift`, `AppServices.swift`, `PerformancePanelView.swift`
- `Tests/BerlinanRuntimeTests/TakeTests.swift`
- spec FR-IO-11, README, CHANGELOG

## Out of scope

Selecting a bar range inside a take; CC lanes in takes (the capture
records notes only); tempo maps inside a take; storing takes in the
`.berlinan` document.
