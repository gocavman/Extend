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

extension Notification.Name {
    static let watchWaterDataUpdated = Notification.Name("watchWaterDataUpdated")
    static let watchPlanDataUpdated  = Notification.Name("watchPlanDataUpdated")
}

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
        guard let type = userInfo["type"] as? String else { return }
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        switch type {
        case "water_update":
            guard let todayOz = userInfo["today_oz"] as? Double,
                  let goalOz  = userInfo["goal_oz"]   as? Double else { return }
            defaults.set(todayOz, forKey: "water_today_oz")
            defaults.set(goalOz,  forKey: "water_goal_oz")
            WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWatch.Water")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchWaterDataUpdated, object: nil)
            }
        case "plan_update":
            guard let data = userInfo["multiday_data"] as? Data else { return }
            defaults.set(data, forKey: "widget_plan_multiday")
            WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWatch.PlanRing")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchPlanDataUpdated, object: nil)
            }
        default:
            break
        }
    }
}
