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

/// Which health metric(s) the Watch steps complication shows.
public enum WatchStepsMode: String, Codable, CaseIterable {
    case stepsOnly    = "steps"
    case distanceOnly = "distance"
    case both         = "both"

    public var displayName: String {
        switch self {
        case .stepsOnly:    return "Steps"
        case .distanceOnly: return "Distance"
        case .both:         return "Steps & Distance"
        }
    }
}

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

/// User-editable goal settings for the Watch steps/distance complication.
public struct WatchStepsSettings: Codable {
    public var mode: WatchStepsMode
    public var stepsGoal: Double
    public var distanceGoal: Double
    public var distanceUnit: WatchDistanceUnit

    public static let `default` = WatchStepsSettings(
        mode: .stepsOnly,
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
