////
////  WorkoutLog.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

/// Represents a completed workout that has been logged
public struct WorkoutLog: Identifiable, Codable, Hashable {
    public let id: UUID
    public var workoutName: String
    public var completedAt: Date
    public var exercises: [LoggedExercise]
    public var restPeriods: [LoggedRest]
    public var notes: String
    public var duration: TimeInterval // in seconds

    public init(
        id: UUID = UUID(),
        workoutName: String,
        completedAt: Date = Date(),
        exercises: [LoggedExercise] = [],
        restPeriods: [LoggedRest] = [],
        notes: String = "",
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.workoutName = workoutName
        self.completedAt = completedAt
        self.exercises = exercises
        self.restPeriods = restPeriods
        self.notes = notes
        self.duration = duration
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workoutName = try c.decode(String.self, forKey: .workoutName)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        exercises = try c.decode([LoggedExercise].self, forKey: .exercises)
        restPeriods = (try? c.decodeIfPresent([LoggedRest].self, forKey: .restPeriods)) ?? []
        notes = try c.decode(String.self, forKey: .notes)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
    }
}

/// Represents a single exercise within a logged workout
public struct LoggedExercise: Identifiable, Codable, Hashable {
    public let id: UUID
    public let exerciseID: UUID
    public var exerciseName: String
    public var sets: [LoggedSet]
    public var notes: String
    /// Seconds the stopwatch ran for this exercise
    public var activeSeconds: Int
    /// Equipment IDs the user indicated they actually used for this exercise session
    public var usedEquipmentIDs: [UUID]

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseName: String,
        sets: [LoggedSet] = [],
        notes: String = "",
        activeSeconds: Int = 0,
        usedEquipmentIDs: [UUID] = []
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
        self.notes = notes
        self.activeSeconds = activeSeconds
        self.usedEquipmentIDs = usedEquipmentIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        exerciseID = try c.decode(UUID.self, forKey: .exerciseID)
        exerciseName = try c.decode(String.self, forKey: .exerciseName)
        sets = try c.decode([LoggedSet].self, forKey: .sets)
        notes = try c.decode(String.self, forKey: .notes)
        activeSeconds = (try? c.decodeIfPresent(Int.self, forKey: .activeSeconds)) ?? 0
        usedEquipmentIDs = (try? c.decodeIfPresent([UUID].self, forKey: .usedEquipmentIDs)) ?? []
    }
}

/// Represents a single set within a logged exercise
public struct LoggedSet: Identifiable, Codable, Hashable {
    public let id: UUID
    public var reps: Int
    public var weight: Double
    /// Seconds elapsed on the per-set timed countdown (0 if not a timed set)
    public var timedSeconds: Int

    public init(id: UUID = UUID(), reps: Int, weight: Double, timedSeconds: Int = 0) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.timedSeconds = timedSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reps = try c.decode(Int.self, forKey: .reps)
        weight = try c.decode(Double.self, forKey: .weight)
        timedSeconds = (try? c.decodeIfPresent(Int.self, forKey: .timedSeconds)) ?? 0
    }
}

/// A rest period that was part of a logged workout
public struct LoggedRest: Identifiable, Codable, Hashable {
    public let id: UUID
    /// The configured rest duration in seconds
    public var configuredDuration: Int
    /// How long the user actually rested (timer value when they moved on)
    public var actualDuration: Int

    public init(id: UUID = UUID(), configuredDuration: Int, actualDuration: Int) {
        self.id = id
        self.configuredDuration = configuredDuration
        self.actualDuration = actualDuration
    }
}
