# Phase 47 — Per-voice MIDI Channel — Verification

Date: 2026-10-24 · Branch: feature/47-voice-channel · Suite: **333 tests / 115 suites green**

## Automated results (CoreMIDI loopback, test-owned virtual destination as the synth)

| Criterion | Result |
|---|---|
| Playing: after `setChannel`, bass note-ons go out on ch 12, none on ch 3 | ✅ |
| Old channel gets CC 123 for a sounding note (Ambient drift drone) | ✅ |
| Change made while a template load is pending survives the bar-line swap | ✅ |
| Capture export names/writes the track on the new channel ("bass \| ch12") | ✅ |

Each test was proven to bite: with the pending-load carry, the old-channel
flush, or the transport project copy disabled in turn, exactly the matching
test failed. The red commit itself failed at compile time (no API yet).

CoreMIDI `clientCreation(-2/-304)` hit twice during back-to-back mutation
runs (all tests of a run fail at client creation, before any behavior);
3 clean reruns after it passed. Same environmental flake as phase 45.

## Manual (debug build)

| Check | Result |
|---|---|
| "ch N" in the lane opens Channel 1–16; current one checked; used channels named ("Channel 1 — Pluck 1") | ✅ screenshot |
| Picked Channel 12 for Bass while playing → label "ch 12", playback continues | ✅ screenshot |
| Label aligned with the voice name (borderless menu inset compensated); `.button` menu style rejected — it truncated items ("Channel…Pluck 1") | ✅ screenshot |

Deviation from what the user was told when choosing storage: the option
text said the change "can be undone with Undo" — Undo covers generative
engine state only (FR-UX-5), like CC profiles and MIDI delay. Reported to
the user; re-picking the channel reverts it.

## Human checklist (pending)

- [ ] Two voices on two channels of a multitimbral synth (or two Live
      tracks) — each hears only its voice; switching while playing leaves
      no hanging note
- [ ] Save, reopen: the channel is kept
