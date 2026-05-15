////
////  WorkoutModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UIKit

/// Module for viewing and creating workouts.
public struct WorkoutModule: AppModule {
    public let id: UUID = ModuleIDs.workouts
    public let displayName: String = "Workout"
    public let iconName: String = "dumbbell"
    public let description: String = "View and create your workout routines"

    public var order: Int = 1
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(WorkoutsModuleView())
    }
}

private struct WorkoutsModuleView: View {
    @Environment(WorkoutsState.self) var state
    @Environment(ExercisesState.self) var exercisesState

    @State private var showingAdd = false
    @State private var editingWorkout: Workout?
    @State private var startingWorkout: Workout?
    @State private var deletingWorkout: Workout?
    @State private var searchText: String = ""

    private var filteredWorkouts: [Workout] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = state.workouts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !trimmedSearch.isEmpty else { return sorted }
        return sorted.filter { matchesSearch($0, searchKey: trimmedSearch) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and add button
            HStack {
                Text("Workout")
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
                // Favorites tiles
                if !state.favoriteWorkouts.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(state.favoriteWorkouts) { workout in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        startingWorkout = workout
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: "dumbbell.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.black)
                                            Text(workout.name)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.black)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(width: 70, height: 80)
                                        .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                SearchField(text: $searchText, placeholder: "Search workouts...")

                if filteredWorkouts.isEmpty {
                    Text("No workouts found")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(filteredWorkouts) { workout in
                        HStack(spacing: 12) {
                            // Play button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                startingWorkout = workout
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.black)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(workout.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                let trimmedNotes = workout.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedNotes.isEmpty {
                                    Text(trimmedNotes)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                if !workout.exercises.isEmpty {
                                    let exerciseNames = workoutExerciseNames(workout)
                                    let namesText = exerciseNames.joined(separator: ", ")
                                    Text("Exercises: \(workout.exercises.count) (\(namesText))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Star / Favorite button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                state.toggleFavorite(id: workout.id)
                            }) {
                                Image(systemName: state.isFavorite(workout.id) ? "star.fill" : "star")
                                    .foregroundColor(state.isFavorite(workout.id) ? .yellow : .gray)
                            }
                            .buttonStyle(.plain)

                            // Clone button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                state.cloneWorkout(workout)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)

                            // Edit button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingWorkout = workout
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)

                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingWorkout = workout
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                deletingWorkout = workout
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .sheet(isPresented: $showingAdd) {
                WorkoutEditor(title: "Add Workout") { workout in
                    state.addWorkout(workout)
                }
                .environment(exercisesState)
            }
            .sheet(item: $editingWorkout) { workout in
                WorkoutEditor(title: "Edit Workout", initialWorkout: workout) { updated in
                    state.updateWorkout(updated)
                } onDelete: {
                    state.removeWorkout(id: workout.id)
                }
                .environment(exercisesState)
            }
            .sheet(item: $startingWorkout) { workout in
                StartWorkoutView(workout: workout)
                    .environment(exercisesState)
                    .environment(MuscleGroupsState.shared)
                    .environment(EquipmentState.shared)
                    .environment(WorkoutLogState.shared)
            }
            .alert("Delete Workout?", isPresented: .constant(deletingWorkout != nil)) {
                Button("Cancel", role: .cancel) {
                    deletingWorkout = nil
                }
                Button("Delete", role: .destructive) {
                    if let workout = deletingWorkout {
                        state.removeWorkout(id: workout.id)
                        deletingWorkout = nil
                    }
                }
            } message: {
                Text("This will permanently delete the workout.")
            }
        }
    }

    private func workoutExerciseNames(_ workout: Workout) -> [String] {
        workout.exercises.compactMap { item in
            exercisesState.exercises.first { $0.id == item.exerciseID }?.name
        }
    }

    private func matchesSearch(_ workout: Workout, searchKey: String) -> Bool {
        if workout.name.localizedCaseInsensitiveContains(searchKey) {
            return true
        }
        if workout.notes.localizedCaseInsensitiveContains(searchKey) {
            return true
        }
        let exerciseNames = workoutExerciseNames(workout)
        if exerciseNames.contains(where: { $0.localizedCaseInsensitiveContains(searchKey) }) {
            return true
        }
        return false
    }
}

private struct WorkoutEditor: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ExercisesState.self) var exercisesState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState

    let title: String
    let initialWorkout: Workout?
    let onSave: (Workout) -> Void
    let onDelete: (() -> Void)?

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var workoutExercises: [WorkoutExercise] = []
    @State private var showingPicker = false
    @State private var searchText = ""
    @State private var showDeleteConfirm = false

    init(title: String, initialWorkout: Workout? = nil, onSave: @escaping (Workout) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.initialWorkout = initialWorkout
        self.onSave = onSave
        self.onDelete = onDelete

        if let workout = initialWorkout {
            _name = State(initialValue: workout.name)
            _notes = State(initialValue: workout.notes)
            _workoutExercises = State(initialValue: workout.exercises)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $name)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Exercises") {
                    if workoutExercises.isEmpty {
                        Text("No exercises added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(workoutExercises.enumerated()), id: \.element.id) { index, item in
                            if let exercise = exercisesState.exercises.first(where: { $0.id == item.exerciseID }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(exercise.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Spacer()

                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            let cloned = WorkoutExercise(exerciseID: item.exerciseID)
                                            workoutExercises.insert(cloned, at: index + 1)
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .foregroundColor(.black)
                                        }
                                        .buttonStyle(.plain)

                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            workoutExercises.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    let primaryMuscles = exercise.primaryMuscleGroupIDs.compactMap { id in
                                        muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                                    }
                                    let secondaryMuscles = exercise.secondaryMuscleGroupIDs.compactMap { id in
                                        muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                                    }
                                    let allMuscles = (primaryMuscles + secondaryMuscles).joined(separator: ", ")

                                    if !allMuscles.isEmpty {
                                        Text("Muscles: \(allMuscles)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    let equipmentNames = exercise.equipmentIDs.compactMap { id in
                                        equipmentState.sortedItems.first { $0.id == id }?.name
                                    }.joined(separator: ", ")

                                    if !equipmentNames.isEmpty {
                                        Text("Equipment: \(equipmentNames)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .onMove { indices, newOffset in
                            workoutExercises.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingPicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.black)
                            Text("Add Exercise")
                                .foregroundColor(.black)
                        }
                    }
                    .sheet(isPresented: $showingPicker) {
                        ExercisePickerView(searchText: $searchText) { exerciseID in
                            let item = WorkoutExercise(exerciseID: exerciseID)
                            workoutExercises.append(item)
                        }
                        .environment(exercisesState)
                        .environment(muscleGroupsState)
                        .environment(equipmentState)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                    if onDelete != nil {
                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 22))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let workout = Workout(
                            id: initialWorkout?.id ?? UUID(),
                            name: name,
                            notes: notes,
                            exercises: workoutExercises
                        )
                        onSave(workout)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Workout?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete the workout.")
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}

private struct ExercisePickerView: View {
    @Environment(ExercisesState.self) var exercisesState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState
    @Environment(\.dismiss) var dismiss

    @Binding var searchText: String
    let onSelect: (UUID) -> Void

    @State private var showToast = false
    @State private var lastAddedName = ""

    private var filteredExercises: [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return exercisesState.exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return exercisesState.exercises
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                SearchField(text: $searchText, placeholder: "Search exercises...")

                ForEach(filteredExercises) { exercise in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(exercise.id)
                        lastAddedName = exercise.name
                        showToast = true
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(exercise.name)
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.black)
                            }

                            let primaryMuscles = exercise.primaryMuscleGroupIDs.compactMap { id in
                                muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                            }
                            let secondaryMuscles = exercise.secondaryMuscleGroupIDs.compactMap { id in
                                muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                            }
                            let allMuscles = (primaryMuscles + secondaryMuscles).joined(separator: ", ")

                            if !allMuscles.isEmpty {
                                Text("Muscles: \(allMuscles)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            let equipmentNames = exercise.equipmentIDs.compactMap { id in
                                equipmentState.sortedItems.first { $0.id == id }?.name
                            }.joined(separator: ", ")

                            if !equipmentNames.isEmpty {
                                Text("Equipment: \(equipmentNames)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text("Added \(lastAddedName)")
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 12)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                showToast = false
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Start Workout View

public struct StartWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ModuleState.self) var moduleState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState
    @Environment(WorkoutLogState.self) var logState

    public let workout: Workout

    @State private var currentExerciseIndex: Int = 0
    @State private var timerSeconds: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var timerTask: Task<Void, Never>?
    @State private var expandedInfo: Bool = false
    @State private var sets: [WorkoutSet] = []
    @State private var notes: String = ""
    @State private var workoutStartTime: Date = Date()
    @State private var exerciseData: [UUID: (sets: [WorkoutSet], notes: String, timerSeconds: Int)] = [:]
    @State private var showingHistory: Bool = false

    private var currentExercise: Exercise? {
        guard currentExerciseIndex < workout.exercises.count else { return nil }
        let exerciseID = workout.exercises[currentExerciseIndex].exerciseID
        return exercisesState.exercises.first { $0.id == exerciseID }
    }

    public init(workout: Workout) {
        self.workout = workout
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Navigation bar with exercise count
                HStack {
                    Button(action: { previousExercise() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                    }
                    .disabled(currentExerciseIndex == 0)

                    Spacer()

                    Text("\(currentExerciseIndex + 1) of \(workout.exercises.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: { nextExercise() }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.black)
                    }
                    .disabled(currentExerciseIndex == workout.exercises.count - 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.98, green: 0.98, blue: 1.0))

                ScrollView {
                    VStack(spacing: 16) {
                        if let exercise = currentExercise {
                            // Exercise name with info button
                            HStack(spacing: 12) {
                                Spacer()
                                Text(exercise.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()

                                Button(action: { expandedInfo.toggle() }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)

                            // Expandable info section
                            if expandedInfo {
                                VStack(alignment: .leading, spacing: 8) {
                                    let primaryGroups = exercise.primaryMuscleGroupIDs.compactMap { id in
                                        muscleGroupsState.sortedGroups.first { $0.id == id }
                                    }
                                    let secondaryGroups = exercise.secondaryMuscleGroupIDs.compactMap { id in
                                        muscleGroupsState.sortedGroups.first { $0.id == id }
                                    }
                                    let allGroups = primaryGroups + secondaryGroups
                                    let allMuscles = allGroups.map(\.name).joined(separator: ", ")

                                    // A group has a real image if it has a non-nil asset name or custom data
                                    let groupsWithImages = allGroups.filter {
                                        $0.customPrimaryImageData != nil ||
                                        ($0.primaryImageAssetName != nil && !($0.primaryImageAssetName!.isEmpty))
                                    }
                                    let hasAnyImages = !groupsWithImages.isEmpty

                                    if !allMuscles.isEmpty {
                                        if hasAnyImages {
                                            // Images present — show label only, no redundant name list
                                            Text("Muscles:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            // No images — show full name list, skip thumbnails
                                            Text("Muscles: \(allMuscles)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    // Muscle thumbnails — only when real images exist
                                    if hasAnyImages {
                                        LazyVGrid(
                                            columns: [
                                                GridItem(.flexible()),
                                                GridItem(.flexible())
                                            ],
                                            spacing: 12
                                        ) {
                                            ForEach(allGroups) { group in
                                                VStack(spacing: 4) {
                                                    MuscleGroupThumbnail(group: group, size: 144)
                                                    Text(group.name)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }

                                    let equipmentNames = exercise.equipmentIDs.compactMap { id in
                                        equipmentState.sortedItems.first { $0.id == id }?.name
                                    }.joined(separator: ", ")

                                    if !equipmentNames.isEmpty {
                                        Text("Equipment: \(equipmentNames)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)

                                Divider()
                                    .padding(.horizontal, 16)
                            }

                            // Timer section
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Button(action: { toggleTimer() }) {
                                        Image(systemName: isTimerRunning ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.black)
                                    }
                                    .buttonStyle(.plain)

                                    Text("\(formatTime(timerSeconds))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()

                                    Button(action: { resetTimer() }) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .foregroundColor(.black)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)

                            // Sets section
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Sets")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Spacer()

                                    // History button — only shown when previous logs exist
                                    if let ex = currentExercise,
                                       lastLoggedSets(for: ex.id) != nil {
                                        Button(action: { showingHistory = true }) {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundColor(.black)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Button(action: { addSet() }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.black)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if sets.isEmpty {
                                    Text("No sets recorded")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Set")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text("\(index + 1)")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .frame(maxWidth: .infinity, alignment: .center)
                                                        .padding(6)
                                                        .background(Color(red: 0.98, green: 0.98, blue: 1.0))
                                                        .cornerRadius(4)
                                                }

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Reps")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    TextField("0", text: Binding(
                                                        get: { set.reps == 0 ? "" : "\(set.reps)" },
                                                        set: {
                                                            if let value = Int($0) {
                                                                sets[index].reps = value
                                                            } else if $0.isEmpty {
                                                                sets[index].reps = 0
                                                            }
                                                        }
                                                    ))
                                                    .keyboardType(.numberPad)
                                                    .font(.caption)
                                                    .padding(6)
                                                    .background(Color(red: 0.98, green: 0.98, blue: 1.0))
                                                    .cornerRadius(4)
                                                }

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Weight")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    TextField("0.00", text: Binding(
                                                        get: { set.weight == 0 ? "" : String(format: "%.2f", set.weight) },
                                                        set: {
                                                            if let value = Double($0) {
                                                                sets[index].weight = value
                                                            } else if $0.isEmpty {
                                                                sets[index].weight = 0
                                                            }
                                                        }
                                                    ))
                                                    .keyboardType(.decimalPad)
                                                    .font(.caption)
                                                    .padding(6)
                                                    .background(Color(red: 0.98, green: 0.98, blue: 1.0))
                                                    .cornerRadius(4)
                                                }

                                                if index == sets.count - 1 {
                                                    Button(action: { addSet() }) {
                                                        Image(systemName: "plus.circle.fill")
                                                            .foregroundColor(.black)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .padding(.top, 20)
                                                } else {
                                                    Button(action: { removeSet(at: index) }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .padding(.top, 20)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)

                            // Notes section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                TextField("Add notes...", text: $notes, axis: .vertical)
                                    .lineLimit(3, reservesSpace: true)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                    .cornerRadius(6)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .sheet(isPresented: $showingHistory) {
                    if let exercise = currentExercise {
                        ExerciseHistorySheet(exercise: exercise, logState: logState)
                    }
                }

                // Complete workout button
                HStack {
                    Spacer()
                    Button(action: { completeWorkout() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete Workout")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            workoutStartTime = Date()
            initializeSets()
        }
        .onDisappear { timerTask?.cancel() }
    }

    private func previousExercise() {
        if currentExerciseIndex > 0 {
            saveCurrentExerciseData()
            currentExerciseIndex -= 1
            loadExerciseData()
        }
    }

    private func nextExercise() {
        if currentExerciseIndex < workout.exercises.count - 1 {
            saveCurrentExerciseData()
            currentExerciseIndex += 1
            loadExerciseData()
        }
    }

    private func saveCurrentExerciseData() {
        guard let exerciseID = workout.exercises[safe: currentExerciseIndex]?.exerciseID else { return }
        exerciseData[exerciseID] = (sets: sets, notes: notes, timerSeconds: timerSeconds)
    }

    private func loadExerciseData() {
        guard let exerciseID = workout.exercises[safe: currentExerciseIndex]?.exerciseID else { return }
        
        if let savedData = exerciseData[exerciseID] {
            sets = savedData.sets
            notes = savedData.notes
            timerSeconds = savedData.timerSeconds
        } else {
            sets = []
            notes = ""
            timerSeconds = 0
            initializeSets()
        }
        
        isTimerRunning = false
        timerTask?.cancel()
        expandedInfo = false
    }

    private func resetForNewExercise() {
        timerSeconds = 0
        isTimerRunning = false
        timerTask?.cancel()
        expandedInfo = false
        sets = []
        notes = ""
        initializeSets()
    }

    private func toggleTimer() {
        isTimerRunning.toggle()
        if isTimerRunning {
            startTimer()
        } else {
            timerTask?.cancel()
        }
    }

    private func startTimer() {
        timerTask = Task {
            while isTimerRunning && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    DispatchQueue.main.async {
                        timerSeconds += 1
                    }
                }
            }
        }
    }

    private func resetTimer() {
        isTimerRunning = false
        timerTask?.cancel()
        timerSeconds = 0
    }

    private func addSet() {
        sets.append(WorkoutSet(reps: 0, weight: 0))
    }

    private func removeSet(at index: Int) {
        guard index < sets.count else { return }
        sets.remove(at: index)
    }

    private func initializeSets() {
        guard let exerciseID = workout.exercises[safe: currentExerciseIndex]?.exerciseID,
              let logged = lastLoggedSets(for: exerciseID), !logged.isEmpty else {
            sets = [WorkoutSet(reps: 0, weight: 0)]
            return
        }
        // Pre-populate from the most recent log entry for this exercise
        sets = logged.map { WorkoutSet(reps: $0.reps, weight: $0.weight) }
    }

    /// Returns the sets from the most recent log that contains this exercise, or nil if none.
    private func lastLoggedSets(for exerciseID: UUID) -> [LoggedSet]? {
        let match = logState.sortedLogs
            .compactMap { log in log.exercises.first(where: { $0.exerciseID == exerciseID }) }
            .first
        return match.flatMap { $0.sets.isEmpty ? nil : $0.sets }
    }

    private func completeWorkout() {
        // Save current exercise data
        saveCurrentExerciseData()
        
        // Create logged exercises from saved data
        var loggedExercises: [LoggedExercise] = []
        
        for workoutExercise in workout.exercises {
            if let exercise = exercisesState.exercises.first(where: { $0.id == workoutExercise.exerciseID }),
               let savedData = exerciseData[workoutExercise.exerciseID] {
                
                let loggedSets = savedData.sets.map { set in
                    LoggedSet(reps: set.reps, weight: set.weight)
                }
                
                let loggedExercise = LoggedExercise(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    sets: loggedSets,
                    notes: savedData.notes
                )
                
                loggedExercises.append(loggedExercise)
            }
        }
        
        // Calculate workout duration
        let duration = Date().timeIntervalSince(workoutStartTime)
        
        // Create and save workout log
        let workoutLog = WorkoutLog(
            workoutName: workout.name,
            completedAt: Date(),
            exercises: loggedExercises,
            notes: "",
            duration: duration
        )
        
        WorkoutLogState.shared.addLog(workoutLog)
        
        // Navigate to Log module
        moduleState.selectModule(ModuleIDs.progress)
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        dismiss()
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

// MARK: - Workout Set Model

private struct WorkoutSet: Identifiable {
    let id: UUID = UUID()
    var reps: Int
    var weight: Double
}

// MARK: - TextField Placeholder Extension

extension View {
    func placeholder(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: @escaping () -> some View) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Array Safe Subscript Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Exercise History Sheet

struct ExerciseHistorySheet: View {
    @Environment(\.dismiss) var dismiss

    let exercise: Exercise
    let logState: WorkoutLogState

    /// All past log entries for this exercise, newest first.
    private var history: [(date: Date, sets: [LoggedSet], notes: String)] {
        logState.sortedLogs.compactMap { log in
            guard let ex = log.exercises.first(where: { $0.exerciseID == exercise.id }),
                  !ex.sets.isEmpty else { return nil }
            return (date: log.completedAt, sets: ex.sets, notes: ex.notes)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.secondary)
                        Text("No History")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Complete a workout with this exercise to see history here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text(entry.date, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(entry.date, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                // Sets grid: Set # | Reps | Weight
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Set")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Reps")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        Text("Weight")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }

                                    ForEach(Array(entry.sets.enumerated()), id: \.offset) { idx, set in
                                        HStack {
                                            Text("\(idx + 1)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text("\(set.reps)")
                                                .font(.caption)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                            Text(set.weight == 0 ? "—" : String(format: "%.1f lbs", set.weight))
                                                .font(.caption)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(6)

                                // Notes from that session
                                if !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Notes: \(entry.notes)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History: \(exercise.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    WorkoutsModuleView()
        .environment(WorkoutsState.shared)
        .environment(ExercisesState.shared)
}
