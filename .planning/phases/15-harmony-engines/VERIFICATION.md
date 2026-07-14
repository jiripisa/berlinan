# Phase 15 — Verification

Date: 2026-07-14

| Criterion | Result |
|---|---|
| Progression unroll (looped cycling, non-looped holds last) | ✅ |
| Manual §7.1 presets (degree walks verified per name) | ✅ |
| Weighted mode: deterministic per seed, offsets from table only, gaps in 8–16, horizon > 1000 bars | ✅ |
| Bass reharm: uppers frozen, bass majority pitch class follows the walk (C→Ab), gates ≥ 1 beat | ✅ |
| Backward compat: nil-harmony ≡ legacy schedule (byte-equal render); old JSON decodes; golden master green | ✅ |
| Snapshot exposes scheduleEvents; UI strip shows mode picker + upcoming chips + countdown | ✅ (evidence screenshot) |
| `swift test` | ✅ 150 tests / 50 suites |
| TDD red → green | ✅ |

## Human checklist (user)

- [ ] Pick "Progression → 1-7-6-5", play: the bed walks degrees every 4 bars
- [ ] Pick "Bass reharmonization → 1-6-4-1": bed static, bass re-roots with held notes

## Notes

- Harmony modes materialize into TranspositionSchedule (render pipeline
  untouched); open-ended modes have a 1024-bar horizon (≈45 min @ 90 BPM).
- Mode switching only while stopped (transport rebuild) — runtime switching
  deferred to M4 polish.
- Degree buttons still work in every mode (live events merge into the
  schedule, last-wins per bar).
