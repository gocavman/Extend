////
////  Workout.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

// MARK: - Workout Timer Mode

/// Specifies how exercises should be timed during a workout or loop.
public enum WorkoutTimerMode: Codable, Equatable {
    case none
    case interval(workSeconds: Int, restSeconds: Int)
    case tabata   // fixed 20s work / 10s rest
    case emom     // fixed 60s per set, no rest

    private enum CodingKeys: String, CodingKey { case type, workSeconds, restSeconds }
    private enum TypeKey: String, Codable { case none, interval, tabata, emom }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(TypeKey.self, forKey: .type)
        switch type {
        case .none:     self = .none
        case .interval:
            let w = try c.decodeIfPresent(Int.self, forKey: .workSeconds) ?? 45
            let r = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 15
            self = .interval(workSeconds: w, restSeconds: r)
        case .tabata:   self = .tabata
        case .emom:     self = .emom
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(TypeKey.none, forKey: .type)
        case .interval(let w, let r):
            try c.encode(TypeKey.interval, forKey: .type)
            try c.encode(w, forKey: .workSeconds)
            try c.encode(r, forKey: .restSeconds)
        case .tabata:
            try c.encode(TypeKey.tabata, forKey: .type)
        case .emom:
            try c.encode(TypeKey.emom, forKey: .type)
        }
    }

    public var displayName: String {
        switch self {
        case .none:     return "None"
        case .interval: return "Interval"
        case .tabata:   return "Tabata"
        case .emom:     return "EMOM"
        }
    }

    /// Work duration in seconds.
    public var workSeconds: Int {
        switch self {
        case .none:                      return 0
        case .interval(let w, _):        return w
        case .tabata:                    return 20
        case .emom:                      return 60
        }
    }

    /// Rest duration in seconds.
    public var restSeconds: Int {
        switch self {
        case .none:                      return 0
        case .interval(_, let r):        return r
        case .tabata:                    return 10
        case .emom:                      return 0
        }
    }
}

// MARK: - Workout Loop

/// First-class model for a loop group. Keyed by the same UUID used on WorkoutExercise.loopID.
public struct WorkoutLoop: Identifiable, Codable {
    public let id: UUID
    /// How many times to cycle through all exercises in this loop.
    public var rounds: Int
    /// nil = inherit from the workout-level timerMode.
    public var timerMode: WorkoutTimerMode?

    public init(id: UUID = UUID(), rounds: Int = 1, timerMode: WorkoutTimerMode? = nil) {
        self.id        = id
        self.rounds    = rounds
        self.timerMode = timerMode
    }

    private enum CodingKeys: String, CodingKey { case id, rounds, timerMode }

    public init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self, forKey: .id)
        rounds     = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 1
        timerMode  = try c.decodeIfPresent(WorkoutTimerMode.self, forKey: .timerMode)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(rounds, forKey: .rounds)
        try c.encodeIfPresent(timerMode, forKey: .timerMode)
    }
}

// MARK: - Set Target

/// The target for a single predefined set — either a rep count or a timed duration.
public enum SetTarget: Codable, Equatable {
    case reps(Int)               // target rep count; 0 = no hint
    case timed(seconds: Int)     // duration in seconds

    private enum CodingKeys: String, CodingKey { case type, value }
    private enum TypeKey: String, Codable { case reps, timed }

    public init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(TypeKey.self, forKey: .type)
        let val  = try c.decodeIfPresent(Int.self, forKey: .value) ?? 0
        switch type {
        case .reps:  self = .reps(val)
        case .timed: self = .timed(seconds: val)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .reps(let n):
            try c.encode(TypeKey.reps, forKey: .type)
            try c.encode(n, forKey: .value)
        case .timed(let s):
            try c.encode(TypeKey.timed, forKey: .type)
            try c.encode(s, forKey: .value)
        }
    }

    /// Human-readable summary string (e.g. "8 reps", "0m 30s").
    public var label: String {
        switch self {
        case .reps(let n):    return n > 0 ? "\(n) reps" : "reps"
        case .timed(let s):
            let m = s / 60; let sec = s % 60
            return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
        }
    }
}

// MARK: - Predefined Set

/// A single target set defined at the workout-planning level.
public struct PredefinedSet: Identifiable, Codable {
    public let id: UUID
    public var target: SetTarget   // .reps(n) or .timed(seconds:)

    public init(id: UUID = UUID(), target: SetTarget = .reps(0)) {
        self.id     = id
        self.target = target
    }

    // Legacy migration: old format stored just targetReps as an Int
    private enum CodingKeys: String, CodingKey { case id, target, targetReps }

    public init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        id     = try c.decode(UUID.self, forKey: .id)
        if let t = try c.decodeIfPresent(SetTarget.self, forKey: .target) {
            target = t
        } else {
            // Migrate from old targetReps-only format
            let reps = try c.decodeIfPresent(Int.self, forKey: .targetReps) ?? 0
            target = .reps(reps)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,     forKey: .id)
        try c.encode(target, forKey: .target)
    }
}

// MARK: - Rest Item

/// A rest period row in a workout's item list.
public struct RestItem: Identifiable, Codable {
    public let id: UUID
    public var duration: Int   // seconds
    /// When non-nil, this rest is part of the named loop and will be visited during loop cycling.
    public var loopID: UUID?

    public init(id: UUID = UUID(), duration: Int = 60, loopID: UUID? = nil) {
        self.id       = id
        self.duration = duration
        self.loopID   = loopID
    }

    private enum CodingKeys: String, CodingKey { case id, duration, loopID }

    public init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self, forKey: .id)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration) ?? 60
        loopID   = try c.decodeIfPresent(UUID.self, forKey: .loopID)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(duration, forKey: .duration)
        try c.encodeIfPresent(loopID, forKey: .loopID)
    }
}

// MARK: - Workout Exercise

/// An exercise entry in a workout, supporting loop grouping and predefined targets.
public struct WorkoutExercise: Identifiable, Codable {
    public let id: UUID
    public var exerciseID: UUID
    /// Exercises sharing the same non-nil loopID are grouped into a loop (superset/circuit).
    public var loopID: UUID?
    /// Predefined target sets. Empty = no targets. Each set has its own type (reps or timed).
    public var predefinedSets: [PredefinedSet]

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        loopID: UUID? = nil,
        predefinedSets: [PredefinedSet] = []
    ) {
        self.id             = id
        self.exerciseID     = exerciseID
        self.loopID         = loopID
        self.predefinedSets = predefinedSets
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseID, loopID, predefinedSets
        // Legacy keys — kept for backwards-compatible decoding only
        case useTimedSet, timedSetDuration
    }

    public init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self, forKey: .id)
        exerciseID      = try c.decode(UUID.self, forKey: .exerciseID)
        loopID          = try c.decodeIfPresent(UUID.self, forKey: .loopID)

        if let sets = try c.decodeIfPresent([PredefinedSet].self, forKey: .predefinedSets) {
            predefinedSets = sets
        } else {
            // Migrate old uniform-timed model to per-set targets
            let wasTimed  = try c.decodeIfPresent(Bool.self, forKey: .useTimedSet) ?? false
            let timedSecs = try c.decodeIfPresent(Int.self, forKey: .timedSetDuration) ?? 30
            predefinedSets = []
            _ = wasTimed   // silence unused warning; migration produces empty sets
            _ = timedSecs
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(exerciseID,     forKey: .exerciseID)
        try c.encode(loopID,         forKey: .loopID)
        try c.encode(predefinedSets, forKey: .predefinedSets)
    }
}

// MARK: - Workout Item

/// A flat ordered item in a workout — either an exercise or a rest period.
public enum WorkoutItem: Identifiable, Codable {
    case exercise(WorkoutExercise)
    case rest(RestItem)

    public var id: UUID {
        switch self {
        case .exercise(let e): return e.id
        case .rest(let r):     return r.id
        }
    }

    private enum ItemType: String, Codable { case exercise, rest }
    private enum CodingKeys: String, CodingKey { case type, exercise, rest }

    public init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ItemType.self, forKey: .type)
        switch type {
        case .exercise:
            self = .exercise(try c.decode(WorkoutExercise.self, forKey: .exercise))
        case .rest:
            self = .rest(try c.decode(RestItem.self, forKey: .rest))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exercise(let ex):
            try c.encode(ItemType.exercise, forKey: .type)
            try c.encode(ex, forKey: .exercise)
        case .rest(let r):
            try c.encode(ItemType.rest, forKey: .type)
            try c.encode(r, forKey: .rest)
        }
    }
}

// MARK: - Workout

public struct Workout: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var notes: String
    /// Ordered flat list of exercises and rest periods.
    public var items: [WorkoutItem]
    public var isFavorite: Bool
    /// Raw value of HKWorkoutActivityType. nil = use .other at export time.
    public var healthKitActivityType: UInt?
    /// Timer mode applied to exercises during this workout.
    public var timerMode: WorkoutTimerMode
    /// When true, automatically advance to the next exercise when the phase timer finishes.
    public var autoAdvance: Bool
    /// Loop configuration keyed by loopID. Entries are created when exercises are grouped.
    public var loops: [String: WorkoutLoop]
    /// Warmup countdown duration in seconds (0 = no warmup).
    public var warmupSeconds: Int
    /// Cooldown countdown duration in seconds (0 = no cooldown).
    public var cooldownSeconds: Int

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        items: [WorkoutItem] = [],
        isFavorite: Bool = false,
        healthKitActivityType: UInt? = nil,
        timerMode: WorkoutTimerMode = .none,
        autoAdvance: Bool = false,
        loops: [String: WorkoutLoop] = [:],
        warmupSeconds: Int = 0,
        cooldownSeconds: Int = 0
    ) {
        self.id                    = id
        self.name                  = name
        self.notes                 = notes
        self.items                 = items
        self.isFavorite            = isFavorite
        self.healthKitActivityType = healthKitActivityType
        self.timerMode             = timerMode
        self.autoAdvance           = autoAdvance
        self.loops                 = loops
        self.warmupSeconds         = warmupSeconds
        self.cooldownSeconds       = cooldownSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, items, isFavorite, healthKitActivityType
        case timerMode, autoAdvance, loops
        case warmupSeconds, cooldownSeconds
        case exercises  // legacy key from old model
    }

    public init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self, forKey: .id)
        name       = try c.decode(String.self, forKey: .name)
        notes      = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        healthKitActivityType = try c.decodeIfPresent(UInt.self, forKey: .healthKitActivityType)
        timerMode  = try c.decodeIfPresent(WorkoutTimerMode.self, forKey: .timerMode) ?? .none
        autoAdvance = try c.decodeIfPresent(Bool.self, forKey: .autoAdvance) ?? false
        loops      = try c.decodeIfPresent([String: WorkoutLoop].self, forKey: .loops) ?? [:]
        warmupSeconds   = try c.decodeIfPresent(Int.self, forKey: .warmupSeconds) ?? 0
        cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds) ?? 0

        if let newItems = try c.decodeIfPresent([WorkoutItem].self, forKey: .items) {
            items = newItems
        } else {
            let legacy = try c.decodeIfPresent([WorkoutExercise].self, forKey: .exercises) ?? []
            items = legacy.map { WorkoutItem.exercise($0) }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,          forKey: .id)
        try c.encode(name,        forKey: .name)
        try c.encode(notes,       forKey: .notes)
        try c.encode(items,       forKey: .items)
        try c.encode(isFavorite,  forKey: .isFavorite)
        try c.encodeIfPresent(healthKitActivityType, forKey: .healthKitActivityType)
        try c.encode(timerMode,       forKey: .timerMode)
        try c.encode(autoAdvance,     forKey: .autoAdvance)
        try c.encode(loops,           forKey: .loops)
        try c.encode(warmupSeconds,   forKey: .warmupSeconds)
        try c.encode(cooldownSeconds, forKey: .cooldownSeconds)
    }

    // MARK: Convenience helpers

    /// Resolves the effective timer mode for a given exercise.
    /// Priority: loop-level timerMode (if non-nil) > workout-level timerMode.
    public func effectiveTimerMode(for exercise: WorkoutExercise) -> WorkoutTimerMode {
        if let lid = exercise.loopID,
           let loop = loops[lid.uuidString],
           let loopMode = loop.timerMode {
            return loopMode
        }
        return timerMode
    }

    /// Looks up a WorkoutLoop by UUID (convenience wrapper over the String-keyed dict).
    public func loop(for id: UUID) -> WorkoutLoop? {
        loops[id.uuidString]
    }

    /// All exercise items in order.
    public var exerciseItems: [WorkoutExercise] {
        items.compactMap {
            if case .exercise(let e) = $0 { return e } else { return nil }
        }
    }

    /// All distinct loop IDs in the order they first appear.
    public var orderedLoopIDs: [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for item in items {
            if case .exercise(let e) = item, let lid = e.loopID, !seen.contains(lid) {
                seen.insert(lid)
                result.append(lid)
            }
        }
        return result
    }
}
