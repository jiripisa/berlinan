/// Step-based ratchet expansion (M §13.5) — THE single source of truth for
/// both the SMF writer and the live converter (they diverged once; never
/// again).
///
/// Retriggers subdivide ONE 16th step (quarter-based, meter-independent),
/// not the note's gate: ratchet 2 = 32nd-note spacing, ratchet 3 = 16th
/// triplets — the audible "d-d-d" of hardware sequencers. The gate-based
/// variant (sliced short pluck gates ≈ 30–40 ms) read as a flam, not a
/// ratchet (user feedback 2026-07-15).
public enum Ratchet {

    /// The subdivided window: one 16th step.
    public static let stepTicks: Tick = Time.ppqn / 4      // 240

    /// Expand a note into its retriggers (identity for ratchet 1). Sub-gates
    /// are 90% of the slice, capped at the original gate so plucks stay
    /// plucky; expanded hits carry ratchet 1 (idempotent).
    public static func expand(_ note: RenderedNote) -> [RenderedNote] {
        guard note.ratchet > 1 else { return [note] }
        let slice = stepTicks / Tick(note.ratchet)
        let subGate = max(1, min(slice * 9 / 10, note.gate))
        return (0..<Tick(note.ratchet)).map { k in
            var hit = note
            hit.at = note.at + k * slice
            hit.gate = subGate
            hit.ratchet = 1
            return hit
        }
    }
}
