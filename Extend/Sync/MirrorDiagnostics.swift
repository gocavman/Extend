////
////  MirrorDiagnostics.swift
////  Extend
////
////  In-app ring buffer for mirrored-workout diagnostic lines. The phone and
////  watch each keep their own copy (they're separate processes), so when
////  something's wrong the user can pull up the buffer on each device to see
////  exactly where the handshake broke instead of needing Console.app on a
////  paired Mac.
////
////  Every `log(...)` line is also printed to stdout so a connected Xcode
////  debugger still shows it — this is purely additive on top of `print`.
////

import Foundation
import Observation

@MainActor
@Observable
public final class MirrorDiagnostics {

    public static let shared = MirrorDiagnostics()

    /// Captured diagnostic lines, oldest first. Capped at `limit`.
    public private(set) var lines: [String] = []

    private let limit = 200
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    /// Append a stamped line and mirror it to stdout. Safe to call from any
    /// task on the main actor.
    public func log(_ message: String) {
        let stamped = "[\(formatter.string(from: Date()))] \(message)"
        print("[mirror] \(message)")
        lines.append(stamped)
        if lines.count > limit {
            lines.removeFirst(lines.count - limit)
        }
    }

    public func clear() {
        lines.removeAll()
    }

    /// Joins the buffer into a single string suitable for share / pasteboard.
    public func exportText() -> String {
        lines.joined(separator: "\n")
    }
}
