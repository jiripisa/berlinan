import SwiftUI
import BerlinanEngine
import BerlinanRuntime

/// One voice lane (spec §11.2): role badge, pattern strip with its own
/// playhead (each lane's loop position — the phasing is literally visible),
/// lifecycle dots, loop length, and the per-voice controls.
struct VoiceLaneView: View {
    let ui: UIState
    let voice: LiveEngine.Snapshot.VoiceSnapshot
    var onEdit: () -> Void = {}

    private var identity: Color {
        switch voice.role {
        case .bedPluck1: return VoiceColor.bedPluck1
        case .bedPluck2: return VoiceColor.bedPluck2
        case .bass:      return VoiceColor.bass
        case .pad:       return VoiceColor.pad
        case .lead:      return VoiceColor.lead
        case .drone:     return VoiceColor.drone
        case .rhythm:    return VoiceColor.rhythm
        case .aux:       return VoiceColor.lead
        }
    }

    private var isMuted: Bool { ui.mutedIDs.contains(voice.id) }
    private var channel: Int {
        Int(ui.project.voices.first { $0.id == voice.id }?.channel ?? 0) + 1
    }
    private var loopSteps: Int {
        Int(voice.pattern.length / (ui.project.meter.ticksPerBeat / 4))
    }

    var body: some View {
        HStack(spacing: 10) {
            // Identity edge + header block
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isMuted ? AppColor.ink4 : identity)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(ui.voiceName(voice.id))
                    .font(AppFont.sectionLabel)
                    .tracking(AppTracking.label)
                    .foregroundStyle(isMuted ? AppColor.ink4 : AppColor.ink)
                    .textCase(.uppercase)
                HStack(spacing: 0) {
                    channelMenu
                    Text(" · \(loopSteps) steps")
                        .font(AppFont.monoCaption)
                        .foregroundStyle(AppColor.ink3)
                }
                LifecycleDotsView(lifecycle: voice.pattern.lifecycle,
                                  locked: voice.pattern.locked)
            }
            .frame(width: 108, alignment: .leading)

            PatternStripView(ui: ui, voice: voice, identity: identity,
                             dimmed: isMuted || !voice.active)
                .overlay(alignment: .topTrailing) {
                    if !voice.active {
                        Text("WAITS")
                            .font(AppFont.sansBold(8))
                            .tracking(AppTracking.label)
                            .foregroundStyle(AppColor.tangerine)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColor.tangerineGlow)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppColor.tangerineLine,
                                                      lineWidth: 1))
                            .padding(4)
                            .help("The arranger holds this voice back — it joins on a later bar (or right-click ▸ voice on)")
                    }
                }
                .onDrag { ui.dragItem(for: voice.id) ?? NSItemProvider() }
                .contextMenu {
                    if voice.melodyActive && ui.hasLeadVoice {
                        Button("Promote Melody to Lead") {
                            ui.promoteToLead(voice.id)
                        }
                    }
                    Menu("Alternate With") {
                        ForEach(ui.voices.filter { $0.id != voice.id },
                                id: \.id) { other in
                            Button(ui.voiceName(other.id)) {
                                ui.setAlternating(AlternatingConfig(
                                    voiceA: voice.id, voiceB: other.id))
                            }
                        }
                    }
                    if ui.alternating != nil {
                        Button("Stop Alternation") { ui.setAlternating(nil) }
                    }
                    Button(voice.active ? "Voice Off (engine)" : "Voice On (engine)") {
                        ui.setVoiceActive(voice.id, !voice.active)
                    }
                }

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    laneButton("speaker.slash.fill", active: isMuted,
                               activeColor: AppColor.rec, help: "Mute") {
                        ui.toggleMute(voice.id)
                    }
                    laneButton(voice.pattern.locked ? "lock.fill" : "lock.open",
                               active: voice.pattern.locked,
                               activeColor: AppColor.amber, help: "Lock (freeze mutations)") {
                        ui.toggleLock(voice.id)
                    }
                }
                HStack(spacing: 6) {
                    laneButton("arrow.clockwise", active: false,
                               activeColor: AppColor.tangerine,
                               help: regenerateHelp) {
                        ui.regenerate(voice.id)
                    }
                    .disabled(regenerateInert)
                    laneButton("circle.slash", active: voice.blankActive,
                               activeColor: AppColor.cyan, help: "Blank cycle (one silent loop)") {
                        ui.blankCycle(voice.id)
                    }
                }
                HStack(spacing: 6) {
                    laneButton("pencil",
                               active: voice.pattern.provenance.generator == .handEdited,
                               activeColor: AppColor.amber,
                               help: "Edit pattern (hand edits lock)") {
                        onEdit()
                    }
                    laneButton("wave.3.right",
                               active: voice.midiDelayEnabled,
                               activeColor: AppColor.cyan,
                               help: "MIDI delay — echoes as notes (use when no audio delay is available)") {
                        ui.toggleMIDIDelay(voice.id)
                    }
                }
                HStack(spacing: 6) {
                    laneButton("music.note",
                               active: voice.melodyActive,
                               activeColor: AppColor.tangerine,
                               help: "Melody extraction (M §8.1): mute all, raise 3–4 accents; evolves every few bars. Toggle off restores the pattern") {
                        ui.toggleMelody(voice.id)
                    }
                }
            }
        }
        .padding(8)
        .background(AppColor.bgPanel2)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.lineSoft, lineWidth: 1))
    }

    /// MIDI channel picker (phase 47) — also while playing; a channel shared
    /// with another voice names it.
    private var channelMenu: some View {
        Menu {
            ForEach(0..<16, id: \.self) { index in
                let others = ui.voicesOnChannel(UInt8(index), except: voice.id)
                let title = "Channel \(index + 1)"
                    + (others.isEmpty ? "" : " — " + others.joined(separator: ", "))
                Button {
                    ui.setChannel(UInt8(index), for: voice.id)
                } label: {
                    if index + 1 == channel {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            Text("ch \(channel)")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink3)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.horizontal, -3.5)       // the borderless menu insets its label
        .help("MIDI channel of this voice — set your synth or DAW track to receive on it")
    }

    /// Deterministic voices (drone, heartbeat) have nothing to re-roll.
    private var regenerateInert: Bool {
        [.drone, .heartbeat].contains(voice.pattern.provenance.generator)
    }

    private var regenerateHelp: String {
        switch voice.pattern.provenance.generator {
        case .drone, .heartbeat:
            return "This voice is deterministic — there is nothing to re-roll"
        case .bassMelody:
            return "Regenerate at next loop: a NEW walk over the SAME harmony (downbeat roots stay the progression's)"
        default:
            return "Regenerate at next loop"
        }
    }

    private func laneButton(_ symbol: String, active: Bool, activeColor: Color,
                            help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? activeColor : AppColor.ink3)
                .frame(width: 26, height: 22)
                .background(active ? activeColor.opacity(0.18) : AppColor.bgPanel)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? activeColor.opacity(0.45) : AppColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Legitimization countdown `●●●○` (spec §11.2): filled = verbatim plays
/// remaining; all-empty ring = established (mutable); amber = locked.
struct LifecycleDotsView: View {
    let lifecycle: Lifecycle
    let locked: Bool

    var body: some View {
        HStack(spacing: 3) {
            let remaining: Int = {
                if case .repeating(let n) = lifecycle { return min(n, 4) }
                return 0
            }()
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < remaining
                          ? (locked ? AppColor.amber : AppColor.ink2)
                          : Color.clear)
                    .overlay(Circle().stroke(
                        remaining == 0 ? AppColor.cyanLine : AppColor.ink4,
                        lineWidth: 1))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

/// Canvas step grid: notes in the voice identity color, accents outlined
/// tangerine, per-voice playhead sweep.
struct PatternStripView: View {
    let ui: UIState
    let voice: LiveEngine.Snapshot.VoiceSnapshot
    let identity: Color
    let dimmed: Bool

    var body: some View {
        Canvas { context, size in
            let pattern = voice.pattern
            let length = Double(pattern.length)
            let step = Double(ui.project.meter.ticksPerBeat) / 4.0
            let beat = Double(ui.project.meter.ticksPerBeat)

            // Grid: 16th lines soft, beat lines stronger.
            var tick = 0.0
            while tick < length {
                let x = tick / length * size.width
                let isBeat = tick.truncatingRemainder(dividingBy: beat) == 0
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line,
                               with: .color((isBeat ? AppColor.line : AppColor.lineSoft)),
                               lineWidth: 1)
                tick += step
            }

            // Pitch band: self-scaling to the pattern's resolved range.
            let resolved = pattern.notes.map {
                ui.project.key.resolve($0.pitch, referenceC: 60)
            }
            let low = Double(resolved.min() ?? 0) - 2
            let high = Double(resolved.max() ?? 1) + 2
            let span = max(high - low, 5)

            for (note, pitch) in zip(pattern.notes, resolved) {
                let x = Double(note.position) / length * size.width
                let w = max(3, Double(note.gate) / length * size.width)
                let normalized = (Double(pitch) - low) / span
                let y = (1 - normalized) * (size.height - 8) + 2
                let rect = CGRect(x: x, y: y, width: w, height: 6)
                let shape = Path(roundedRect: rect, cornerRadius: 2)
                context.fill(shape, with: .color(identity.opacity(dimmed ? 0.25 : 0.9)))
                if note.accent {
                    context.stroke(shape, with: .color(AppColor.tangerineLine), lineWidth: 1)
                }
            }

            // Per-voice playhead: local loop position — lanes drift apart
            // visibly when lengths differ (the phasing, on screen).
            if let current = ui.currentTick {
                let local = Double((current + pattern.startOffset) % pattern.length)
                let x = local / length * size.width
                var head = Path()
                head.move(to: CGPoint(x: x, y: 0))
                head.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(head, with: .color(AppColor.tangerine), lineWidth: 1.5)
            }

            if voice.blankActive {
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(AppColor.bgWindow.opacity(0.6)))
            }
        }
        .background(AppColor.laneGradient)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppColor.line, lineWidth: 1))
        .frame(minHeight: 56)
    }
}
