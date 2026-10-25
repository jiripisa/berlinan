import SwiftUI
import BerlinanRuntime

/// Takes window (FR-IO-11, phase 49): every Play→Stop pass, newest first,
/// the one being recorded on top. Rename in place, save as .mid, drag into
/// Live, delete.
struct TakesView: View {
    let store: TakeStore

    @State private var pendingDelete: Take?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TAKES")
                .font(AppFont.sansBold(11))
                .tracking(AppTracking.label)
                .foregroundStyle(AppColor.tangerine)
                .padding(.bottom, 2)
            Text("every play → stop · kept until you delete it · drag a take into Live")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink3)
                .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let live = store.liveTake {
                        TakeRow(store: store, take: live, recording: true,
                                onDelete: {})
                    }
                    ForEach(store.takes) { take in
                        TakeRow(store: store, take: take, recording: false,
                                onDelete: { pendingDelete = take })
                    }
                }
            }
            .overlay {
                if store.liveTake == nil && store.takes.isEmpty {
                    Text("Press play — each pass is recorded as a take.")
                        .font(AppFont.monoCaption)
                        .foregroundStyle(AppColor.ink3)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 320, alignment: .topLeading)
        .background(AppColor.bgWindow)
        .preferredColorScheme(.dark)
        .confirmationDialog("Delete “\(pendingDelete?.name ?? "")”?",
                            isPresented: Binding(get: { pendingDelete != nil },
                                                 set: { if !$0 { pendingDelete = nil } }),
                            presenting: pendingDelete) { take in
            Button("Delete Take", role: .destructive) { store.delete(take) }
        } message: { _ in
            Text("The take is removed from disk. Export it first if you want to keep it.")
        }
    }
}

private struct TakeRow: View {
    let store: TakeStore
    let take: Take
    let recording: Bool
    let onDelete: () -> Void

    @State private var name = ""

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(recording ? AppColor.rec : AppColor.ink4)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 3) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(AppFont.sansMedium(12))
                    .foregroundStyle(AppColor.ink)
                    .onSubmit { store.rename(take, to: name) }
                Text(details)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(recording ? AppColor.rec : AppColor.ink3)
                    .lineLimit(1)
            }
            Spacer()
            if !recording {
                rowButton("square.and.arrow.down", help: "Save as .mid…") {
                    store.exportMIDI(take)
                }
                rowButton("trash", help: "Delete take…", action: onDelete)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onDrag { store.dragItem(take) }
        .overlay(Rectangle().fill(AppColor.lineSoft).frame(height: 1), alignment: .bottom)
        .onAppear { name = take.name }
        .onChange(of: take.name) { _, newName in name = newName }
    }

    private var details: String {
        let seconds = Int(take.durationSeconds.rounded())
        let duration = String(format: "%d:%02d", seconds / 60, seconds % 60)
        let started = take.startedAt.formatted(date: .abbreviated, time: .shortened)
        let voices = take.voices.map(\.name).joined(separator: ", ")
        let prefix = recording ? "recording · " : ""
        return "\(prefix)\(started) · \(take.bars) bar\(take.bars == 1 ? "" : "s") · \(duration) · \(Int(take.bpm.rounded())) BPM · \(voices)"
    }

    private func rowButton(_ symbol: String, help: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColor.ink3)
                .frame(width: 26, height: 22)
                .background(AppColor.bgPanel)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
