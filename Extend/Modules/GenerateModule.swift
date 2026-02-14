////
////  GenerateModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit

/// Module for generating random workouts based on filters and preferences
public struct GenerateModule: AppModule {
    public let id: UUID = ModuleIDs.generate
    public let displayName: String = "Generate"
    public let iconName: String = "sparkles"
    public let description: String = "Generate random workouts with custom filters"

    public var order: Int = 2
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(GenerateModuleView())
    }
}

private struct GenerateModuleView: View {
    @Environment(GenerateState.self) var generateState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(EquipmentState.self) var equipmentState
    @Environment(MuscleGroupsState.self) var muscleGroupsState

    @State private var showEquipmentFilter = false
    @State private var showMuscleFilter = false
    @State private var saveWorkoutName = ""
    @State private var showSaveWorkoutDialog = false
    @State private var hasGenerated = false
    @State private var startingWorkout: Workout?

    var body: some View {
        VStack(spacing: 0) {
            // Header with title
            Text("Generate")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            List {
                // Min/Max Exercise Count Section
                Section("Workout Size") {
                    HStack {
                        Text("Minimum")
                        Spacer()
                        HStack(spacing: 12) {
                            Button(action: {
                                if generateState.minExercises > 1 {
                                    generateState.minExercises -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(generateState.minExercises > 1 ? .black : .gray)
                            }
                            .buttonStyle(.plain)
                            .disabled(generateState.minExercises <= 1)
                            
                            Text("\(generateState.minExercises)")
                                .frame(width: 30, alignment: .center)
                            
                            Button(action: {
                                if generateState.minExercises < 100 {
                                    generateState.minExercises += 1
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(generateState.minExercises < 100 ? .black : .gray)
                            }
                            .buttonStyle(.plain)
                            .disabled(generateState.minExercises >= 100)
                        }
                    }

                    HStack {
                        Text("Maximum")
                        Spacer()
                        HStack(spacing: 12) {
                            Button(action: {
                                if generateState.maxExercises > 1 {
                                    generateState.maxExercises -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(generateState.maxExercises > 1 ? .black : .gray)
                            }
                            .buttonStyle(.plain)
                            .disabled(generateState.maxExercises <= 1)
                            
                            Text("\(generateState.maxExercises)")
                                .frame(width: 30, alignment: .center)
                            
                            Button(action: {
                                if generateState.maxExercises < 100 {
                                    generateState.maxExercises += 1
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(generateState.maxExercises < 100 ? .black : .gray)
                            }
                            .buttonStyle(.plain)
                            .disabled(generateState.maxExercises >= 100)
                        }
                    }
                }

                // Filter Selection Section
                Section("Filters") {
                    Button(action: { showEquipmentFilter.toggle() }) {
                        HStack {
                            Text("Equipment")
                            Spacer()
                            Text("\(generateState.selectedEquipmentIDs.count) selected")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showEquipmentFilter) {
                        EquipmentFilterView()
                            .environment(generateState)
                            .environment(equipmentState)
                    }

                    Button(action: { showMuscleFilter.toggle() }) {
                        HStack {
                            Text("Muscle Groups")
                            Spacer()
                            Text("\(generateState.selectedMuscleGroupIDs.count) selected")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showMuscleFilter) {
                        MuscleGroupFilterView()
                            .environment(generateState)
                            .environment(muscleGroupsState)
                    }
                }

                // Generate Button Section
                Section {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        generateState.generateWorkout(
                            from: exercisesState.exercises,
                            equipment: equipmentState.sortedItems,
                            muscleGroups: muscleGroupsState.sortedGroups
                        )
                        hasGenerated = true
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Workout")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
                    }
                }

                // Generated Exercises Section
                if !generateState.generatedExercises.isEmpty {
                    GeneratedExercisesSection(
                        exercises: generateState.generatedExercises,
                        generateState: generateState,
                        muscleGroupsState: muscleGroupsState,
                        equipmentState: equipmentState,
                        onStartWorkout: { startingWorkout = $0 },
                        onSaveWorkout: { showSaveWorkoutDialog = true }
                    )
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(generateState.generatedExercises.isEmpty ? .inactive : .active))
            .sheet(item: $startingWorkout) { workout in
                StartWorkoutView(workout: workout)
                    .environment(ExercisesState.shared)
                    .environment(MuscleGroupsState.shared)
                    .environment(EquipmentState.shared)
            }
            .alert("Save Workout", isPresented: $showSaveWorkoutDialog) {
                TextField("Workout Name", text: $saveWorkoutName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if !saveWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let workoutsState = WorkoutsState.shared
                        generateState.saveAsWorkout(
                            name: saveWorkoutName,
                            to: workoutsState
                        )
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                }
                .disabled(saveWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a name for this generated workout")
            }
        }
        .onAppear {
            generateState.resetGenerated()
        }
    }
}

// MARK: - Equipment Filter View

private struct EquipmentFilterView: View {
    @Environment(GenerateState.self) var generateState
    @Environment(EquipmentState.self) var equipmentState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(equipmentState.sortedItems) { equipment in
                    HStack {
                        Text(equipment.name)
                        Spacer()
                        if generateState.selectedEquipmentIDs.contains(equipment.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.black)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if generateState.selectedEquipmentIDs.contains(equipment.id) {
                            generateState.selectedEquipmentIDs.remove(equipment.id)
                        } else {
                            generateState.selectedEquipmentIDs.insert(equipment.id)
                        }
                    }
                }
            }
            .navigationTitle("Select Equipment")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Muscle Group Filter View

private struct MuscleGroupFilterView: View {
    @Environment(GenerateState.self) var generateState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(muscleGroupsState.sortedGroups) { group in
                    HStack {
                        Text(group.name)
                        Spacer()
                        if generateState.selectedMuscleGroupIDs.contains(group.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.black)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if generateState.selectedMuscleGroupIDs.contains(group.id) {
                            generateState.selectedMuscleGroupIDs.remove(group.id)
                        } else {
                            generateState.selectedMuscleGroupIDs.insert(group.id)
                        }
                    }
                }
            }
            .navigationTitle("Select Muscle Groups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Generated Exercises Section

private struct GeneratedExercisesSection: View {
    let exercises: [GeneratedExerciseItem]
    let generateState: GenerateState
    let muscleGroupsState: MuscleGroupsState
    let equipmentState: EquipmentState
    let onStartWorkout: (Workout) -> Void
    let onSaveWorkout: () -> Void

    var body: some View {
        Section("Generated Exercises") {
            ForEach(exercises) { item in
                if let index = generateState.generatedExercises.firstIndex(where: { $0.id == item.id }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.exercise.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            let primaryMuscles = item.exercise.primaryMuscleGroupIDs.compactMap { id in
                                muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                            }
                            let secondaryMuscles = item.exercise.secondaryMuscleGroupIDs.compactMap { id in
                                muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                            }
                            let allMuscles = (primaryMuscles + secondaryMuscles).joined(separator: ", ")

                            if !allMuscles.isEmpty {
                                Text("Muscles: \(allMuscles)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            let equipmentNames = item.exercise.equipmentIDs.compactMap { id in
                                equipmentState.sortedItems.first { $0.id == id }?.name
                            }.joined(separator: ", ")

                            if !equipmentNames.isEmpty {
                                Text("Equipment: \(equipmentNames)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            generateState.cloneGeneratedExercise(at: index)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            generateState.removeGeneratedExercise(at: index)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                }
            }
            .onMove { indices, newOffset in
                generateState.generatedExercises.move(fromOffsets: indices, toOffset: newOffset)
            }

            // Start Workout Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let workout = Workout(
                    name: "Generated Workout",
                    notes: "",
                    exercises: generateState.generatedExercises.map { WorkoutExercise(exerciseID: $0.exercise.id) }
                )
                onStartWorkout(workout)
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Workout")
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.black)
            }

            // Save as Workout Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSaveWorkout()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save as Workout")
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.black)
            }
        }
    }
}

#Preview {
    GenerateModuleView()
        .environment(GenerateState.shared)
        .environment(ExercisesState.shared)
        .environment(EquipmentState.shared)
        .environment(MuscleGroupsState.shared)
}
