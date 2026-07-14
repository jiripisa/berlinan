import Foundation
import Observation
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
        }
        mutedIDs = Set(project.voices.map(\.id).filter { transport.isMuted($0) })
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
        if transport.isPlaying { transport.stop() } else { transport.play() }
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
        services.transport?.enqueue(.regenerate(voiceID: voiceID))
    }

    func blankCycle(_ voiceID: String) {
        services.transport?.enqueue(.blankCycle(voiceID: voiceID))
    }
}
