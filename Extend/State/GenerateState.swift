////
////  GenerateState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation

@Observable
public final class GenerateState {
    public static let shared = GenerateState()

    public var minExercises: Int = 5
    public var maxExercises: Int = 5
    public var selectedEquipmentIDs: Set<UUID> = []
    public var selectedMuscleGroupIDs: Set<UUID> = []
    public var generatedExercises: [GeneratedExerciseItem] = []

    private init() {}

    /// Generates a balanced workout with three phases: diversity, randomness, and shuffle
    public func generateWorkout(
        from exercises: [Exercise],
        equipment: [Equipment],
        muscleGroups: [MuscleGroup]
    ) {
        generatedExercises = []

        // Filter exercises based on selected criteria
        let filtered = filterExercises(exercises)

        guard !filtered.isEmpty else { return }

        let targetCount = minExercises == maxExercises ? minExercises : Int.random(in: minExercises...maxExercises)
        var selected: [Exercise] = []

        // Phase 1: Diversity - Ensure representation of each selected filter
        selected = ensureDiversity(
            from: filtered,
            targetCount: targetCount,
            selectedEquipmentIDs: selectedEquipmentIDs,
            selectedMuscleGroupIDs: selectedMuscleGroupIDs
        )

        // Phase 2: Randomness - Fill remaining slots with random exercises
        if selected.count < targetCount {
            selected = fillWithRandomness(
                selected: selected,
                targetCount: targetCount,
                from: filtered
            )
        }

        // Phase 3: Final Shuffle - Randomly reorder for variety
        selected.shuffle()

        // Convert to GeneratedExerciseItem
        generatedExercises = selected.map { GeneratedExerciseItem(exercise: $0) }
    }

    public func cloneGeneratedExercise(at index: Int) {
        guard index < generatedExercises.count else { return }
        let original = generatedExercises[index]
        // Create a new GeneratedExerciseItem with new UUID (not a copy of the original)
        let cloned = GeneratedExerciseItem(exercise: original.exercise)
        generatedExercises.insert(cloned, at: index + 1)
    }

    public func removeGeneratedExercise(at index: Int) {
        guard index < generatedExercises.count else { return }
        generatedExercises.remove(at: index)
    }

    public func resetGenerated() {
        generatedExercises = []
    }

    public func saveAsWorkout(
        name: String,
        notes: String = "",
        to workoutsState: WorkoutsState
    ) {
        let workout = Workout(
            name: name,
            notes: notes,
            exercises: generatedExercises.map { WorkoutExercise(exerciseID: $0.exercise.id) }
        )
        workoutsState.addWorkout(workout)
        generatedExercises = []
    }

    // MARK: - Private Methods

    private func filterExercises(_ exercises: [Exercise]) -> [Exercise] {
        // If no filters selected, return all exercises
        if selectedEquipmentIDs.isEmpty && selectedMuscleGroupIDs.isEmpty {
            return exercises
        }

        return exercises.filter { exercise in
            let hasMatchingEquipment = selectedEquipmentIDs.isEmpty ||
                !Set(exercise.equipmentIDs).intersection(selectedEquipmentIDs).isEmpty

            let hasMatchingMuscle = selectedMuscleGroupIDs.isEmpty ||
                !Set(exercise.primaryMuscleGroupIDs).intersection(selectedMuscleGroupIDs).isEmpty ||
                !Set(exercise.secondaryMuscleGroupIDs).intersection(selectedMuscleGroupIDs).isEmpty

            return hasMatchingEquipment && hasMatchingMuscle
        }
    }

    private func ensureDiversity(
        from exercises: [Exercise],
        targetCount: Int,
        selectedEquipmentIDs: Set<UUID>,
        selectedMuscleGroupIDs: Set<UUID>
    ) -> [Exercise] {
        var selected: [Exercise] = []
        var usedExerciseIDs: Set<UUID> = []

        // Ensure at least one exercise per selected equipment
        for equipmentID in selectedEquipmentIDs {
            if let exercise = exercises.first(where: { $0.equipmentIDs.contains(equipmentID) && !usedExerciseIDs.contains($0.id) }) {
                selected.append(exercise)
                usedExerciseIDs.insert(exercise.id)
                if selected.count >= targetCount { return selected }
            }
        }

        // Ensure at least one exercise per selected muscle group
        for muscleID in selectedMuscleGroupIDs {
            if let exercise = exercises.first(where: {
                ($0.primaryMuscleGroupIDs.contains(muscleID) || $0.secondaryMuscleGroupIDs.contains(muscleID)) &&
                    !usedExerciseIDs.contains($0.id)
            }) {
                selected.append(exercise)
                usedExerciseIDs.insert(exercise.id)
                if selected.count >= targetCount { return selected }
            }
        }

        return selected
    }

    private func fillWithRandomness(
        selected: [Exercise],
        targetCount: Int,
        from exercises: [Exercise]
    ) -> [Exercise] {
        var result = selected
        let usedIDs = Set(result.map { $0.id })
        let available = exercises.filter { !usedIDs.contains($0.id) }

        while result.count < targetCount && !available.isEmpty {
            if let random = available.randomElement(),
               !result.contains(where: { $0.id == random.id }) {
                result.append(random)
            } else {
                break
            }
        }

        return result
    }
}

/// Wrapper for generated exercises with unique ID for list identification
public struct GeneratedExerciseItem: Identifiable {
    public let id: UUID = UUID()
    public let exercise: Exercise

    public init(exercise: Exercise) {
        self.exercise = exercise
    }
}
