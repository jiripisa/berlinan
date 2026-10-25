import Foundation
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

/// Phase 49 (FR-IO-11): every Play→Stop pass is a take — browsable, saved
/// on disk, exportable as .mid.

private final class TakeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Take] = []

    func append(_ take: Take) {
        lock.lock(); defer { lock.unlock() }
        storage.append(take)
    }

    var takes: [Take] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}

private func fast(_ project: Project) -> Project {
    var p = project
    p.bpm = 200                                    // one bar = 1.2 s
    return p
}

private func sampleTake(name: String = "Take 1",
                        startedAt: Date = Date(timeIntervalSince1970: 1_000)) -> Take {
    let bar = Meter.fourFour.ticksPerBar
    return Take(name: name, startedAt: startedAt, bpm: 120, meter: .fourFour,
                voices: [Take.Voice(id: "bass", role: .bass, channel: 2, name: "Bass"),
                         Take.Voice(id: "pad", role: .pad, channel: 3, name: "Pad")],
                notes: [RenderedNote(voiceID: "bass", at: 0, midiNote: 36, velocity: 100,
                                     gate: 240, accent: true, ratchet: 1),
                        RenderedNote(voiceID: "pad", at: bar, midiNote: 60, velocity: 80,
                                     gate: 960, accent: false, ratchet: 1)],
                length: 2 * bar)
}

@Suite("Takes — recording in the transport", .serialized)
struct TakeRecordingTests {

    @Test("Play→Stop makes one take; a second pass is a separate take")
    func onePerPass() throws {
        let midi = try MIDIService(clientName: "BerlinanTakeTest1",
                                   sourceName: "Berlinan Take Test 1")
        let transport = Transport(project: fast(.demo), midi: midi)
        let box = TakeBox()
        transport.setTakeHandler { box.append($0) }

        transport.play()
        Thread.sleep(forTimeInterval: 1.5)
        let live = try #require(transport.liveTake(), "a take is in progress")
        #expect(!live.notes.isEmpty)
        transport.stop()
        #expect(transport.liveTake() == nil)

        transport.play()
        Thread.sleep(forTimeInterval: 0.8)
        transport.stop()

        let takes = box.takes
        try #require(takes.count == 2)
        let bar = Project.demo.meter.ticksPerBar
        for take in takes {
            #expect(take.bpm == 200)
            #expect(take.meter == Project.demo.meter)
            #expect(take.voices.map(\.id) == Project.demo.voices.map(\.id))
            #expect(take.voices.map(\.name) == ["Pluck 1", "Pluck 2", "Bass"])
            #expect(take.length > 0 && take.length % bar == 0, "whole bars")
            let first = try #require(take.notes.map(\.at).min())
            #expect(first < bar, "rebased to the take's first bar")
            #expect(take.notes.allSatisfy { $0.at < take.length })
        }
        #expect(takes[0].id != takes[1].id)
        #expect(takes[0].length >= takes[1].length, "the first pass was longer")
    }

    @Test("Play and an immediate Stop leave no take")
    func emptyPassDropped() throws {
        let midi = try MIDIService(clientName: "BerlinanTakeTest2",
                                   sourceName: "Berlinan Take Test 2")
        var project = fast(.ambientDrift)
        project.voices = []
        let transport = Transport(project: project, midi: midi)
        let box = TakeBox()
        transport.setTakeHandler { box.append($0) }
        transport.play()
        Thread.sleep(forTimeInterval: 0.3)
        transport.stop()
        #expect(box.takes.isEmpty)
    }

    @Test("A template loaded while playing splits the take at the bar line")
    func templateLoadSplits() throws {
        let midi = try MIDIService(clientName: "BerlinanTakeTest3",
                                   sourceName: "Berlinan Take Test 3")
        let transport = Transport(project: fast(.demo), midi: midi)
        let box = TakeBox()
        transport.setTakeHandler { box.append($0) }
        transport.play()
        Thread.sleep(forTimeInterval: 0.6)
        transport.loadProject(fast(.fullEnsemble))
        Thread.sleep(forTimeInterval: 2.0)
        #expect(box.takes.count == 1, "the demo take ends at the bar line")
        #expect(transport.liveTake()?.voices.count == 6)
        transport.stop()

        let takes = box.takes
        try #require(takes.count == 2)
        #expect(takes[0].voices.count == 3)
        #expect(takes[1].voices.count == 6)
        #expect(takes[0].length == Project.demo.meter.ticksPerBar, "one bar of demo")
        let bar = Project.fullEnsemble.meter.ticksPerBar
        let first = try #require(takes[1].notes.map(\.at).min())
        #expect(first < bar, "the second take starts at its own tick 0")
        #expect(takes[1].notes.allSatisfy { $0.at < takes[1].length })
    }
}

@Suite("Takes — file format and library")
struct TakeLibraryTests {

    private func scratchDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("berlinan-takes-\(UUID().uuidString)")
    }

    @Test("JSON round trip keeps everything")
    func roundTrip() throws {
        let take = sampleTake()
        let data = try JSONEncoder().encode(take)
        #expect(try JSONDecoder().decode(Take.self, from: data) == take)
    }

    @Test("Duration and bar count")
    func duration() {
        let take = sampleTake()                     // 2 bars of 4/4 at 120 BPM
        #expect(take.bars == 2)
        #expect(abs(take.durationSeconds - 4.0) < 0.001)
    }

    @Test(".mid has one track per voice on its channel")
    func smf() {
        let bytes = sampleTake().smf()
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(Array(bytes.prefix(4)) == Array("MThd".utf8))
        #expect(bytes[10] == 0 && bytes[11] == 3, "tempo track + 2 voices")
        #expect(text.contains("bass | ch3 | bass"))
        #expect(text.contains("pad | ch4 | pad"))
        #expect(bytes.contains(0x92), "bass note-on on channel 3")
    }

    @Test("Save, list newest first, rename, delete; broken files skipped")
    func library() throws {
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TakeLibrary(directory: directory)
        #expect(library.all().isEmpty, "a missing folder is an empty library")

        let older = sampleTake(name: "Take 1", startedAt: Date(timeIntervalSince1970: 1_000))
        let newer = sampleTake(name: "Take 2", startedAt: Date(timeIntervalSince1970: 2_000))
        try library.save(older)
        try library.save(newer)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("junk.json"))
        #expect(library.all().map(\.name) == ["Take 2", "Take 1"])

        try library.rename(id: older.id, to: "Keeper")
        #expect(library.all().map(\.name) == ["Take 2", "Keeper"])

        try library.save(newer)                    // saving again overwrites
        #expect(library.all().count == 2)

        try library.delete(id: newer.id)
        #expect(library.all().map(\.name) == ["Keeper"])
    }
}
