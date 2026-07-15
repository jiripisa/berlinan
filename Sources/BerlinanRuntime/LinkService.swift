import CAblLink
import Foundation

/// Swift facade over the official `abl_link` C wrapper (FR-IO-5, spec §8.5).
/// One instance owns one Link peer and one app-thread session state.
///
/// All session-state access is funneled through a lock: abl_link's
/// capture/commit-app pair expects a single "app thread", but Berlinan
/// queries Link from both the scheduler thread (per-wake re-anchor) and the
/// main thread (UI), so the lock provides that single-thread discipline.
public final class LinkService: @unchecked Sendable {

    private let link: abl_link
    private let state: abl_link_session_state
    private let lock = NSLock()

    public init(bpm: Double) {
        link = abl_link_create(bpm)
        state = abl_link_create_session_state()
    }

    deinit {
        abl_link_enable(link, false)
        abl_link_destroy_session_state(state)
        abl_link_destroy(link)
    }

    // MARK: - Peer discovery

    public var isEnabled: Bool { abl_link_is_enabled(link) }

    /// Joins/leaves the Link session (opens UDP multicast — the app enables
    /// this only when the user picks the LINK sync mode).
    public func enable(_ on: Bool) { abl_link_enable(link, on) }

    public var numPeers: UInt64 { abl_link_num_peers(link) }

    /// The Link clock, microseconds (same timebase as mach host time).
    public func clockMicros() -> Int64 { abl_link_clock_micros(link) }

    // MARK: - Session state (app-thread pair, serialized by the lock)

    public func tempo() -> Double {
        lock.lock(); defer { lock.unlock() }
        abl_link_capture_app_session_state(link, state)
        return abl_link_tempo(state)
    }

    public func setTempo(_ bpm: Double) {
        lock.lock(); defer { lock.unlock() }
        abl_link_capture_app_session_state(link, state)
        abl_link_set_tempo(state, bpm, abl_link_clock_micros(link))
        abl_link_commit_app_session_state(link, state)
    }

    /// Beat position on the shared grid at the given Link time.
    public func beat(atMicros micros: Int64, quantum: Double) -> Double {
        lock.lock(); defer { lock.unlock() }
        abl_link_capture_app_session_state(link, state)
        return abl_link_beat_at_time(state, micros, quantum)
    }

    /// Ask the session to place `beat` at `micros` (granted verbatim without
    /// peers; with peers the beat lands on the next quantum boundary).
    public func requestBeat(_ beat: Double, atMicros micros: Int64, quantum: Double) {
        lock.lock(); defer { lock.unlock() }
        abl_link_capture_app_session_state(link, state)
        abl_link_request_beat_at_time(state, beat, micros, quantum)
        abl_link_commit_app_session_state(link, state)
    }
}
