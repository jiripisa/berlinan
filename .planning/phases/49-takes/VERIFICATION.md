# Phase 49 — Takes — Verification

Date: 2026-10-25 · Branch: feature/49-takes · Suite: **340 tests / 117 suites green**

## Automated results

| Criterion | Result |
|---|---|
| Play→Stop → one take: rebased, whole bars, tempo/meter/voices; second pass separate | ✅ |
| Play→Stop without notes → no take | ✅ |
| Template load while playing splits the take at the bar line (1 bar of demo + a 6-voice take starting at its own tick 0) | ✅ |
| `liveTake()` grows while playing, nil after stop | ✅ |
| `Take` JSON round trip; duration/bars; `.mid` tempo track + one track per voice on its channel | ✅ |
| `TakeLibrary`: missing folder = empty, newest first, rename, overwrite, delete, junk file skipped | ✅ |

The recording tests were proven to bite: with the template split, the
empty-take drop, or the rebase disabled in turn, the matching test
failed. The rebase was at first NOT caught (it only matters for the
second take of a split) — the split test now also checks note positions
(separate test commit).

## Manual (debug build)

| Check | Result |
|---|---|
| Window ▸ Takes: take being recorded on top, red, growing ("recording · … 7 bars · 0:19"); finished take below with Save/Delete | ✅ screenshot |
| Stop → the live take becomes a finished one (13 bars) | ✅ (accessibility tree) |
| Rename "Take 1" → "Keeper": written to disk, kept after relaunch | ✅ screenshot after relaunch |
| Save .mid → `Keeper.mid`: Standard MIDI format 1, 4 tracks, 960 PPQ, tempo 90 BPM | ✅ `file` / hex |
| Delete → confirmation dialog ("removed from disk, export first"), file gone, row gone | ✅ screenshot |
| Drag a take into a Finder folder → `Keeper.mid`, byte-identical to the export | ✅ |
| Autosave of the take in progress (file present while recording) | ✅ |

Found and fixed while testing the drag: `NSItemProvider(contentsOf:)`
made Finder name the drop "MIDI audio.midi"; `suggestedName` gave
"Keeper.midi" / "Keeper.mid.midi"; a file-representation registration was
ignored. `NSItemProvider(object: url as NSURL)` keeps "Keeper.mid".

Not verified: the older voice-lane pattern drag (phase 25, same
`NSItemProvider(contentsOf:)`) — my synthetic drag did not start a drag
from the lane at all, so neither the bug nor a fix could be checked; left
unchanged. Takes in Ableton Live itself not tried (no Live session here).

## Human checklist (pending)

- [ ] Drag a take into Live's arrangement / a clip slot — tracks land per voice
- [ ] Drag a lane pattern into Finder — does it arrive as "MIDI audio.midi"? (then apply the NSURL fix there too)
- [ ] Quit while recording, relaunch — the take is there (≤ 10 s missing)
