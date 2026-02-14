////
////  WorkoutsState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Observation
import Foundation

@Observable
public final class WorkoutsState {
    public static let shared = WorkoutsState()

    @ObservationIgnored private let storageKey = "workouts_data"

    public var workouts: [Workout] = []

    private init() {
        loadWorkouts()
    }

    public func addWorkout(_ workout: Workout) {
        workouts.append(workout)
        saveWorkouts()
    }

    public func updateWorkout(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
            saveWorkouts()
        }
    }

    public func removeWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
        saveWorkouts()
    }

    public func cloneWorkout(_ workout: Workout) {
        let cloned = Workout(
            id: UUID(),
            name: "\(workout.name) Copy",
            notes: workout.notes,
            exercises: workout.exercises.map { WorkoutExercise(exerciseID: $0.exerciseID) }
        )
        workouts.append(cloned)
        saveWorkouts()
    }

    public func resetWorkouts() {
        workouts = []
        saveWorkouts()
    }

    private func loadWorkouts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decoded
        }
    }

    private func saveWorkouts() {
        if let encoded = try? JSONEncoder().encode(workouts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
