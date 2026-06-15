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

// MARK: - Complication Appearance Settings

/// Color preset options for Watch face complications.
public enum ComplicationColorPreset: String, Codable, CaseIterable {
    case orange = "orange"
    case blue   = "blue"
    case green  = "green"
    case red    = "red"
    case purple = "purple"
    case yellow = "yellow"
    case cyan   = "cyan"
    case pink   = "pink"
    case mint   = "mint"
    case indigo = "indigo"

    public var displayName: String { rawValue.capitalized }
}

/// Whether a circular complication renders as a gauge ring or a rising shape fill.
public enum ComplicationStyle: String, Codable, CaseIterable {
    case ring = "ring"
    case fill = "fill"
}

/// Appearance settings for a single complication.
public struct ComplicationAppearance: Codable, Equatable {
    public var colorPreset: ComplicationColorPreset
    public var style: ComplicationStyle
    /// SF Symbol name used as the fill mask when style == .fill.
    public var shape: String

    public init(colorPreset: ComplicationColorPreset, style: ComplicationStyle, shape: String) {
        self.colorPreset = colorPreset
        self.style = style
        self.shape = shape
    }

    public static let defaultSteps = ComplicationAppearance(colorPreset: .orange, style: .ring, shape: "circle.fill")
    public static let defaultWater = ComplicationAppearance(colorPreset: .blue,   style: .ring, shape: "circle.fill")
    public static let defaultPlan  = ComplicationAppearance(colorPreset: .blue,   style: .ring, shape: "circle.fill")
}

/// Appearance settings for all five Watch complications.
public struct WatchComplicationUserSettings: Codable, Equatable {
    public var stepsOnly: ComplicationAppearance
    public var distanceOnly: ComplicationAppearance
    public var stepsAndDistance: ComplicationAppearance
    public var water: ComplicationAppearance
    public var plan: ComplicationAppearance

    public init(
        stepsOnly: ComplicationAppearance,
        distanceOnly: ComplicationAppearance,
        stepsAndDistance: ComplicationAppearance,
        water: ComplicationAppearance,
        plan: ComplicationAppearance
    ) {
        self.stepsOnly = stepsOnly
        self.distanceOnly = distanceOnly
        self.stepsAndDistance = stepsAndDistance
        self.water = water
        self.plan = plan
    }

    public static let `default` = WatchComplicationUserSettings(
        stepsOnly:        .defaultSteps,
        distanceOnly:     .defaultSteps,
        stepsAndDistance: .defaultSteps,
        water:            .defaultWater,
        plan:             .defaultPlan
    )
}

private let complicationSettingsKey = "watch_complication_settings"

public func readWatchComplicationSettings() -> WatchComplicationUserSettings {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: complicationSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchComplicationUserSettings.self, from: data) {
        return decoded
    }
    return .default
}

// MARK: - Water reading

public func readWaterTodayOz() -> Double {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
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
