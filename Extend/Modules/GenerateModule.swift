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
    @State private var showSavePresetDialog = false
    @State private var presetName = ""
    @State private var showManagePresets = false
    @State private var selectedPresetId: UUID?

    private var canSavePreset: Bool {
        // Always allow saving presets - even with default settings
        true
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with title, filter tags, and save button
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Generate")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    HStack(spacing: 12) {
                        if !generateState.filterPresets.isEmpty {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showManagePresets = true
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 18))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSavePresetDialog = true
                        }) {
                            Image(systemName: "heart")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                        }
                        .disabled(!canSavePreset)
                    }
                }
                
                // Filter tags
                if !generateState.filterPresets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(generateState.filterPresets) { preset in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    generateState.applyFilterPreset(preset)
                                    selectedPresetId = preset.id
                                }) {
                                    Text(preset.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedPresetId == preset.id ? .white : .black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedPresetId == preset.id ? Color.black : Color.clear)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))

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
                                    selectedPresetId = nil
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
                                    selectedPresetId = nil
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
                                    selectedPresetId = nil
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
                                    selectedPresetId = nil
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
                Section {
                    Button(action: { 
                        selectedPresetId = nil
                        showEquipmentFilter.toggle() 
                    }) {
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

                    Button(action: { 
                        selectedPresetId = nil
                        showMuscleFilter.toggle() 
                    }) {
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
                } header: {
                    Text("Filters")
                }

                // Generate Button Section
                Section {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedPresetId = nil  // Clear selection when generating
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(8)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
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
            .sheet(isPresented: $showManagePresets) {
                ManageFilterPresetsView()
                    .environment(generateState)
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
            .sheet(isPresented: $showSavePresetDialog) {
                SaveFilterPresetSheet(
                    name: $presetName,
                    onSave: {
                        if !presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            generateState.addFilterPreset(name: presetName)
                            presetName = ""
                            showSavePresetDialog = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    },
                    onCancel: {
                        presetName = ""
                        showSavePresetDialog = false
                    }
                )
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

    private var equipmentOptions: [Equipment] {
        let items = equipmentState.sortedItems
        guard let noneIndex = items.firstIndex(where: { $0.name == "None" }) else {
            return items
        }
        var reordered = items
        let noneItem = reordered.remove(at: noneIndex)
        reordered.insert(noneItem, at: 0)
        return reordered
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(equipmentOptions) { equipment in
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

// MARK: - Manage Filter Presets View

private struct ManageFilterPresetsView: View {
    @Environment(GenerateState.self) var generateState
    @Environment(EquipmentState.self) var equipmentState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(\.dismiss) var dismiss

    @State private var showRenameDialog = false
    @State private var renamePresetID: UUID?
    @State private var renameValue = ""
    @State private var showDeleteConfirmation = false
    @State private var presetToDeleteId: UUID?
    
    // Helper functions to break down complex expressions
    private func getEquipmentNames(for equipmentIDs: Set<UUID>) -> String {
        equipmentIDs.compactMap { id in
            equipmentState.sortedItems.first(where: { $0.id == id })?.name
        }.joined(separator: ", ")
    }
    
    private func getMuscleGroupNames(for muscleGroupIDs: Set<UUID>) -> String {
        muscleGroupIDs.compactMap { id in
            muscleGroupsState.sortedGroups.first(where: { $0.id == id })?.name
        }.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            List {
                if generateState.filterPresets.isEmpty {
                    Text("No saved filters")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ForEach(generateState.filterPresets) { preset in
                        FilterPresetRow(
                            preset: preset,
                            equipmentState: equipmentState,
                            muscleGroupsState: muscleGroupsState,
                            getEquipmentNames: getEquipmentNames,
                            getMuscleGroupNames: getMuscleGroupNames,
                            onRename: {
                                renamePresetID = preset.id
                                renameValue = preset.name
                                showRenameDialog = true
                            },
                            onDelete: {
                                presetToDeleteId = preset.id
                                showDeleteConfirmation = true
                            }
                        )
                    }
                    .onMove { indices, newOffset in
                        generateState.filterPresets.move(fromOffsets: indices, toOffset: newOffset)
                        generateState.savePresetsPublic()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Saved Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Filter", isPresented: $showRenameDialog) {
                TextField("Name", text: $renameValue)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    guard let id = renamePresetID else { return }
                    generateState.updateFilterPresetName(id: id, name: renameValue)
                }
                .disabled(renameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a new name for this filter")
            }
            .alert("Delete Filter", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let id = presetToDeleteId {
                        generateState.removeFilterPreset(id: id)
                        presetToDeleteId = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    presetToDeleteId = nil
                }
            } message: {
                if let id = presetToDeleteId,
                   let preset = generateState.filterPresets.first(where: { $0.id == id }) {
                    Text("Are you sure you want to delete '\(preset.name)'? This cannot be undone.")
                }
            }
        }
    }
}

// MARK: - Filter Preset Row View

private struct FilterPresetRow: View {
    let preset: GenerateFilterPreset
    let equipmentState: EquipmentState
    let muscleGroupsState: MuscleGroupsState
    let getEquipmentNames: (Set<UUID>) -> String
    let getMuscleGroupNames: (Set<UUID>) -> String
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                // Filter details
                VStack(alignment: .leading, spacing: 2) {
                    Text("Min: \(preset.minExercises), Max: \(preset.maxExercises)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    // Equipment names
                    if !preset.equipmentIDs.isEmpty {
                        Text("Equipment: \(getEquipmentNames(Set(preset.equipmentIDs)))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Muscle group names
                    if !preset.muscleGroupIDs.isEmpty {
                        Text("Muscles: \(getMuscleGroupNames(Set(preset.muscleGroupIDs)))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 8) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onRename()
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
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

// MARK: - Save Filter Preset Sheet

private struct SaveFilterPresetSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("Enter name", text: $name)
                }
            }
            .navigationTitle("Save Filter Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(name.isEmpty)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
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
