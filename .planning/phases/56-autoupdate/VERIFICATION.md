# Phase 56 — Auto-update — Verification

Date: 2026-10-25 · Branch: feature/56-autoupdate · Suite: **340 tests / 117 suites green**

## Results

| Criterion | Result |
|---|---|
| Sparkle 2.10.1 resolved via SPM; embedded in `Contents/Frameworks`, XPC services removed | ✅ |
| Debug build: ad-hoc signature `codesign --verify --deep --strict` | ✅ |
| `build.sh dist`: Sparkle signed Developer ID + hardened runtime; app + DMG notarization **Accepted**, stapled; `spctl` Notarized Developer ID; notarized app launches | ✅ |
| `build.sh dist` writes a signed appcast (`appcast: docs/appcast.xml`) | ✅ (test output discarded — it pointed at the old 1.2.7 DMG) |
| Settings window (⌘,): toggle default **on**, persists (Sparkle `SUEnableAutomaticChecks` in user defaults); Check Now; app menu "Check for Updates…" | ✅ screenshot + accessibility |
| **End-to-end**: 1.2.7 build, feed on a local HTTP server (EdDSA-signed 1.2.99 DMG) → at launch the dialog "Berlinan 1.2.99 is now available—you have 1.2.7" → Install Update → Install and Relaunch → the same path now holds 1.2.99, new process running, signature valid | ✅ |
| Toggle off → no feed request at launch (server log), no dialog; toggle on via the UI → dialog again | ✅ |
| Release notes from the CHANGELOG render in the dialog | ✅ screenshot |
| No silent installs: `SUAllowsAutomaticUpdates` = NO removes Sparkle's "automatically download and install" checkbox | ✅ screenshot |

Test hygiene: the feed override (`SUFeedURL` in user defaults) and every
other Sparkle key written during the test were deleted afterwards; the
test server was stopped and the scratch builds removed.

## Not verified / notes

- The first real update can only happen once a release with Sparkle is out:
  1.2.8 will be the first version that updates itself (to 1.2.9 and later).
  Installs of 1.2.7 and older have no updater and need one manual download.
- The live feed `https://jiripisa.github.io/berlinan/appcast.xml` does not
  exist until the 1.2.8 release commits it; until then the background check
  fails silently (404).

## Human checklist (pending)

- [ ] Back up the Sparkle private key: `generate_keys -x <file>`, store offline
- [ ] After 1.2.9: an installed 1.2.8 offers and installs it
