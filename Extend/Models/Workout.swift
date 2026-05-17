////
////  Workout.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

// MARK: - Predefined Set

/// A single target set defined at the workout-planning level.
/// The set count is the array length; targetReps shows as ghost placeholder text during the workout.
public struct PredefinedSet: Identifiable, Codable {
    public let id: UUID
    public var targetReps: Int   // 0 = no rep hint; used as ghost text

    public init(id: UUID = UUID(), targetReps: Int = 0) {
        self.id = id
        self.targetReps = targetReps
    }
}

// MARK: - Rest Item

/// A rest period row in a workout's item list.
public struct RestItem: Identifiable, Codable {
    public let id: UUID
    public var duration: Int   // seconds

    public init(id: UUID = UUID(), duration: Int = 60) {
        self.id = id
        self.duration = duration
    }

    private enum CodingKeys: String, CodingKey {
        case id, duration
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self, forKey: .id)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration) ?? 60
    }
}

// MARK: - Workout Exercise

/// An exercise entry in a workout, now supporting loop grouping and predefined targets.
public struct WorkoutExercise: Identifiable, Codable {
    public let id: UUID
    public var exerciseID: UUID
    /// Exercises sharing the same non-nil loopID are grouped into a loop (superset/circuit).
    public var loopID: UUID?
    /// Predefined target sets. Empty = no targets. Count = number of set rows pre-created.
    public var predefinedSets: [PredefinedSet]
    /// When true, each set is timed rather than rep-based.
    public var useTimedSet: Bool
    /// Duration in seconds for each timed set (only used when useTimedSet is true).
    public var timedSetDuration: Int

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        loopID: UUID? = nil,
        predefinedSets: [PredefinedSet] = [],
        useTimedSet: Bool = false,
        timedSetDuration: Int = 30
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.loopID = loopID
        self.predefinedSets = predefinedSets
        self.useTimedSet = useTimedSet
        self.timedSetDuration = timedSetDuration
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseID, loopID, predefinedSets, useTimedSet, timedSetDuration
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(UUID.self, forKey: .id)
        exerciseID        = try c.decode(UUID.self, forKey: .exerciseID)
        loopID            = try c.decodeIfPresent(UUID.self, forKey: .loopID)
        predefinedSets    = try c.decodeIfPresent([PredefinedSet].self, forKey: .predefinedSets) ?? []
        useTimedSet       = try c.decodeIfPresent(Bool.self, forKey: .useTimedSet) ?? false
        timedSetDuration  = try c.decodeIfPresent(Int.self, forKey: .timedSetDuration) ?? 30
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
        case .rest(let r): return r.id
        }
    }

    private enum ItemType: String, Codable {
        case exercise, rest
    }

    private enum CodingKeys: String, CodingKey {
        case type, exercise, rest
    }

    public init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ItemType.self, forKey: .type)
        switch type {
        case .exercise:
            let ex = try c.decode(WorkoutExercise.self, forKey: .exercise)
            self = .exercise(ex)
        case .rest:
            let r = try c.decode(RestItem.self, forKey: .rest)
            self = .rest(r)
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

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        items: [WorkoutItem] = [],
        isFavorite: Bool = false
    ) {
        self.id         = id
        self.name       = name
        self.notes      = notes
        self.items      = items
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, items, isFavorite
        case exercises  // legacy key from old model
    }

    public init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self, forKey: .id)
        name       = try c.decode(String.self, forKey: .name)
        notes      = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false

        if let newItems = try c.decodeIfPresent([WorkoutItem].self, forKey: .items) {
            items = newItems
        } else {
            let legacy = try c.decodeIfPresent([WorkoutExercise].self, forKey: .exercises) ?? []
            items = legacy.map { WorkoutItem.exercise($0) }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,         forKey: .id)
        try c.encode(name,       forKey: .name)
        try c.encode(notes,      forKey: .notes)
        try c.encode(items,      forKey: .items)
        try c.encode(isFavorite, forKey: .isFavorite)
    }

    // MARK: Convenience helpers

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
