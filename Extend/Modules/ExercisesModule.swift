////
////  ExercisesModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit

/// Module for managing exercises
public struct ExercisesModule: AppModule {
    public let id: UUID = ModuleIDs.exercises
    public let displayName: String = "Exercises"
    public let iconName: String = "flame.fill"
    public let description: String = "Add and manage exercises with muscle groups and equipment"
    
    public var order: Int = 6
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(ExercisesModuleView())
    }
}

private struct ExercisesModuleView: View {
    @Environment(ExercisesState.self) var state
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState
    
    @State private var searchText: String = ""
    @State private var showingAdd = false
    @State private var editingExercise: Exercise?
    
    private var filteredExercises: [Exercise] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            return state.exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return state.exercises
            .filter { matchesSearch($0, searchKey: trimmedSearch) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and add button
            HStack {
                Text("Exercises")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingAdd = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            List {
                SearchField(text: $searchText, placeholder: "Search exercises...")
                
                // Exercises List
                if filteredExercises.isEmpty {
                    Text("No exercises found")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(filteredExercises) { exercise in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            editingExercise = exercise
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                    // Show muscle groups
                    if !exercise.primaryMuscleGroupIDs.isEmpty || !exercise.secondaryMuscleGroupIDs.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Muscles:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            Text(formattedMuscleGroups(primaryIDs: exercise.primaryMuscleGroupIDs,
                                                      secondaryIDs: exercise.secondaryMuscleGroupIDs))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !exercise.equipmentIDs.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Equipment:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            Text(equipmentNames(exercise.equipmentIDs).joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    let trimmedNotes = exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedNotes.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Notes:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            Text(trimmedNotes)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Image(systemName: "pencil")
                                    .foregroundColor(.black)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingExercise = exercise
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                state.removeExercise(id: exercise.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .sheet(isPresented: $showingAdd) {
                ExerciseEditor(title: "Add Exercise") { exercise in
                    state.addExercise(exercise)
                }
                .environment(muscleGroupsState)
                .environment(equipmentState)
            }
            .sheet(item: $editingExercise) { exercise in
                ExerciseEditor(title: "Edit Exercise", initialExercise: exercise) { updated in
                    state.updateExercise(updated)
                }
                .environment(muscleGroupsState)
                .environment(equipmentState)
            }
        }
    }
    
    private func muscleGroupNames(_ ids: [UUID]) -> [String] {
        ids.compactMap { id in
            muscleGroupsState.sortedGroups.first { $0.id == id }?.name
        }
    }

    private func formattedMuscleGroups(primaryIDs: [UUID], secondaryIDs: [UUID]) -> String {
        let primaryNames = muscleGroupNames(primaryIDs)
        let secondaryNames = muscleGroupNames(secondaryIDs)
        if secondaryNames.isEmpty {
            return primaryNames.joined(separator: ", ")
        }
        let primaryText = primaryNames.joined(separator: ", ")
        let secondaryText = secondaryNames.joined(separator: ", ")
        return "\(primaryText) (\(secondaryText))"
    }

    private func equipmentNames(_ ids: [UUID]) -> [String] {
        ids.compactMap { id in
            equipmentState.sortedItems.first { $0.id == id }?.name
        }
    }
    
    private func matchesSearch(_ exercise: Exercise, searchKey: String) -> Bool {
        if exercise.name.localizedCaseInsensitiveContains(searchKey) {
            return true
        }
        if exercise.notes.localizedCaseInsensitiveContains(searchKey) {
            return true
        }
        let muscleIDs = exercise.primaryMuscleGroupIDs + exercise.secondaryMuscleGroupIDs
        let muscleNames = muscleGroupNames(muscleIDs)
        if muscleNames.contains(where: { $0.localizedCaseInsensitiveContains(searchKey) }) {
            return true
        }
        let equipmentNamesList = equipmentNames(exercise.equipmentIDs)
        if equipmentNamesList.contains(where: { $0.localizedCaseInsensitiveContains(searchKey) }) {
            return true
        }
        return false
    }
}

// MARK: - Exercise Editor

private struct ExerciseEditor: View {
    @Environment(\.dismiss) var dismiss
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState
    
    let title: String
    let initialExercise: Exercise?
    let onSave: (Exercise) -> Void
    
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var primaryMuscleGroupIDs: Set<UUID> = []
    @State private var secondaryMuscleGroupIDs: Set<UUID> = []
    @State private var selectedEquipmentIDs: Set<UUID> = []
    @State private var hasInitialized: Bool = false
    @State private var showSecondaryMuscles: Bool = false
    
    init(title: String, initialExercise: Exercise? = nil, onSave: @escaping (Exercise) -> Void) {
        self.title = title
        self.initialExercise = initialExercise
        self.onSave = onSave
        
        if let exercise = initialExercise {
            _name = State(initialValue: exercise.name)
            _notes = State(initialValue: exercise.notes)
            _selectedEquipmentIDs = State(initialValue: Set(exercise.equipmentIDs))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $name)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                
                Section("Primary Muscle Groups") {
                    Text("Main muscles worked by this exercise")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                    
                    if muscleGroupsState.sortedGroups.isEmpty {
                        Text("No muscle groups available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(muscleGroupsState.sortedGroups) { group in
                            Toggle(group.name, isOn: Binding(
                                get: { primaryMuscleGroupIDs.contains(group.id) },
                                set: { isSelected in
                                    if isSelected {
                                        primaryMuscleGroupIDs.insert(group.id)
                                    } else {
                                        primaryMuscleGroupIDs.remove(group.id)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                Section("Secondary Muscle Groups (Optional)") {
                    DisclosureGroup(isExpanded: $showSecondaryMuscles) {
                        if muscleGroupsState.sortedGroups.isEmpty {
                            Text("No muscle groups available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(muscleGroupsState.sortedGroups) { group in
                                Toggle(group.name, isOn: Binding(
                                    get: { secondaryMuscleGroupIDs.contains(group.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            secondaryMuscleGroupIDs.insert(group.id)
                                        } else {
                                            secondaryMuscleGroupIDs.remove(group.id)
                                        }
                                    }
                                ))
                            }
                        }
                    } label: {
                        Text("Additional muscles engaged during this exercise")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Section("Equipment") {
                    if equipmentState.sortedItems.isEmpty {
                        Text("No equipment available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(equipmentState.sortedItems) { equipment in
                            Toggle(equipment.name, isOn: Binding(
                                get: { selectedEquipmentIDs.contains(equipment.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedEquipmentIDs.insert(equipment.id)
                                    } else {
                                        selectedEquipmentIDs.remove(equipment.id)
                                    }
                                }
                            ))
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let exercise = Exercise(
                            id: initialExercise?.id ?? UUID(),
                            name: name,
                            notes: notes,
                            primaryMuscleGroupIDs: Array(primaryMuscleGroupIDs),
                            secondaryMuscleGroupIDs: Array(secondaryMuscleGroupIDs),
                            equipmentIDs: Array(selectedEquipmentIDs)
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if !hasInitialized {
                    // Ensure selections are properly initialized
                    if let exercise = initialExercise {
                        primaryMuscleGroupIDs = Set(exercise.primaryMuscleGroupIDs)
                        secondaryMuscleGroupIDs = Set(exercise.secondaryMuscleGroupIDs)
                        selectedEquipmentIDs = Set(exercise.equipmentIDs)
                    }
                    hasInitialized = true
                }
            }
        }
    }
}

#Preview {
    ExercisesModuleView()
        .environment(ExercisesState.shared)
        .environment(MuscleGroupsState.shared)
        .environment(EquipmentState.shared)
}
