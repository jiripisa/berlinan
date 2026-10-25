# Berlinan — Design Language

Visual design system for the Berlinan app. Derived from **Sampio**'s proven studio-dark design system (`../Sampio/Sources/Sampio/Views/Theme/DesignTokens.swift`), adapted and extended for a generative sequencer. Implementation mirror: `Sources/Berlinan/Theme/DesignTokens.swift` — this document is the source of truth; the Swift file must match it token for token.

---

## 1. Principles

1. **Studio-dark, always.** One theme only (no light mode in v1) — the app lives next to DAWs and hardware in dim studios. Deep neutral surfaces, hairline separations, restrained glow accents. This is Sampio's foundation, kept intact because it already reads as serious audio software.
2. **Data is monospaced.** Every number the producer reads under pressure — bars, ticks, BPM, degrees, LCM countdowns, CC values — is set in mono with tabular rendering. Sans is for labels and controls only.
3. **Calm surface, live details.** The overall canvas is static and quiet; *movement is information*: playheads, lifecycle dots, convergence ring, MIDI activity LEDs. Nothing animates decoratively.
4. **Hardware-informed, not skeuomorphic.** Flat panels and hairlines; the only "physical" metaphors are LED-style indicators and step-grid cells — echoes of the sequencers the genre was built on (Manual §1), not wood-panel nostalgia.
5. **Accent = state, never decoration.** Tangerine marks *what is hot right now* (playing, active, armed). If everything glows, nothing does.

---

## 2. Color Tokens

### 2.1 Surfaces (adopted from Sampio unchanged — proven)

| Token | Hex | Use |
|---|---|---|
| `bgRoom` | `#0b0d10` | outermost background (around window content) |
| `bgWindow` | `#131418` | window body |
| `bgPanel` | `#1a1c21` | sub-panels: toolbars, inspector |
| `bgPanel2` | `#15171b` | deeper: voice-lane pattern strips |
| `bgPanel3` | `#0f1115` | deepest: timeline strip, status bar |
| `toolbarGradient` | `#16191f → #12141a` (vertical) | transport bar chrome |
| `laneGradient` | `#161920 → #0e1014` (vertical) | pattern-strip interior fill |

### 2.2 Hairlines

| Token | Hex |
|---|---|
| `line` | `#24272d` |
| `lineSoft` | `#1d1f24` |
| `lineStrong` | `#2c3037` |

### 2.3 Text — ink scale (adopted from Sampio)

| Token | Hex | Use |
|---|---|---|
| `ink` | `#e7ecf2` | primary text, big numerals |
| `ink2` | `#aab2bd` | secondary labels |
| `ink3` | `#7e8692` | tertiary: field labels (POS, HARMONY, LCM…), hints, captions |
| `ink4` | `#606973` | disabled / ghosted states only — never for labels or hints |

**Contrast floor** (raised 2026-10-25 after labels proved hard to read):
every text colour must reach **4.5:1** on all four panel backgrounds —
`ink3` measures 4.6–5.1:1, `ink2` 8.0–8.8:1. `ink4` (3.1–3.4:1) is reserved
for disabled or empty controls, where WCAG's text minimum does not apply,
and still stays readable. The originals (`#6b727c` 3.5:1, `#4a5159` 2.1:1)
were too dark for 9–10 pt labels.

### 2.4 Accents — the Berlinan differentiation

Sampio's primary accent is electric cyan. Berlinan swaps the hierarchy: the primary accent is **tangerine** — a deliberate nod to Tangerine Dream and warm analog-era hardware — with cyan demoted to a secondary, informational role. This keeps the family resemblance while making the two apps instantly distinguishable.

| Token | Hex | Use |
|---|---|---|
| `tangerine` | `#FF9E4A` | **primary accent**: playhead, active degree button, playing-state controls, selection |
| `tangerineSoft` | `#E8873A` | hover/secondary intensity |
| `tangerineDeep` | `#A85C1F` | pressed / low-emphasis fills |
| `tangerineGlow` | `#FF9E4A` @ 18% | background halo of active controls (Sampio glow pattern) |
| `tangerineLine` | `#FF9E4A` @ 45% | border of active controls |
| `cyan` | `#4FD9F2` | **secondary/informational**: phasing & convergence display, sync status (Link/clock), harmony-timeline markers |
| `cyanGlow` / `cyanLine` | @ 18% / 45% | same pattern as tangerine |

### 2.5 Functional colors

| Token | Hex | Use |
|---|---|---|
| `rec` | `#FF6A4F` | capture/record states, destructive confirmation (Sampio value) |
| `recGlow` / `recLine` | @ 20% / 45% | armed halo / border |
| `amber` | `#F6C16B` | warnings: pending-at-next-bar badges, "echoes already in MIDI" delay warning, tension-budget spent |
| `green` | `#7BD88F` | positive/live: MIDI activity LEDs, sync locked, note-on flashes |

### 2.6 Voice identity colors

Each voice lane carries a desaturated identity hue (lane header strip, notes in the pattern view, its channel in the harmony overview). Muted enough not to fight the accent system:

| Role | Hex | Character |
|---|---|---|
| bedPluck1 | `#5FB8C9` (dusty cyan) | the sequence |
| bedPluck2 | `#5F9EC9` (dusty blue) | the phasing partner |
| bass | `#C9975F` (dusty amber) | the anchor |
| pad | `#9B7FC9` (dusty violet) | the harmony bed |
| lead | `#D9DDE3` (near-ink) | the voice |
| drone | `#5F6FA8` (deep slate blue) | the continuity |
| rhythm | `#C96F6F` (dusty red) | the heartbeat |

Active/playing notes render at full identity hue; idle at 55% opacity; muted lanes drop to `ink4` tinting.

---

## 3. Typography

System fonts only (Sampio decision, kept): native rendering, no font-loading complexity. SF Pro (sans) + SF Mono via `.system(design:)`.

| Role token | Font | Size/weight | Tracking | Use |
|---|---|---|---|---|
| `sectionLabel` | sans bold | 9.5 | 1.6 pt | uppercase panel headers: "VOICES", "HARMONY", "PHASING" |
| `fieldLabel` | mono medium | 9 | 1.3 pt | field captions: "BPM", "KEY", "LCM", "DEG" |
| `monoCaption` | mono regular | 10 | 0.6 pt | readouts, status bar, hints |
| `timecodeBig` | mono medium | 18 | — | bar:beat position, BPM display |
| `degreeDisplay` | mono bold | 24 | — | current transposition degree (the biggest number in the app) |
| `body` | sans regular | 11 | 0.2 pt | buttons, menus, inspector controls |

Rules: all-caps only with wide tracking (`sectionLabel`/`fieldLabel`); numerals in readouts use monospaced digits everywhere (including sans contexts via `.monospacedDigit()`).

---

## 4. Component Language

- **Panels**: flat `bgPanel*` fills separated by 1 px `line` hairlines; corner radius 6 for floating elements (popovers, sheets), 4 for inline controls, 0 for docked panels.
- **Active-state pattern** (from Sampio): `*Glow` background + `*Line` border + full-strength icon/text. Applied uniformly: degree buttons, MIDI-delay toggle, lock icons, sync indicator.
- **Step grid cells**: rounded-2 rectangles; empty = `bgPanel3` with `lineSoft` border; note = voice identity color; accent note = identity color + `tangerineLine` border; playing column highlighted by a `tangerineGlow` sweep.
- **Lifecycle dots** (legitimization, spec §11.2): four 5 px dots `●●●○` — filled = repeats remaining (`ink2`), the moment a pattern becomes mutable the row flashes once in `cyan`.
- **Convergence ring** (spec §11.3): thin circular progress in `cyan` around the LCM readout; completes exactly when all loops re-converge.
- **LED indicators**: 6 px circles — `green` MIDI activity (per voice, 120 ms decay), `rec` capture, `amber` pending-change. Glow via 2 px blur shadow of the same color at 60%.
- **Buttons**: borderless icon buttons on toolbars (Sampio `EditToolbarButton` pattern — hover = `bgPanel` lift, active = glow pattern); text buttons only in sheets/dialogs.
- **Sheets** (settings, export, MIDI setup): `bgWindow` cards over a dimmed scrim, `sectionLabel` headers, right-aligned action row.
- **Spacing**: 8 pt base grid; 12 pt panel padding; 4 pt intra-control gaps.
- **Focus & keyboard**: focused lane gets a `lineStrong` left edge bar (3 px) in the voice identity color; never a system focus ring on the canvas.

---

## 5. Signature Screens (mood targets)

- **Main window** reads like a modern hardware sequencer's companion: dark lanes with softly glowing step grids, one tangerine playhead sweeping all lanes in sync, mono numerals ticking. Density comparable to Ableton's Session View — informative, never cramped.
- **Performance panel** feels like a live instrument: seven large degree buttons (tangerine glow on the active one), two knobs, snapshot slots as labeled pads.
- **Delay Cheat Sheet** looks like a printed studio reference card: mono table, `fieldLabel` headers, copy buttons.

The bar to clear: side by side with Ableton Live and a Moog editor, Berlinan should look like it belongs — an *advanced instrument*, not a utility.

---

## 6. Implementation Notes

- Mirror this document into `Sources/Berlinan/Theme/DesignTokens.swift` as `enum AppColor`, `enum AppFont`, `enum AppTracking` + new `enum VoiceColor` (Sampio file is the structural template; keep the hex comments for traceability).
- All views consume tokens only — no inline `Color(red:...)` literals outside `DesignTokens.swift` (enforced by grep check in CI/pre-merge later).
- Window appearance forced to dark (`NSAppearance(named: .darkAqua)`); the app does not follow the system light mode in v1.
