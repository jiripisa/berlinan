# Phase 53 — HTML Manual — Verification

Date: 2026-10-25 · Branch: feature/53-manual · User request: a detailed
HTML manual linked from the website, with screenshots marking the control
each passage talks about.

## Delivered

- `docs/manual.html` (English, like the site; same tokens and fonts as
  `index.html`): getting started, window overview, every control of the
  transport bar, harmony and horizon strips, voice lanes (channel menu,
  lifecycle, pattern strip, 7 lane buttons, lane menu, pattern editor),
  performance panel (degrees, snapshots, re-roll, B, tension, scenes,
  arranger + forms, ambient, density, MIDI learn, export), convergence
  footer, Takes, Delay Cheat Sheet, connecting Live/hardware/sync,
  projects and templates, shortcuts, concepts, troubleshooting.
- 14 screenshots from the 1.2.7 release build in `docs/assets/manual/`
  (main window, arranger running, 8 menus, 2 sheets, 2 windows). Marks
  and zoomed regions are pure CSS over the unedited images.
- Links: index nav, hero meta, download section, footer; README.

## Checks

| Check | Result |
|---|---|
| Every text claim checked against the code (views, UIState, AppServices, engine defaults) | ✅ |
| Rendered in headless Chrome at 1400 px: every mark sits on its control (reviewed slice by slice; six crops corrected) | ✅ |
| Rendered at 600 px: single column, no horizontal overflow (grid fixed to `minmax(0, 1fr)`) | ✅ |
| Menus captured with the window at the screen's right/bottom edge so they open over the app, no desktop or other apps in the shots | ✅ |
