////
////  WatchConnectivityBridge.swift
////  ExtendWatch
////
////  Watch-side WatchConnectivity singleton.
////  • Sends water logs to the paired iPhone when the user adds water on the watch.
////  • Receives iPhone-pushed water totals to keep the watch display in sync.
////  • Receives iPhone-pushed plan snapshots so WatchPlanDetailView shows current data.
////

import Foundation
import WatchConnectivity
import WidgetKit

// Note: Notification.Name extensions are now in ContentView.swift
// to avoid duplicate definitions

final class WatchConnectivityBridge: NSObject {
    static let shared = WatchConnectivityBridge()
    private let appGroupID = "group.com.cavanmannenbach.extend"

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Queues a water log to be delivered to the paired iPhone.
    func sendWaterLog(oz: Double, date: Date) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo([
            "type": "water_log",
            "oz": oz,
            "date": date.timeIntervalSince1970
        ])
    }

    /// Forwards a workout session that finished on the watch back to the iPhone
    /// so it can be stored in WorkoutLogState. `hkWorkoutUUID` is the UUID of
    /// the HKWorkout the live session already saved to Apple Health — the
    /// iPhone stamps that on the log and skips its own export to avoid duplicates.
    /// `exercises` carries per-set detail when the user ran a blueprint-driven
    /// workout; nil/empty for simple sessions (single exercise, timer, voice).
    func sendCompletedLog(name: String,
                          completedAt: Date,
                          duration: TimeInterval,
                          hkActivityTypeRaw: UInt?,
                          hkWorkoutUUID: UUID?,
                          exercises: [WatchLoggedExercise]? = nil) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        var payload: [String: Any] = [
            "type": "watch_log_completed",
            "name": name,
            "completed_at": completedAt.timeIntervalSince1970,
            "duration": duration
        ]
        if let hkActivityTypeRaw { payload["activity_type_raw"] = hkActivityTypeRaw }
        if let hkWorkoutUUID { payload["hk_workout_uuid"] = hkWorkoutUUID.uuidString }
        if let exercises, !exercises.isEmpty,
           let data = try? JSONEncoder().encode(exercises) {
            payload["exercises_data"] = data
        }
        WCSession.default.transferUserInfo(payload)
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionReachabilityDidChange(_ session: WCSession) {}

    // Receive payloads pushed from the iPhone
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handlePayload(userInfo)
    }

    // Receive the latest-state context pushed via updateApplicationContext.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handlePayload(applicationContext)
    }

    // Real-time, reply-expected messages. Used by the iPhone to start/end a
    // live HKWorkoutSession on the watch — that way the watch collects real
    // heart rate / calories while the iPhone drives the workout flow.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        guard let type = message["type"] as? String else {
            replyHandler(["ok": false])
            return
        }
        switch type {
        case "start_workout":
            let raw = message["activity_type_raw"] as? UInt
            let name = (message["name"] as? String) ?? "Workout"
            Task { @MainActor in
                let ok = await WatchWorkoutSessionManager.shared.start(activityTypeRaw: raw, name: name)
                replyHandler(["ok": ok])
            }
        case "end_workout":
            Task { @MainActor in
                let uuid = await WatchWorkoutSessionManager.shared.end()
                if let uuid {
                    replyHandler(["ok": true, "workout_uuid": uuid.uuidString])
                } else {
                    replyHandler(["ok": false])
                }
            }
        default:
            replyHandler(["ok": false])
        }
    }

    private func handlePayload(_ payload: [String: Any]) {
        guard let type = payload["type"] as? String else { return }
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        switch type {
        case "water_update":
            guard let todayOz = payload["today_oz"] as? Double,
                  let goalOz  = payload["goal_oz"]   as? Double else { return }
            // Stamp the day so readers can detect a stale value after midnight rollover.
            let stampedDate = (payload["date"] as? Double).map { Date(timeIntervalSince1970: $0) }
                ?? Calendar.current.startOfDay(for: Date())
            // During rapid quick-adds, the iPhone's in-flight value can lag
            // behind the watch's optimistic total. Accept lower values only when
            // they represent a fresh day (treated as a midnight reset).
            let currentLocal = defaults.double(forKey: "water_today_oz")
            let storedDate = defaults.object(forKey: "water_today_date") as? Date
            let isNewDay = storedDate.map { !Calendar.current.isDate($0, inSameDayAs: stampedDate) } ?? true
            let effectiveOz = isNewDay ? todayOz : max(todayOz, currentLocal)
            defaults.set(effectiveOz, forKey: "water_today_oz")
            defaults.set(stampedDate, forKey: "water_today_date")
            defaults.set(goalOz,  forKey: "water_goal_oz")
            WidgetCenter.shared.reloadAllTimelines()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchWaterDataUpdated, object: nil)
            }
        case "plan_update":
            guard let data = payload["multiday_data"] as? Data else { return }
            defaults.set(data, forKey: "widget_plan_multiday")
            // Kind-specific reload is more reliable than reloadAllTimelines on watchOS,
            // which the complication budget can defer or drop.
            WidgetCenter.shared.reloadTimelines(ofKind: "PlanComplication")
            WidgetCenter.shared.reloadAllTimelines()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchPlanDataUpdated, object: nil)
            }
        case "library_update":
            guard let data = payload["library_data"] as? Data else { return }
            defaults.set(data, forKey: "watch_library")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchLibraryDataUpdated, object: nil)
            }
        case "reload_complications":
            // Triggered when plan data changes on iPhone
            WidgetCenter.shared.reloadTimelines(ofKind: "PlanComplication")
            WidgetCenter.shared.reloadAllTimelines()
        default:
            break
        }
    }
}
