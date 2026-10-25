# Phase 56 — Auto-update (user request)

## Goal

User request (2026-10-25): at launch the app checks whether a newer
version is available; if so it offers the update and, when the user
agrees, updates itself. The check can be switched on/off in the app's
settings. User decisions: **Sparkle**; the check is **on by default**.
New requirement **FR-UX-8**.

## Design decisions

- **Sparkle 2** (SPM, `sparkle-project/Sparkle` from 2.6.4; resolved 2.10.1)
  via `SPUStandardUpdaterController`: standard dialog (release notes,
  Install Update / Skip This Version / Remind Me Later), download, EdDSA +
  Developer ID verification, replace and relaunch.
- **At launch**: when enabled, a background check on every launch (not
  Sparkle's daily schedule) — the user asked for "at start". A background
  check shows UI only when an update exists. Nothing is downloaded or
  installed without the user's yes.
- **Setting**: a new app-level Settings window (Berlinan ▸ Settings…, ⌘,),
  toggle "Check for updates when Berlinan starts", bound to
  `SPUUpdater.automaticallyChecksForUpdates` (Sparkle persists it in user
  defaults). Plus "Check for Updates…" in the app menu and a button in
  Settings for a manual check.
- **Feed**: `https://jiripisa.github.io/berlinan/appcast.xml` (GitHub Pages,
  HTTPS), enclosure = the release DMG on GitHub Releases. Info.plist:
  `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks` = YES.
- **Signing key**: EdDSA pair from Sparkle's `generate_keys` — private key
  in the developer's login Keychain (never in the repo), public key in
  Info.plist. `build.sh dist` signs the DMG with `sign_update` and writes
  `docs/appcast.xml` (version, release-notes link, length, signature).
- **Bundle**: `build.sh` copies `Sparkle.framework` into
  `Contents/Frameworks`; the app is unsandboxed (NFR-7), so Sparkle's XPC
  services are removed (Sparkle docs: only sandboxed apps need them).
  Code signing inside-out: Autoupdate, Updater.app, framework, app —
  hardened runtime + timestamp (debug: ad-hoc).
- The engine and runtime layers are untouched.

## Acceptance criteria

- [ ] App builds and launches with Sparkle embedded (debug + dist);
      `codesign --verify --deep --strict` passes; notarization accepted
- [ ] Settings window: toggle persists across launches; default on
- [ ] Launch with the toggle on and a newer appcast item → update dialog;
      with the toggle off → no request
- [ ] End-to-end: an older build updates itself to a newer signed build
      from a local feed and relaunches as the new version
- [ ] `build.sh dist` produces a valid signed appcast entry
- [ ] Docs: spec FR-UX-8, README, manual (EN + CS), CHANGELOG

## Out of scope

Delta updates, beta channel, automatic silent install.
