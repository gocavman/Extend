////
////  WatchConnectivityReceiver.swift
////  Extend
////
////  iPhone-side WatchConnectivity singleton.
////  • Receives water logs queued from the Apple Watch and saves them to WaterState.
////  • Pushes current water totals to the watch whenever the iPhone logs or loads water.
////

import Foundation
import WatchConnectivity

final class WatchConnectivityReceiver: NSObject {
    static let shared = WatchConnectivityReceiver()
    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// True only when there's an active, paired watch with the watch app installed.
    private var canSendToWatch: Bool {
        WCSession.isSupported() &&
        WCSession.default.activationState == .activated &&
        WCSession.default.isPaired &&
        WCSession.default.isWatchAppInstalled
    }

    /// Push the iPhone's current water totals to the watch display and complication.
    func sendWaterUpdate(todayOz: Double, goalOz: Double) {
        guard canSendToWatch else { return }
        let payload: [String: Any] = [
            "type": "water_update",
            "today_oz": todayOz,
            "goal_oz": goalOz,
            "date": Calendar.current.startOfDay(for: Date()).timeIntervalSince1970,
            "sent_at": Date().timeIntervalSince1970
        ]
        try? WCSession.default.updateApplicationContext(payload)
        WCSession.default.transferUserInfo(payload)
    }

    /// Push the ±7-day plan snapshots to the watch so WatchPlanDetailView and the
    /// Today's Plan complication stay current. Uses `updateApplicationContext` for
    /// immediate latest-state delivery (the system wakes the watch and replaces
    /// any previous context), and also queues a `transferUserInfo` so the update
    /// still lands if the watch is unreachable. Without the application-context
    /// path, complication refreshes can be deferred for minutes by the watchOS
    /// complication budget.
    func sendPlanUpdate(multidaySnapshots: [WidgetPlanSnapshot]) {
        guard canSendToWatch else { return }
        guard let data = try? JSONEncoder().encode(multidaySnapshots) else { return }
        let payload: [String: Any] = [
            "type": "plan_update",
            "multiday_data": data,
            "sent_at": Date().timeIntervalSince1970
        ]
        try? WCSession.default.updateApplicationContext(payload)
        WCSession.default.transferUserInfo(payload)
    }

    /// Pushes the watch's full startable library (all workouts/exercises/
    /// timers/voice trainers in compact form) so the Watch Library tab can
    /// browse and start any of them without depending on what's planned today.
    /// Uses `updateApplicationContext` for immediate latest-state delivery,
    /// plus `transferUserInfo` for guaranteed eventual delivery.
    func sendLibraryUpdate(_ snapshot: WatchLibrarySnapshot) {
        guard canSendToWatch else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let payload: [String: Any] = [
            "type": "library_update",
            "library_data": data,
            "sent_at": Date().timeIntervalSince1970
        ]
        try? WCSession.default.updateApplicationContext(payload)
        WCSession.default.transferUserInfo(payload)
    }

    /// Force a complication refresh on the watch. Call this when plan data changes
    /// but no other payload is needed.
    func sendComplicationRefresh() {
        guard canSendToWatch else { return }
        WCSession.default.transferUserInfo([
            "type": "reload_complications"
        ])
    }

    // MARK: - Live workout session bridging

    /// True when the watch is paired, app installed, and currently reachable
    /// (i.e. an interactive `sendMessage` will succeed). Required for the live
    /// workout session bridge to do anything.
    var isWatchReachable: Bool {
        canSendToWatch && WCSession.default.isReachable
    }

    /// Asks the watch to begin an HKWorkoutSession for the given activity type.
    /// Returns true when the watch confirms the session started. Falls back to
    /// false on any error (unreachable, no app installed, HK auth missing).
    func startWatchWorkout(activityTypeRaw: UInt?, name: String) async -> Bool {
        guard isWatchReachable else { return false }
        let payload: [String: Any] = [
            "type": "start_workout",
            "activity_type_raw": activityTypeRaw ?? 0,
            "name": name
        ]
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            WCSession.default.sendMessage(payload, replyHandler: { reply in
                cont.resume(returning: (reply["ok"] as? Bool) ?? false)
            }, errorHandler: { _ in
                cont.resume(returning: false)
            })
        }
    }

    /// Asks the watch to end the in-flight session and return the saved
    /// HKWorkout's UUID — caller stamps that UUID on the iPhone WorkoutLog
    /// so we end up with exactly one HKWorkout in Apple Health.
    func endWatchWorkout() async -> UUID? {
        guard isWatchReachable else { return nil }
        let payload: [String: Any] = ["type": "end_workout"]
        return await withCheckedContinuation { (cont: CheckedContinuation<UUID?, Never>) in
            WCSession.default.sendMessage(payload, replyHandler: { reply in
                guard (reply["ok"] as? Bool) == true,
                      let uuidString = reply["workout_uuid"] as? String,
                      let uuid = UUID(uuidString: uuidString) else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: uuid)
            }, errorHandler: { _ in
                cont.resume(returning: nil)
            })
        }
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate when the user switches Apple Watch models
        WCSession.default.activate()
    }

    // Receive water logs and watch-initiated workout logs.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "water_log":
            guard let oz = userInfo["oz"] as? Double,
                  let timestamp = userInfo["date"] as? Double else { return }
            let date = Date(timeIntervalSince1970: timestamp)
            DispatchQueue.main.async {
                WaterState.shared.addLog(WaterLog(amountOz: oz, loggedAt: date))
            }
        case "watch_log_completed":
            handleWatchCompletedLog(userInfo)
        default:
            break
        }
    }

    /// Builds a WorkoutLog from a payload sent by the watch when the user
    /// finished a session on the wrist, and adopts the HKWorkout UUID the
    /// watch already saved to Apple Health so the iPhone doesn't re-export.
    /// When the payload includes per-exercise set data from the blueprint
    /// runner, those are reconstructed as `LoggedExercise` / `LoggedSet`.
    private func handleWatchCompletedLog(_ payload: [String: Any]) {
        guard let name = payload["name"] as? String,
              let completedAtTs = payload["completed_at"] as? Double,
              let duration = payload["duration"] as? Double else { return }
        let completedAt = Date(timeIntervalSince1970: completedAtTs)
        let activityTypeRaw = payload["activity_type_raw"] as? UInt
        let hkUUID: UUID? = (payload["hk_workout_uuid"] as? String).flatMap { UUID(uuidString: $0) }

        // Decode the optional exercises blob — watch sends this only for
        // blueprint-driven workouts. Falls back to a "duration-only" log.
        let loggedExercises: [LoggedExercise] = {
            guard let data = payload["exercises_data"] as? Data,
                  let watchExercises = try? JSONDecoder().decode([WatchLoggedExercise].self, from: data) else {
                return []
            }
            return watchExercises.enumerated().map { (idx, we) in
                let exerciseID = UUID(uuidString: we.exerciseID) ?? UUID()
                let sets = we.sets.map { LoggedSet(reps: $0.reps, weight: $0.weight) }
                return LoggedExercise(
                    exerciseID: exerciseID,
                    exerciseName: we.exerciseName,
                    sets: sets,
                    notes: "",
                    activeSeconds: we.activeSeconds,
                    orderIndex: idx
                )
            }
        }()

        DispatchQueue.main.async {
            let log = WorkoutLog(
                workoutName: name,
                completedAt: completedAt,
                exercises: loggedExercises,
                notes: "Started on Apple Watch",
                duration: duration
            )
            // Pass exportToHealthKit: true so the iPhone still records it when
            // the watch couldn't produce a UUID (HK auth missing, session
            // failed, etc.) — when a UUID IS provided, addLog short-circuits
            // the export to avoid duplicates.
            WorkoutLogState.shared.addLog(
                log,
                exportToHealthKit: HealthKitState.shared.exportStrengthWorkouts,
                activityTypeRaw: activityTypeRaw,
                existingHealthKitUUID: hkUUID
            )
        }
    }
}
