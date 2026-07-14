# Phase 19 — Pattern Editor, Project Settings, Documents

## Goal

Close M3 (→ v0.3.0): hand-editable patterns that lock (FR-P-7), a project settings sheet (key/mode/tempo/meter — stopped-only in M3), and `.berlinan` documents (open/save incl. snapshot slots and hand edits).

## Deliverables

- Engine:
  - `Action.replacePattern(voiceID:pattern:)` — binds at the voice's next loop boundary ≥ request tick; the pattern arrives **locked** and `.established` (hand edits never mutate — FR-P-7); clears pending regenerate/blank/accumulator state.
  - `VoiceConfig.overridePattern: Pattern?` — hand edits persist in the document; `materialize` uses it verbatim (locked) instead of the generator.
  - `Project.snapshots: [LiveEngine.StateSnapshot?]?` — slot persistence (spec §6.6).
- App:
  - **Pattern editor sheet** per lane (pencil button): note list on the 16th grid — step / degree / octave / velocity / accent / delete + add-note; Apply = update `project.voices[].overridePattern` **and** enqueue the live `replacePattern` (bar-boundary bind, no stop needed).
  - **Settings sheet** (gear in the transport bar): key root, mode, BPM (40–220), meter presets (4/4, 3/4, 6/8, 7/8, 5/4, 5/8 with manual groupings) — enabled while stopped, transport rebuild (runtime tempo/key changes → M4 per FR-GS-5).
  - **Documents**: File ▸ Open (⌘O) / Save As (⌘⇧S) — `.berlinan` = pretty-printed project JSON (UTI declared in Info.plist; the spec's package format arrives with capture persistence — deviation noted). Save embeds snapshot slots + overrides; open rebuilds transport + restores slots.
- M3 exit: version 0.3.0 (Info.plist + EngineInfo), CHANGELOG entry, tag.

## Acceptance criteria

- [x] replacePattern: binds at the next loop boundary (old bar before, new after); pattern locked + established; never auto-mutates afterwards; chunk-independent
- [x] overridePattern: materialized verbatim and locked; renders reproduce the hand-edited notes exactly
- [x] Project.snapshots + overridePattern survive JSON round-trip; 0.2.x JSON (neither key) still decodes; goldens untouched
- [x] Open/save round-trip via CLI-written file (automated: decode(saved) == project)
- [x] `swift test` green; `./build.sh debug` clean; smoke launch; editor + settings sheets render (visual check)
- [ ] Human: edit a note in a lane → hear it change at the next loop and see the lock engage; save, reopen, the edit survives
- [x] Tag v0.3.0 after merge

## Out of scope

Runtime tempo/key/meter changes (M4, FR-GS-5), NSDocument/DocumentGroup architecture + autosave (M4 polish), drag editing in the strip (editor sheet first), capture persistence in documents.
