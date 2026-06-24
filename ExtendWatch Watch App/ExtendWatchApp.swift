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
final class ExtendWatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            await WatchWorkoutSessionManager.shared.startMirrored(config: workoutConfiguration)
        }
    }
}
