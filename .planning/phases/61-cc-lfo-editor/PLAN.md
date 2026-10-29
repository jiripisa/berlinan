# Phase 61 — CC LFO editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Edit CC LFOs per voice in a strip under the voice lane, live while
playing, with a midi.guide parameter browser (Manufacturer › Model ›
Parameter) behind a magnifier button.

**Architecture:** `CCLane` gains an optional direct `controller` and display
`label` (old documents keep resolving `target` through `ccMap`). A new
`LiveEngine.Action.setCCLanes` swaps a voice's lanes at the render head and
forces one emission of the new values. The midi.guide CSV database is
converted by a script into one bundled JSON file read by
`MIDIGuideCatalog` (runtime layer), which also owns the search rule. SwiftUI
adds `LFOStripView` under each lane, a `KnobView`, and
`CCParameterBrowserView` (sheet).

**Tech Stack:** Swift 6 / SPM, SwiftUI (macOS 14), Swift Testing, Python 3
(build-time data script only).

**Spec:** `.planning/phases/61-cc-lfo-editor/DESIGN.md` (approved
2026-10-29) — read it first; this plan does not repeat its UI details.

## Global Constraints

- Branch `feat/61-cc-lfo-editor`; merge to `main` with `--no-ff`; Conventional
  Commits with scope; `git status` before every commit; no AI attribution
  trailers; **no push** (the user confirms pushes separately).
- Old documents/templates must load and render byte-identically: all existing
  goldens (`Tests/BerlinanEngineTests/Goldens`) stay green unchanged.
- `BerlinanEngine` stays Foundation-free.
- Up to **4 LFOs per voice** (FR-MOD-3). Default CC: first LFO **74**, second
  **71**, further ones **74**. New LFO: sine, 16 bars, center 0.6, depth 0.3
  (Min 57 / Max 95), phase 0.
- Min/Max ↔ engine: `center = (min+max)/254`, `depth = (max−min)/127`;
  displayed Min/Max = `round((center ∓ depth/2)·127)`.
- Depth knob edits `depth` keeping `center`; depth is limited so the range
  stays inside 0…127 (`depth ≤ 2·min(center, 1−center)`).
- S&H: cycle length and phase controls disabled (engine ignores them).
- Live edit semantics (user): cycle/phase change may jump; removing an LFO or
  changing its CC leaves the old parameter where it is; a changed/added lane
  emits its current value once at the next grid point.
- Search: case-insensitive substring on manufacturer **or model** names only.
- midi.guide credit text: `Data: midi.guide (CC BY-SA 4.0)`; data file keeps
  CC BY-SA 4.0 with a NOTICE next to it.
- UI text contrast per design_language.md §2.3 (labels ≥ ink3; ink4 only
  for disabled). Bilingual website rule (project CLAUDE.md): every
  `docs/*.html` change also in `docs/cs/*.html`.

## Review Focus

1. **Old project with `ccMap` lanes edited in the UI** — the row must show the
   resolved CC (e.g. 74 for target "filter") and the first edit must keep
   sound continuity (controller materialized, no silent lane). Test in Task 1
   (`resolvedController`) + Task 3 manual check.
2. **Typing Min > Max, or values outside 0–127** — clamp to 0…127 and swap so
   Min ≤ Max; never crash on `CCLane` preconditions. Test in Task 1
   (`setRange` swap/clamp).
3. **Knob dragged fast while playing** — many `setCCLanes` per second must not
   flood MIDI: each forces at most one emission per lane per grid point.
   Test in Task 2 (two enqueues inside one window → one forced event).
4. **Search with leading/trailing spaces or empty string** — trimmed; empty
   shows the full catalog. Test in Task 4.
5. **Bundled data file missing (e.g. `swift run` without the bundle)** — the
   🔍 button is disabled with a tooltip, nothing crashes. Covered by Task 4
   (`bundled()` returns nil, not a trap) + Task 6 manual check.

---

### Task 1: `CCLane` direct controller, label and range helpers

**Files:**
- Modify: `Sources/BerlinanEngine/Modulation.swift`
- Test: `Tests/BerlinanEngineTests/ModulationTests.swift`

**Interfaces:**
- Produces (all on `CCLane`, public):
  - `var controller: UInt8?` — direct CC number; wins over `target`.
  - `var label: String?` — display name, e.g. `"Arturia MicroFreak › Cutoff"`.
  - init gains `controller: UInt8? = nil, label: String? = nil` (last params).
  - `func resolvedController(ccMap: [String: UInt8]) -> UInt8?`
  - `var minValue: Int`, `var maxValue: Int` (0–127, rounded).
  - `mutating func setRange(min: Int, max: Int)` — clamps to 0…127, swaps if
    min > max, writes center/depth.
  - `mutating func setDepthKeepingCenter(_ depth: Double)` — clamps as in
    Global Constraints.
  - `static let maxPerVoice = 4`
  - `static func makeDefault(index: Int) -> CCLane` — `target: ""`,
    controller 74/71/74…, sine, 16 bars, center 0.6, depth 0.3.
- `ModulationEngine.render(lanes:ccMap:voiceID:in:meter:seed:syncTick:)` —
  new last param `syncTick: Tick = 0`: the first grid point ≥ `syncTick`
  (continuous) / the first step whose emission ≥ `syncTick` (S&H) always
  emits; replaces today's "tick 0 / step 0 always emits" (identical for 0).

- [ ] **Step 1: Write the failing tests** (suite `CCLaneEditingTests`):
  - `directControllerWinsOverMap`: lane `controller: 23, target: "filter"`,
    ccMap `["filter": 74]` → every rendered event has `controller == 23`.
  - `oldLaneStillResolvesThroughMap`: no controller → `resolvedController`
    = 74, events use 74.
  - `decodesOldJSONWithoutNewKeys` / `encodingOmitsNilKeys`: JSON of an old
    lane decodes with `controller == nil`; encoding it contains neither
    `"controller"` nor `"label"`.
  - `minMaxFromCenterDepth`: center 0.6, depth 0.3 → (57, 95).
  - `setRangeSwapsAndClamps`: `setRange(min: 140, max: -5)` → (0, 127);
    `setRange(min: 100, max: 20)` → (20, 100); rendered values stay in 20…100.
  - `depthKeepsCenterAndStaysInRange`: center 0.6 → `setDepthKeepingCenter(0.5)`
    → depth 0.5, (44, 108); center 0.9 → `setDepthKeepingCenter(0.5)` → depth
    ≈ 0.2.
  - `defaultsAlternate74And71`: `makeDefault(index:)` 0→74, 1→71, 2→74.
  - `syncTickForcesOneEmission`: depth 0 lane (constant), render bar 1..<2
    (3840..<7680) with `syncTick: 3840` → exactly one event at 3840; same
    without syncTick → none.
  - `syncTickForcesSampleHold`: S&H lane, depth 0, `syncTick: 3840` → one
    event at the first step emission ≥ 3840.
- [ ] **Step 2:** `swift test --filter CCLaneEditingTests` → FAIL (compile).
- [ ] **Step 3:** Implement in `Modulation.swift`; keep existing goldens.
- [ ] **Step 4:** `swift test` → all green (goldens unchanged).
- [ ] **Step 5:** Commit `feat(engine): CC lanes address a CC directly, range helpers, sync emission (FR-MOD-3)`.

### Task 2: Live lane swap in the engine

**Files:**
- Modify: `Sources/BerlinanEngine/LiveEngine.swift`
- Test: `Tests/BerlinanEngineTests/CCLaneLiveTests.swift` (new)

**Interfaces:**
- Consumes: Task 1 `syncTick`.
- Produces: `LiveEngine.Action.setCCLanes(voiceID: String, lanes: [CCLane])`
  — binds at the render head (`max(requestTick, renderedUpTo)`), like
  `setMIDIDelay`; stores the lanes in the engine's project and a per-voice
  sync tick passed to `ModulationEngine.render` by `renderCC`.

- [ ] **Step 1: Failing tests:**
  - `swapTakesEffectAtRenderHead`: demo project, render 0..<3840, enqueue
    `setCCLanes("bedPluck1", [lane controller 30, depth 0, center 0.5])` at
    3840, render 3840..<7680 → contains `(controller 30, at 3840, value 64)`;
    no event with controller 74 for bedPluck1 after 3840.
  - `emptyLanesSilenceTheVoice`: `setCCLanes(…, [])` → no bedPluck1 CC after.
  - `twoSwapsInOneWindowEmitOnce`: two enqueues before the next render → one
    forced event per lane at the bind tick (Review Focus 3).
  - `unknownVoiceIsNoOp`.
- [ ] **Step 2:** run → FAIL. **Step 3:** implement. **Step 4:** `swift test` green.
- [ ] **Step 5:** Commit `feat(engine): swap a voice's CC lanes live (FR-MOD-3)`.

### Task 3: App plumbing; drop CC profiles

**Files:**
- Modify: `Sources/Berlinan/AppServices.swift`, `Sources/Berlinan/UIState.swift`,
  `Sources/Berlinan/Views/VoiceLaneView.swift` (remove "CC Profile" menu only)
- Delete: `Sources/BerlinanRuntime/CCProfileStore.swift`, the `CCProfileTests`
  suite in `Tests/BerlinanRuntimeTests/ControlProfileTests.swift`

**Interfaces:**
- Produces:
  - `AppServices.setVoiceCCLanes(_ voiceID: String, lanes: [CCLane])` —
    updates `project`; playing → `transport?.enqueue(.setCCLanes…)` +
    `transportStale = true`; stopped → `rebuildTransport()` (pattern of
    `updateVoiceMIDIDelay`).
  - `UIState.ccLanes(for voiceID: String) -> [CCLane]`
  - `UIState.addLFO(to voiceID: String)` (no-op at `CCLane.maxPerVoice`),
    `UIState.removeLFO(_ index: Int, from voiceID: String)`,
    `UIState.updateLFO(_ index: Int, of voiceID: String, _ change: (inout CCLane) -> Void)`
    — `updateLFO` first materializes `controller` from `resolvedController`
    so old map-based lanes keep their CC (Review Focus 1).
  - `UIState.collapsedLFOVoices: Set<String>` + `toggleLFOStrip(_:)` (not saved).
- Removed: `UIState.profileStore`, `applyProfile`, `AppServices.updateVoiceCCMap`.
  (The swapped MicroFreak numbers disappear with the store; nothing else
  hard-codes them — verified by grep.)

- [ ] **Step 1:** implement; `swift build` clean; `swift test` green.
- [ ] **Step 2:** Commit `refactor(app): LFO edits through UIState; CC profile menu removed (FR-MOD-5)`.

### Task 4: midi.guide data + `MIDIGuideCatalog`

**Files:**
- Create: `scripts/update_midiguide.py` (Python: CSV → JSON; jq cannot read
  CSV, and `scripts/make_appcast.py` sets the precedent),
  `Resources/MIDIGuide/midiguide.json`, `Resources/MIDIGuide/NOTICE.md`
  (source URL, commit SHA, date, CC BY-SA 4.0, "modified: CC rows only,
  converted to JSON"), `Sources/BerlinanRuntime/MIDIGuideCatalog.swift`
- Modify: `build.sh` (copy `Resources/MIDIGuide` into `Contents/Resources/`)
- Test: `Tests/BerlinanRuntimeTests/MIDIGuideCatalogTests.swift`

**Interfaces:**
- Script: downloads `https://codeload.github.com/pencilresearch/midi/tar.gz/refs/heads/main`
  into a temp dir, reads every `*.csv` except `*.triggers.csv` (utf-8-sig),
  keeps rows whose `cc_msb` is an integer 0–127, `min`/`max` from
  `cc_min_value`/`cc_max_value` clamped to 0–127 (default 0/127), empty
  section → `"General"`; groups manufacturer › model (file's `device`) in
  case-insensitive alphabetical order; parameters in file order; writes
  compact JSON + NOTICE.
- JSON shape: `[{"name": "...", "models": [{"name": "...", "parameters":
  [{"section": "...", "name": "...", "cc": 23, "min": 0, "max": 127}]}]}]`.
- Swift (`public struct MIDIGuideCatalog: Sendable`):
  - nested `Parameter` (`section`, `name`, `cc: UInt8`, `min: UInt8`,
    `max: UInt8`), `Model` (`name`, `parameters`), `Manufacturer` (`name`,
    `models`) — all `Codable, Hashable, Sendable`.
  - `let manufacturers: [Manufacturer]`; `init(manufacturers:)`;
    `static func load(from url: URL) throws -> MIDIGuideCatalog`;
    `static func bundled(in bundle: Bundle = .main) -> MIDIGuideCatalog?`
    (resource `MIDIGuide/midiguide.json`; nil when missing);
    `func filtered(by query: String) -> [Manufacturer]` — trimmed query; empty
    → all; manufacturer name match → all its models; else only matching
    models; else dropped.

- [ ] **Step 1: Failing tests** (fixture catalog Elektron[Digitakt, Digitone,
  Analog Four], Digitech[Whammy], Arturia[MicroFreak]):
  - `"digi"` → Elektron [Digitakt, Digitone] + Digitech [Whammy];
  - `"  "` / `""` → all three, all models; `"ARTURIA"` → Arturia, all models;
    `"xyz"` → empty;
  - `bundledMissingReturnsNil`: `bundled(in: Bundle(for:…))`-free variant —
    `load(from:)` on a nonexistent URL throws, `bundled(in:)` on a bundle
    without the resource returns nil;
  - `realSnapshotLoads`: load `Resources/MIDIGuide/midiguide.json` via
    `#filePath` → > 100 manufacturers; Arturia › MicroFreak: Timbre 12,
    Shape 13, Cutoff 23.
- [ ] **Step 2:** run script; run tests → FAIL. **Step 3:** implement catalog.
- [ ] **Step 4:** `swift test` green; `./build.sh debug` → file present in
  `build/debug/Berlinan.app/Contents/Resources/MIDIGuide/`.
- [ ] **Step 5:** Commit `feat(runtime): bundled midi.guide CC catalog with manufacturer/model search (FR-MOD-9)`.

### Task 5: LFO strip, row and knob

**Files:**
- Create: `Sources/Berlinan/Views/KnobView.swift`,
  `Sources/Berlinan/Views/LFOStripView.swift`
- Modify: `Sources/Berlinan/Views/VoiceLaneView.swift`

**Interfaces:**
- `KnobView(value: Binding<Double>, range: ClosedRange<Double>, label: String, disabled: Bool)`
  — vertical drag (≈150 pt = full range), tangerine arc, mono readout.
- `LFOStripView(ui: UIState, voiceID: String)` — rows + "＋ add LFO" (hidden
  at 4); each row per DESIGN goal 2: CC field (Enter/blur commits; editing
  clears `label`), 🔍 (opens Task 6 sheet; disabled + tooltip when catalog nil),
  label text (`label`, or the old `target` name for map lanes), shape menu,
  cycle menu 1/2/4/8/16/32/64, Min/Max fields, depth + phase knobs (S&H
  disables cycle + phase), curve preview, ✕.
- Curve preview: render `[lane]` with `ModulationEngine.render` over one cycle
  (S&H: one bar) into a `Canvas`; dashed Min/Max lines; playhead at
  `(ui.currentTick mod previewLength) / previewLength`.
- `VoiceLaneView`: body becomes a VStack (existing HStack + strip when lanes
  exist and not collapsed); header gets `∿ ＋` (no lanes) or `∿ n` toggle.

- [ ] **Step 1:** implement; `./build.sh debug`; `./run.sh debug`.
- [ ] **Step 2: Manual checklist** (record in VERIFICATION.md): add/remove
  LFOs up to 4; CC field typing incl. 200/−1; Min>Max typing; depth knob
  narrows/widens around center; S&H disables cycle/phase; collapse; old demo
  lane shows CC 74 "filter"; CC changes audible/visible live (MIDI monitor).
- [ ] **Step 3:** Commit `feat(app): CC LFO strip under each voice lane (FR-MOD-3)`.

### Task 6: Parameter browser + credits

**Files:**
- Create: `Sources/Berlinan/Views/CCParameterBrowserView.swift`,
  `Resources/Credits.html` (About panel credits: midi.guide CC BY-SA 4.0 link)
- Modify: `Sources/Berlinan/UIState.swift` (catalog loaded once,
  `lastBrowsedModel: (manufacturer: String, model: String)?`),
  `Sources/Berlinan/Views/LFOStripView.swift`, `build.sh` (copy Credits.html)

**Interfaces:**
- `CCParameterBrowserView(catalog: MIDIGuideCatalog, initial: (String, String)?, onPick: (manufacturer: String, model: String, parameter: MIDIGuideCatalog.Parameter) -> Void)`
  — search field + three columns, section headers in the parameter column,
  Select / Cancel, double-click picks, footer credit.
- On pick: `controller = cc`, `label = "<manufacturer> <model> › <name>"`,
  `setRange(min: parameter.min, max: parameter.max)`; remember the model.

- [ ] **Step 1:** implement; build + run; checklist: "digi" → Elektron with 4
  Digi models; selecting changes right column; pick sets CC + name + range;
  reopening starts at the last model; About shows the credit.
- [ ] **Step 2:** Commit `feat(app): midi.guide parameter browser for CC LFOs (FR-MOD-9)`.

### Task 7: Docs, manual, website

**Files:**
- Modify: `generative_sequencer_spec.md` (FR-MOD-3 UI editor + direct CC;
  FR-MOD-5 → profiles replaced by the browser; new FR-MOD-9 browser + data
  licence; §-traceability), `README.md` (feature + credit in License),
  `CHANGELOG.md` (Unreleased), `development_workflow.md` (§2.1 bundle copies
  MIDIGuide + Credits; release step: run `scripts/update_midiguide.py`),
  `docs/manual.html` + `docs/cs/manual.html` (new "CC LFO" section in Voice
  lanes with strip + browser screenshots and marks; lane-menu text without
  CC Profile; credit), `docs/index.html` + `docs/cs/index.html` (feature
  line), screenshots in `docs/assets/manual/` (new `lfo-strip.png`,
  `cc-browser.png`; retake `main.png`, `menu-lane.png` and any figure whose
  marks moved because of the strip).
- [ ] **Step 1:** edit docs; take screenshots from the debug build; re-measure
  marks; check both languages in Safari and Chrome.
- [ ] **Step 2:** Commit `docs: CC LFO editor and midi.guide browser — spec, manual EN/CS, website`.

### Task 8: Verify and merge

- [ ] `swift test` (all green, count recorded), `./build.sh debug`, final
  whole-branch review by a fresh reviewer; fix findings.
- [ ] `VERIFICATION.md`, ROADMAP (phase 61 row), STATE; commit; merge
  `--no-ff` to `main`; delete branch. Ask the user before any push/release.
