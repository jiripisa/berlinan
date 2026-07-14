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
