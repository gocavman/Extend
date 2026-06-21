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
    /// HKWorkoutActivityType raw value the watch should use when starting a
    /// live HKWorkoutSession from this item. nil → .other.
    public let hkActivityTypeRaw: UInt?
    /// Name to use when creating a WorkoutLog after finishing this item.
    /// Distinct from `name` because iPhone completion-matching uses prefixes
    /// for voice trainers / timers. nil → fall back to `name`.
    public let logName: String?
    /// "workout" | "exercise" | "voice" | "timer". nil for older snapshots.
    public let kind: String?
    /// UUID string of the underlying object. Lets the watch resolve a workout
    /// blueprint by ID.
    public let sourceID: String?

    public init(name: String,
                icon: String,
                isCompleted: Bool = false,
                hkActivityTypeRaw: UInt? = nil,
                logName: String? = nil,
                kind: String? = nil,
                sourceID: String? = nil) {
        self.name = name
        self.icon = icon
        self.isCompleted = isCompleted
        self.hkActivityTypeRaw = hkActivityTypeRaw
        self.logName = logName
        self.kind = kind
        self.sourceID = sourceID
    }

    private enum CodingKeys: String, CodingKey {
        case name, icon, isCompleted, hkActivityTypeRaw, logName, kind, sourceID
    }

    // Tolerate older snapshots written before the new fields existed.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        isCompleted = (try? c.decodeIfPresent(Bool.self, forKey: .isCompleted)) ?? false
        hkActivityTypeRaw = try? c.decodeIfPresent(UInt.self, forKey: .hkActivityTypeRaw)
        logName = try? c.decodeIfPresent(String.self, forKey: .logName)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        sourceID = try? c.decodeIfPresent(String.self, forKey: .sourceID)
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

    public var stepsTextColor: String
    public var distanceTextColor: String
    public var stepsAndDistanceTextColor: String
    public var waterTextColor: String
    public var planTextColor: String

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
        planColor: String = "",
        stepsTextColor: String = "",
        distanceTextColor: String = "",
        stepsAndDistanceTextColor: String = "",
        waterTextColor: String = "",
        planTextColor: String = ""
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
        self.stepsTextColor = stepsTextColor
        self.distanceTextColor = distanceTextColor
        self.stepsAndDistanceTextColor = stepsAndDistanceTextColor
        self.waterTextColor = waterTextColor
        self.planTextColor = planTextColor
    }

    // Custom decode that defaults missing text-color keys to "" so existing
    // user settings (which only have shape colors) keep working.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stepsShape = try c.decodeIfPresent(String.self, forKey: .stepsShape) ?? ""
        distanceShape = try c.decodeIfPresent(String.self, forKey: .distanceShape) ?? ""
        stepsAndDistanceShape = try c.decodeIfPresent(String.self, forKey: .stepsAndDistanceShape) ?? ""
        waterShape = try c.decodeIfPresent(String.self, forKey: .waterShape) ?? ""
        planShape = try c.decodeIfPresent(String.self, forKey: .planShape) ?? ""
        stepsColor = try c.decodeIfPresent(String.self, forKey: .stepsColor) ?? ""
        distanceColor = try c.decodeIfPresent(String.self, forKey: .distanceColor) ?? ""
        stepsAndDistanceColor = try c.decodeIfPresent(String.self, forKey: .stepsAndDistanceColor) ?? ""
        waterColor = try c.decodeIfPresent(String.self, forKey: .waterColor) ?? ""
        planColor = try c.decodeIfPresent(String.self, forKey: .planColor) ?? ""
        stepsTextColor = try c.decodeIfPresent(String.self, forKey: .stepsTextColor) ?? ""
        distanceTextColor = try c.decodeIfPresent(String.self, forKey: .distanceTextColor) ?? ""
        stepsAndDistanceTextColor = try c.decodeIfPresent(String.self, forKey: .stepsAndDistanceTextColor) ?? ""
        waterTextColor = try c.decodeIfPresent(String.self, forKey: .waterTextColor) ?? ""
        planTextColor = try c.decodeIfPresent(String.self, forKey: .planTextColor) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case stepsShape, distanceShape, stepsAndDistanceShape, waterShape, planShape
        case stepsColor, distanceColor, stepsAndDistanceColor, waterColor, planColor
        case stepsTextColor, distanceTextColor, stepsAndDistanceTextColor, waterTextColor, planTextColor
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

// MARK: - Watch page visibility settings

private let pageVisibilityKey = "watch_page_visibility"

/// Which pages to show in the Watch app's main TabView. Settings is always shown
/// (otherwise the user would have no way to re-enable hidden pages).
public struct WatchPageVisibility: Codable, Equatable {
    public var showPlan: Bool
    public var showSteps: Bool
    public var showWater: Bool
    public var showLibrary: Bool

    public init(showPlan: Bool = true, showSteps: Bool = true, showWater: Bool = true, showLibrary: Bool = true) {
        self.showPlan = showPlan
        self.showSteps = showSteps
        self.showWater = showWater
        self.showLibrary = showLibrary
    }

    private enum CodingKeys: String, CodingKey {
        case showPlan, showSteps, showWater, showLibrary
    }

    // Tolerate older settings written before showLibrary existed.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showPlan = (try? c.decodeIfPresent(Bool.self, forKey: .showPlan)) ?? true
        showSteps = (try? c.decodeIfPresent(Bool.self, forKey: .showSteps)) ?? true
        showWater = (try? c.decodeIfPresent(Bool.self, forKey: .showWater)) ?? true
        showLibrary = (try? c.decodeIfPresent(Bool.self, forKey: .showLibrary)) ?? true
    }

    public static let `default` = WatchPageVisibility()
}

public func readWatchPageVisibility() -> WatchPageVisibility {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: pageVisibilityKey),
       let decoded = try? JSONDecoder().decode(WatchPageVisibility.self, from: data) {
        return decoded
    }
    return .default
}

public func writeWatchPageVisibility(_ settings: WatchPageVisibility) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(settings) {
        defaults.set(encoded, forKey: pageVisibilityKey)
    }
}

// MARK: - Watch Library

private let watchLibraryKey = "watch_library"

public struct WatchLibraryItem: Codable, Identifiable, Hashable {
    public let id: String
    public let kind: String
    public let name: String
    public let icon: String
    public let hkActivityTypeRaw: UInt?
    public let logName: String
    /// User-favorited on the iPhone. Drives the Favorites tile in the Watch Library hub.
    public let isFavorite: Bool

    public init(id: String, kind: String, name: String, icon: String,
                hkActivityTypeRaw: UInt? = nil, logName: String,
                isFavorite: Bool = false) {
        self.id = id
        self.kind = kind
        self.name = name
        self.icon = icon
        self.hkActivityTypeRaw = hkActivityTypeRaw
        self.logName = logName
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, icon, hkActivityTypeRaw, logName, isFavorite
    }

    // Tolerate older snapshots written before isFavorite existed.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(String.self, forKey: .kind)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        hkActivityTypeRaw = try? c.decodeIfPresent(UInt.self, forKey: .hkActivityTypeRaw)
        logName = try c.decode(String.self, forKey: .logName)
        isFavorite = (try? c.decodeIfPresent(Bool.self, forKey: .isFavorite)) ?? false
    }
}

public struct WatchLibrarySnapshot: Codable, Hashable {
    public let workouts: [WatchLibraryItem]
    public let exercises: [WatchLibraryItem]
    public let timers: [WatchLibraryItem]
    public let voiceTrainers: [WatchLibraryItem]
    /// Flattened "runner" view of each Workout, keyed by the workout's UUID
    /// string. Empty for libraries pushed by older iPhones.
    public let workoutBlueprints: [String: WatchWorkoutBlueprint]
    /// Most-recently-started library items, newest first, deduped. Projected
    /// from WorkoutLogState on the iPhone.
    public let recents: [WatchLibraryItem]

    public init(workouts: [WatchLibraryItem] = [],
                exercises: [WatchLibraryItem] = [],
                timers: [WatchLibraryItem] = [],
                voiceTrainers: [WatchLibraryItem] = [],
                workoutBlueprints: [String: WatchWorkoutBlueprint] = [:],
                recents: [WatchLibraryItem] = []) {
        self.workouts = workouts
        self.exercises = exercises
        self.timers = timers
        self.voiceTrainers = voiceTrainers
        self.workoutBlueprints = workoutBlueprints
        self.recents = recents
    }

    private enum CodingKeys: String, CodingKey {
        case workouts, exercises, timers, voiceTrainers, workoutBlueprints, recents
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workouts = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .workouts)) ?? []
        exercises = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .exercises)) ?? []
        timers = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .timers)) ?? []
        voiceTrainers = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .voiceTrainers)) ?? []
        workoutBlueprints = (try? c.decodeIfPresent([String: WatchWorkoutBlueprint].self, forKey: .workoutBlueprints)) ?? [:]
        recents = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .recents)) ?? []
    }

    public static let empty = WatchLibrarySnapshot()
}

public struct WatchWorkoutBlueprint: Codable, Hashable {
    public let id: String
    public let name: String
    public let hkActivityTypeRaw: UInt?
    public let exercises: [WatchBlueprintExercise]

    public init(id: String, name: String, hkActivityTypeRaw: UInt?, exercises: [WatchBlueprintExercise]) {
        self.id = id
        self.name = name
        self.hkActivityTypeRaw = hkActivityTypeRaw
        self.exercises = exercises
    }
}

public struct WatchBlueprintExercise: Codable, Hashable, Identifiable {
    public let id: String
    public let exerciseID: String
    public let name: String
    public let icon: String
    public let predefinedSets: [WatchPredefinedSet]
    public let loopRound: Int?
    public let loopTotalRounds: Int?
    public let complexRound: Int?
    public let complexTotalRounds: Int?

    public init(id: String, exerciseID: String, name: String, icon: String,
                predefinedSets: [WatchPredefinedSet],
                loopRound: Int? = nil,
                loopTotalRounds: Int? = nil,
                complexRound: Int? = nil,
                complexTotalRounds: Int? = nil) {
        self.id = id
        self.exerciseID = exerciseID
        self.name = name
        self.icon = icon
        self.predefinedSets = predefinedSets
        self.loopRound = loopRound
        self.loopTotalRounds = loopTotalRounds
        self.complexRound = complexRound
        self.complexTotalRounds = complexTotalRounds
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseID, name, icon, predefinedSets, loopRound, loopTotalRounds, complexRound, complexTotalRounds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        exerciseID = try c.decode(String.self, forKey: .exerciseID)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        predefinedSets = (try? c.decodeIfPresent([WatchPredefinedSet].self, forKey: .predefinedSets)) ?? []
        loopRound = try? c.decodeIfPresent(Int.self, forKey: .loopRound)
        loopTotalRounds = try? c.decodeIfPresent(Int.self, forKey: .loopTotalRounds)
        complexRound = try? c.decodeIfPresent(Int.self, forKey: .complexRound)
        complexTotalRounds = try? c.decodeIfPresent(Int.self, forKey: .complexTotalRounds)
    }
}

public struct WatchPredefinedSet: Codable, Hashable {
    public let reps: Int
    public let weight: Double
    public let timedSeconds: Int
    public let restSecondsAfter: Int

    public init(reps: Int, weight: Double, timedSeconds: Int = 0, restSecondsAfter: Int = 0) {
        self.reps = reps
        self.weight = weight
        self.timedSeconds = timedSeconds
        self.restSecondsAfter = restSecondsAfter
    }

    private enum CodingKeys: String, CodingKey {
        case reps, weight, timedSeconds, restSecondsAfter
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reps = try c.decode(Int.self, forKey: .reps)
        weight = try c.decode(Double.self, forKey: .weight)
        timedSeconds = (try? c.decodeIfPresent(Int.self, forKey: .timedSeconds)) ?? 0
        restSecondsAfter = (try? c.decodeIfPresent(Int.self, forKey: .restSecondsAfter)) ?? 0
    }
}

public struct WatchLoggedExercise: Codable, Hashable {
    public let exerciseID: String
    public let exerciseName: String
    public let activeSeconds: Int
    public let sets: [WatchLoggedSet]

    public init(exerciseID: String, exerciseName: String, activeSeconds: Int, sets: [WatchLoggedSet]) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.activeSeconds = activeSeconds
        self.sets = sets
    }
}

public struct WatchLoggedSet: Codable, Hashable {
    public let reps: Int
    public let weight: Double

    public init(reps: Int, weight: Double) {
        self.reps = reps
        self.weight = weight
    }
}

public func writeWatchLibrarySnapshot(_ snapshot: WatchLibrarySnapshot) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let encoded = try? JSONEncoder().encode(snapshot) {
        defaults.set(encoded, forKey: watchLibraryKey)
    }
}

public func readWatchLibrarySnapshot() -> WatchLibrarySnapshot {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = defaults.data(forKey: watchLibraryKey),
       let decoded = try? JSONDecoder().decode(WatchLibrarySnapshot.self, from: data) {
        return decoded
    }
    return .empty
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
