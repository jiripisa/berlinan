# Phase 10 — Live Engine (Pull Model + Action Queue)

## Goal

The engine side of "it plays" (spec §5.2): a stateful `LiveEngine` the future scheduler pulls with consecutive tick windows, plus the quantized action queue (lock / regenerate / blank cycle / transpose). Engine-only, no CoreMIDI, TDD.

## Deliverables (Sources/BerlinanEngine/)

- `LiveEngine.swift`
  - `LiveEngine(project:)` — materializes voices exactly like `OfflineRenderer` (shared code path).
  - `mutating render(range:) -> [RenderedNote]` — incremental, seam-safe: consecutive windows of any size reproduce the whole-range render; per-voice segment cursors; lifecycle advance + auto-mutation at loop boundaries (as in phase 09).
  - `mutating enqueue(_ action: Action, atTick:)` with quantized binding:
    - `.transpose(degreeOffset)` → appended to the schedule at `quantizedEventBar` (FR-H-3);
    - `.regenerate(voiceID)` → new pattern (next generation seed) at the voice's **next loop boundary ≥ request tick**;
    - `.blankCycle(voiceID)` → exactly one silent loop at the next boundary; the voice re-enters automatically; **lifecycle frozen during the blank** (an unheard play must not count toward legitimization);
    - `.setLock(voiceID, on)` → immediate flag; locked patterns never mutate/regenerate.
  - Note: runtime **mute stays OUT of the engine** — spec §8.2 applies mutes as a post-render gate in the Runtime for ≤ 20 ms latency; the engine remains fully deterministic.

## Acceptance criteria

- [x] No-action equivalence: `LiveEngine` chunked renders (unaligned windows) byte-match `OfflineRenderer.renderNotes` for the demo project
- [x] Chunk-independence WITH actions: same actions at same request ticks ⇒ identical output regardless of window sizes
- [x] Regenerate: content changes at the first boundary ≥ request tick, never before; new provenance seed; lifecycle restarts at N
- [x] Blank cycle: exactly one loop of silence; pattern resumes verbatim; remaining-repeat count unchanged across the blank
- [x] Transpose: enqueued mid-bar binds at the next bar (notes before/after the boundary prove it)
- [x] Lock: an established, locked pattern never auto-mutates; unlock resumes mutation
- [x] TDD red → green; `swift test` green

## Out of scope

CoreMIDI (phase 11), wall-clock scheduling (phase 12), mute/solo (runtime, phase 13), snapshots (M3).
