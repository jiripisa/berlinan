/// PLL-style tempo estimator for incoming MIDI clock (FR-IO-4, spec §8.4):
/// median of the last 9 inter-pulse intervals kills outliers, an EMA smooths
/// the rest. Pure value type — fully unit-testable.
public struct ClockEstimator: Sendable {

    private var intervals: [Double] = []      // ns between pulses, last 9
    private var lastPulseNanos: UInt64? = nil
    private var smoothed: Double? = nil       // EMA of the median interval
    public private(set) var pulseCount = 0

    public init() {}

    public mutating func pulse(atNanos nanos: UInt64) {
        if let last = lastPulseNanos, nanos > last {
            let interval = Double(nanos - last)
            intervals.append(interval)
            if intervals.count > 9 { intervals.removeFirst() }
            let median = intervals.sorted()[intervals.count / 2]
            smoothed = smoothed.map { $0 * 0.9 + median * 0.1 } ?? median
        }
        lastPulseNanos = nanos
        pulseCount += 1
    }

    /// Estimated tempo (24 PPQ), nil until two pulses arrived.
    public var bpm: Double? {
        smoothed.map { 60_000_000_000.0 / ($0 * 24.0) }
    }

    public var lastPulse: UInt64? { lastPulseNanos }

    public mutating func reset() {
        intervals.removeAll()
        lastPulseNanos = nil
        smoothed = nil
        pulseCount = 0
    }
}
