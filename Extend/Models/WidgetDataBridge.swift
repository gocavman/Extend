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
private let todayLogCountKey = "today_log_count"
private let todayLogCountDateKey = "today_log_count_date"

/// Writes the number of activities the user has logged today into the App
/// Group so the Watch's Library complication can show "Extend — N done"
/// without needing to decode the full log graph from the widget extension.
/// `date` is stored alongside so a stale yesterday count zero's itself out
/// after midnight even if no refresh fires on the new day.
public func writeTodayLogCount(_ count: Int) {
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    defaults.set(count, forKey: todayLogCountKey)
    defaults.set(Calendar.current.startOfDay(for: Date()), forKey: todayLogCountDateKey)
}

/// A single displayable item in today's plan.
public struct WidgetPlanItem: Codable {
    public let name: String
    public let icon: String   // SF Symbol name
    public let isCompleted: Bool
    /// HKWorkoutActivityType raw value the watch should use when starting a
    /// live HKWorkoutSession from this item. nil → .other.
    public let hkActivityTypeRaw: UInt?
    /// Name to use when the Watch creates a WorkoutLog after finishing this
    /// item. Distinct from `name` because completion-matching on iPhone uses
    /// prefixed strings for voice trainers / timers ("Trainer – Foo",
    /// "Tabata – 5×30"). When nil the receiver falls back to `name`.
    public let logName: String?
    /// "workout" | "exercise" | "voice" | "timer". nil for older snapshots.
    public let kind: String?
    /// UUID string of the underlying object. Lets the watch resolve a workout
    /// blueprint by ID without walking the icon string.
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

// MARK: - Watch Library

private let watchLibraryKey = "watch_library"

/// A startable item the Watch can launch as a live HKWorkoutSession without
/// the iPhone having to be involved. Flat enough that the Watch doesn't need
/// to know about the full Workout / Exercise / TimerConfig / VoiceTrainerConfig
/// models — iPhone projects these every time the relevant collections change.
public struct WatchLibraryItem: Codable, Identifiable, Hashable {
    public let id: String       // stringified UUID — unique across kinds
    public let kind: String     // "workout" | "exercise" | "timer" | "voice"
    public let name: String
    public let icon: String     // SF Symbol
    public let hkActivityTypeRaw: UInt?
    /// Name to use when the Watch creates a WorkoutLog after finishing.
    /// Mirrors the convention in WidgetPlanItem so completion-matching on the
    /// iPhone works regardless of which device started the session.
    public let logName: String
    /// User-favorited on the iPhone. Drives the Watch Library's Favorites tile.
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
    /// string. The Watch picks this up when the user taps a workout so it can
    /// guide the user through each exercise + set without needing to decode
    /// the full Workout model graph (loops, complexes, rests, etc.).
    /// Empty for libraries pushed by older iPhones.
    public let workoutBlueprints: [String: WatchWorkoutBlueprint]
    /// Most-recently-started library items, newest first, deduped. iPhone
    /// projects this from WorkoutLogState.logs so the Watch's "Recents" tile
    /// reflects activity across both devices.
    public let recents: [WatchLibraryItem]
    /// Voice trainer playback configs, keyed by the trainer's UUID string.
    /// When the Watch starts a voice trainer it looks the config up here so
    /// the wrist-side runner can speak lines, run round/rest timers, and
    /// apply start/rest warnings without round-tripping to the iPhone.
    public let voiceConfigs: [String: WatchVoiceTrainerConfig]

    public init(workouts: [WatchLibraryItem] = [],
                exercises: [WatchLibraryItem] = [],
                timers: [WatchLibraryItem] = [],
                voiceTrainers: [WatchLibraryItem] = [],
                workoutBlueprints: [String: WatchWorkoutBlueprint] = [:],
                recents: [WatchLibraryItem] = [],
                voiceConfigs: [String: WatchVoiceTrainerConfig] = [:]) {
        self.workouts = workouts
        self.exercises = exercises
        self.timers = timers
        self.voiceTrainers = voiceTrainers
        self.workoutBlueprints = workoutBlueprints
        self.recents = recents
        self.voiceConfigs = voiceConfigs
    }

    private enum CodingKeys: String, CodingKey {
        case workouts, exercises, timers, voiceTrainers, workoutBlueprints, recents, voiceConfigs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workouts = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .workouts)) ?? []
        exercises = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .exercises)) ?? []
        timers = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .timers)) ?? []
        voiceTrainers = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .voiceTrainers)) ?? []
        workoutBlueprints = (try? c.decodeIfPresent([String: WatchWorkoutBlueprint].self, forKey: .workoutBlueprints)) ?? [:]
        recents = (try? c.decodeIfPresent([WatchLibraryItem].self, forKey: .recents)) ?? []
        voiceConfigs = (try? c.decodeIfPresent([String: WatchVoiceTrainerConfig].self, forKey: .voiceConfigs)) ?? [:]
    }

    public static let empty = WatchLibrarySnapshot()
}

/// Watch-friendly projection of a VoiceTrainerConfig — just the fields the
/// wrist-side playback engine needs. Lines are pre-split off the raw text on
/// the iPhone so the watch doesn't need to redo it every round.
public struct WatchVoiceTrainerConfig: Codable, Hashable {
    public let id: String
    public let name: String
    /// Per-line strings, already trimmed and with empty lines removed.
    public let lines: [String]
    public let roundLength: Int
    public let restLength: Int
    public let delayBetweenLines: Int
    public let numberOfRounds: Int
    public let randomOrder: Bool
    /// 1-30 seconds. 0 → no pre-workout countdown.
    public let workoutStartWarning: Int
    /// 1-30 seconds. 0 → no rest-end countdown.
    public let restEndWarning: Int

    public init(id: String, name: String, lines: [String],
                roundLength: Int, restLength: Int, delayBetweenLines: Int,
                numberOfRounds: Int, randomOrder: Bool,
                workoutStartWarning: Int, restEndWarning: Int) {
        self.id = id
        self.name = name
        self.lines = lines
        self.roundLength = roundLength
        self.restLength = restLength
        self.delayBetweenLines = delayBetweenLines
        self.numberOfRounds = numberOfRounds
        self.randomOrder = randomOrder
        self.workoutStartWarning = workoutStartWarning
        self.restEndWarning = restEndWarning
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, lines, roundLength, restLength, delayBetweenLines,
             numberOfRounds, randomOrder, workoutStartWarning, restEndWarning
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        lines = (try? c.decodeIfPresent([String].self, forKey: .lines)) ?? []
        roundLength = (try? c.decodeIfPresent(Int.self, forKey: .roundLength)) ?? 60
        restLength = (try? c.decodeIfPresent(Int.self, forKey: .restLength)) ?? 0
        delayBetweenLines = (try? c.decodeIfPresent(Int.self, forKey: .delayBetweenLines)) ?? 0
        numberOfRounds = (try? c.decodeIfPresent(Int.self, forKey: .numberOfRounds)) ?? 1
        randomOrder = (try? c.decodeIfPresent(Bool.self, forKey: .randomOrder)) ?? false
        workoutStartWarning = (try? c.decodeIfPresent(Int.self, forKey: .workoutStartWarning)) ?? 0
        restEndWarning = (try? c.decodeIfPresent(Int.self, forKey: .restEndWarning)) ?? 0
    }
}

/// Watch-friendly projection of a Workout — flat list of items the runner
/// walks one at a time. Each item is either a single exercise (the runner
/// logs sets one-by-one) or a complex round group (the runner shows all
/// participating exercises on one screen with a shared countdown that
/// auto-advances rounds).
///
/// `exercises` is preserved as the legacy field so older Watch builds (which
/// only know how to walk a flat exercise list) keep working. New runners walk
/// `items` when present, and `exercises` is filled with only the per-exercise
/// items so the legacy decoder still surfaces something sensible.
public struct WatchWorkoutBlueprint: Codable, Hashable {
    public let id: String
    public let name: String
    public let hkActivityTypeRaw: UInt?
    public let exercises: [WatchBlueprintExercise]
    public let items: [WatchBlueprintItem]

    public init(id: String, name: String, hkActivityTypeRaw: UInt?,
                exercises: [WatchBlueprintExercise],
                items: [WatchBlueprintItem]? = nil) {
        self.id = id
        self.name = name
        self.hkActivityTypeRaw = hkActivityTypeRaw
        self.exercises = exercises
        // When the caller hands us nothing item-shaped, default to one item
        // per exercise so any code reading `items` sees the same sequence.
        self.items = items ?? exercises.map { .exercise($0) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, hkActivityTypeRaw, exercises, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        hkActivityTypeRaw = try? c.decodeIfPresent(UInt.self, forKey: .hkActivityTypeRaw)
        exercises = (try? c.decodeIfPresent([WatchBlueprintExercise].self, forKey: .exercises)) ?? []
        // Older snapshots (no `items` field) → synthesize one item per exercise
        // so the new runner code can still walk them as a flat list.
        if let decoded = try? c.decodeIfPresent([WatchBlueprintItem].self, forKey: .items) ?? nil {
            items = decoded
        } else {
            items = exercises.map { .exercise($0) }
        }
    }
}

/// One step in a workout blueprint — either a single exercise (set-by-set
/// runner) or a complex round group (single-screen, shared timer).
public enum WatchBlueprintItem: Codable, Hashable {
    case exercise(WatchBlueprintExercise)
    case complex(WatchBlueprintComplex)

    private enum CodingKeys: String, CodingKey { case kind, exercise, complex }
    private enum Kind: String, Codable { case exercise, complex }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .exercise:
            self = .exercise(try c.decode(WatchBlueprintExercise.self, forKey: .exercise))
        case .complex:
            self = .complex(try c.decode(WatchBlueprintComplex.self, forKey: .complex))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exercise(let ex):
            try c.encode(Kind.exercise, forKey: .kind)
            try c.encode(ex, forKey: .exercise)
        case .complex(let cx):
            try c.encode(Kind.complex, forKey: .kind)
            try c.encode(cx, forKey: .complex)
        }
    }
}

/// A complex shows all participating exercises simultaneously on one screen
/// with a shared per-round countdown. The runner repeats the same exercise
/// list `rounds` times, and the user can adjust the per-exercise reps/weight
/// at any time during the round; when the countdown expires (or the user
/// advances manually), the runner records one logged set per exercise using
/// the values at that moment, then resets the countdown for the next round.
public struct WatchBlueprintComplex: Codable, Hashable, Identifiable {
    public let id: String
    /// Display name from the parent workout — falls back to a generic label
    /// when the user hasn't named the complex.
    public let name: String
    public let rounds: Int
    public let intervalSeconds: Int
    public let exercises: [WatchBlueprintExercise]

    public init(id: String, name: String, rounds: Int, intervalSeconds: Int,
                exercises: [WatchBlueprintExercise]) {
        self.id = id
        self.name = name
        self.rounds = rounds
        self.intervalSeconds = intervalSeconds
        self.exercises = exercises
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, rounds, intervalSeconds, exercises
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Complex"
        rounds = (try? c.decodeIfPresent(Int.self, forKey: .rounds)) ?? 1
        intervalSeconds = (try? c.decodeIfPresent(Int.self, forKey: .intervalSeconds)) ?? 60
        exercises = (try? c.decodeIfPresent([WatchBlueprintExercise].self, forKey: .exercises)) ?? []
    }
}

public struct WatchBlueprintExercise: Codable, Hashable, Identifiable {
    public let id: String              // WorkoutExercise.id (item ID, unique within a workout)
    public let exerciseID: String      // Exercise.id — used by iPhone to rehydrate LoggedExercise.exerciseID
    public let name: String
    public let icon: String
    public let predefinedSets: [WatchPredefinedSet]
    /// 1-based round number when this entry is one cycle of a loop. nil when
    /// this exercise is standalone. The iPhone pre-expands loops so the watch
    /// just walks a flat list; this field drives the "Round N of M" subtitle.
    public let loopRound: Int?
    public let loopTotalRounds: Int?
    /// 1-based round number when this entry is one cycle of a complex.
    /// Drives the "Round N of M (Complex)" subtitle.
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
    /// Duration (seconds) for a timed set. 0 → not timed (use reps). When > 0
    /// the runner shows a countdown timer instead of a rep stepper.
    public let timedSeconds: Int
    /// Auto-rest after this set, in seconds. Populated by the iPhone from loop
    /// timer modes (Tabata/Interval rest) and from explicit RestItem entries
    /// between exercises. 0 → no automatic rest screen, move straight on.
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

// MARK: - Watch → iPhone logged completion

/// What the watch reports for each exercise when it finishes a workout
/// blueprint. iPhone uses this to rebuild a full WorkoutLog + LoggedExercise
/// graph and call WorkoutLogState.addLog.
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
