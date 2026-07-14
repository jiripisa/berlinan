# Step-based ratchet (follow-up fix, 2026-07-15)

User feedback: gate-based ratchet slices (~30–40 ms on short pluck gates)
read as a flam, not the hardware "d-d-d".

- New `Ratchet.expand` in the engine — THE single source of truth for both
  the SMF writer and the live converter (the math had been duplicated).
- Retriggers now subdivide ONE 16th step (240 ticks): ratchet 2 = 32nd
  spacing, ratchet 3 = 16th triplets. Sub-gate = min(90% slice, original
  gate) so plucks stay plucky.
- Golden regenerated (justified: ratchet timing change in the demo render).
- 202 tests green; live ≡ export by construction now.
