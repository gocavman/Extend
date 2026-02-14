////
////  Workout.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

public struct Workout: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var notes: String
    public var exercises: [WorkoutExercise]

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        exercises: [WorkoutExercise] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.exercises = exercises
    }
}

public struct WorkoutExercise: Identifiable, Codable {
    public let id: UUID
    public var exerciseID: UUID

    public init(id: UUID = UUID(), exerciseID: UUID) {
        self.id = id
        self.exerciseID = exerciseID
    }
}
