import Testing
@testable import BerlinanEngine

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let meter = Meter.fourFour

private func rendered(_ at: Tick, note: UInt8 = 60, velocity: UInt8 = 100,
                      gate: Tick = 120, ratchet: Int = 1,
                      voice: String = "a") -> RenderedNote {
    RenderedNote(voiceID: voice, at: at, midiNote: note, velocity: velocity,
                 gate: gate, accent: false, ratchet: ratchet)
}

// MARK: - VLQ

@Suite("Variable-length quantities")
struct VLQTests {

    @Test("Known vectors")
    func vectors() {
        #expect(SMFWriter.vlq(0) == [0x00])
        #expect(SMFWriter.vlq(127) == [0x7F])
        #expect(SMFWriter.vlq(128) == [0x81, 0x00])
        #expect(SMFWriter.vlq(960) == [0x87, 0x40])
        #expect(SMFWriter.vlq(0x0FFF_FFFF) == [0xFF, 0xFF, 0xFF, 0x7F])
    }
}

// MARK: - Header & track-0 metas

@Suite("SMF structure")
struct SMFStructureTests {

    @Test("Header: MThd, format 1, ntrks, division 960")
    func header() {
        let bytes = SMFWriter.encode(bpm: 90, meter: meter,
                                     tracks: [SMFTrack(name: "a", channel: 0, notes: [])],
                                     length: bar)
        let expected: [UInt8] = [0x4D, 0x54, 0x68, 0x64,          // MThd
                                 0x00, 0x00, 0x00, 0x06,          // length 6
                                 0x00, 0x01,                      // format 1
                                 0x00, 0x02,                      // 2 tracks (tempo + 1 voice)
                                 0x03, 0xC0]                      // 960 PPQN
        #expect(Array(bytes.prefix(14)) == expected)
    }

    @Test("Track 0 carries tempo (90 BPM) and 4/4 time signature metas")
    func track0Metas() {
        let bytes = SMFWriter.encode(bpm: 90, meter: meter, tracks: [], length: bar)
        // set tempo: round(60_000_000 / 90) = 666_667 = 0x0A2C2B
        #expect(contains(bytes, subsequence: [0xFF, 0x51, 0x03, 0x0A, 0x2C, 0x2B]))
        // time signature 4/4: nn=4, dd=2 (2^2), cc=24, bb=8
        #expect(contains(bytes, subsequence: [0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08]))
    }

    @Test("7/8 time signature meta (dd = 3)")
    func sevenEight() {
        let bytes = SMFWriter.encode(bpm: 96, meter: Meter(beatsPerBar: 7, beatUnit: 8),
                                     tracks: [], length: 7 * 480)
        #expect(contains(bytes, subsequence: [0xFF, 0x58, 0x04, 0x07, 0x03, 0x18, 0x08]))
    }

    @Test("Markers land on track 0 with their labels")
    func markers() {
        let bytes = SMFWriter.encode(bpm: 90, meter: meter, tracks: [], length: 2 * bar,
                                     markers: [(at: bar, label: "B-Part")])
        // FF 06 len "B-Part"
        #expect(contains(bytes, subsequence: [0xFF, 0x06, 0x06] + Array("B-Part".utf8)))
    }

    @Test("Exact voice-track bytes for a single note")
    func singleNoteTrack() {
        let track = SMFTrack(name: "v", channel: 0, notes: [rendered(0, gate: 120)])
        let bytes = SMFWriter.encode(bpm: 90, meter: meter, tracks: [track], length: beat)
        let expectedTrack: [UInt8] =
            [0x4D, 0x54, 0x72, 0x6B,                  // MTrk
             0x00, 0x00, 0x00, 0x14,                  // chunk length = 20 bytes
             0x00, 0xFF, 0x03, 0x01] + Array("v".utf8) +  // track name "v"
            [0x00, 0x90, 60, 100,                     // Δ0 note on C4 vel 100
             0x78, 0x80, 60, 0,                       // Δ120 note off
             0x87, 0x28,                              // Δ840 (to tick 960)
             0xFF, 0x2F, 0x00]                        // end of track
        #expect(suffix(of: bytes, is: expectedTrack))
    }
}

// MARK: - Ratchets & note-off integrity

@Suite("Ratchets and note-off integrity")
struct SMFIntegrityTests {

    @Test("Ratchet 2 splits a note into retriggers across its gate")
    func ratchet() {
        let track = SMFTrack(name: "v", channel: 0,
                             notes: [rendered(0, gate: 120, ratchet: 2)])
        let events = noteEvents(SMFWriter.encode(bpm: 90, meter: meter,
                                                 tracks: [track], length: beat))
        let ons = events.filter { $0.on }
        #expect(ons.map(\.at) == [0, 60])
        for e in events where !e.on {
            #expect(e.at <= 120)
        }
    }

    @Test("Same-pitch overlap: first off clipped to second onset; offs before ons")
    func overlapClipped() {
        let track = SMFTrack(name: "v", channel: 0, notes: [
            rendered(0, gate: 500),        // would ring past the next onset
            rendered(240, gate: 120),
        ])
        let events = noteEvents(SMFWriter.encode(bpm: 90, meter: meter,
                                                 tracks: [track], length: beat))
        #expect(events.map { ($0.at, $0.on) } == [(0, true), (240, false), (240, true), (360, false)])
    }

    @Test("Fuzz: every note-on has exactly one matching note-off (generated ensemble)")
    func pairing() {
        let key = Key.default
        for seed in UInt64(1)...20 {
            let voices = [
                Voice(id: "bed1", role: .bedPluck1,
                      register: RegisterWindow(low: 48, high: 84), referenceC: 60,
                      pattern: PatternFactory.make(id: "b1", config: .seedProcedure(bars: 1, mutations: 4),
                                                   role: .bedPluck1, key: key, meter: meter, seed: seed)),
                Voice(id: "bass", role: .bass,
                      register: RegisterWindow(low: 24, high: 48), referenceC: 36,
                      pattern: PatternFactory.make(id: "bs", config: .pulsingBass(accents: 3),
                                                   role: .bass, key: key, meter: meter, seed: seed)),
            ]
            let notes = HarmonyEngine.render(voices: voices, schedule: .pedal,
                                             key: key, meter: meter, in: 0..<(8 * bar))
            for voice in voices {
                let track = SMFTrack(name: voice.id, channel: 0,
                                     notes: notes.filter { $0.voiceID == voice.id })
                let events = noteEvents(SMFWriter.encode(bpm: 90, meter: meter,
                                                         tracks: [track], length: 8 * bar))
                var sounding = Set<UInt8>()
                for e in events {
                    if e.on {
                        #expect(!sounding.contains(e.note), "double note-on without off")
                        sounding.insert(e.note)
                    } else {
                        #expect(sounding.contains(e.note), "orphan note-off")
                        sounding.remove(e.note)
                    }
                }
                #expect(sounding.isEmpty, "hanging notes at end of track")
            }
        }
    }

    @Test("Determinism: identical inputs → identical bytes")
    func deterministicBytes() {
        let track = SMFTrack(name: "v", channel: 3,
                             notes: [rendered(0), rendered(480, note: 67, ratchet: 3)])
        let a = SMFWriter.encode(bpm: 90, meter: meter, tracks: [track], length: bar)
        let b = SMFWriter.encode(bpm: 90, meter: meter, tracks: [track], length: bar)
        #expect(a == b)
    }
}

// MARK: - Tiny test-side helpers (scan channel events; not a full parser)

private func contains(_ haystack: [UInt8], subsequence needle: [UInt8]) -> Bool {
    guard needle.count <= haystack.count else { return false }
    return (0...(haystack.count - needle.count)).contains { start in
        Array(haystack[start..<(start + needle.count)]) == needle
    }
}

private func suffix(of bytes: [UInt8], is expected: [UInt8]) -> Bool {
    bytes.count >= expected.count && Array(bytes.suffix(expected.count)) == expected
}

/// Scans the LAST track chunk of the file for note on/off events.
private func noteEvents(_ bytes: [UInt8]) -> [(at: Tick, on: Bool, note: UInt8)] {
    // Find last "MTrk"
    var trackStart = -1
    for i in 0...(bytes.count - 4) where Array(bytes[i..<i+4]) == Array("MTrk".utf8) {
        trackStart = i
    }
    precondition(trackStart >= 0)
    var i = trackStart + 8
    var time: Tick = 0
    var events: [(Tick, Bool, UInt8)] = []
    while i < bytes.count {
        // delta VLQ
        var delta: Tick = 0
        while true {
            let b = bytes[i]; i += 1
            delta = (delta << 7) | Tick(b & 0x7F)
            if b & 0x80 == 0 { break }
        }
        time += delta
        let status = bytes[i]; i += 1
        switch status & 0xF0 {
        case 0x90:
            events.append((time, true, bytes[i])); i += 2
        case 0x80:
            events.append((time, false, bytes[i])); i += 2
        case 0xF0 where status == 0xFF:
            let type = bytes[i]; i += 1
            var len: Int = 0
            while true {
                let b = bytes[i]; i += 1
                len = (len << 7) | Int(b & 0x7F)
                if b & 0x80 == 0 { break }
            }
            i += len
            if type == 0x2F { return events.map { (at: $0.0, on: $0.1, note: $0.2) } }
        default:
            preconditionFailure("unexpected status byte in test scan")
        }
    }
    return events.map { (at: $0.0, on: $0.1, note: $0.2) }
}
