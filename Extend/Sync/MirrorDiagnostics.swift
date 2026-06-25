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
////  `log(_:)` is intentionally callable from any thread without isolation
////  hops: the watch's background-launched `WKApplicationDelegate.handle(_:)`
////  has a very short window before the system can suspend the app, and
////  wrapping the log in `Task { @MainActor in … }` was eating it. Writes
////  are protected by an `NSLock`; the SwiftUI-observed `lines` snapshot is
////  republished on MainActor for the view layer. Every line also goes
////  through `os.Logger` so a Mac with Console.app pointed at the device
////  can see it without the app open.
////

import Foundation
import Observation
import os

@Observable
public final class MirrorDiagnostics {

    public static let shared = MirrorDiagnostics()

    /// MainActor-readable snapshot of the buffer for SwiftUI. Republished
    /// from `storage` whenever a new line lands.
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

    /// Thread-safe; call from any context — including the watch's
    /// background-launched workout handler where a Task hop can be
    /// suspended before it ever runs.
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
