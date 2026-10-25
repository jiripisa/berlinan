# Phase 51 — Default Key A Minor (user request)

## Goal

User request (2026-10-25): the app starts in A minor instead of C minor.

## Design decisions

- App-level default, not the engine's: `Key.default` (C natural minor)
  stays — the golden master (`demo16.mid`) and ~18 engine tests are built
  on it, and the CLI renders whatever key a project file says.
- `TemplateStore.defaultKey` = A natural minor; applied to the launch
  project and to the built-in templates (Demo trio, Full ensemble, Ambient
  drift). User templates and saved documents keep their own key.

## Acceptance criteria

- [ ] Launch: KEY shows A naturalMinor, notes sound in A minor
- [ ] Each built-in template loads in A minor; a saved document keeps its key
- [ ] Full suite green (engine goldens untouched); app builds

## Out of scope

A user-selectable default key setting.
