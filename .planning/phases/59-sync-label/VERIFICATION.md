# Phase 59 — Clock-source label stuck on INT (user report) — Verification

Date: 2026-10-26 · Branch: fix/59-sync-label

Cause: `UIState.syncMode` (and `linkPeers`) were computed properties reading
the non-observable `Transport`, so SwiftUI never re-rendered the label after
INT/EXT/LINK was picked — the mode itself did change.
Fix: both are stored, observed properties mirrored in `refresh()` (30 Hz),
like every other transport readout.

| Check | Result |
|---|---|
| Debug build; INT → EXT: label turns cyan "EXT", status "EXT — waiting for clock" | ✅ screenshot |
| Full cycle INT/EXT/LINK by the owner in the app | ✅ owner confirmed ("Ano") |
| `swift test` | see release phase 60 |
