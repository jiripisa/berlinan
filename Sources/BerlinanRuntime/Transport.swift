import Darwin
import Foundation
import BerlinanEngine

/// The transport: owns the scheduler thread that pulls `LiveEngine` with
/// consecutive tick windows, timestamps events via `TickClock`, and sends
/// them through `MIDIService` (spec §8.2). MIDI clock master (FR-IO-3).
///
/// M2 simplification (documented in the plan): `play()` always restarts from
/// tick 0 with a fresh engine — deterministic every time.
public final class Transport: @unchecked Sendable {

    private let project: Project
    private let midi: MIDIService
    private let channelMap: [String: UInt8]
    private let wakeInterval: TimeInterval = 0.025      // spec §8.2
    private let lookaheadNanos: Double = 150_000_000    // 150 ms
    private let prerollNanos: Double = 100_000_000      // anchor 100 ms ahead

    private let lock = NSLock()
    private var thread: Thread?
    private var running = false
    private var pendingActions: [LiveEngine.Action] = []
    private var mutedVoices: Set<String> = []
    private var latestSnapshot: LiveEngine.Snapshot?
    private var latestFullState: LiveEngine.StateSnapshot?
    private var latestOffset: Int = 0
    private var activeClock: TickClock?
    private var capture: CaptureBuffer
    private var pendingBPM: Double? = nil
    private var liveBPM: Double
    public private(set) var sendsClock = true

    /// The tempo in force (tracks runtime changes; FR-GS-5).
    public var currentBPM: Double {
        lock.lock(); defer { lock.unlock() }
        return liveBPM
    }

    /// Runtime tempo change — binds at the next bar boundary (clock segments
    /// stay continuous at the swap tick).
    public func setTempo(_ bpm: Double) {
        let clamped = max(40, min(220, bpm))
        lock.lock(); defer { lock.unlock() }
        if running {
            pendingBPM = clamped
        } else {
            liveBPM = clamped
        }
    }

    public init(project: Project, midi: MIDIService) {
        self.project = project
        self.midi = midi
        self.liveBPM = project.bpm
        self.channelMap = Dictionary(uniqueKeysWithValues:
            project.voices.map { ($0.id, $0.channel) })
        // Preview snapshot so the UI shows the initial patterns before play.
        let preview = LiveEngine(project: project)
        self.latestSnapshot = preview.snapshot()
        self.latestFullState = preview.captureState()
        // Rolling capture ≈ 60 minutes at the project tempo (FR-IO-7).
        self.capture = CaptureBuffer(
            capacityTicks: Tick(project.bpm * 60.0 * Double(Time.ppqn)))
    }

    public var isPlaying: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    // MARK: - UI mirror (spec §5.4)

    /// The engine state as of the last scheduler wake (or the pre-play
    /// preview). Safe to call from any thread at UI rates.
    public func snapshot() -> LiveEngine.Snapshot? {
        lock.lock(); defer { lock.unlock() }
        return latestSnapshot
    }

    /// The transposition offset in force at the last wake.
    public var currentDegreeOffset: Int {
        lock.lock(); defer { lock.unlock() }
        return latestOffset
    }

    /// The tick sounding right now, or nil when stopped. Derived from the
    /// clock, so it moves smoothly between scheduler wakes.
    public var currentTick: Tick? {
        lock.lock(); defer { lock.unlock() }
        guard running, let clock = activeClock else { return nil }
        let tick = clock.tick(atMach: mach_absolute_time())
        return tick >= 0 ? tick : 0
    }

    public func isMuted(_ voiceID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return mutedVoices.contains(voiceID)
    }

    /// The full recallable engine state as of the last wake (FR-L-6);
    /// available pre-play (the preview engine's state).
    public func captureState() -> LiveEngine.StateSnapshot? {
        lock.lock(); defer { lock.unlock() }
        return latestFullState
    }

    // MARK: - Capture export (FR-IO-7 + FR-IO-6a)

    /// The last `lastBars` whole bars of the capture as an SMF, or nil when
    /// nothing has been captured yet. Callable any time, including mid-play.
    public func exportCapture(lastBars: Int) -> [UInt8]? {
        lock.lock()
        let buffer = capture
        lock.unlock()
        guard !buffer.isEmpty else { return nil }
        let clip = buffer.notes(lastBars: lastBars, endTick: buffer.head,
                                meter: project.meter)
        guard !clip.isEmpty else { return nil }

        let barTicks = project.meter.ticksPerBar
        let coveredBars = min(Tick(lastBars), buffer.head / barTicks)
        let length = max(barTicks, coveredBars * barTicks)
        let tracks = project.voices.map { config -> SMFTrack in
            let hint = DelayHint.compute(role: config.role, bpm: project.bpm)
            return SMFTrack(
                name: "\(config.id) | ch\(config.channel + 1) | \(config.role.rawValue) | delay: \(hint.division.label)",
                channel: config.channel,
                notes: clip.filter { $0.voiceID == config.id })
        }
        return SMFWriter.encode(bpm: currentBPM, meter: project.meter,
                                tracks: tracks, length: length)
    }

    // MARK: - Transport controls

    public func play() {
        lock.lock()
        guard !running else { lock.unlock(); return }
        running = true
        pendingActions.removeAll()
        lock.unlock()

        let thread = Thread { [weak self] in self?.schedulerLoop() }
        thread.name = "berlinan.scheduler"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
    }

    public func stop() {
        lock.lock()
        let wasRunning = running
        running = false
        activeClock = nil
        lock.unlock()
        guard wasRunning else { return }
        // The loop observes `running` at each wake (≤ 25 ms) and exits.
        while thread?.isExecuting == true {
            Thread.sleep(forTimeInterval: 0.005)
        }
        thread = nil
        if sendsClock { midi.send([(hostTime: 0, event: .stop)]) }
        midi.flush()                                    // FR-IO-8
    }

    // MARK: - Live controls

    /// Quantized engine actions (transpose / regenerate / blank / lock) —
    /// consumed by the scheduler at its next wake, bound at the render head.
    public func enqueue(_ action: LiveEngine.Action) {
        lock.lock(); defer { lock.unlock() }
        pendingActions.append(action)
    }

    /// Runtime mute — post-render gate (spec §8.2), takes effect at the next
    /// wake (≤ 25 ms) and silences anything already sounding on the channel.
    public func setMuted(_ voiceID: String, _ muted: Bool) {
        lock.lock()
        if muted { mutedVoices.insert(voiceID) } else { mutedVoices.remove(voiceID) }
        lock.unlock()
        if muted, let channel = channelMap[voiceID] {
            midi.flush(channel: channel)
        }
    }

    // MARK: - Scheduler loop (dedicated thread)

    private func schedulerLoop() {
        var engine = LiveEngine(project: project)
        var clock = TickClock.current(
            bpm: currentBPM,
            anchorMach: machAfter(nanos: prerollNanos))
        lock.lock()
        activeClock = clock
        lock.unlock()
        if sendsClock {
            midi.send([(hostTime: clock.machTime(forTick: 0), event: .start)])
        }
        var renderHead: Tick = 0
        let barTicks = project.meter.ticksPerBar

        while true {
            lock.lock()
            let stillRunning = running
            let actions = pendingActions
            pendingActions.removeAll()
            let muted = mutedVoices
            let requestedBPM = pendingBPM
            lock.unlock()
            guard stillRunning else { return }

            for action in actions {
                engine.enqueue(action, atTick: renderHead)
            }

            // Runtime tempo (FR-GS-5): bind at the next bar boundary — the
            // window clamps to it, and once the render head reaches it the
            // clock swaps with segment continuity.
            var tempoBoundary: Tick? = nil
            if let newBPM = requestedBPM {
                let boundary = (renderHead + barTicks - 1) / barTicks * barTicks
                if renderHead == boundary {
                    clock = TickClock.current(
                        bpm: newBPM,
                        anchorMach: clock.machTime(forTick: boundary),
                        anchorTick: boundary)
                    lock.lock()
                    activeClock = clock
                    liveBPM = newBPM
                    pendingBPM = nil
                    lock.unlock()
                } else {
                    tempoBoundary = boundary
                }
            }

            var target = clock.tick(atMach: machAfter(nanos: lookaheadNanos))
            if let boundary = tempoBoundary {
                target = min(target, boundary)
            }
            if target > renderHead {
                let window = renderHead..<target
                let rendered = engine.render(range: window)
                var timed = NoteEventConverter.events(
                    for: rendered, channelMap: channelMap, muted: muted)
                timed += NoteEventConverter.ccEvents(
                    for: engine.renderCC(range: window), channelMap: channelMap)
                if sendsClock {
                    timed += NoteEventConverter.clockTicks(in: window)
                        .map { NoteEventConverter.TimedEvent(tick: $0, event: .clock) }
                }
                midi.send(timed.map {
                    (hostTime: clock.machTime(forTick: $0.tick), event: $0.event)
                })
                // Capture what the engine PLAYED (pre-mute — muting is a
                // monitor decision, the jam is recorded whole; FR-IO-7).
                lock.lock()
                capture.append(rendered, upTo: target)
                lock.unlock()
                renderHead = target
            }

            // Publish the UI mirror (spec §5.4).
            let snap = engine.snapshot()
            let fullState = engine.captureState()
            let bar = Int(renderHead / project.meter.ticksPerBar)
            let offset = engine.transpositionOffset(atBar: bar)
            lock.lock()
            latestSnapshot = snap
            latestFullState = fullState
            latestOffset = offset
            lock.unlock()

            Thread.sleep(forTimeInterval: wakeInterval)
        }
    }

    private func machAfter(nanos: Double) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let deltaMach = nanos * Double(info.denom) / Double(info.numer)
        return mach_absolute_time() + UInt64(deltaMach.rounded())
    }
}
