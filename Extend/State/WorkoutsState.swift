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
    @ObservationIgnored private let favoritesKey = "workouts_favorites"

    public var workouts: [Workout] = []
    public var favoriteWorkoutIDs: Set<UUID> = []

    /// Set by the dashboard to deep-link directly into a specific workout's start screen
    public var pendingLaunchID: UUID? = nil

    private init() {
        loadWorkouts()
        loadFavorites()
    }

    public func toggleFavorite(id: UUID) {
        if favoriteWorkoutIDs.contains(id) {
            favoriteWorkoutIDs.remove(id)
        } else {
            favoriteWorkoutIDs.insert(id)
        }
        saveFavorites()
    }

    public func isFavorite(_ id: UUID) -> Bool {
        favoriteWorkoutIDs.contains(id)
    }

    public var favoriteWorkouts: [Workout] {
        workouts.filter { favoriteWorkoutIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func resetFavorites() {
        favoriteWorkoutIDs = []
        saveFavorites()
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

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(Array(favoriteWorkoutIDs)) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            favoriteWorkoutIDs = Set(decoded)
        }
    }
}
