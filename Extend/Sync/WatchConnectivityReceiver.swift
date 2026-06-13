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

    /// Push the iPhone's current water totals to the watch display and complication.
    func sendWaterUpdate(todayOz: Double, goalOz: Double) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        WCSession.default.transferUserInfo([
            "type": "water_update",
            "today_oz": todayOz,
            "goal_oz": goalOz
        ])
    }

    /// Push the ±7-day plan snapshots to the watch so WatchPlanDetailView stays current.
    func sendPlanUpdate(multidaySnapshots: [WidgetPlanSnapshot]) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(multidaySnapshots) else { return }
        WCSession.default.transferUserInfo([
            "type": "plan_update",
            "multiday_data": data
        ])
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate when the user switches Apple Watch models
        WCSession.default.activate()
    }

    // Receive water logs queued by the watch
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String, type == "water_log",
              let oz = userInfo["oz"] as? Double,
              let timestamp = userInfo["date"] as? Double else { return }
        let date = Date(timeIntervalSince1970: timestamp)
        DispatchQueue.main.async {
            WaterState.shared.addLog(WaterLog(amountOz: oz, loggedAt: date))
        }
    }
}
