import CoreMIDI
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
    private(set) var liveKey: Key? = nil
    private(set) var liveBPM: Double? = nil
    /// Arranger mirror (FR-A-1/6); nil = performance mode.
    private(set) var arrangement: LiveEngine.ArrangementStatus? = nil
    /// Density macro in force (FR-A-3).
    private(set) var density: Double = 1
    /// Remaining tension-budget spends (FR-H-7).
    private(set) var tensionRemaining: Int = 2
    /// Pending bar-bound changes (horizon strip, phase 32).
    private(set) var upcomingEvents: [LiveEngine.UpcomingEvent] = []

    var project: Project { services.project }

    init(services: AppServices) {
        self.services = services
        self.controlMap = ControlMap.load()
        refresh()
        services.onControlTrigger = { [weak self] trigger in
            self?.handleTrigger(trigger)
        }
    }

    // MARK: - MIDI learn (FR-IO-10)

    private(set) var controlMap: ControlMap
    private(set) var learnMode = false
    private(set) var armedMacro: ControlMacro? = nil

    func toggleLearnMode() {
        learnMode.toggle()
        armedMacro = nil
    }

    /// Single entry point for every macro control: LEARN mode arms the macro
    /// for the next incoming trigger; otherwise it executes.
    func perform(_ macro: ControlMacro) {
        if learnMode {
            armedMacro = macro
            return
        }
        execute(macro)
    }

    private func handleTrigger(_ trigger: ControlTrigger) {
        if learnMode, let macro = armedMacro {
            controlMap.bind(macro, to: trigger)
            controlMap.save()
            armedMacro = nil
            return
        }
        if let macro = controlMap.macro(for: trigger) {
            execute(macro)
        }
    }

    private func execute(_ macro: ControlMacro) {
        switch macro {
        case .playStop:          togglePlayback()
        case .degree(let k):     pressDegree(k)
        case .rerollUnlocked:    rerollAllUnlocked()
        case .newSeed:           newSeed()
        case .recallSlot(let s): recallSnapshot(slot: s)
        case .advancePhase:      advancePhase()
        case .fireBPart:         fireBPart()
        }
    }

    // MARK: - Arranger & dynamics (FR-A-1/3/4/5/6)

    func setArrangerEnabled(_ on: Bool) {
        services.setArrangerEnabled(on)
        refresh()
    }

    /// "Advance now": fire the arranger's next change at the next bar.
    func advancePhase() {
        services.transport?.enqueue(.advancePhase)
    }

    /// The S4 move (FR-A-5) — works in performance mode too.
    func fireBPart() {
        services.transport?.enqueue(.fireBPart)
    }

    /// CC scenes (phase 34): names available for the SCENE menu.
    var sceneNames: [String] { (project.ccScenes ?? []).map(\.name) }

    /// Morph every CC target toward the scene over 8 bars.
    func morphToScene(_ name: String) {
        services.transport?.enqueue(.morphToScene(name: name, bars: 8))
    }

    /// Spend one out-of-key allowance (FR-H-7) — lands on the pad voice
    /// when there is one, else the first voice.
    func spendTension() {
        let target = project.voices.first { $0.role == .pad }
            ?? project.voices.first
        guard let target else { return }
        services.transport?.enqueue(.spendTension(voiceID: target.id))
    }

    /// Density macro (FR-A-3), binds at the next bar while playing.
    func setDensity(_ value: Double) {
        services.setDensity(value)
        refresh()
    }

    var ambientMode: Bool { project.arrangement?.ambientMode ?? false }

    // MARK: - Melody (FR-MEL-1/2)

    var hasLeadVoice: Bool { project.voices.contains { $0.role == .lead } }

    /// The name the UI shows for a voice — by role, never the id (FR-UX-7).
    func voiceName(_ id: String) -> String { project.voiceLabels[id] ?? id }

    /// Alternating phrase scheduler (FR-MEL-3).
    var alternating: AlternatingConfig? { project.alternating }

    func setAlternating(_ config: AlternatingConfig?) {
        services.setAlternating(config)
        refresh()
    }

    /// Melody extraction toggle — binds at the voice's next loop boundary.
    func toggleMelody(_ voiceID: String) {
        services.transport?.enqueue(.extractMelody(voiceID: voiceID))
    }

    /// Engine-level voice on/off (FR-A-6 manual override); next bar.
    func setVoiceActive(_ voiceID: String, _ on: Bool) {
        services.transport?.enqueue(.setVoiceActive(voiceID: voiceID, on: on))
    }

    /// Copy the extracted melody to the lead voice (locked legato line).
    func promoteToLead(_ voiceID: String) {
        services.transport?.enqueue(.promoteToLead(voiceID: voiceID))
    }

    /// Ambient mode (FR-A-4). Stopped-only (it rescales legitimization at
    /// materialize time); the toggle is disabled while playing.
    func setAmbientMode(_ on: Bool) {
        services.setAmbientMode(on)
        refresh()
    }

    /// Arrangement form preset (phase 35). Stopped-only.
    func setArrangerForm(_ config: ArrangementConfig) {
        services.setArrangerForm(config)
        refresh()
    }

    // MARK: - Templates (phase 36)

    /// The template armed to take over at the next bar (phase 42), for the
    /// horizon strip; nil when nothing is pending.
    private(set) var pendingTemplateName: String? = nil

    func applyTemplate(_ template: Project, name: String) {
        services.applyTemplate(template)
        pendingTemplateName = isPlaying ? name : nil
        refresh()
    }

    func saveAsTemplate() {
        services.saveAsTemplate()
    }

    // MARK: - CC LFO lanes (phase 61, FR-MOD-3)

    /// Voices whose LFO strip is folded away (view state, not saved).
    private(set) var collapsedLFOVoices: Set<String> = []

    func ccLanes(for voiceID: String) -> [CCLane] {
        project.voices.first { $0.id == voiceID }?.ccLanes ?? []
    }

    /// The CC map of a voice — resolves lanes from documents before phase 61.
    func ccMap(for voiceID: String) -> [String: UInt8] {
        project.voices.first { $0.id == voiceID }?.ccMap ?? [:]
    }

    func addLFO(to voiceID: String) {
        var lanes = ccLanes(for: voiceID)
        guard lanes.count < CCLane.maxPerVoice else { return }
        lanes.append(CCLane.makeDefault(index: lanes.count))
        collapsedLFOVoices.remove(voiceID)
        services.setVoiceCCLanes(voiceID, lanes: lanes)
    }

    func removeLFO(_ index: Int, from voiceID: String) {
        var lanes = ccLanes(for: voiceID)
        guard lanes.indices.contains(index) else { return }
        lanes.remove(at: index)
        services.setVoiceCCLanes(voiceID, lanes: lanes)
    }

    /// Edit one lane. A lane from an older document addresses its CC by
    /// name; the first edit pins the resolved number so the sound continues.
    func updateLFO(_ index: Int, of voiceID: String,
                   _ change: (inout CCLane) -> Void) {
        var lanes = ccLanes(for: voiceID)
        guard lanes.indices.contains(index) else { return }
        var lane = lanes[index]
        if lane.controller == nil {
            lane.controller = lane.resolvedController(ccMap: ccMap(for: voiceID))
        }
        change(&lane)
        guard lane != lanes[index] else { return }
        lanes[index] = lane
        services.setVoiceCCLanes(voiceID, lanes: lanes)
    }

    func toggleLFOStrip(_ voiceID: String) {
        if collapsedLFOVoices.contains(voiceID) {
            collapsedLFOVoices.remove(voiceID)
        } else {
            collapsedLFOVoices.insert(voiceID)
        }
    }

    /// Per-voice MIDI channel (phase 47); `channel` is 0-based.
    func setChannel(_ channel: UInt8, for voiceID: String) {
        services.setVoiceChannel(voiceID, channel: channel)
        refresh()
    }

    /// The other voices on a channel, by name ("Bass") — for the lane menu.
    func voicesOnChannel(_ channel: UInt8, except voiceID: String) -> [String] {
        project.voices
            .filter { $0.channel == channel && $0.id != voiceID }
            .map { voiceName($0.id) }
    }

    // MARK: - Drag & drop (FR-IO-9 subset)

    /// A bar-aligned single-track .mid of the voice's CURRENT pattern —
    /// looped to the pattern/bar LCM (≤ 16 bars) so it cycles seamlessly
    /// under Ableton's launch quantization.
    func dragItem(for voiceID: String) -> NSItemProvider? {
        guard let voice = voices.first(where: { $0.id == voiceID }),
              let config = project.voices.first(where: { $0.id == voiceID })
        else { return nil }
        let pattern = voice.pattern
        let barTicks = project.meter.ticksPerBar
        let period = Convergence.period(lengths: [pattern.length, barTicks])
            ?? barTicks
        let length = min(period, 16 * barTicks)
        let key = liveKey ?? project.key
        let notes = pattern.occurrences(in: 0..<length).map { occ -> RenderedNote in
            let resolved = key.resolve(occ.note.pitch, referenceC: config.referenceC)
            let velocity = min(127, Int(occ.note.velocity) + (occ.note.accent ? 20 : 0))
            return RenderedNote(voiceID: voiceID, at: occ.at,
                                midiNote: config.register.fold(resolved),
                                velocity: UInt8(velocity), gate: occ.note.gate,
                                accent: occ.note.accent, ratchet: occ.note.ratchet)
        }
        guard !notes.isEmpty else { return nil }
        let hint = DelayHint.compute(role: config.role, bpm: liveBPM ?? project.bpm)
        let track = SMFTrack(
            name: "\(voiceID) | \(config.role.rawValue) | delay: \(hint.division.label)",
            channel: config.channel, notes: notes)
        let bytes = SMFWriter.encode(bpm: liveBPM ?? project.bpm,
                                     meter: project.meter,
                                     tracks: [track], length: length)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("berlinan-\(voiceID).mid")
        do {
            try Data(bytes).write(to: url)
        } catch {
            return nil
        }
        return NSItemProvider(contentsOf: url)
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
            liveKey = snapshot.key
            arrangement = snapshot.arrangement
            density = snapshot.density
            tensionRemaining = snapshot.tensionRemaining
            upcomingEvents = snapshot.upcomingEvents
        }
        liveBPM = transport.currentBPM
        syncMode = transport.currentSyncMode
        linkPeers = transport.linkService?.numPeers ?? 0
        midiOutputAvailable = services.midi?.isOutputAvailable ?? false
        if !transport.hasPendingProjectLoad { pendingTemplateName = nil }
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
        let key = liveKey ?? project.key
        return "\(names[key.root]) \(key.scale.mode.rawValue)"
    }

    var bpmText: String {
        String(Int((liveBPM ?? project.bpm).rounded()))
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

    // MARK: - Sync mode (FR-IO-4)

    /// Mirrored in refresh(): Transport is not observable, so a computed
    /// property never re-rendered the INT/EXT/LINK label (phase 59).
    private(set) var syncMode: Transport.SyncMode = .internalClock

    /// INT / EXT / LINK (stopped only — the transport guards it too). Link's
    /// network session is joined exactly while LINK is selected.
    func setSyncMode(_ mode: Transport.SyncMode) {
        guard let transport = services.transport else { return }
        transport.setSyncMode(mode)
        transport.linkService?.enable(mode == .link)
        refresh()
    }

    // MARK: - MIDI output (phase 44)

    /// False while the chosen output device is unplugged.
    private(set) var midiOutputAvailable = true

    var midiOutputName: String { services.outputName }
    var midiOutputID: MIDIUniqueID? { services.midiOutputID }
    var midiDestinations: [MIDIService.Destination] { services.midiDestinations }

    func setMIDIOutput(_ destination: MIDIService.Destination?) {
        services.setMIDIOutput(destination)
        refresh()
    }

    /// Mirrored in refresh() for the same reason as syncMode.
    private(set) var linkPeers: UInt64 = 0

    /// 🎲 New Seed (FR-UX-6): fresh universe, undoable.
    func newSeed() {
        pushUndo()
        services.reseed()
        refresh()
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
