import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers
import BerlinanEngine
import BerlinanRuntime

/// The 30 Hz read-only mirror of the transport/engine state (spec §5.4) plus
/// the action dispatch surface. All musical logic stays behind the Transport;
/// this type only reflects and forwards.
@MainActor
@Observable
final class UIState {

    private let services: AppServices
    private var timer: Timer?

    private(set) var isPlaying = false
    private(set) var voices: [LiveEngine.Snapshot.VoiceSnapshot] = []
    private(set) var currentTick: Tick? = nil
    private(set) var degreeOffset = 0
    private(set) var mutedIDs: Set<String> = []
    private(set) var scheduleEvents: [TranspositionEvent] = []

    var project: Project { services.project }

    init(services: AppServices) {
        self.services = services
        refresh()
    }

    // MARK: - Mirror

    func startMirror() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMirror() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        guard let transport = services.transport else { return }
        isPlaying = transport.isPlaying
        currentTick = transport.currentTick
        degreeOffset = transport.currentDegreeOffset
        if let snapshot = transport.snapshot() {
            voices = snapshot.voices
            scheduleEvents = snapshot.scheduleEvents
        }
        mutedIDs = Set(project.voices.map(\.id).filter { transport.isMuted($0) })
    }

    /// Events at or after the current bar (harmony strip chips, FR-H-9).
    var upcomingHarmonyEvents: [TranspositionEvent] {
        let currentBar = Int((currentTick ?? 0) / project.meter.ticksPerBar)
        return scheduleEvents.filter { $0.bar > currentBar }
    }

    /// "→ +5 in 3 bars" countdown, nil when nothing is scheduled ahead.
    var nextHarmonyEventText: String? {
        guard let next = upcomingHarmonyEvents.first, currentTick != nil else { return nil }
        let currentBar = Int((currentTick ?? 0) / project.meter.ticksPerBar)
        let inBars = next.bar - currentBar
        let label = next.degreeOffset == 0 ? "1" : String(format: "%+d", next.degreeOffset)
        return "→ \(label) in \(inBars) bar\(inBars == 1 ? "" : "s")"
    }

    var barBeatText: String {
        let meter = project.meter
        guard let tick = currentTick else { return "—.—" }
        let bar = tick / meter.ticksPerBar + 1
        let beat = (tick % meter.ticksPerBar) / meter.ticksPerBeat + 1
        return "\(bar).\(beat)"
    }

    var keyText: String {
        let names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        return "\(names[project.key.root]) \(project.key.scale.mode.rawValue)"
    }

    // MARK: - Actions (FR-UX-2/4)

    func togglePlayback() {
        guard let transport = services.transport else { return }
        if transport.isPlaying {
            transport.stop()
            // Project edits made mid-play (hand edits) reach the next run.
            services.rebuildTransportIfStale()
        } else {
            transport.play()
        }
        refresh()
    }

    func toggleMute(_ voiceID: String) {
        guard let transport = services.transport else { return }
        transport.setMuted(voiceID, !mutedIDs.contains(voiceID))
        refresh()
    }

    func toggleLock(_ voiceID: String) {
        guard let transport = services.transport else { return }
        let locked = voices.first { $0.id == voiceID }?.pattern.locked ?? false
        transport.enqueue(.setLock(voiceID: voiceID, on: !locked))
    }

    func regenerate(_ voiceID: String) {
        pushUndo()
        services.transport?.enqueue(.regenerate(voiceID: voiceID))
    }

    func blankCycle(_ voiceID: String) {
        services.transport?.enqueue(.blankCycle(voiceID: voiceID))
    }

    /// Toggle the MIDI delay (FR-MOD-7): live action + document persistence.
    func toggleMIDIDelay(_ voiceID: String) {
        let current = voices.first { $0.id == voiceID }?.midiDelayEnabled ?? false
        services.updateVoiceMIDIDelay(voiceID, enabled: !current)
        if isPlaying {
            services.transport?.enqueue(.setMIDIDelay(voiceID: voiceID,
                                                      enabled: !current))
        }
        refresh()
    }

    // MARK: - Snapshots & undo (FR-L-6, FR-UX-5)

    private(set) var snapshotSlots: [LiveEngine.StateSnapshot?] =
        Array(repeating: nil, count: 6)
    private var undoStack: [LiveEngine.StateSnapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }

    func saveSnapshot(slot: Int) {
        guard snapshotSlots.indices.contains(slot) else { return }
        snapshotSlots[slot] = services.transport?.captureState()
    }

    func recallSnapshot(slot: Int) {
        guard snapshotSlots.indices.contains(slot),
              let snapshot = snapshotSlots[slot] else { return }
        pushUndo()
        services.transport?.enqueue(.recallSnapshot(snapshot))
    }

    /// Automatic undo point before every destructive action.
    private func pushUndo() {
        guard let state = services.transport?.captureState() else { return }
        undoStack.append(state)
        if undoStack.count > 20 { undoStack.removeFirst() }
    }

    func undo() {
        guard let state = undoStack.popLast() else { return }
        services.transport?.enqueue(.recallSnapshot(state))
    }

    /// Restore slots from an opened document (phase 19).
    func loadSlots(_ slots: [LiveEngine.StateSnapshot?]?) {
        var normalized = slots ?? []
        if normalized.count < 6 {
            normalized += Array(repeating: nil, count: 6 - normalized.count)
        }
        snapshotSlots = Array(normalized.prefix(6))
        undoStack.removeAll()
    }

    // MARK: - Hand edits (FR-P-7)

    /// Persist the edit into the project AND swap it live at the next loop
    /// boundary when playing.
    func applyHandEdit(voiceID: String, pattern: BerlinanEngine.Pattern) {
        pushUndo()
        services.updateVoiceOverride(voiceID, pattern: pattern)
        if isPlaying {
            services.transport?.enqueue(.replacePattern(voiceID: voiceID,
                                                        pattern: pattern))
        }
        refresh()
    }

    // MARK: - Performance macros (FR-UX-3 partial)

    /// Degree button 1–7: 1 = home (offset 0), k = offset k−1; binds at the
    /// next bar (FR-H-3 via the engine).
    func pressDegree(_ degree: Int) {
        precondition((1...7).contains(degree))
        services.transport?.enqueue(.transpose(degreeOffset: degree - 1))
    }

    /// "Re-roll all unlocked" (FR-UX-2): regenerate every voice whose pattern
    /// is not locked.
    func rerollAllUnlocked() {
        guard let transport = services.transport else { return }
        pushUndo()
        for voice in voices where !voice.pattern.locked {
            transport.enqueue(.regenerate(voiceID: voice.id))
        }
    }

    // MARK: - Capture export (FR-IO-7)

    func exportCapture(lastBars: Int) {
        guard let transport = services.transport,
              let bytes = transport.exportCapture(lastBars: lastBars) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "berlinan-capture-\(lastBars)bars.mid"
        panel.allowedContentTypes = [.midi]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? Data(bytes).write(to: url)
        }
    }

    var captureAvailable: Bool {
        services.transport?.exportCapture(lastBars: 1) != nil
    }
}
