////
////  MirrorDiagnostics.swift
////  ExtendWatch
////
////  Watch-side mirror of the in-app diagnostic ring buffer. The iPhone
////  has its own copy (separate process), and each captures the events its
////  side of the handshake sees — together they tell a complete story when
////  a phone-driven mirrored workout fails to launch.
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

    public func exportText() -> String {
        lines.joined(separator: "\n")
    }
}
