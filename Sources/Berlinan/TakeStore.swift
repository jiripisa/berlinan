import AppKit
import Observation
import UniformTypeIdentifiers
import BerlinanRuntime

/// The Takes window's model (FR-IO-11, phase 49): finished takes from the
/// library on disk plus the take being recorded. Names new takes
/// "Take N" and saves the take in progress every 10 s, so a crash loses
/// at most those seconds.
@MainActor
@Observable
final class TakeStore {

    private let library: TakeLibrary
    /// Newest first, the take in progress excluded.
    private(set) var takes: [Take] = []
    /// The take in progress (refreshed every second), nil when stopped.
    private(set) var liveTake: Take?

    /// Where the take in progress comes from (the current transport).
    @ObservationIgnored var liveSource: () -> Take? = { nil }
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastAutosave = Date.distantPast
    /// Names given to takes before they reach the disk (live renames too).
    @ObservationIgnored private var pendingNames: [UUID: String] = [:]

    private static let nextNumberKey = "nextTakeNumber"
    private static let autosaveInterval: TimeInterval = 10

    init(library: TakeLibrary = TakeLibrary(directory: TakeLibrary.defaultDirectory())) {
        self.library = library
        reload()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Recording

    /// A finished take from the transport (any thread hops here).
    func finished(_ take: Take) {
        save(named(take))
        if liveTake?.id == take.id { liveTake = nil }
        pendingNames[take.id] = nil
        reload()
    }

    private func tick() {
        guard let live = liveSource() else {
            liveTake = nil
            return
        }
        let take = named(live)
        liveTake = take
        if Date().timeIntervalSince(lastAutosave) >= Self.autosaveInterval {
            lastAutosave = Date()
            save(take)
        }
    }

    private func named(_ take: Take) -> Take {
        var take = take
        if let name = pendingNames[take.id] {
            take.name = name
        } else {
            let defaults = UserDefaults.standard
            let number = max(1, defaults.integer(forKey: Self.nextNumberKey))
            defaults.set(number + 1, forKey: Self.nextNumberKey)
            take.name = "Take \(number)"
            pendingNames[take.id] = take.name
        }
        return take
    }

    private func save(_ take: Take) {
        try? library.save(take)
    }

    private func reload() {
        let liveID = liveTake?.id
        takes = library.all().filter { $0.id != liveID }
    }

    // MARK: - Actions

    func rename(_ take: Take, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if take.id == liveTake?.id {
            pendingNames[take.id] = trimmed
            liveTake?.name = trimmed
        } else {
            try? library.rename(id: take.id, to: trimmed)
            reload()
        }
    }

    func delete(_ take: Take) {
        try? library.delete(id: take.id)
        reload()
    }

    func exportMIDI(_ take: Take) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(Self.fileName(take)).mid"
        panel.allowedContentTypes = [.midi]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? Data(take.smf()).write(to: url)
        }
    }

    /// Drag into Live or Finder (FR-IO-9): a temp .mid named after the take.
    func dragItem(_ take: Take) -> NSItemProvider {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.fileName(take)).mid")
        guard (try? Data(take.smf()).write(to: url)) != nil else { return NSItemProvider() }
        // A file URL keeps the file's own name ("Take 3.mid");
        // NSItemProvider(contentsOf:) made Finder drop "MIDI audio.midi".
        return NSItemProvider(object: url as NSURL)
    }

    private static func fileName(_ take: Take) -> String {
        let cleaned = take.name.components(separatedBy: CharacterSet(charactersIn: "/:\\"))
            .joined(separator: "-")
        return cleaned.isEmpty ? "berlinan-take" : cleaned
    }
}
