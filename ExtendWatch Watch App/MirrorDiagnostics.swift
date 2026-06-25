////
////  MirrorDiagnostics.swift
////  ExtendWatch
////
////  Watch-side mirror of the in-app diagnostic ring buffer. The iPhone
////  has its own copy (separate process), and each captures the events its
////  side of the handshake sees — together they tell a complete story when
////  a phone-driven mirrored workout fails to launch.
////
////  `log(_:)` is intentionally callable from any thread without isolation
////  hops: the watch's background-launched `WKApplicationDelegate.handle(_:)`
////  has a very short window before the system can suspend the app, and
////  wrapping the log in `Task { @MainActor in … }` was eating it.
////

import Foundation
import Observation
import os

@Observable
public final class MirrorDiagnostics {

    public static let shared = MirrorDiagnostics()

    @MainActor public private(set) var lines: [String] = []

    // These are touched from `nonisolated static func log(...)`, so their
    // isolation has to be explicitly nonisolated — otherwise Swift infers
    // them as MainActor from the enclosing @Observable class and the log
    // function can't reference them.
    nonisolated private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String] = []
    nonisolated private static let limit = 200
    nonisolated private static let logger = Logger(subsystem: "com.cavanmannenbach.extend", category: "mirror")
    nonisolated private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    public nonisolated static func log(_ message: String) {
        let stamped = "[\(stampFormatter.string(from: Date()))] \(message)"
        logger.info("\(message, privacy: .public)")
        lock.lock()
        storage.append(stamped)
        if storage.count > limit {
            storage.removeFirst(storage.count - limit)
        }
        let snapshot = storage
        lock.unlock()
        Task { @MainActor in
            shared.lines = snapshot
        }
    }

    @MainActor
    public func clear() {
        Self.lock.lock()
        Self.storage.removeAll()
        Self.lock.unlock()
        lines = []
    }

    @MainActor
    public func exportText() -> String {
        lines.joined(separator: "\n")
    }
}
