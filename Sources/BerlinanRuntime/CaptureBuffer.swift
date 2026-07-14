import BerlinanEngine

/// Rolling performance capture (FR-IO-7): every note the engine played,
/// prunable to a tick capacity, exportable as bar-aligned clips. Pure value
/// type — the Transport owns one and feeds it from the scheduler thread.
public struct CaptureBuffer: Sendable {

    private var notes: [RenderedNote] = []
    private var headTick: Tick = 0
    public let capacityTicks: Tick

    public init(capacityTicks: Tick) {
        precondition(capacityTicks > 0)
        self.capacityTicks = capacityTicks
    }

    public var isEmpty: Bool { notes.isEmpty }
    public var allNotes: [RenderedNote] { notes }
    public var head: Tick { headTick }

    /// Append a rendered window; `upTo` advances the head (the exclusive end
    /// of what has been rendered so far).
    public mutating func append(_ rendered: [RenderedNote], upTo tick: Tick) {
        notes.append(contentsOf: rendered)
        headTick = max(headTick, tick)
        let floorTick = headTick - capacityTicks
        if let firstKept = notes.firstIndex(where: { $0.at >= floorTick }) {
            if firstKept > 0 { notes.removeFirst(firstKept) }
        } else if !notes.isEmpty {
            notes.removeAll()
        }
    }

    /// The last `lastBars` whole bars ending at (or before) `endTick`,
    /// rebased to start at tick 0 **on a bar boundary** — exported clips
    /// launch cleanly under DAW quantization (FR-IO-9 groundwork).
    public func notes(lastBars: Int, endTick: Tick, meter: Meter) -> [RenderedNote] {
        precondition(lastBars > 0)
        let barTicks = meter.ticksPerBar
        let end = endTick / barTicks * barTicks          // floor to bar
        let start = max(0, end - Tick(lastBars) * barTicks)
        return notes
            .filter { $0.at >= start && $0.at < end }
            .map { n in
                var out = n
                out.at -= start
                return out
            }
    }
}
