////
////  WidgetDataBridge.swift
////  ExtendWidget
////
////  Read-only side: the widget reads the snapshot written by the main app.
////

import Foundation

private let appGroupID = "group.com.cavanmannenbach.extend"
private let snapshotKey = "widget_plan_snapshot"

/// A single displayable item in today's plan.
public struct WidgetPlanItem: Codable {
    public let name: String
    public let icon: String   // SF Symbol name
}

/// The full snapshot written by the main app and read by the widget.
public struct WidgetPlanSnapshot: Codable {
    public let planName: String?
    public let date: Date
    public let items: [WidgetPlanItem]
    public let isRestDay: Bool
}

// MARK: - Reading

public func readWidgetSnapshot() -> WidgetPlanSnapshot {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: snapshotKey),
       let decoded = try? JSONDecoder().decode(WidgetPlanSnapshot.self, from: data) {
        return decoded
    }
    return WidgetPlanSnapshot(planName: nil, date: Date(), items: [], isRestDay: true)
}
