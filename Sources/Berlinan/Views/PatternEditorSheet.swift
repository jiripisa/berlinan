import SwiftUI
import BerlinanEngine

/// Hand editor (FR-P-7): a mono note table on the 16th grid. Apply persists
/// the pattern as the voice's override (document) and, while playing, swaps
/// it live at the next loop boundary — arriving locked.
struct PatternEditorSheet: View {
    let ui: UIState
    let voiceID: String
    @Environment(\.dismiss) private var dismiss

    private struct EditNote: Identifiable {
        let id = UUID()
        var step: Int
        var degree: Int
        var octave: Int
        var velocity: Int
        var accent: Bool
        var gate: Tick
    }

    @State private var notes: [EditNote] = []
    @State private var lengthSteps = 16

    private var stepTicks: Tick { ui.project.meter.ticksPerBeat / 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EDIT \(ui.voiceName(voiceID).uppercased())")
                .font(AppFont.sansBold(11))
                .tracking(AppTracking.label)
                .foregroundStyle(AppColor.tangerine)
            Text("hand edits lock the pattern — it will not mutate (FR-P-7)")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink3)

            HStack(spacing: 8) {
                Text("LOOP")
                    .font(AppFont.fieldLabel).tracking(AppTracking.field)
                    .foregroundStyle(AppColor.ink3)
                Stepper("\(lengthSteps) steps", value: $lengthSteps, in: 2...64)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink2)
            }

            header
            ScrollView {
                ForEach($notes) { $note in
                    row($note)
                }
            }
            .frame(minHeight: 180, maxHeight: 280)

            HStack {
                Button {
                    let used = Set(notes.map(\.step))
                    let free = (0..<lengthSteps).first { !used.contains($0) } ?? 0
                    notes.append(EditNote(step: free, degree: 0, octave: 0,
                                          velocity: 100, accent: false, gate: 120))
                } label: {
                    Label("Add note", systemImage: "plus")
                        .font(AppFont.body)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply") {
                    apply()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(notes.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 480)
        .background(AppColor.bgWindow)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            Text("STEP").frame(width: 70, alignment: .leading)
            Text("DEGREE").frame(width: 90, alignment: .leading)
            Text("OCT").frame(width: 60, alignment: .leading)
            Text("VEL").frame(width: 70, alignment: .leading)
            Text("ACC").frame(width: 40, alignment: .leading)
            Spacer()
        }
        .font(AppFont.fieldLabel)
        .tracking(AppTracking.field)
        .foregroundStyle(AppColor.ink3)
    }

    private func row(_ note: Binding<EditNote>) -> some View {
        HStack {
            Stepper("\(note.wrappedValue.step + 1)",
                    value: note.step, in: 0...(lengthSteps - 1))
                .font(AppFont.monoCaption).frame(width: 70, alignment: .leading)
            Stepper("\(note.wrappedValue.degree)",
                    value: note.degree, in: -7...14)
                .font(AppFont.monoCaption).frame(width: 90, alignment: .leading)
            Stepper("\(note.wrappedValue.octave)",
                    value: note.octave, in: -2...2)
                .font(AppFont.monoCaption).frame(width: 60, alignment: .leading)
            Stepper("\(note.wrappedValue.velocity)",
                    value: note.velocity, in: 1...127, step: 5)
                .font(AppFont.monoCaption).frame(width: 70, alignment: .leading)
            Toggle("", isOn: note.accent)
                .labelsHidden().toggleStyle(.checkbox).frame(width: 40)
            Spacer()
            Button {
                notes.removeAll { $0.id == note.wrappedValue.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColor.rec)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(AppColor.ink2)
    }

    private func load() {
        guard let voice = ui.voices.first(where: { $0.id == voiceID }) else { return }
        let pattern = voice.pattern
        lengthSteps = max(2, Int(pattern.length / stepTicks))
        notes = pattern.notes
            .sorted { $0.position < $1.position }
            .map { n in
                EditNote(step: Int(n.position / stepTicks),
                         degree: n.pitch.degree, octave: n.pitch.octave,
                         velocity: Int(n.velocity), accent: n.accent,
                         gate: n.gate)
            }
    }

    private func apply() {
        // Last edit wins per step (positions must be unique).
        var byStep: [Int: EditNote] = [:]
        for note in notes where note.step < lengthSteps { byStep[note.step] = note }
        let patternNotes = byStep.values
            .sorted { $0.step < $1.step }
            .map { n in
                PatternNote(position: Tick(n.step) * stepTicks,
                            pitch: DegreePitch(degree: n.degree, octave: n.octave),
                            velocity: UInt8(n.velocity),
                            gate: n.gate, accent: n.accent)
            }
        guard !patternNotes.isEmpty else { return }
        let pattern = BerlinanEngine.Pattern(
            id: "\(voiceID)/hand",
            length: Tick(lengthSteps) * stepTicks,
            notes: patternNotes,
            provenance: Provenance(generator: .handEdited, version: 1, seed: 0),
            locked: true,
            lifecycle: .established)
        ui.applyHandEdit(voiceID: voiceID, pattern: pattern)
    }
}
