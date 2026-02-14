////
////  QuickWorkoutState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation

/// State management for Quick Workout favorite exercises
/// Persists favorite exercise selections across app sessions
@Observable
public final class QuickWorkoutState {
    public static let shared = QuickWorkoutState()

    public var favoriteExerciseIDs: Set<UUID> = []

    private let favoritesKey = "quick_workout_favorites"

    private init() {
        loadFavorites()
    }

    // MARK: - Favorite Management

    /// Toggle favorite status for an exercise
    public func toggleFavorite(exerciseID: UUID) {
        if favoriteExerciseIDs.contains(exerciseID) {
            favoriteExerciseIDs.remove(exerciseID)
        } else {
            favoriteExerciseIDs.insert(exerciseID)
        }
        saveFavorites()
    }

    /// Check if an exercise is favorited
    public func isFavorite(_ exerciseID: UUID) -> Bool {
        favoriteExerciseIDs.contains(exerciseID)
    }

    // MARK: - Persistence

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(Array(favoriteExerciseIDs)) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            favoriteExerciseIDs = Set(decoded)
        }
    }

    /// Reset favorites to empty
    public func resetFavorites() {
        favoriteExerciseIDs = []
        saveFavorites()
    }
}
