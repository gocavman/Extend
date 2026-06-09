////
////  WidgetDataBridge.swift
////  Extend
////
////  Shared data model written by the main app into the App Group container
////  so the Today's Plan widget can display current plan items without
////  needing to decode the full model graph.
////

import Foundation
import WidgetKit

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

// MARK: - Writing (main app calls this)

public func writeWidgetSnapshot(
    planName: String?,
    items: [WidgetPlanItem]
) {
    let snapshot = WidgetPlanSnapshot(
        planName: planName,
        date: Calendar.current.startOfDay(for: Date()),
        items: items,
        isRestDay: items.isEmpty
    )
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(snapshot) {
        defaults.set(encoded, forKey: snapshotKey)
    }
    // Tell WidgetKit to reload all timelines
    WidgetCenter.shared.reloadAllTimelines()
}

// MARK: - Reading (widget calls this)

public func readWidgetSnapshot() -> WidgetPlanSnapshot {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: snapshotKey),
       let decoded = try? JSONDecoder().decode(WidgetPlanSnapshot.self, from: data) {
        return decoded
    }
    return WidgetPlanSnapshot(planName: nil, date: Date(), items: [], isRestDay: true)
}
