import Foundation
import BerlinanEngine

/// One Play→Stop pass (FR-IO-11, phase 49): what the engine played, rebased
/// to the take's first bar, plus what is needed to export it on its own.
/// A template loaded while playing starts a new take at its bar line.
public struct Take: Codable, Equatable, Identifiable, Sendable {

    public struct Voice: Codable, Equatable, Sendable {
        public var id: String
        public var role: VoiceRole
        public var channel: UInt8
        /// Musician-facing name at recording time ("Pluck 1", FR-UX-7).
        public var name: String

        public init(id: String, role: VoiceRole, channel: UInt8, name: String) {
            self.id = id
            self.role = role
            self.channel = channel
            self.name = name
        }
    }

    public var id: UUID
    public var name: String
    public var startedAt: Date
    /// Tempo at the start of the take (the SMF tempo).
    public var bpm: Double
    public var meter: Meter
    public var voices: [Voice]
    public var notes: [RenderedNote]
    /// Whole bars, from tick 0.
    public var length: Tick

    public init(id: UUID = UUID(), name: String = "", startedAt: Date, bpm: Double,
                meter: Meter, voices: [Voice], notes: [RenderedNote], length: Tick) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.bpm = bpm
        self.meter = meter
        self.voices = voices
        self.notes = notes
        self.length = length
    }

    public var bars: Int { Int(length / meter.ticksPerBar) }

    public var durationSeconds: Double {
        Double(length) / Double(Time.ppqn) * 60.0 / bpm
    }

    /// Type-1 SMF, one track per voice — named like the capture export.
    public func smf() -> [UInt8] {
        let tracks = voices.map { voice -> SMFTrack in
            let hint = DelayHint.compute(role: voice.role, bpm: bpm)
            return SMFTrack(
                name: "\(voice.id) | ch\(voice.channel + 1) | \(voice.role.rawValue) | delay: \(hint.division.label)",
                channel: voice.channel,
                notes: notes.filter { $0.voiceID == voice.id })
        }
        return SMFWriter.encode(bpm: bpm, meter: meter, tracks: tracks,
                                length: max(length, meter.ticksPerBar))
    }
}

extension Take {

    /// A take starting now for `project`.
    static func start(project: Project, bpm: Double) -> Take {
        let labels = project.voiceLabels
        return Take(startedAt: Date(), bpm: bpm, meter: project.meter,
                    voices: project.voices.map {
                        Voice(id: $0.id, role: $0.role, channel: $0.channel,
                              name: labels[$0.id] ?? $0.id)
                    },
                    notes: [], length: 0)
    }

    /// Extend the recorded length to cover `tick` (rounded up to a bar).
    mutating func extend(to tick: Tick) {
        let barTicks = meter.ticksPerBar
        length = max(length, (tick + barTicks - 1) / barTicks * barTicks)
    }
}

/// Takes on disk (FR-IO-11): one JSON file per take in a folder. Unreadable
/// files are skipped, never fatal.
public struct TakeLibrary: Sendable {

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `~/Library/Application Support/Berlinan/Takes`.
    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Berlinan/Takes", isDirectory: true)
    }

    /// All takes, newest first.
    public func all() -> [Take] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Take.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Write (or overwrite) the take's file.
    public func save(_ take: Take) throws {
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(take).write(to: url(for: take.id), options: .atomic)
    }

    public func rename(id: UUID, to name: String) throws {
        var take = try JSONDecoder().decode(Take.self, from: Data(contentsOf: url(for: id)))
        take.name = name
        try save(take)
    }

    public func delete(id: UUID) throws {
        try FileManager.default.removeItem(at: url(for: id))
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
