# Phase 29 — Alternating Scheduler, Tension Scoring, Bass Melody

## Goal

The rest of the melody engine: two voices in complementary 4-bar phrase
slots that never sound together (FR-MEL-3), note choice scored by the
manual's interval tension table with the tense→release→release walk as the
default contour (FR-MEL-4), and the bass-melody mode — progression roots
joined by scale passing tones (FR-MEL-5).

## Design decisions

- **Alternation (FR-MEL-3)**: `Project.alternating: AlternatingConfig?`
  (voiceA, voiceB, phraseBars=4) + live `.setAlternating` action
  (bar-quantized). Render-level gate: a note sounds only if its onset bar
  belongs to the voice's slot (`(bar / phraseBars) % 2`), and gates clamp at
  the slot edge — "never simultaneously" holds at the tick level. Delay-hint
  tags: slot A keeps the role's division, slot B answers on quarters
  (`DelayHint.compute(alternationSlot:)`), so the two phrases echo
  differently (M §8.3).
- **Tension (FR-MEL-4)**: `TensionTable.score(semitones:)` per M §4.4
  (unison/P5 restful … m2/tritone tense). Melody growth picks switch to the
  tension-walk policy: growth stages cycle tense → release → release,
  scoring each candidate against the melody note preceding it.
- **Bass melody (FR-MEL-5)**: new generator `.bassMelody(bars:)` — beat 1 of
  every bar states the bar's progression root (offsets baked from the
  resolved schedule); the bar's tail walks stepwise through scale degrees
  toward the next bar's root. Regenerate refreshes it after harmony moves.

## Acceptance criteria

- [ ] Alternation: 16 bars → no tick where both voices sound; A owns bars
      0–3/8–11, B owns 4–7/12–15; toggle off restores both; chunk-safe
- [ ] Delay hints differ between the two alternating voices
- [ ] TensionTable: manual's ordering (m2 > tritone > M7 … > P5 > unison)
- [ ] Growth with tension-walk: first growth adds a tense note, the next
      two add restful ones (deterministic)
- [ ] bassMelody: beat-1 roots match the schedule per bar; passing tones are
      in-scale and stepwise (|Δdegree| ≤ 2); loops at the requested length
- [ ] Human: alternating call-and-answer feels like M §8.3; bass melody
      walks the progression

## Out of scope

Tension budget & chord layer & kick (30), release (31).
