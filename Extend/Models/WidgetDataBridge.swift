////
////  WidgetDataBridge.swift
////  Extend
////
////  Shared data model written by the main app into the App Group container
////  so the Today's Plan widget and Watch app can display current plan items
////  without needing to decode the full model graph.
////

import Foundation
import WidgetKit

private let appGroupID = "group.com.cavanmannenbach.extend"
private let snapshotKey = "widget_plan_snapshot"
private let multidayKey = "widget_plan_multiday"
private let stepsSettingsKey = "watch_steps_settings"
private let waterTodayOzKey = "water_today_oz"
private let waterGoalOzKey = "water_goal_oz"
private let waterUnitKey = "water_unit"

/// A single displayable item in today's plan.
public struct WidgetPlanItem: Codable {
    public let name: String
    public let icon: String   // SF Symbol name
    public let isCompleted: Bool

    public init(name: String, icon: String, isCompleted: Bool = false) {
        self.name = name
        self.icon = icon
        self.isCompleted = isCompleted
    }
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
    // Tell WidgetKit to reload local (iOS) widget timelines. The Watch is updated
    // separately by writeMultiDaySnapshots() / sendPlanUpdate() with real data —
    // sending a parallel no-data refresh here just burns the complication budget
    // before the actual data arrives.
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

// MARK: - Multi-day snapshots (Watch app day browsing)

/// Writes a window of plan snapshots (±7 days) so the Watch app can browse days.
public func writeMultiDaySnapshots(_ snapshots: [WidgetPlanSnapshot]) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(snapshots) {
        defaults.set(encoded, forKey: multidayKey)
    }
}

/// Reads the multi-day plan snapshots. Returns an empty array if not yet written.
public func readMultiDaySnapshots() -> [WidgetPlanSnapshot] {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: multidayKey),
       let decoded = try? JSONDecoder().decode([WidgetPlanSnapshot].self, from: data) {
        return decoded
    }
    return []
}

// MARK: - Steps / Distance goal settings (Watch complications)

/// Whether distances are shown in kilometres or miles.
public enum WatchDistanceUnit: String, Codable, CaseIterable {
    case km    = "km"
    case miles = "mi"

    public var displayName: String {
        switch self {
        case .km:    return "Kilometres (km)"
        case .miles: return "Miles (mi)"
        }
    }
}

/// User-editable goal settings for the Watch steps/distance complications.
public struct WatchStepsSettings: Codable {
    /// Daily step goal used by the Steps and Steps & Distance complications.
    public var stepsGoal: Double
    /// Daily distance goal in the chosen unit used by the Distance and Steps & Distance complications.
    public var distanceGoal: Double
    /// Distance unit preference.
    public var distanceUnit: WatchDistanceUnit

    public static let `default` = WatchStepsSettings(
        stepsGoal: 10_000,
        distanceGoal: 8.0,
        distanceUnit: .km
    )
}

public func writeWatchStepsSettings(_ settings: WatchStepsSettings) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(settings) {
        defaults.set(encoded, forKey: stepsSettingsKey)
    }
    WidgetCenter.shared.reloadAllTimelines()
    // Settings are now managed directly on the Watch via WatchSettingsView.
    // No WatchConnectivity sync needed since both devices write to the same App Group.
}

public func readWatchStepsSettings() -> WatchStepsSettings {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: stepsSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchStepsSettings.self, from: data) {
        return decoded
    }
    return .default
}

// MARK: - Complication Appearance Settings (Simplified)
//
// Complications now use .widgetAccentable() to automatically adapt to the watch face COLOR.
// Users can still choose SHAPES for filled complications, but colors are handled by watchOS.
// This prevents white-on-white text issues and improves compatibility with different watch faces.

/// Shape + color preferences for Watch face complications.
/// Shape: empty string = ring, otherwise SF Symbol name.
/// Color: empty string = watch-face accent (default), otherwise one of the named presets.
public struct WatchComplicationShapeSettings: Codable, Equatable {
    public var stepsShape: String
    public var distanceShape: String
    public var stepsAndDistanceShape: String
    public var waterShape: String
    public var planShape: String

    public var stepsColor: String
    public var distanceColor: String
    public var stepsAndDistanceColor: String
    public var waterColor: String
    public var planColor: String

    public init(
        stepsShape: String = "",
        distanceShape: String = "",
        stepsAndDistanceShape: String = "",
        waterShape: String = "",
        planShape: String = "",
        stepsColor: String = "",
        distanceColor: String = "",
        stepsAndDistanceColor: String = "",
        waterColor: String = "",
        planColor: String = ""
    ) {
        self.stepsShape = stepsShape
        self.distanceShape = distanceShape
        self.stepsAndDistanceShape = stepsAndDistanceShape
        self.waterShape = waterShape
        self.planShape = planShape
        self.stepsColor = stepsColor
        self.distanceColor = distanceColor
        self.stepsAndDistanceColor = stepsAndDistanceColor
        self.waterColor = waterColor
        self.planColor = planColor
    }

    public static let `default` = WatchComplicationShapeSettings()
}

private let complicationShapeSettingsKey = "watch_complication_shapes"

public func writeWatchComplicationShapeSettings(_ settings: WatchComplicationShapeSettings) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(settings) {
        defaults.set(encoded, forKey: complicationShapeSettingsKey)
    }
    WidgetCenter.shared.reloadAllTimelines()
}

public func readWatchComplicationShapeSettings() -> WatchComplicationShapeSettings {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: complicationShapeSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchComplicationShapeSettings.self, from: data) {
        return decoded
    }
    return .default
}

// MARK: - Water data (widget + watch reads)

/// Reads today's total water intake in oz from the App Group container.
/// Returns 0 if the stored value is stale (last written before today's local midnight).
public func readWaterTodayOz() -> Double {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    guard let stored = defaults.object(forKey: "water_today_date") as? Date,
          Calendar.current.isDate(stored, inSameDayAs: Date()) else { return 0 }
    return defaults.double(forKey: waterTodayOzKey)
}

/// Reads the user's daily water goal in oz from the App Group container.
public func readWaterGoalOz() -> Double {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    let val = defaults.double(forKey: waterGoalOzKey)
    return val > 0 ? val : 64.0
}

/// Reads the preferred water unit string ("oz" or "mL") from the App Group container.
public func readWaterUnit() -> String {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    return defaults.string(forKey: waterUnitKey) ?? "oz"
}
