# Phase 25 — v1.0 Release

## Goal

Close M4 → v1.0.0: app icon, README, CHANGELOG, dist pipeline smoke, tag. Link (23) ships deferred (licensing decision pending — documented); everything else in M4 is in.

## Deliverables

- `Resources/AppIcon.png` (1024×1024, generated: studio-dark rounded square, three phasing lane bars in the voice identity colors + tangerine playhead — the app's own visual signature).
- `README.md`: what Berlinan is, musician quick start (Ableton setup incl. Delay Cheat Sheet), build/run/dist instructions, doc map (manual/spec/design/workflow), version/status table.
- Version 1.0.0 (Info.plist + EngineInfo), CHANGELOG entry.
- `./build.sh dist` smoke: expected to build the release bundle and **gracefully skip signing/notarization without a Developer ID identity** (watch-list item stays for when the cert exists).
- Tag `v1.0.0`; ROADMAP/STATE closed for M4.

## Acceptance criteria

- [ ] Icon renders in the Dock/Finder (build.sh picks it up; no more missing-icon warning)
- [ ] README present and accurate
- [ ] `swift test` green; `./build.sh release` clean; dist smoke behaves as documented
- [ ] Tag v1.0.0 on main
- [ ] Human: final jam pass on 1.0 — sync both directions, learn, dnd, delay, seed dice

## Out of scope

Developer ID signing + notarized DMG (blocked on certificate — procedure documented in development_workflow.md §2.3), App Store, Link.
