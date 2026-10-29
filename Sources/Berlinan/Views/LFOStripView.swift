import SwiftUI
import BerlinanEngine

/// CC LFOs of one voice (phase 61, FR-MOD-3): a strip under the voice lane,
/// one row per LFO. Every edit goes out live (the engine swaps the lanes at
/// its render head) and is saved with the project.
struct LFOStripView: View {
    let ui: UIState
    let voiceID: String

    var body: some View {
        let lanes = ui.ccLanes(for: voiceID)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lanes.enumerated()), id: \.offset) { index, lane in
                LFORowView(ui: ui, voiceID: voiceID, index: index, lane: lane)
            }
            if lanes.count < CCLane.maxPerVoice {
                Button {
                    ui.addLFO(to: voiceID)
                } label: {
                    Text("＋ add LFO")
                        .font(AppFont.monoCaption)
                        .foregroundStyle(AppColor.ink3)
                }
                .buttonStyle(.plain)
                .help("Add another CC LFO to this voice (up to \(CCLane.maxPerVoice))")
            }
        }
    }
}

/// One LFO: CC number, shape, cycle, Min/Max, depth and phase knobs, curve.
struct LFORowView: View {
    let ui: UIState
    let voiceID: String
    let index: Int
    let lane: CCLane

    private static let cycleChoices: [Double] = [1, 2, 4, 8, 16, 32, 64]

    @State private var browsing = false

    private var isSampleHold: Bool { lane.shape == .sampleHold }

    private var controller: Int? {
        lane.resolvedController(ccMap: ui.ccMap(for: voiceID)).map(Int.init)
    }

    /// The picked parameter's name, or the target name of an older lane.
    private var parameterName: String? {
        lane.label ?? (lane.controller == nil && !lane.target.isEmpty ? lane.target : nil)
    }

    private func update(_ change: (inout CCLane) -> Void) {
        ui.updateLFO(index, of: voiceID, change)
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                fieldLabel("CC")
                NumberField(value: controller ?? 0, width: 34) { typed in
                    let number = UInt8(max(0, min(127, typed)))
                    update { lane in
                        if lane.controller != number { lane.label = nil }
                        lane.controller = number
                    }
                }
                .help("CC number (0–127) the LFO sends")
                Button {
                    browsing = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ui.midiGuide == nil ? AppColor.ink4 : AppColor.ink2)
                        .frame(width: 20, height: 18)
                        .background(AppColor.bgPanel2)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppColor.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(ui.midiGuide == nil)
                .help(ui.midiGuide == nil
                      ? "The midi.guide parameter list is missing from this build"
                      : "Find the parameter by manufacturer and model (midi.guide)")
            }
            Text(parameterName ?? "")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 220, alignment: .leading)
                .help(parameterName ?? "")

            shapeMenu
            cycleMenu

            HStack(spacing: 4) {
                fieldLabel("MIN")
                NumberField(value: lane.minValue, width: 30) { typed in
                    update { $0.setRange(min: typed, max: $0.maxValue) }
                }
                fieldLabel("MAX")
                NumberField(value: lane.maxValue, width: 30) { typed in
                    update { $0.setRange(min: $0.minValue, max: typed) }
                }
            }
            .help("The range the LFO swings between, in CC values (0–127)")

            KnobView(value: Binding(get: { lane.depth },
                                    set: { depth in update { $0.setDepthKeepingCenter(depth) } }),
                     label: "DEPTH",
                     help: "Widen or narrow the range around its middle")
            KnobView(value: Binding(get: { lane.phase },
                                    set: { phase in update { $0.phase = min(phase, 0.999) } }),
                     range: 0...0.999,
                     label: "PHASE",
                     readout: { "\(Int(($0 * 360).rounded()))°" },
                     disabled: isSampleHold,
                     help: isSampleHold ? "S&H steps on 8th notes — phase does not apply"
                                        : "Where in its cycle the LFO starts")

            LFOCurveView(lane: lane, meter: ui.project.meter)
                .equatable()
                .overlay { playhead }
                .frame(minWidth: 80, maxWidth: .infinity)
                .frame(height: 26)

            Button {
                ui.removeLFO(index, from: voiceID)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColor.ink3)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Remove this LFO (the parameter stays where it is)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .sheet(isPresented: $browsing) {
            if let catalog = ui.midiGuide {
                CCParameterBrowserView(catalog: catalog, initial: ui.lastBrowsedModel) { pick in
                    ui.applyBrowserPick(pick, toLFO: index, of: voiceID)
                }
            }
        }
        .background(AppColor.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.lineSoft, lineWidth: 1))
    }

    private var shapeMenu: some View {
        Menu {
            ForEach(LFOShapeName.all, id: \.shape) { item in
                Button(item.title) { update { $0.shape = item.shape } }
            }
        } label: {
            menuLabel(LFOShapeName.title(lane.shape))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("LFO shape")
    }

    private var cycleMenu: some View {
        Menu {
            ForEach(Self.cycleChoices, id: \.self) { bars in
                Button(Self.cycleTitle(bars)) { update { $0.cycleBars = bars } }
            }
        } label: {
            menuLabel(Self.cycleTitle(lane.cycleBars), dimmed: isSampleHold)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(isSampleHold)
        .help(isSampleHold ? "S&H steps on 8th notes — cycle length does not apply"
                           : "Cycle length in bars")
    }

    private static func cycleTitle(_ bars: Double) -> String {
        let number = bars == bars.rounded() ? "\(Int(bars))" : "\(bars)"
        return bars == 1 ? "1 bar" : "\(number) bars"
    }

    /// Where the song is inside the previewed cycle.
    @ViewBuilder private var playhead: some View {
        if let tick = ui.currentTick {
            GeometryReader { geo in
                let length = LFOCurveView.previewLength(lane, meter: ui.project.meter)
                let x = CGFloat(Double(tick % length) / Double(length)) * geo.size.width
                Rectangle()
                    .fill(AppColor.tangerine)
                    .frame(width: 1)
                    .offset(x: x)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.fieldLabel)
            .tracking(AppTracking.field)
            .foregroundStyle(AppColor.ink3)
    }

    private func menuLabel(_ text: String, dimmed: Bool = false) -> some View {
        Text(text)
            .font(AppFont.monoCaption)
            .foregroundStyle(dimmed ? AppColor.ink4 : AppColor.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColor.bgPanel2)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppColor.line, lineWidth: 1))
    }
}

/// Display names of the LFO shapes.
enum LFOShapeName {
    static let all: [(shape: LFOShape, title: String)] = [
        (.sine, "∿ sine"), (.triangle, "△ triangle"), (.sawUp, "saw ↑"),
        (.sawDown, "saw ↓"), (.square, "⊓ square"), (.sampleHold, "S&H"),
    ]

    static func title(_ shape: LFOShape) -> String {
        all.first { $0.shape == shape }?.title ?? "\(shape)"
    }
}

/// The lane's curve over one cycle (S&H: one bar), drawn from the engine's
/// own CC stream so the picture is what the synth gets. Equatable — it
/// redraws only when the lane changes, not with every playhead tick.
struct LFOCurveView: View, Equatable {
    let lane: CCLane
    let meter: Meter

    static func previewLength(_ lane: CCLane, meter: Meter) -> Tick {
        lane.shape == .sampleHold
            ? meter.ticksPerBar
            : max(1, Tick(lane.cycleBars * Double(meter.ticksPerBar)))
    }

    var body: some View {
        Canvas { context, size in
            let length = Self.previewLength(lane, meter: meter)
            var preview = lane
            preview.controller = 0
            let events = ModulationEngine.render(lanes: [preview], ccMap: [:], voiceID: "",
                                                 in: 0..<length, meter: meter, seed: 1)
            func y(_ value: Int) -> CGFloat {
                size.height - 2 - CGFloat(value) / 127 * (size.height - 4)
            }
            for bound in [lane.minValue, lane.maxValue] {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y(bound)))
                line.addLine(to: CGPoint(x: size.width, y: y(bound)))
                context.stroke(line, with: .color(AppColor.lineStrong),
                               style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            guard let first = events.first else { return }
            var curve = Path()
            curve.move(to: CGPoint(x: 0, y: y(Int(first.value))))
            for event in events.dropFirst() {
                let x = CGFloat(Double(event.at) / Double(length)) * size.width
                curve.addLine(to: CGPoint(x: x, y: curve.currentPoint?.y ?? 0))
                curve.addLine(to: CGPoint(x: x, y: y(Int(event.value))))
            }
            curve.addLine(to: CGPoint(x: size.width, y: curve.currentPoint?.y ?? 0))
            context.stroke(curve, with: .color(AppColor.tangerine), lineWidth: 1.5)
        }
        .background(AppColor.bgPanel3)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Integer field that commits on Return or when it loses focus.
struct NumberField: View {
    let value: Int
    var width: CGFloat = 36
    let onCommit: (Int) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(AppFont.monoCaption)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(AppColor.ink)
            .frame(width: width)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(AppColor.bgPanel3)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(focused ? AppColor.tangerineLine : AppColor.line, lineWidth: 1))
            .focused($focused)
            .onAppear { text = "\(value)" }
            .onChange(of: value) { _, new in text = "\(new)" }
            .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
            .onSubmit { commit() }
    }

    private func commit() {
        if let typed = Int(text.trimmingCharacters(in: .whitespaces)) {
            onCommit(typed)
        }
        text = "\(value)"
    }
}
