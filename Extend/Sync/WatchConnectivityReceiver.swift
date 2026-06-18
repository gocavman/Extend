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
        WCSession.default.transferUserInfo([
            "type": "water_update",
            "today_oz": todayOz,
            "goal_oz": goalOz,
            "date": Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        ])
    }

    /// Push the ±7-day plan snapshots to the watch so WatchPlanDetailView stays current.
    func sendPlanUpdate(multidaySnapshots: [WidgetPlanSnapshot]) {
        guard canSendToWatch else { return }
        guard let data = try? JSONEncoder().encode(multidaySnapshots) else { return }
        WCSession.default.transferUserInfo([
            "type": "plan_update",
            "multiday_data": data
        ])
    }

    /// Push the complication appearance + steps/distance settings to the watch.
    /// Uses updateApplicationContext for atomic latest-state delivery so a fast
    /// burst of edits doesn't queue up redundant userInfo transfers.
    func sendComplicationSettings(
        complicationSettings: WatchComplicationUserSettings,
        stepsSettings: WatchStepsSettings
    ) {
        guard canSendToWatch else { return }
        var payload: [String: Any] = ["type": "complication_settings_update"]
        if let settingsData = try? JSONEncoder().encode(complicationSettings) {
            payload["settings_data"] = settingsData
        }
        if let stepsData = try? JSONEncoder().encode(stepsSettings) {
            payload["steps_settings_data"] = stepsData
        }
        try? WCSession.default.updateApplicationContext(payload)
    }

    /// Force a complication refresh on the watch. Call this when plan data changes
    /// but no other payload is needed.
    func sendComplicationRefresh() {
        guard canSendToWatch else { return }
        WCSession.default.transferUserInfo([
            "type": "reload_complications"
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
