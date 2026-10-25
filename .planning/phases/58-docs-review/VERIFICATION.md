# Phase 58 — Documentation review (agent team) — Verification

Date: 2026-10-26 · Branch: feature/58-docs-review · User request: review the
manual/docs so a layperson understands them, no invented terms, concise,
makes sense; team of agents (pedagogue, Berlin School expert, QA, team
leader) + Codex as an independent reviewer.

## Process (workflow wf_32afd555-e7b)

- Review: pedagogue 30, Berlin School expert 17, quality controller 35,
  Codex 18 findings (docs/manual.html, docs/cs/manual.html, docs/index.html,
  docs/cs/index.html, README style laws + quick start).
- Team leader: 44 decisions (each checked against the Swift code), 15
  rejected with reasons, glossary of contested terms for EN/CS.
- EN + CS editors applied them; final QA: all 44 applied, EN/CS consistent,
  figure/mark markup, CSS, JS, ids and hrefs unchanged, no new HTML errors.

## Main corrections

- False claims: source of the style manual (≈225 video transcripts of one
  channel, not "225 hours of interviews"); B "drops the bed" (off by
  default); delay divisions vs DelayHint; AUTO "only advises"; README EXT
  setup ("Sync OUT to Berlinan" cannot work).
- Invented terms replaced or defined at first use (tension budget, lifecycle
  dots, convergence footer, bed, payoff, filter journey, …); voice names
  glossed; Getting started order fixed (output before Space); Czech wording
  ("soubor" for the ensemble, "glissando", anglicisms).

## Follow-ups done in this phase (owner approved)

- App tooltip of the clock menu: no more "Sync OUT to Berlinan"/"bar phase".
- Image alt texts and the animation aria-label use the new terms.
- README intro rewritten in the same plain wording.
- MIDI learn routing step: added "Monitor: In" (Live forwards MIDI only then).

Checked: Safari rendering of the CS manual and website; `swift build` green.
