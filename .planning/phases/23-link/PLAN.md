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

**DEFERRED** pending the user's licensing decision. No code in this phase.
Clock-slave is the shipping sync path for v1.0; Link integration (LinkKit/
C++ wrapper, quantum-aligned start, session tempo) becomes a post-v1 phase
once unblocked.

Sources: github.com/Ableton/link (LICENSE.md), ableton.github.io
