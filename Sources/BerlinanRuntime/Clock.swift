import Darwin
import BerlinanEngine

/// Musical-time ↔ host-time mapping (spec §8.1). Pure math over an anchor:
/// mach time at tick 0. The timebase is injected so tests can use identity
/// (mach = ns); production uses `TickClock.current(bpm:anchorMach:)`.
public struct TickClock: Sendable {
    public let bpm: Double
    public let anchorMach: UInt64
    /// The tick anchored at `anchorMach` — runtime tempo changes create a
    /// new clock segment anchored at the swap boundary (piecewise-linear
    /// map, spec §8.1; FR-GS-5).
    public let anchorTick: Tick
    public let timebase: (numer: UInt64, denom: UInt64)

    public init(bpm: Double, anchorMach: UInt64, anchorTick: Tick = 0,
                timebase: (numer: UInt64, denom: UInt64)) {
        precondition(bpm > 0)
        self.bpm = bpm
        self.anchorMach = anchorMach
        self.anchorTick = anchorTick
        self.timebase = timebase
    }

    /// Production clock with the machine's real timebase.
    public static func current(bpm: Double, anchorMach: UInt64,
                               anchorTick: Tick = 0) -> TickClock {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return TickClock(bpm: bpm, anchorMach: anchorMach, anchorTick: anchorTick,
                         timebase: (UInt64(info.numer), UInt64(info.denom)))
    }

    /// Nanoseconds per tick at this tempo (960 PPQN).
    private var nanosPerTick: Double { 60_000_000_000.0 / (bpm * Double(Time.ppqn)) }

    /// mach units for a musical tick.
    public func machTime(forTick tick: Tick) -> UInt64 {
        let nanos = Double(tick - anchorTick) * nanosPerTick
        let mach = nanos * Double(timebase.denom) / Double(timebase.numer)
        return UInt64(Int64(anchorMach) + Int64(mach.rounded()))
    }

    /// The musical tick at a mach time (floor; below anchorTick before it).
    public func tick(atMach mach: UInt64) -> Tick {
        let deltaNanos = Double(Int64(mach) - Int64(anchorMach))
            * Double(timebase.numer) / Double(timebase.denom)
        return anchorTick + Tick((deltaNanos / nanosPerTick).rounded(.down))
    }
}
