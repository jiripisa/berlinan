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

    private var project: Project
    private let midi: MIDIService
    private var channelMap: [String: UInt8]
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
    /// A whole project waiting for the next bar (phase 42).
    private var pendingProject: Project? = nil
    /// Transport tick where the running engine's tick 0 sits (phase 42).
    private var engineOrigin: Tick = 0
    private var liveBPM: Double
    public private(set) var sendsClock = true

    // MARK: - Sync mode (FR-IO-4/5)

    public enum SyncMode: Equatable, Sendable { case internalClock, externalClock, link }

    private var syncMode: SyncMode = .internalClock
    private var estimator = ClockEstimator()
    private var latestPulse: (index: Int, mach: UInt64)? = nil
    private var externalStartMach: UInt64? = nil
    private var clockInputConnected = false

    /// The Link peer (FR-IO-5), created on the first switch to `.link` and
    /// kept for the transport's lifetime. Creation does NOT join the network
    /// session — the app calls `linkService?.enable(true)` when the user
    /// picks LINK, so tests (and headless use) stay socket-free.
    public private(set) var linkService: LinkService? = nil

    public var currentSyncMode: SyncMode {
        lock.lock(); defer { lock.unlock() }
        return syncMode
    }

    /// Switch clock source (stopped only). External mode listens to the
    /// named source (nil = all external sources), follows Start/Stop and
    /// locks tempo/phase to the pulse stream. Link mode locks tempo/phase to
    /// the Link session's beat grid.
    public func setSyncMode(_ mode: SyncMode, sourceName: String? = nil) {
        lock.lock()
        guard !running else { lock.unlock(); return }
        syncMode = mode
        let needsConnect = mode == .externalClock && !clockInputConnected
        if needsConnect { clockInputConnected = true }
        if mode == .link && linkService == nil {
            linkService = LinkService(bpm: liveBPM)
        }
        lock.unlock()
        if needsConnect {
            midi.connectClockInput(sourceName: sourceName) { [weak self] message, mach in
                self?.handleRealTime(message, mach: mach)
            }
        }
    }

    private func handleRealTime(_ message: MIDIService.RealTimeMessage, mach: UInt64) {
        // hostTime 0 = "deliver now": such packets arrive with a ZERO
        // timestamp — substitute the arrival time (exactly what hardware
        // slaves do; sub-ms loopback error, absorbed by the estimator).
        let effectiveMach = mach == 0 ? mach_absolute_time() : mach
        lock.lock()
        guard syncMode == .externalClock else { lock.unlock(); return }
        switch message {
        case .clock:
            estimator.pulse(atNanos: Self.nanos(fromMach: effectiveMach))
            latestPulse = (index: estimator.pulseCount - 1, mach: effectiveMach)
            lock.unlock()
        case .start, .continuePlayback:
            estimator.reset()
            latestPulse = nil
            externalStartMach = effectiveMach
            lock.unlock()
            play()
        case .stop:
            lock.unlock()
            stop()
        }
    }

    private static func nanos(fromMach mach: UInt64) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return mach * UInt64(info.numer) / UInt64(info.denom)
    }

    /// The tempo in force (tracks runtime changes; FR-GS-5).
    public var currentBPM: Double {
        lock.lock(); defer { lock.unlock() }
        return liveBPM
    }

    /// Runtime tempo change — binds at the next bar boundary (clock segments
    /// stay continuous at the swap tick). In Link mode the change goes to the
    /// whole Link session instead (the loop follows it back).
    public func setTempo(_ bpm: Double) {
        let clamped = max(40, min(220, bpm))
        lock.lock()
        if syncMode == .link, let link = linkService {
            lock.unlock()
            link.setTempo(clamped)
            return
        }
        if running {
            pendingBPM = clamped
        } else {
            liveBPM = clamped
        }
        lock.unlock()
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
        let tick = clock.tick(atMach: mach_absolute_time()) - engineOrigin
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
        let project = self.project
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
        pendingProject = nil
        engineOrigin = 0
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
        pendingProject = nil
        lock.unlock()
        guard wasRunning else { return }
        // The loop observes `running` at each wake (≤ 25 ms) and exits.
        while thread?.isExecuting == true {
            Thread.sleep(forTimeInterval: 0.005)
        }
        thread = nil
        lock.lock()
        let external = syncMode == .externalClock
        lock.unlock()
        if sendsClock && !external { midi.send([(hostTime: 0, event: .stop)]) }
        midi.flush()                                    // FR-IO-8
    }

    // MARK: - Live controls

    /// Load a whole project while playing (phase 42): it takes over at the
    /// next bar — the clock keeps running, the new piece starts from its
    /// beginning there. Ignored when stopped (rebuild the transport instead).
    public func loadProject(_ newProject: Project) {
        lock.lock(); defer { lock.unlock() }
        guard running else { return }
        pendingProject = newProject
    }

    public var hasPendingProjectLoad: Bool {
        lock.lock(); defer { lock.unlock() }
        return pendingProject != nil
    }

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
        let channel = channelMap[voiceID]
        lock.unlock()
        if muted, let channel {
            midi.flush(channel: channel)
        }
    }

    // MARK: - Scheduler loop (dedicated thread)

    private func schedulerLoop() {
        lock.lock()
        var engine = LiveEngine(project: project)
        let external = syncMode == .externalClock
        let link = syncMode == .link ? linkService : nil
        let startAnchor = externalStartMach
        externalStartMach = nil
        lock.unlock()

        // Link (FR-IO-5): quantum = one bar; tick 0 lands on the session's
        // next quantum boundary (granted verbatim when there are no peers).
        var quantum = Double(project.meter.ticksPerBar) / Double(Time.ppqn)
        var clock: TickClock
        if let link {
            let anchorMach = machAfter(nanos: prerollNanos)
            let anchorMicros = link.clockMicros() + Int64(prerollNanos / 1_000)
            link.requestBeat(0, atMicros: anchorMicros, quantum: quantum)
            let tempo = link.tempo()
            clock = TickClock.current(bpm: tempo, anchorMach: anchorMach)
            lock.lock()
            liveBPM = tempo
            lock.unlock()
        } else {
            clock = TickClock.current(
                bpm: currentBPM,
                anchorMach: external ? (startAnchor ?? mach_absolute_time())
                                     : machAfter(nanos: prerollNanos))
        }
        lock.lock()
        activeClock = clock
        lock.unlock()
        let emitClock = sendsClock && !external      // never re-broadcast a followed clock
        if emitClock {
            midi.send([(hostTime: clock.machTime(forTick: 0), event: .start)])
        }
        var renderHead: Tick = 0
        var origin: Tick = 0                         // engine tick 0 in transport ticks
        var barTicks = project.meter.ticksPerBar

        while true {
            lock.lock()
            let stillRunning = running
            let actions = pendingActions
            pendingActions.removeAll()
            let muted = mutedVoices
            let requestedBPM = (external || link != nil) ? nil : pendingBPM
            let estimate = external ? estimator.bpm : nil
            let pulse = latestPulse
            let requestedProject = pendingProject
            lock.unlock()
            guard stillRunning else { return }

            // Live project load (phase 42): at the next bar a fresh engine
            // takes over with its tick 0 on that bar; the clock runs on.
            var projectBoundary: Tick? = nil
            if let newProject = requestedProject {
                let boundary = Self.nextBar(after: renderHead, origin: origin, barTicks: barTicks)
                if renderHead == boundary {
                    engine = LiveEngine(project: newProject)
                    origin = boundary
                    barTicks = newProject.meter.ticksPerBar
                    quantum = Double(barTicks) / Double(Time.ppqn)
                    let adoptTempo = !external && link == nil
                        && newProject.bpm != clock.bpm
                    if adoptTempo {
                        clock = TickClock.current(
                            bpm: newProject.bpm,
                            anchorMach: clock.machTime(forTick: boundary),
                            anchorTick: boundary)
                    }
                    lock.lock()
                    project = newProject
                    channelMap = Dictionary(uniqueKeysWithValues:
                        newProject.voices.map { ($0.id, $0.channel) })
                    mutedVoices.removeAll()
                    if pendingProject == newProject { pendingProject = nil }
                    engineOrigin = boundary
                    if adoptTempo {
                        activeClock = clock
                        liveBPM = newProject.bpm
                        pendingBPM = nil
                    }
                    lock.unlock()
                } else {
                    projectBoundary = boundary
                }
            }

            for action in actions {
                engine.enqueue(action, atTick: renderHead - origin)
            }

            // External sync (FR-IO-4): re-anchor the clock segment to the
            // latest pulse (pulse k = tick k·40) with the smoothed tempo —
            // micro-warping through piecewise segments, never tick jumps.
            if external, let estimate, let pulse {
                if abs(estimate - clock.bpm) > 0.25 {
                    clock = TickClock.current(bpm: estimate,
                                              anchorMach: pulse.mach,
                                              anchorTick: Tick(pulse.index) * 40)
                    lock.lock()
                    activeClock = clock
                    liveBPM = estimate
                    lock.unlock()
                }
                // Freewheel: no pulse for > 500 ms → hold the last segment
                // (nothing to do — the segment simply keeps running).
            }

            // Link sync (FR-IO-5): when the session tempo moved, re-anchor
            // to the session's CURRENT beat position (both clocks count mach
            // time, so between tempo changes the segment tracks the grid).
            if let link {
                let tempo = link.tempo()
                if abs(tempo - clock.bpm) > 0.25 {
                    let anchorMach = mach_absolute_time()
                    let beat = link.beat(atMicros: link.clockMicros(),
                                         quantum: quantum)
                    clock = TickClock.current(
                        bpm: tempo, anchorMach: anchorMach,
                        anchorTick: Tick((beat * Double(Time.ppqn)).rounded()))
                    lock.lock()
                    activeClock = clock
                    liveBPM = tempo
                    lock.unlock()
                }
            }

            // Runtime tempo (FR-GS-5, internal mode): bind at the next bar
            // boundary — the window clamps to it, and once the render head
            // reaches it the clock swaps with segment continuity.
            var tempoBoundary: Tick? = nil
            if let newBPM = requestedBPM {
                let boundary = Self.nextBar(after: renderHead, origin: origin, barTicks: barTicks)
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
            if let boundary = projectBoundary {
                target = min(target, boundary)
            }
            if target > renderHead {
                let window = renderHead..<target
                let local = (renderHead - origin)..<(target - origin)
                let rendered = engine.render(range: local).map { note -> RenderedNote in
                    var shifted = note
                    shifted.at += origin
                    return shifted
                }
                let cc = engine.renderCC(range: local).map { event -> RenderedCC in
                    var shifted = event
                    shifted.at += origin
                    return shifted
                }
                lock.lock()
                let channels = channelMap
                lock.unlock()
                var timed = NoteEventConverter.events(
                    for: rendered, channelMap: channels, muted: muted)
                timed += NoteEventConverter.ccEvents(for: cc, channelMap: channels)
                if emitClock {
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
            let bar = Int((renderHead - origin) / barTicks)
            let offset = engine.transpositionOffset(atBar: bar)
            lock.lock()
            latestSnapshot = snap
            latestFullState = fullState
            latestOffset = offset
            lock.unlock()

            // Arranger ending (FR-A-1): the engine renders nothing at/after
            // its stop tick — wait for that musical moment, then shut down
            // from inside the loop (a self-stop; external stop() sees
            // running == false and stays out of the way).
            if let localStop = engine.pendingStopTick, renderHead >= localStop + origin {
                let stopTick = localStop + origin
                let stopMach = clock.machTime(forTick: stopTick)
                while mach_absolute_time() < stopMach && isPlaying {
                    Thread.sleep(forTimeInterval: 0.005)
                }
                lock.lock()
                let stillRunningNow = running
                running = false
                activeClock = nil
                lock.unlock()
                if stillRunningNow {
                    if emitClock { midi.send([(hostTime: 0, event: .stop)]) }
                    midi.flush()                             // FR-IO-8
                }
                return
            }

            Thread.sleep(forTimeInterval: wakeInterval)
        }
    }

    /// The first bar line at or after `tick`; bars count from the running
    /// engine's origin (a loaded project may bring a different meter).
    static func nextBar(after tick: Tick, origin: Tick, barTicks: Tick) -> Tick {
        origin + (tick - origin + barTicks - 1) / barTicks * barTicks
    }

    private func machAfter(nanos: Double) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let deltaMach = nanos * Double(info.denom) / Double(info.numer)
        return mach_absolute_time() + UInt64(deltaMach.rounded())
    }
}
