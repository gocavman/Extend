//
//  ExtendWatchApp.swift
//  ExtendWatch Watch App
//
//  Created by CAVAN MANNENBACH on 6/11/26.
//

import SwiftUI
import HealthKit
import WatchKit

@main
struct ExtendWatch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(ExtendWatchAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Handles the system-level `handle(_ workoutConfiguration:)` callback the
/// iPhone triggers via `HKHealthStore.startWatchApp(toHandle:)`. The watch
/// app is woken (or foregrounded) and we kick off a primary HKWorkoutSession
/// + start mirroring it back so the iPhone can receive live HR/calories
/// through its companion `HKLiveWorkoutBuilder`. The session's display
/// name arrives moments later as a `MirroredSessionMessage.name(...)`
/// payload over `sendToRemoteWorkoutSession`.
///
/// Lifecycle methods below are heavily logged on purpose. When phone-driven
/// workout mirroring is misbehaving, the trace of which delegate callbacks
/// fired (and which didn't) is the single most useful piece of diagnostic
/// data — it lets us distinguish "watch never woke" from "watch woke but
/// the mirrored-workout selector wasn't delivered."
final class ExtendWatchAppDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        // Synchronous log — MirrorDiagnostics.log is nonisolated so the
        // entry lands in the ring buffer before any further work.
        MirrorDiagnostics.log("applicationDidFinishLaunching (cold launch)")
        // Sanity-check the Info.plist — if `WKBackgroundModes` doesn't
        // include `workout-processing`, the system silently refuses to
        // deliver `handle(_:)` for HKWorkoutConfiguration when iPhone
        // calls `startWatchApp(toHandle:)`.
        if let modes = Bundle.main.infoDictionary?["WKBackgroundModes"] as? [String] {
            MirrorDiagnostics.log("WKBackgroundModes = \(modes)")
        } else {
            MirrorDiagnostics.log("WKBackgroundModes = (missing!)")
        }
    }

    func applicationDidBecomeActive() {
        MirrorDiagnostics.log("applicationDidBecomeActive")
    }

    func applicationWillResignActive() {
        MirrorDiagnostics.log("applicationWillResignActive")
    }

    func applicationWillEnterForeground() {
        MirrorDiagnostics.log("applicationWillEnterForeground")
    }

    func applicationDidEnterBackground() {
        MirrorDiagnostics.log("applicationDidEnterBackground")
    }

    // MARK: - Workout dispatch

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        // Log SYNCHRONOUSLY first. A background-launched watch app gets a
        // very narrow execution window before the system can suspend it;
        // wrapping this in a Task was eating the log entry entirely.
        MirrorDiagnostics.log("handle(HKWorkoutConfiguration) fired — activity=\(workoutConfiguration.activityType.rawValue)")
        Task { @MainActor in
            let ok = await WatchWorkoutSessionManager.shared.startMirrored(config: workoutConfiguration)
            MirrorDiagnostics.log("startMirrored returned ok=\(ok)")
        }
    }

    // MARK: - Other handle overloads (caught defensively in case the
    // system is routing the call to a different selector than expected)

    func handle(_ userActivity: NSUserActivity) {
        MirrorDiagnostics.log("handle(NSUserActivity) — \(userActivity.activityType)")
    }

    func handleActiveWorkoutRecovery() {
        MirrorDiagnostics.log("handleActiveWorkoutRecovery (post-crash recovery)")
    }
}
