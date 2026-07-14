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
    public private(set) var sendsClock = true

    public init(project: Project, midi: MIDIService) {
        self.project = project
        self.midi = midi
        self.channelMap = Dictionary(uniqueKeysWithValues:
            project.voices.map { ($0.id, $0.channel) })
    }

    public var isPlaying: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
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
        let clock = TickClock.current(
            bpm: project.bpm,
            anchorMach: machAfter(nanos: prerollNanos))
        if sendsClock {
            midi.send([(hostTime: clock.machTime(forTick: 0), event: .start)])
        }
        var renderHead: Tick = 0

        while true {
            lock.lock()
            let stillRunning = running
            let actions = pendingActions
            pendingActions.removeAll()
            let muted = mutedVoices
            lock.unlock()
            guard stillRunning else { return }

            for action in actions {
                engine.enqueue(action, atTick: renderHead)
            }

            let target = clock.tick(atMach: machAfter(nanos: lookaheadNanos))
            if target > renderHead {
                let window = renderHead..<target
                var timed = NoteEventConverter.events(
                    for: engine.render(range: window),
                    channelMap: channelMap, muted: muted)
                if sendsClock {
                    timed += NoteEventConverter.clockTicks(in: window)
                        .map { NoteEventConverter.TimedEvent(tick: $0, event: .clock) }
                }
                midi.send(timed.map {
                    (hostTime: clock.machTime(forTick: $0.tick), event: $0.event)
                })
                renderHead = target
            }
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
