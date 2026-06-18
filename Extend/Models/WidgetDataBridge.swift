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
    // Tell WidgetKit to reload all timelines (iOS widgets + watchOS complications)
    WidgetCenter.shared.reloadAllTimelines()
    #if os(iOS)
    // Force the Watch to update by sending a WatchConnectivity message
    WatchConnectivityReceiver.shared.sendComplicationRefresh()
    #endif
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
    #if os(iOS)
    // The App Group is per-device, so the watch needs an explicit copy.
    WatchConnectivityReceiver.shared.sendComplicationSettings(
        complicationSettings: readWatchComplicationSettings(),
        stepsSettings: settings
    )
    #endif
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

public func writeWatchComplicationSettings(_ settings: WatchComplicationUserSettings) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(settings) {
        defaults.set(encoded, forKey: complicationSettingsKey)
    }
    WidgetCenter.shared.reloadAllTimelines()
    #if os(iOS)
    // The App Group is per-device, so the watch needs an explicit copy of the
    // appearance settings (the previous refresh-only ping did nothing).
    WatchConnectivityReceiver.shared.sendComplicationSettings(
        complicationSettings: settings,
        stepsSettings: readWatchStepsSettings()
    )
    #endif
}

public func readWatchComplicationSettings() -> WatchComplicationUserSettings {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: complicationSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchComplicationUserSettings.self, from: data) {
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
