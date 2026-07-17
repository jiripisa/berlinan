# Phase 28 — Melody Extraction & Lead Promotion — Verification

Date: 2026-07-18 · Branch: feature/28-melody-extraction · Suite: **271 tests / 93 suites green**

## Automated results

| Criterion | Result |
|---|---|
| selectAccents: 3–4 picks, pairwise ≥ 2 steps apart, deterministic | ✅ |
| On-beat preference (≤ 1 off-beat pick with 4 on-beat candidates) | ✅ |
| Never root+fifth-only across 12 seeds | ✅ |
| Extraction at the loop boundary: sparser, all accents | ✅ |
| Toggle off restores the source verbatim | ✅ (test rewritten: toggle slots are last-wins like blank/regenerate — sequential enqueue between renders) |
| 2-bar inversion changes the note set; 4/8-bar growth adds exactly one each | ✅ |
| Chunk-independence with a running extraction | ✅ |
| Promotion: lead pattern locked, 3–4 notes, every gate ≥ one beat | ✅ |
| Promotion without a lead voice: safe no-op | ✅ |
| App builds: ♪ lane toggle + "Promote Melody to Lead" context item | ✅ |

## Design notes

- Extraction arrives locked + established: the melody engine owns its own
  evolution clock (M §8.1's 2-bar/4-bar schedule), the Legitimizer stays out
  — same exemption class as accumulators.
- Snapshot recall exits the technique (melody state cleared) — the recalled
  universe wins.
- Demo has no lead voice, so promotion is discoverable only when a project
  defines one (context item hidden otherwise).

## Human checklist (pending)

- [ ] MEL on the running bed: the room opens, 3–4 notes carry a line
- [ ] The line breathes on its own (change at 2 bars, growth later)
- [ ] MEL off: the original groove returns seamlessly
- [ ] With a lead-voice project: promotion lands a legato line on the lead
