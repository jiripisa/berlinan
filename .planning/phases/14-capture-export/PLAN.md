# Phase 14 — Capture & Export + Performance Panel

## Goal

Close M2 (→ v0.2.0): the record-the-jam workflow (FR-IO-7 + FR-IO-6a) and the first performance macros (FR-UX-3 partial) — degree buttons 1–7 and "re-roll all unlocked".

## Deliverables

- Runtime: `CaptureBuffer` (pure, unit-tested) — rolling log of `RenderedNote`s with a tick-capacity prune (default ≈ 60 min at project tempo); `notes(lastBars:endTick:meter:)` selection that **rebases onto a bar boundary** so exported clips launch cleanly in Ableton (FR-IO-9 groundwork).
- Runtime: `Transport` integration — scheduler appends every rendered window to the capture (post-mute filtering NOT applied: the capture records what the engine played; mutes are a monitor decision); `exportCapture(lastBars:) -> [UInt8]?` building per-voice `SMFTrack`s (channel map, names) via the existing `SMFWriter`.
- App: `PerformancePanelView` (spec §11.4 partial) — 7 degree buttons (1 = home/offset 0 … 7 = +6, active = current offset, tangerine glow), "re-roll all unlocked" button; bottom of the window above the convergence footer.
- App: Export — "Export last 8/16/32/64 bars…" (File menu + toolbar button) via `NSSavePanel`, default name `berlinan-capture-<bars>bars.mid`.

## Acceptance criteria

- [ ] CaptureBuffer: prune respects capacity; selection returns exactly the notes in the window; rebase lands on a bar boundary and re-zeroes ticks
- [ ] Transport integration: after a short play, `exportCapture(lastBars: 1)` returns a valid SMF (MThd prefix, ≥ 1 note-on) — loopback-style test
- [ ] Degree buttons enqueue `.transpose(degreeOffset: k−1)`; DEG chip follows (engine offset covered by existing tests; UI wiring manual)
- [ ] Re-roll enqueues `.regenerate` for every unlocked voice only
- [ ] `swift test` green; `./build.sh debug` clean
- [ ] Human checklist: jam → press degree buttons (bed transposes at next bar) → export last 16 bars → drag into Ableton: clip starts on a bar, plays what you heard
- [ ] M2 exit: version bump to 0.2.0 + tag (DMG smoke deferred until a Developer ID cert exists — watch list)

## Out of scope

Export of the pattern pool as clips (M4 FR-IO-9), MIDI-learn (M4), snapshot slots (M3), wall-clock ("last N minutes") export scope (M3 — bars only for now).
