# Phase 24 — Verification

Date: 2026-07-15

| Criterion | Result |
|---|---|
| ControlMap: bind/lookup/persist round-trip; last-wins both directions | ✅ |
| Control input loopback: CC to the virtual destination fires the handler | ✅ |
| CCProfileStore: built-ins (Generic 74; Microfreak 12/13); user JSON loads | ✅ |
| Lane drag exports bar-aligned .mid (LCM-looped ≤ 16 bars) | ✅ code path; Ableton drop = human checklist |
| swift test green; build clean; smoke launch | ✅ 219 tests / 80 suites |

## Notes

- CC triggers fire only at value ≥ 64: pads on CC send value 0 on release,
  which would double-fire every macro (found during review, not by a test —
  the loopback test sends value 64 and stays green with the gate).
- LEARN flow: toggle LEARN → click a control (it arms) → move a knob /
  press a pad aimed at "Berlinan Control" → binding saved to
  ~/Library/Application Support/Berlinan/midimap.json.
- Profiles: lane context menu → CC Profile ▸; user files in
  Application Support/Berlinan/profiles/*.json ({"name":..., "map":{...}}).

## Human checklist (user)

- [ ] Map a hardware knob/pad: LEARN → click degree 5 → move the knob
  (controller routed to "Berlinan Control") → LEARN off → knob switches degree.
- [ ] Drag a lane's pattern strip into Ableton Session View → clip loops
  seamlessly and matches what the lane plays.
