# Phase 23 — Ableton Link (licensing gate)

## Gate result (2026-07-15)

Verified via web: **Ableton Link (desktop C++ library) is dual-licensed** —
GPLv2+ for open-source use, or a proprietary license granted by Ableton on
request (link-devs@ableton.com) for closed-source apps.

Berlinan's situation: private repo today, but signed-DMG distribution to
other machines is the stated goal (NFR-7). Integrating Link under GPLv2
would obligate open-sourcing the app upon distribution.

## Decision required from the user (recorded as an open question)

1. **Open-source Berlinan** (GPLv2-compatible) → Link under GPL, no contact
   with Ableton needed; or
2. **Request the proprietary Link license** from Ableton (free of charge,
   email agreement) and integrate after it is granted; or
3. **Skip Link** — clock slave (phase 22) already covers tempo/transport
   sync with Ableton in both directions (master via phase 12, slave via 22).

## Status

**UNBLOCKED 2026-07-15**: user decision — Berlinan is OPEN SOURCE. Project
licensed GPL-2.0-or-later (LICENSE added), mirroring Link's license exactly.
Integration plan: vendor Ableton/link (with its asio submodule) under
Vendor/, compile the repo's official `abl_link` C wrapper in a C++ SPM
target, wrap it in a Swift `LinkService`, and add a `.link` sync mode to the
Transport (per-wake beat/tempo query → clock segment re-anchor, same
machinery as the clock slave).

Sources: github.com/Ableton/link (LICENSE.md), ableton.github.io
