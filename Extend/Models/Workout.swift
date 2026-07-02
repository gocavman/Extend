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
    case tabata(workSeconds: Int = 20, restSeconds: Int = 10)
    case emom(intervalSeconds: Int = 60)

    private enum CodingKeys: String, CodingKey { case type, workSeconds, restSeconds, intervalSeconds }
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
        case .tabata:
            let w = try c.decodeIfPresent(Int.self, forKey: .workSeconds) ?? 20
            let r = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 10
            self = .tabata(workSeconds: w, restSeconds: r)
        case .emom:
            let i = try c.decodeIfPresent(Int.self, forKey: .intervalSeconds) ?? 60
            self = .emom(intervalSeconds: i)
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
        case .tabata(let w, let r):
            try c.encode(TypeKey.tabata, forKey: .type)
            try c.encode(w, forKey: .workSeconds)
            try c.encode(r, forKey: .restSeconds)
        case .emom(let i):
            try c.encode(TypeKey.emom, forKey: .type)
            try c.encode(i, forKey: .intervalSeconds)
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
        case .tabata(let w, _):          return w
        case .emom(let i):               return i
        }
    }

    /// Rest duration in seconds.
    public var restSeconds: Int {
        switch self {
        case .none:                      return 0
        case .interval(_, let r):        return r
        case .tabata(_, let r):          return r
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
    /// Timer mode for this loop. nil = no timer (same as .none).
    public var timerMode: WorkoutTimerMode?
    /// When true, a spoken 3-2-1 countdown plays on the last 3 seconds of each timed phase.
    public var roundCountdown: Bool

    public init(id: UUID = UUID(), rounds: Int = 1, timerMode: WorkoutTimerMode? = nil, roundCountdown: Bool = false) {
        self.id             = id
        self.rounds         = rounds
        self.timerMode      = timerMode
        self.roundCountdown = roundCountdown
    }

    private enum CodingKeys: String, CodingKey { case id, rounds, timerMode, roundCountdown }

    public init(from decoder: Decoder) throws {
        let c          = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self, forKey: .id)
        rounds         = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 1
        timerMode      = try c.decodeIfPresent(WorkoutTimerMode.self, forKey: .timerMode)
        roundCountdown = try c.decodeIfPresent(Bool.self, forKey: .roundCountdown) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(rounds, forKey: .rounds)
        try c.encodeIfPresent(timerMode, forKey: .timerMode)
        try c.encode(roundCountdown, forKey: .roundCountdown)
    }
}

// MARK: - Workout Complex

/// First-class model for a complex group. Keyed by the same UUID used on WorkoutExercise.complexID.
/// A complex shows all exercises simultaneously on one screen with a shared countdown timer per round.
public struct WorkoutComplex: Identifiable, Codable {
    public var id: UUID
    /// How many rounds to complete through the entire complex.
    public var rounds: Int
    /// Shared countdown duration in seconds per round (e.g. 45 seconds to perform all exercises).
    public var intervalSeconds: Int
    /// When true, the round advances automatically when the interval countdown reaches zero.
    public var autoAdvance: Bool
    /// When true, a spoken 3-2-1 countdown plays on the last 3 seconds of each round's timer.
    public var roundCountdown: Bool
    /// Whether to display the interval timer as a ring or a horizontal bar.
    public var timerStyle: ComplexTimerStyle

    public init(id: UUID = UUID(), rounds: Int = 5, intervalSeconds: Int = 45, autoAdvance: Bool = false, roundCountdown: Bool = false, timerStyle: ComplexTimerStyle = .ring) {
        self.id              = id
        self.rounds          = rounds
        self.intervalSeconds = intervalSeconds
        self.autoAdvance     = autoAdvance
        self.roundCountdown  = roundCountdown
        self.timerStyle      = timerStyle
    }

    private enum CodingKeys: String, CodingKey { case id, rounds, intervalSeconds, autoAdvance, roundCountdown, timerStyle }

    public init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self, forKey: .id)
        rounds          = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 5
        intervalSeconds = try c.decodeIfPresent(Int.self, forKey: .intervalSeconds) ?? 45
        autoAdvance     = try c.decodeIfPresent(Bool.self, forKey: .autoAdvance) ?? false
        roundCountdown  = try c.decodeIfPresent(Bool.self, forKey: .roundCountdown) ?? false
        timerStyle      = try c.decodeIfPresent(ComplexTimerStyle.self, forKey: .timerStyle) ?? .ring
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,              forKey: .id)
        try c.encode(rounds,          forKey: .rounds)
        try c.encode(intervalSeconds, forKey: .intervalSeconds)
        try c.encode(autoAdvance,     forKey: .autoAdvance)
        try c.encode(roundCountdown,  forKey: .roundCountdown)
        try c.encode(timerStyle,      forKey: .timerStyle)
    }
}

/// Display style for the complex interval timer.
public enum ComplexTimerStyle: String, Codable, CaseIterable {
    case ring
    case bar
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
    /// Target weight in the user's preferred unit. 0 = no target weight.
    public var weight: Double

    public init(id: UUID = UUID(), target: SetTarget = .reps(0), weight: Double = 0) {
        self.id     = id
        self.target = target
        self.weight = weight
    }

    // Legacy migration: old format stored just targetReps as an Int
    private enum CodingKeys: String, CodingKey { case id, target, targetReps, weight }

    public init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        id     = try c.decode(UUID.self, forKey: .id)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 0
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
        if weight > 0 { try c.encode(weight, forKey: .weight) }
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

/// An exercise entry in a workout, supporting loop and complex grouping and predefined targets.
public struct WorkoutExercise: Identifiable, Codable {
    public let id: UUID
    public var exerciseID: UUID
    /// Exercises sharing the same non-nil loopID are grouped into a loop (superset/circuit).
    public var loopID: UUID?
    /// Exercises sharing the same non-nil complexID are grouped into a complex (all shown simultaneously).
    public var complexID: UUID?
    /// Predefined target sets. Empty = no targets. Each set has its own type (reps or timed).
    public var predefinedSets: [PredefinedSet]
    /// Per-workout equipment override. When non-empty, replaces the Exercise model's defaultEquipmentIDs
    /// so different workouts can pre-select different equipment for the same exercise.
    public var defaultEquipmentIDs: [UUID]

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        loopID: UUID? = nil,
        complexID: UUID? = nil,
        predefinedSets: [PredefinedSet] = [],
        defaultEquipmentIDs: [UUID] = []
    ) {
        self.id                   = id
        self.exerciseID           = exerciseID
        self.loopID               = loopID
        self.complexID            = complexID
        self.predefinedSets       = predefinedSets
        self.defaultEquipmentIDs  = defaultEquipmentIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseID, loopID, complexID, predefinedSets, defaultEquipmentIDs
        // Legacy keys — kept for backwards-compatible decoding only
        case useTimedSet, timedSetDuration
    }

    public init(from decoder: Decoder) throws {
        let c                = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self, forKey: .id)
        exerciseID           = try c.decode(UUID.self, forKey: .exerciseID)
        loopID               = try c.decodeIfPresent(UUID.self, forKey: .loopID)
        complexID            = try c.decodeIfPresent(UUID.self, forKey: .complexID)
        defaultEquipmentIDs  = try c.decodeIfPresent([UUID].self, forKey: .defaultEquipmentIDs) ?? []

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
        try c.encodeIfPresent(loopID,    forKey: .loopID)
        try c.encodeIfPresent(complexID, forKey: .complexID)
        try c.encode(predefinedSets, forKey: .predefinedSets)
        if !defaultEquipmentIDs.isEmpty { try c.encode(defaultEquipmentIDs, forKey: .defaultEquipmentIDs) }
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
    /// Loop configuration keyed by loopID. Entries are created when exercises are grouped.
    public var loops: [String: WorkoutLoop]
    /// Complex configuration keyed by complexID. Entries are created when exercises are grouped into a complex.
    public var complexes: [String: WorkoutComplex]
    /// Warmup countdown duration in seconds (0 = no warmup).
    public var warmupSeconds: Int
    /// Cooldown countdown duration in seconds (0 = no cooldown).
    public var cooldownSeconds: Int
    /// When true, the workout notes are shown as a small caption below the timer during the workout.
    public var showNotes: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        items: [WorkoutItem] = [],
        isFavorite: Bool = false,
        healthKitActivityType: UInt? = nil,
        loops: [String: WorkoutLoop] = [:],
        complexes: [String: WorkoutComplex] = [:],
        warmupSeconds: Int = 0,
        cooldownSeconds: Int = 0,
        showNotes: Bool = false
    ) {
        self.id                    = id
        self.name                  = name
        self.notes                 = notes
        self.items                 = items
        self.isFavorite            = isFavorite
        self.healthKitActivityType = healthKitActivityType
        self.loops                 = loops
        self.complexes             = complexes
        self.warmupSeconds         = warmupSeconds
        self.cooldownSeconds       = cooldownSeconds
        self.showNotes             = showNotes
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, items, isFavorite, healthKitActivityType
        case timerMode, autoAdvance, loops, complexes   // timerMode/autoAdvance kept for backward-compatible decoding only
        case warmupSeconds, cooldownSeconds, showNotes
        case exercises  // legacy key from old model
    }

    public init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self, forKey: .id)
        name       = try c.decode(String.self, forKey: .name)
        notes      = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        healthKitActivityType = try c.decodeIfPresent(UInt.self, forKey: .healthKitActivityType)
        // timerMode and autoAdvance are no longer stored; silently ignored on decode
        _ = try c.decodeIfPresent(WorkoutTimerMode.self, forKey: .timerMode)
        _ = try c.decodeIfPresent(Bool.self, forKey: .autoAdvance)
        loops      = try c.decodeIfPresent([String: WorkoutLoop].self, forKey: .loops) ?? [:]
        complexes  = try c.decodeIfPresent([String: WorkoutComplex].self, forKey: .complexes) ?? [:]
        warmupSeconds   = try c.decodeIfPresent(Int.self, forKey: .warmupSeconds) ?? 0
        cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds) ?? 0
        showNotes       = try c.decodeIfPresent(Bool.self, forKey: .showNotes) ?? false

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
        try c.encode(loops,           forKey: .loops)
        try c.encode(complexes,       forKey: .complexes)
        try c.encode(warmupSeconds,   forKey: .warmupSeconds)
        try c.encode(cooldownSeconds, forKey: .cooldownSeconds)
        if showNotes { try c.encode(showNotes, forKey: .showNotes) }
    }

    // MARK: Convenience helpers

    /// Resolves the effective timer mode for a given exercise — always loop-level (None if unset).
    public func effectiveTimerMode(for exercise: WorkoutExercise) -> WorkoutTimerMode {
        if let lid = exercise.loopID,
           let loop = loops[lid.uuidString],
           let loopMode = loop.timerMode {
            return loopMode
        }
        return .none
    }

    /// Looks up a WorkoutLoop by UUID (convenience wrapper over the String-keyed dict).
    public func loop(for id: UUID) -> WorkoutLoop? {
        loops[id.uuidString]
    }

    /// Looks up a WorkoutComplex by UUID (convenience wrapper over the String-keyed dict).
    public func complex(for id: UUID) -> WorkoutComplex? {
        complexes[id.uuidString]
    }

    /// Resolves the WorkoutComplex for a given exercise, if it belongs to one.
    public func complex(for exercise: WorkoutExercise) -> WorkoutComplex? {
        guard let cid = exercise.complexID else { return nil }
        return complexes[cid.uuidString]
    }

    /// All distinct complex IDs in the order they first appear.
    public var orderedComplexIDs: [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for item in items {
            if case .exercise(let e) = item, let cid = e.complexID, !seen.contains(cid) {
                seen.insert(cid)
                result.append(cid)
            }
        }
        return result
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
