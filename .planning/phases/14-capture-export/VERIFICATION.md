# Phase 14 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| CaptureBuffer: prune to capacity, exact window selection, bar-boundary rebase (partial current bar excluded), empty cases | ✅ (unit tests; one test-data fix during red — end floors to whole bars by design) |
| Transport export integration: nil before play; after a 1.4 s live run @240 BPM a valid SMF with note-ons | ✅ |
| Degree buttons → `.transpose(k−1)`; re-roll → regenerate unlocked only | ✅ (wiring; engine semantics covered by phase 10 tests) |
| `swift test` | ✅ 140 tests / 46 suites |
| Visual check (`window_evidence.png`) | ✅ performance panel: DEG 1–7 (active glow), RE-ROLL UNLOCKED, EXPORT CAPTURE menu |
| Version bump 0.2.0 (Info.plist + EngineInfo) + CHANGELOG.md | ✅ |

## Human checklist (user)

- [ ] Jam → degree buttons transpose the bed at the next bar (audible + DEG chip)
- [ ] Export last 16 bars → drag into Ableton: clip starts on a bar, contains what you heard

## Notes

- Capture records pre-mute (the whole jam is kept; muting is a monitor
  decision) — documented design choice.
- DMG smoke test deferred until a Developer ID certificate exists (watch list).
