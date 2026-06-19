////
////  WidgetDataBridge.swift
////  ExtendWatch
////
////  Watch-side copy of the shared data bridge.
////  The Watch app only reads from the App Group; writing is done by the iPhone app.
////  This file omits WidgetKit-only APIs and write functions not needed on Watch.
////

import Foundation

private let appGroupID       = "group.com.cavanmannenbach.extend"
private let snapshotKey      = "widget_plan_snapshot"
private let multidayKey      = "widget_plan_multiday"
private let stepsSettingsKey = "watch_steps_settings"
private let waterTodayOzKey  = "water_today_oz"
private let waterGoalOzKey   = "water_goal_oz"
private let waterUnitKey     = "water_unit"

// MARK: - Plan item models

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

/// The full snapshot written by the main app and read by the Watch.
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

public func readMultiDaySnapshots() -> [WidgetPlanSnapshot] {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: multidayKey),
       let decoded = try? JSONDecoder().decode([WidgetPlanSnapshot].self, from: data) {
        return decoded
    }
    return []
}

// MARK: - Steps / Distance goal settings

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

public func readWatchStepsSettings() -> WatchStepsSettings {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: stepsSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchStepsSettings.self, from: data) {
        return decoded
    }
    return .default
}

public func writeWatchStepsSettings(_ settings: WatchStepsSettings) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(settings) {
        defaults.set(encoded, forKey: stepsSettingsKey)
    }
}

// MARK: - Complication shape settings

private let complicationShapeSettingsKey = "watch_complication_shapes"

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

public func readWatchComplicationShapeSettings() -> WatchComplicationShapeSettings {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: complicationShapeSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchComplicationShapeSettings.self, from: data) {
        return decoded
    }
    return .default
}

public func writeWatchComplicationShapeSettings(_ settings: WatchComplicationShapeSettings) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(settings) {
        defaults.set(encoded, forKey: complicationShapeSettingsKey)
    }
}

// MARK: - Water reading

public func readWaterTodayOz() -> Double {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    guard let stored = defaults.object(forKey: "water_today_date") as? Date,
          Calendar.current.isDate(stored, inSameDayAs: Date()) else { return 0 }
    return defaults.double(forKey: waterTodayOzKey)
}

public func readWaterGoalOz() -> Double {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    let val = defaults.double(forKey: waterGoalOzKey)
    return val > 0 ? val : 64.0
}

public func readWaterUnit() -> String {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    return defaults.string(forKey: waterUnitKey) ?? "oz"
}
