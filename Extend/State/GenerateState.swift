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
    public var filterPresets: [GenerateFilterPreset] = []

    @ObservationIgnored private let presetsKey = "generate_filter_presets"

    private init() {
        loadPresets()
    }

    // MARK: - Presets

    public func addFilterPreset(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let preset = GenerateFilterPreset(
            name: trimmedName,
            equipmentIDs: Array(selectedEquipmentIDs),
            muscleGroupIDs: Array(selectedMuscleGroupIDs),
            minExercises: minExercises,
            maxExercises: maxExercises
        )
        filterPresets.append(preset)
        savePresets()
    }

    public func applyFilterPreset(_ preset: GenerateFilterPreset) {
        selectedEquipmentIDs = Set(preset.equipmentIDs)
        selectedMuscleGroupIDs = Set(preset.muscleGroupIDs)
        
        // Ensure min/max are valid (min should not be greater than max)
        if preset.minExercises <= preset.maxExercises {
            minExercises = preset.minExercises
            maxExercises = preset.maxExercises
        } else {
            // If preset has invalid values, swap them
            minExercises = min(preset.minExercises, preset.maxExercises)
            maxExercises = max(preset.minExercises, preset.maxExercises)
        }
    }

    public func removeFilterPreset(id: UUID) {
        filterPresets.removeAll { $0.id == id }
        savePresets()
    }

    public func updateFilterPresetName(id: UUID, name: String) {
        if let index = filterPresets.firstIndex(where: { $0.id == id }) {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return }
            
            let oldPreset = filterPresets[index]
            let updatedPreset = GenerateFilterPreset(
                id: oldPreset.id,
                name: trimmedName,
                equipmentIDs: oldPreset.equipmentIDs,
                muscleGroupIDs: oldPreset.muscleGroupIDs,
                minExercises: oldPreset.minExercises,
                maxExercises: oldPreset.maxExercises
            )
            filterPresets[index] = updatedPreset
            savePresets()
        }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(filterPresets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }
    
    public func savePresetsPublic() {
        savePresets()
    }

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: presetsKey),
              let presets = try? JSONDecoder().decode([GenerateFilterPreset].self, from: data) else {
            return
        }
        filterPresets = presets
    }

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

        // Ensure min is not greater than max to avoid range error
        let safeMin = min(minExercises, maxExercises)
        let safeMax = max(minExercises, maxExercises)
        
        let targetCount = safeMin == safeMax ? safeMin : Int.random(in: safeMin...safeMax)
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
        var available = exercises.filter { !usedIDs.contains($0.id) }

        while result.count < targetCount && !available.isEmpty {
            if let random = available.randomElement() {
                result.append(random)
                // Remove the selected exercise from available pool
                available.removeAll { $0.id == random.id }
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

public struct GenerateFilterPreset: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let equipmentIDs: [UUID]
    public let muscleGroupIDs: [UUID]
    public let minExercises: Int
    public let maxExercises: Int

    public init(
        id: UUID = UUID(),
        name: String,
        equipmentIDs: [UUID],
        muscleGroupIDs: [UUID],
        minExercises: Int = 5,
        maxExercises: Int = 5
    ) {
        self.id = id
        self.name = name
        self.equipmentIDs = equipmentIDs
        self.muscleGroupIDs = muscleGroupIDs
        self.minExercises = minExercises
        self.maxExercises = maxExercises
    }
}
