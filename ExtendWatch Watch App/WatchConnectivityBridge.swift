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

    private func handlePayload(_ payload: [String: Any]) {
        guard let type = payload["type"] as? String else { return }
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        switch type {
        case "water_update":
            guard let todayOz = payload["today_oz"] as? Double,
                  let goalOz  = payload["goal_oz"]   as? Double else { return }
            defaults.set(todayOz, forKey: "water_today_oz")
            // Stamp the day so readers can detect a stale value after midnight rollover.
            let stampedDate = (payload["date"] as? Double).map { Date(timeIntervalSince1970: $0) }
                ?? Calendar.current.startOfDay(for: Date())
            defaults.set(stampedDate, forKey: "water_today_date")
            defaults.set(goalOz,  forKey: "water_goal_oz")
            WidgetCenter.shared.reloadAllTimelines()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchWaterDataUpdated, object: nil)
            }
        case "plan_update":
            guard let data = payload["multiday_data"] as? Data else { return }
            defaults.set(data, forKey: "widget_plan_multiday")
            WidgetCenter.shared.reloadAllTimelines()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchPlanDataUpdated, object: nil)
            }
        case "reload_complications":
            // Triggered when plan data changes on iPhone
            WidgetCenter.shared.reloadAllTimelines()
        default:
            break
        }
    }
}
