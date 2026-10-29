import SwiftUI
import BerlinanRuntime

/// Pick the CC an LFO drives (phase 61, FR-MOD-9): Manufacturer › Model ›
/// Parameter from the bundled midi.guide database. Typing searches
/// manufacturer and model names.
struct CCParameterBrowserView: View {
    typealias Pick = (manufacturer: String, model: String,
                      parameter: MIDIGuideCatalog.Parameter)

    let catalog: MIDIGuideCatalog
    let initial: (manufacturer: String, model: String)?
    let onPick: (Pick) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var manufacturer: String? = nil
    @State private var model: String? = nil
    @State private var parameterIndex: Int? = nil

    private var manufacturers: [MIDIGuideCatalog.Manufacturer] {
        catalog.filtered(by: query)
    }

    private var models: [MIDIGuideCatalog.Model] {
        manufacturers.first { $0.name == manufacturer }?.models ?? []
    }

    private var parameters: [MIDIGuideCatalog.Parameter] {
        models.first { $0.name == model }?.parameters ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHOOSE A PARAMETER")
                .font(AppFont.sansBold(11))
                .tracking(AppTracking.label)
                .foregroundStyle(AppColor.tangerine)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColor.ink3)
                TextField("Search manufacturer or model", text: $query)
                    .textFieldStyle(.plain)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.ink)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppColor.bgPanel3)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))

            HStack(spacing: 0) {
                column("MANUFACTURER") {
                    ForEach(manufacturers, id: \.name) { item in
                        row(item.name, selected: item.name == manufacturer) {
                            selectManufacturer(item.name)
                        }
                    }
                }
                Divider().overlay(AppColor.line)
                column("MODEL") {
                    ForEach(models, id: \.name) { item in
                        row(item.name, selected: item.name == model) {
                            model = item.name
                            parameterIndex = nil
                        }
                    }
                }
                Divider().overlay(AppColor.line)
                column("PARAMETER") {
                    ForEach(Array(parameters.enumerated()), id: \.offset) { index, item in
                        if index == 0 || parameters[index - 1].section != item.section {
                            Text(item.section.uppercased())
                                .font(AppFont.fieldLabel)
                                .tracking(AppTracking.field)
                                .foregroundStyle(AppColor.ink3)
                                .padding(.horizontal, 8)
                                .padding(.top, index == 0 ? 2 : 8)
                                .padding(.bottom, 2)
                        }
                        row("\(item.name) · CC \(item.cc)", selected: index == parameterIndex) {
                            parameterIndex = index
                        }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { pick(index) })
                    }
                }
                .frame(minWidth: 280)
            }
            .frame(height: 340)
            .background(AppColor.bgPanel2)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))

            HStack {
                Link("Data: midi.guide (CC BY-SA 4.0)",
                     destination: URL(string: "https://midi.guide")!)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink3)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Select") { parameterIndex.map(pick) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(parameterIndex == nil)
            }
        }
        .padding(18)
        .frame(width: 760)
        .background(AppColor.bgWindow)
        .preferredColorScheme(.dark)
        .onAppear(perform: restoreInitial)
        .onChange(of: query) { _, _ in keepSelectionVisible() }
    }

    private func selectManufacturer(_ name: String) {
        manufacturer = name
        model = models.first?.name
        parameterIndex = nil
    }

    private func restoreInitial() {
        if let initial, catalog.manufacturers.contains(where: { $0.name == initial.manufacturer }) {
            manufacturer = initial.manufacturer
            model = models.contains { $0.name == initial.model } ? initial.model : models.first?.name
        } else if let first = manufacturers.first {
            selectManufacturer(first.name)
        }
    }

    /// After typing, keep a visible selection in every column.
    private func keepSelectionVisible() {
        if !manufacturers.contains(where: { $0.name == manufacturer }) {
            if let first = manufacturers.first {
                selectManufacturer(first.name)
            } else {
                manufacturer = nil
                model = nil
                parameterIndex = nil
            }
        } else if !models.contains(where: { $0.name == model }) {
            model = models.first?.name
            parameterIndex = nil
        }
    }

    private func pick(_ index: Int) {
        guard let manufacturer, let model, parameters.indices.contains(index) else { return }
        onPick((manufacturer, model, parameters[index]))
        dismiss()
    }

    private func column<Content: View>(_ title: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.fieldLabel)
                .tracking(AppTracking.field)
                .foregroundStyle(AppColor.ink3)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            Divider().overlay(AppColor.line)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) { content() }
                    .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ text: String, selected: Bool,
                     action: @escaping () -> Void) -> some View {
        Text(text)
            .font(AppFont.body)
            .foregroundStyle(selected ? AppColor.ink : AppColor.ink2)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? AppColor.tangerineGlow : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}
