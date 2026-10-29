# Berlinan — Development Workflow, Build & Distribution

How Berlinan is developed, built, run, and shipped. The build/packaging approach is adopted from the **Sampio** project (`../Sampio`), which has a proven Xcode-free, CLI-only pipeline including signed & notarized DMG distribution. The visual language is defined in `design_language.md`; the product spec in `generative_sequencer_spec.md`; the musical authority is `berlin_school_manual.md`.

---

## 1. Toolchain & Project Layout

**No Xcode IDE.** Everything runs from the command line: Swift toolchain (via Xcode Command Line Tools / full Xcode install for `notarytool`), Swift Package Manager, shell scripts.

Target repository layout (this repo grows into it):

```
berlin_school_manual/            # repo root (rename to `berlinan` is an option later)
├── berlin_school_manual.md      # musical authority (normative)
├── basic_concept.md             # product vision
├── generative_sequencer_spec.md # product spec (requirements/architecture/data model)
├── design_language.md           # visual design tokens & principles
├── development_workflow.md      # this document
├── docs/
│   └── synthkeeper/             # source transcripts (NOT committed — see §6.2)
├── .planning/                   # living planning system (see §5)
│   ├── ROADMAP.md  STATE.md  phases/  todos/  research/
├── Package.swift                # SPM manifest — executable app + engine library + CLI
├── Sources/
│   ├── BerlinanEngine/          # pure engine package target (spec §5.1)
│   ├── BerlinanCLI/             # `berlinan render` headless tool (milestone M1)
│   └── Berlinan/                # macOS app target (SwiftUI)
├── Tests/
│   ├── BerlinanEngineTests/     # golden masters, invariants (spec §12)
│   └── BerlinanTests/
├── Resources/
│   ├── Info.plist
│   ├── Berlinan.entitlements
│   └── AppIcon.png              # 1024×1024 source; .icns generated at build time
├── build.sh                     # debug | release | dist | clean
├── run.sh                       # debug (logs in terminal) | release (open .app)
└── .gitignore
```

`Package.swift` sketch (Sampio pattern, split into three targets per spec §5.1):

```swift
// swift-tools-version: 6.0
let package = Package(
    name: "Berlinan",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Berlinan", targets: ["Berlinan"]),
        .executable(name: "berlinan", targets: ["BerlinanCLI"]),
        .library(name: "BerlinanEngine", targets: ["BerlinanEngine"]),
    ],
    targets: [
        .target(name: "BerlinanEngine"),                      // zero Apple-framework deps
        .executableTarget(name: "BerlinanCLI", dependencies: ["BerlinanEngine"]),
        .executableTarget(name: "Berlinan", dependencies: ["BerlinanEngine"]),
        .testTarget(name: "BerlinanEngineTests", dependencies: ["BerlinanEngine"]),
        .testTarget(name: "BerlinanTests", dependencies: ["Berlinan"]),
    ]
)
```

---

## 2. Build (`build.sh`)

Adopted 1:1 from Sampio's `build.sh` with the app name swapped and the extra CLI product. Modes:

| Mode | What it does |
|---|---|
| `./build.sh debug` *(default)* | `swift build -c debug` → assemble `build/debug/Berlinan.app` → **ad-hoc codesign with entitlements** |
| `./build.sh release` | same with `-c release` → `build/release/Berlinan.app` |
| `./build.sh dist` | release build → **Developer ID signing (hardened runtime)** → **DMG** → **notarization + stapling** |
| `./build.sh clean` | remove `build/` and `.build/` |

### 2.1 App-bundle assembly (all modes)

SPM produces a bare executable; the script assembles the bundle manually:

1. `mkdir -p Berlinan.app/Contents/{MacOS,Resources}`; copy the built executable.
2. Copy `Resources/Info.plist` into `Contents/`; copy `Resources/MIDIGuide/` (the midi.guide CC catalog, CC BY-SA 4.0) and `Resources/Credits.rtf` (About panel credits) into `Contents/Resources/`.
3. Generate `AppIcon.icns` from `Resources/AppIcon.png` via `sips` (10 sizes: 16→1024 px) + `iconutil -c icns` into `Contents/Resources/`.
4. `echo -n "APPL????" > Contents/PkgInfo`.
5. `xattr -cr` the bundle (strip quarantine/extended attributes).
6. **Ad-hoc sign with entitlements even for debug builds** — Sampio lesson: TCC permission prompts require entitlements baked into the binary *signature*, not merely present in the bundle:
   ```
   codesign --force --sign - --entitlements Resources/Berlinan.entitlements Berlinan.app
   ```

### 2.2 Distribution (`dist`)

Aligned with the MDPre pipeline (`../MDPre/build.sh`).

1. Find the signing identity automatically:
   ```
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
   `dist` aborts with an error if it is absent (use `release` for an unsigned bundle).
2. Sign with hardened runtime and a secure timestamp (notarization rejects signatures without one). Sparkle (embedded in `Contents/Frameworks` by every build mode, XPC services removed — the app is unsandboxed) is signed first, inside-out: `Autoupdate`, `Updater.app`, `Sparkle.framework`; then the app:
   ```
   codesign --force --options runtime --timestamp --entitlements Resources/Berlinan.entitlements --sign "$IDENTITY" Berlinan.app
   ```
   then verify with `codesign --verify --deep --strict --verbose=2`.
3. Notarize and staple the app itself (zipped with `ditto -c -k --keepParent`), so a copy dragged out of the DMG passes Gatekeeper offline:
   ```
   xcrun notarytool submit build/Berlinan-notarize.zip --keychain-profile notary --wait
   xcrun stapler staple build/release/Berlinan.app
   ```
4. Build the DMG: staging folder with the app + an `/Applications` symlink (drag-to-install UX), then
   ```
   hdiutil create -volname Berlinan -srcfolder staging -ov -format UDZO build/Berlinan.dmg
   ```
5. Sign the DMG with the same identity (`--timestamp`).
6. Notarize and staple the DMG:
   ```
   xcrun notarytool submit build/Berlinan.dmg --keychain-profile notary --wait
   xcrun stapler staple build/Berlinan.dmg
   ```

7. Write the auto-update feed (phase 56): `scripts/make_appcast.py` signs the stapled DMG with Sparkle's `sign_update` (EdDSA private key from the login Keychain) and writes `docs/appcast.xml` — version, release notes from the CHANGELOG section, the GitHub Release download URL, length and signature. Commit it with the release; it goes live with the GitHub Pages deploy. Create the GitHub Release (DMG uploaded as `Berlinan-<version>.dmg`) **before** pushing the appcast, so the feed never points at a missing file.

**Sparkle signing key (one-time, per developer):** `.build/artifacts/sparkle/Sparkle/bin/generate_keys` stores the EdDSA private key in the login Keychain and prints the public key that lives in `Info.plist` (`SUPublicEDKey`). Back it up (`generate_keys -x <file>`, keep the file offline): without it no update can ever be signed for existing installs again.

A notarization `HTTP status code: 403. A required agreement is missing or has expired` is an account issue, not a script one: the Account Holder must accept the updated Apple Developer Program License Agreement at developer.apple.com/account.

The stapled, notarized DMG opens on any Mac without Gatekeeper warnings.

### 2.3 One-time signing setup (per machine)

1. A **Developer ID Application** certificate in the login keychain (Apple Developer Program membership; create via developer.apple.com → Certificates, or Xcode → Settings → Accounts).
2. A stored notarization profile named `notary` (overridable via `NOTARY_PROFILE` env var):
   ```
   xcrun notarytool store-credentials notary \
     --apple-id <apple-id-email> --team-id <TEAMID> --password <app-specific-password>
   ```

### 2.4 Entitlements & sandbox policy

Sampio ships **unsandboxed** (`com.apple.security.app-sandbox = false`) — legitimate for Developer ID/DMG distribution; notarization + hardened runtime is what Gatekeeper requires. Berlinan v1 follows the same policy to avoid entitlement friction around virtual MIDI endpoints and file promises; App Sandbox becomes a backlog item (revisit if App Store distribution is ever wanted). Spec NFR-7 is updated accordingly.

`Berlinan.entitlements` starts minimal (no audio-input needed — we emit MIDI only):

```xml
<dict>
    <key>com.apple.security.app-sandbox</key><false/>
</dict>
```

`Info.plist` essentials (Sampio pattern): `CFBundleIdentifier = io.jp4.berlinan`, `NSPrincipalClass = NSApplication`, `NSHighResolutionCapable`, `LSMinimumSystemVersion = 14.0`, `CFBundleDocumentTypes` for the `.berlinan` document package, and `UTExportedTypeDeclarations` for the custom type.

---

## 3. Run (`run.sh`)

Adopted from Sampio:

- `./run.sh debug` *(default)* — auto-rebuilds when any file under `Sources/` or `Resources/` is newer than the binary, registers the bundle with Launch Services (`lsregister -f`) so macOS treats it as a real app (TCC/permissions), then **`exec`s the binary in the terminal — log output streams live, Ctrl+C quits**.
- `./run.sh release` — auto-rebuild if stale, then `open Berlinan.app`.

Additional dev commands:

```
swift test                                   # engine + app tests
swift run berlinan render proj.json --bars 64 -o out.mid   # headless render (M1)
```

---

## 4. Development Methodology

### 4.1 Document hierarchy (docs-first)

1. **`berlin_school_manual.md`** — musical truth. Never edited casually; changes require transcript evidence.
2. **`generative_sequencer_spec.md`** — product truth. Every feature traces to an FR-ID; implementation deviations are recorded in the spec's traceability matrix.
3. **`.planning/`** — execution state (living, cheap to edit):
   - `ROADMAP.md` — milestones M1–M5 (mirrors spec §13) with phase breakdown and status.
   - `STATE.md` — current position: active phase, blockers, decisions log, next session's entry point.
   - `phases/NN-name/` — one folder per phase: `RESEARCH.md` (optional), `PLAN.md`, `VERIFICATION.md`.
   - `todos/` — small captured items outside the current phase (one file per todo, status field).
   - `research/` — spikes and findings (e.g. LinkKit licensing, CoreMIDI UMP behavior).

### 4.2 The phase cycle (spec → plan → implement → verify)

Milestones (spec §13) are broken into **phases** of roughly 0.5–2 days of work. Each phase runs:

1. **Plan** — write `phases/NN-name/PLAN.md`: goal, the FR-IDs it implements, concrete acceptance criteria (checkable, mapped to spec tests §12), files to touch, out-of-scope notes. If unknowns exist, a short `RESEARCH.md` spike first.
2. **Branch** — create a feature branch off `main`:
   ```
   feat/m1-03-scale-quantizer        # feat/<milestone>-<phase>-<slug>
   fix/<slug>, docs/<slug>, chore/<slug> for non-feature work
   ```
3. **Implement, test-first** — for engine work strictly TDD: write the failing invariant/golden-master test, then the code (the spec's §12 test list is the menu). UI work: implement + manual checklist in `PLAN.md`.
4. **Verify** — `swift test` green; `./build.sh debug` builds; record results in `VERIFICATION.md`. **Musical phases additionally run the listening protocol** (render → import into Ableton → check against the style checklist, spec §12.6) — a phase touching generation is not done until it *sounds* right.
5. **Merge** — merge to `main` with `--no-ff` (preserves phase boundaries in history), delete the branch, update `ROADMAP.md`/`STATE.md`.

Rules:

- **`main` is always green**: builds, tests pass, app launches. Broken states live only on branches.
- One phase = one branch = one merge. No long-lived branches.
- Golden-master diffs (deliberate engine-output changes) get their own commit with the musical justification in the message.

### 4.3 Commit conventions

Conventional Commits with a scope (Sampio practice):

```
feat(engine): degree-based pitch model with octave fold (FR-V-3)
test(engine): invariant — first sounding note is root
fix(midi): flush note-offs on route change (FR-IO-8)
docs(spec): resolve OQ-3 — LinkKit licensing
chore(build): bump version to 0.3
```

- Reference FR-IDs where applicable.
- Small, reviewable commits; tests may precede implementation in history (TDD).

### 4.4 Definition of Done (per phase)

- [ ] Acceptance criteria in `PLAN.md` all checked
- [ ] `swift test` green, no skipped tests without a linked todo
- [ ] `./build.sh debug` + `./run.sh debug` works (app phases)
- [ ] Listening protocol passed (musical phases)
- [ ] Spec traceability updated if behavior deviates
- [ ] `ROADMAP.md` / `STATE.md` updated, branch merged & deleted

### 4.5 Versioning & releases

- Version lives in `Resources/Info.plist` (`CFBundleShortVersionString`); pre-1.0 scheme `0.<milestone>.<patch>` (M2 exit = 0.2.0 — first usable jam tool), 1.0 at M4 exit per spec.
- Release procedure: refresh the midi.guide catalog (`scripts/update_midiguide.py`, review the diff) → bump version → `./build.sh dist` → smoke-test the DMG on a second machine or clean user account (Gatekeeper path!) → `git tag v0.x.y` → changelog entry in `CHANGELOG.md`.
- **Git pushes to any remote happen only after explicit confirmation** (standing rule); no remote is configured initially.

---

## 5. Planning System Bootstrap

Initial `.planning/` content to create when implementation starts (M1 kickoff):

- `ROADMAP.md` — copy spec §13 table, break M1 into phases: `01-package-skeleton`, `02-musical-state-and-scale`, `03-pattern-model`, `04-generators-1-3`, `05-phasing-and-lcm`, `06-legitimizer`, `07-harmony-transposition`, `08-smf-export`, `09-cli-and-golden-masters`.
- `STATE.md` — "M1 not started; next: phase 01."

---

## 6. Repository Policies

### 6.1 `.gitignore`

Sampio's, adapted:

```
.build/
build/
.swiftpm/
*.xcodeproj
xcuserdata/
DerivedData/
.DS_Store
.claude/settings.local.json
docs/synthkeeper/
```

### 6.2 Source transcripts are not committed

`docs/synthkeeper/` holds auto-generated transcripts of third-party YouTube videos — potentially copyrighted material, excluded from the repo for the same reason Sampio excludes `examples/` (user-supplied audio). The distilled knowledge lives in `berlin_school_manual.md`, which is committed. Keep a local backup of the transcripts outside git.
