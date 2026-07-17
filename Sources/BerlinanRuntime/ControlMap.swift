import Foundation

/// MIDI-learn plumbing (FR-IO-10): triggers from a controller mapped to
/// Berlinan macros. Pure value types; persisted as JSON in Application
/// Support.

/// What arrived from the controller.
public enum ControlTrigger: Codable, Hashable, Sendable {
    case cc(channel: UInt8, number: UInt8)
    case note(channel: UInt8, number: UInt8)
}

/// What it does in Berlinan.
public enum ControlMacro: Codable, Hashable, Sendable {
    case playStop
    case degree(Int)          // 1–7
    case rerollUnlocked
    case newSeed
    case recallSlot(Int)      // 0–5
    /// Arranger "advance now" (FR-A-6); no-op while the autopilot is off.
    case advancePhase
    /// The S4 move (FR-A-5): progression + bass swap (+ bed drop).
    case fireBPart
}

public struct ControlMap: Codable, Equatable, Sendable {

    private var bindings: [ControlTrigger: ControlMacro] = [:]

    public init() {}

    /// Bind a macro to a trigger. Last-wins in both directions: the trigger's
    /// previous macro is replaced AND the macro's previous trigger is freed
    /// (one knob per function, one function per knob).
    public mutating func bind(_ macro: ControlMacro, to trigger: ControlTrigger) {
        for (existing, bound) in bindings where bound == macro {
            bindings.removeValue(forKey: existing)
        }
        bindings[trigger] = macro
    }

    public func macro(for trigger: ControlTrigger) -> ControlMacro? {
        bindings[trigger]
    }

    public var isEmpty: Bool { bindings.isEmpty }

    // MARK: - Persistence

    public static func defaultFileURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("Berlinan/midimap.json")
    }

    public static func load(from url: URL = defaultFileURL()) -> ControlMap {
        guard let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode(ControlMap.self, from: data) else {
            return ControlMap()
        }
        return map
    }

    public func save(to url: URL = defaultFileURL()) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? (try? encoder.encode(self))?.write(to: url)
    }
}
