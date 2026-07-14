/// MIDI 1.0 events as sent by Berlinan (spec §9.1: channel voice messages for
/// maximal DAW compatibility), encoded as 32-bit Universal MIDI Packet words
/// for the CoreMIDI event-list API.
public enum MIDI1Event: Equatable, Sendable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8)
    case cc(channel: UInt8, controller: UInt8, value: UInt8)
    case clock              // 0xF8 — 24 PPQ (FR-IO-3, phase 12)
    case start              // 0xFA
    case continuePlayback   // 0xFB
    case stop               // 0xFC

    /// UMP word: [type:4][group:4][status:8][data1:8][data2:8].
    /// Channel voice = message type 0x2; system real-time = type 0x1.
    public var umpWord: UInt32 {
        func voice(_ status: UInt8, _ d1: UInt8, _ d2: UInt8) -> UInt32 {
            0x2000_0000 | UInt32(status) << 16 | UInt32(d1) << 8 | UInt32(d2)
        }
        switch self {
        case let .noteOn(channel, note, velocity):
            return voice(0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F)
        case let .noteOff(channel, note):
            return voice(0x80 | (channel & 0x0F), note & 0x7F, 0)
        case let .cc(channel, controller, value):
            return voice(0xB0 | (channel & 0x0F), controller & 0x7F, value & 0x7F)
        case .clock:
            return 0x10F8_0000
        case .start:
            return 0x10FA_0000
        case .continuePlayback:
            return 0x10FB_0000
        case .stop:
            return 0x10FC_0000
        }
    }
}
