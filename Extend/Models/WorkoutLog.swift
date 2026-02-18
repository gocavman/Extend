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
    public var notes: String
    public var duration: TimeInterval // in seconds
    
    public init(
        id: UUID = UUID(),
        workoutName: String,
        completedAt: Date = Date(),
        exercises: [LoggedExercise] = [],
        notes: String = "",
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.workoutName = workoutName
        self.completedAt = completedAt
        self.exercises = exercises
        self.notes = notes
        self.duration = duration
    }
}

/// Represents a single exercise within a logged workout
public struct LoggedExercise: Identifiable, Codable, Hashable {
    public let id: UUID
    public let exerciseID: UUID
    public var exerciseName: String
    public var sets: [LoggedSet]
    public var notes: String
    
    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseName: String,
        sets: [LoggedSet] = [],
        notes: String = ""
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
        self.notes = notes
    }
}

/// Represents a single set within a logged exercise
public struct LoggedSet: Identifiable, Codable, Hashable {
    public let id: UUID
    public var reps: Int
    public var weight: Double
    
    public init(id: UUID = UUID(), reps: Int, weight: Double) {
        self.id = id
        self.reps = reps
        self.weight = weight
    }
}
