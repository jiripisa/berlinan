# Phase 55 — Legibility (user report) — Verification

Date: 2026-10-25 · Branch: fix/55-legibility

User report: the manual's screenshots showed dark empty boxes; asked to
check that every UI element of the app is readable (no dark text on dark).

## Findings and fixes

1. **Manual — empty dark boxes**: `loading="lazy"` on images inside
   `overflow: hidden` zoom boxes; Safari never loaded them (Chrome did, so
   my headless check missed it). Removed lazy loading (EN + CS). Verified
   in Safari: images appear.
2. **App — low-contrast labels**: measured WCAG contrast of the ink scale
   on all four panel backgrounds: `ink3` 3.5–3.9:1, `ink4` 2.1–2.4:1 — and
   `ink4` was used for 20 text labels (POS/BPM/KEY/DEG, HARMONY, HORIZON,
   LCM, DEG/SNAP/ARR/DENS, settings and editor field labels, hints, the
   engine version). Fix: labels/hints moved to `ink3`; `ink3` → `#7e8692`
   (4.6–5.1:1), `ink4` → `#606973` (3.1–3.4:1, disabled states only).
   Contrast floor documented in design_language.md §2.3.
3. **App — truncated controls**: at default width the performance panel
   squeezed "AUTO" to an empty box, "SNAP" to "SN/AP" and "RE-ROLL
   UNLOCKED" to two lines. The panel now picks one row, two rows, or three
   rows (`ViewThatFits`), labels don't wrap.

## Checks

| Check | Result |
|---|---|
| `swift test` | ✅ 340 tests / 117 suites green |
| Demo trio at 1400 / 1100 / 760 px, stopped | ✅ all labels whole and readable |
| Ambient drift playing at 1400 px (SCENE, phase, advance) | ✅ two rows, nothing truncated |
| Project Settings sheet | ✅ field labels and hint readable |
| Manual in Safari (local) | ✅ screenshots render |

Not done: the manual's screenshots still show the pre-fix (darker) labels;
retake them with the next release build.
