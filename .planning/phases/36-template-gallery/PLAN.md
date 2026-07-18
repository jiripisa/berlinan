# Phase 36 — Template Gallery

## Goal

Discoverability: starting points instead of File ▸ Open JSON. Built-in
templates (Demo trio / Full ensemble / Ambient drift) one click away, plus
save-as-template for the user's own setups.

## Design decisions

- **Built-ins live in the engine** (`Project.fullEnsemble`,
  `Project.ambientDrift` next to `.demo`) so they are testable and the CLI
  can render them. Ambient drift: drone + two beds + chord-layer pad,
  `.ambientPlateau` arrangement, CC scenes (closed/open) mapped to phases,
  72 BPM.
- **App `TemplateStore`**: built-ins + user templates from
  `~/Library/Application Support/Berlinan/templates/*.berlinan`.
  Instantiating a template gets a FRESH master seed (FR-UX-6 — a template
  is a setup, not a recording).
- **UI**: a TEMPLATES menu in the transport bar (stopped-only): built-ins,
  user templates, "Save as Template…" (save panel pre-pointed at the
  templates folder).

## Acceptance criteria

- [ ] fullEnsemble: 6 voices (incl. chordLayer pad, bassMelody, heartbeat,
      lead), renders 8 bars non-empty
- [ ] ambientDrift: drone opens the build order, ambient arrangement,
      scenes present; renders non-empty
- [ ] Template instantiation randomizes the seed (two loads differ)
- [ ] Suite green; app builds with the TEMPLATES menu
- [ ] Human: new session → Ambient drift → press play → it drifts

## Out of scope

A visual gallery window (menu suffices for v1.2), template thumbnails.
