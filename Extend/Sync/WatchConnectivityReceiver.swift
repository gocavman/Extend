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
    /// Used to gate `transferUserInfo` — those messages queue indefinitely in
    /// the iPhone's outbox, so we skip them if there's clearly no recipient.
    private var canSendToWatch: Bool {
        WCSession.isSupported() &&
        WCSession.default.activationState == .activated &&
        WCSession.default.isPaired &&
        WCSession.default.isWatchAppInstalled
    }

    /// Looser gate used for `updateApplicationContext`. After a fresh watch
    /// install the system can briefly report `isWatchAppInstalled == false`
    /// even though the watch is paired and the app will become installed
    /// shortly. Application context is persistent and replaces any previous
    /// payload, so it's safe to set it whenever the session is paired and
    /// activated — the watch will receive it on its next activation. Without
    /// this, the CloudKit-driven water push on iPhone cold-launch was
    /// silently dropped, leaving the complication stuck on stale data.
    private var canUpdateContext: Bool {
        WCSession.isSupported() &&
        WCSession.default.activationState == .activated &&
        WCSession.default.isPaired
    }

    /// Push today's total workout-log count to the watch so the Library
    /// complication can show "Extend — N done". The App Group container is
    /// device-local, so without this the watch widget would never see the
    /// iPhone-side count update.
    func sendTodayLogCountUpdate(count: Int) {
        let payload: [String: Any] = [
            "type": "today_log_count_update",
            "count": count,
            "date": Calendar.current.startOfDay(for: Date()).timeIntervalSince1970,
            "sent_at": Date().timeIntervalSince1970
        ]
        if canUpdateContext {
            try? WCSession.default.updateApplicationContext(payload)
        }
        if canSendToWatch {
            WCSession.default.transferUserInfo(payload)
        }
    }

    /// Push the iPhone's current water totals to the watch display and complication.
    func sendWaterUpdate(todayOz: Double, goalOz: Double) {
        let payload: [String: Any] = [
            "type": "water_update",
            "today_oz": todayOz,
            "goal_oz": goalOz,
            "date": Calendar.current.startOfDay(for: Date()).timeIntervalSince1970,
            "sent_at": Date().timeIntervalSince1970
        ]
        if canUpdateContext {
            try? WCSession.default.updateApplicationContext(payload)
        }
        if canSendToWatch {
            WCSession.default.transferUserInfo(payload)
        }
    }

    /// Push the ±7-day plan snapshots to the watch so WatchPlanDetailView and the
    /// Today's Plan complication stay current. Uses `updateApplicationContext` for
    /// immediate latest-state delivery (the system wakes the watch and replaces
    /// any previous context), and also queues a `transferUserInfo` so the update
    /// still lands if the watch is unreachable. Without the application-context
    /// path, complication refreshes can be deferred for minutes by the watchOS
    /// complication budget.
    func sendPlanUpdate(multidaySnapshots: [WidgetPlanSnapshot]) {
        guard let data = try? JSONEncoder().encode(multidaySnapshots) else { return }
        let payload: [String: Any] = [
            "type": "plan_update",
            "multiday_data": data,
            "sent_at": Date().timeIntervalSince1970
        ]
        if canUpdateContext {
            try? WCSession.default.updateApplicationContext(payload)
        }
        if canSendToWatch {
            WCSession.default.transferUserInfo(payload)
        }
    }

    /// Pushes the watch's full startable library (all workouts/exercises/
    /// timers/voice trainers in compact form) so the Watch Library tab can
    /// browse and start any of them without depending on what's planned today.
    /// Uses `updateApplicationContext` for immediate latest-state delivery,
    /// plus `transferUserInfo` for guaranteed eventual delivery.
    func sendLibraryUpdate(_ snapshot: WatchLibrarySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let payload: [String: Any] = [
            "type": "library_update",
            "library_data": data,
            "sent_at": Date().timeIntervalSince1970
        ]
        if canUpdateContext {
            try? WCSession.default.updateApplicationContext(payload)
        }
        if canSendToWatch {
            WCSession.default.transferUserInfo(payload)
        }
    }

    /// Force a complication refresh on the watch. Call this when plan data changes
    /// but no other payload is needed.
    func sendComplicationRefresh() {
        guard canSendToWatch else { return }
        WCSession.default.transferUserInfo([
            "type": "reload_complications"
        ])
    }

    // Phone-driven live workout sessions are owned by MirroredWorkoutCoordinator,
    // which wakes the watch app via `HKHealthStore.startWatchApp(toHandle:)`
    // and rides the system mirroring channel. The watch-initiated path
    // (logging completed on the wrist) still flows through this receiver
    // via `transferUserInfo` so logs land even when the watch was out of
    // range during the workout.
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Re-push current water totals as soon as the session activates.
        // After a fresh reinstall the iPhone's CloudKit-driven water push can
        // run before the watch app reports itself as installed; this catches
        // that case (and any other time we missed a push while inactive).
        guard activationState == .activated else { return }
        rePushLatestStateToWatch()
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate when the user switches Apple Watch models
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        // The watch just came in range / woke up — re-push so a previously
        // dropped water update lands now that the channel is open.
        guard session.isReachable else { return }
        rePushLatestStateToWatch()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // Fires when isPaired / isWatchAppInstalled flip. Right after a
        // fresh watch install this transitions from false → true; that's
        // exactly when we need to re-deliver the water snapshot.
        guard session.isPaired, session.isWatchAppInstalled else { return }
        rePushLatestStateToWatch()
    }

    private func rePushLatestStateToWatch() {
        DispatchQueue.main.async {
            let oz = WaterState.shared.todayOz
            let goal = WaterState.shared.dailyGoalOz
            self.sendWaterUpdate(todayOz: oz, goalOz: goal)
        }
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
        let extraNotes = (payload["notes"] as? String) ?? ""
        let logType: WorkoutLogType = {
            guard let raw = payload["log_type"] as? String,
                  let parsed = WorkoutLogType(rawValue: raw) else { return .workout }
            return parsed
        }()
        // Watch-measured active kcal from HKLiveWorkoutDataSource. Phone falls back
        // to a MET estimate inside WorkoutLogState.addLog when this is nil.
        let activeCalories: Double? = (payload["active_calories"] as? Double).flatMap { $0 > 0 ? $0 : nil }

        // Decode the optional exercises blob — watch sends this only for
        // blueprint-driven workouts. Falls back to a "duration-only" log.
        let loggedExercises: [LoggedExercise] = {
            guard let data = payload["exercises_data"] as? Data,
                  let watchExercises = try? JSONDecoder().decode([WatchLoggedExercise].self, from: data) else {
                return []
            }
            let library = ExercisesState.shared.exercises
            return watchExercises.enumerated().map { (idx, we) in
                let exerciseID = UUID(uuidString: we.exerciseID) ?? UUID()
                let sets = we.sets.map { LoggedSet(reps: $0.reps, weight: $0.weight) }
                // The watch payload doesn't carry equipment; seed it from the
                // phone-side library so the log matches what the user gets
                // when starting the same exercise from the iPhone.
                let usedEquipment: [UUID] = {
                    guard let ex = library.first(where: { $0.id == exerciseID }) else { return [] }
                    if !ex.defaultEquipmentIDs.isEmpty { return ex.defaultEquipmentIDs }
                    if ex.equipmentIDs.count == 1 { return ex.equipmentIDs }
                    return []
                }()
                return LoggedExercise(
                    exerciseID: exerciseID,
                    exerciseName: we.exerciseName,
                    sets: sets,
                    notes: "",
                    activeSeconds: we.activeSeconds,
                    usedEquipmentIDs: usedEquipment,
                    orderIndex: idx
                )
            }
        }()

        DispatchQueue.main.async {
            let notes: String = {
                let base = "Started on Apple Watch"
                return extraNotes.isEmpty ? base : "\(base)\n\(extraNotes)"
            }()
            let log = WorkoutLog(
                workoutName: name,
                completedAt: completedAt,
                logType: logType,
                exercises: loggedExercises,
                notes: notes,
                duration: duration,
                activeCalories: activeCalories
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
