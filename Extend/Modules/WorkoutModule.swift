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

// MARK: - Loop Color Palette

private let loopColorPalette: [Color] = [
    Color(red: 0.20, green: 0.50, blue: 1.00),   // blue
    Color(red: 0.18, green: 0.72, blue: 0.40),   // green
    Color(red: 1.00, green: 0.55, blue: 0.10),   // orange
    Color(red: 0.60, green: 0.20, blue: 0.90),   // purple
    Color(red: 0.90, green: 0.20, blue: 0.25),   // red
    Color(red: 0.05, green: 0.70, blue: 0.75),   // teal
]

private func loopColor(for loopID: UUID, in orderedLoopIDs: [UUID]) -> Color {
    let index = orderedLoopIDs.firstIndex(of: loopID) ?? 0
    return loopColorPalette[index % loopColorPalette.count]
}

// MARK: - Workouts Module View

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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
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

                                let exerciseItems = workout.exerciseItems
                                if !exerciseItems.isEmpty {
                                    let exerciseNames = exerciseItems.compactMap { item in
                                        exercisesState.exercises.first { $0.id == item.exerciseID }?.name
                                    }
                                    let namesText = exerciseNames.joined(separator: ", ")
                                    Text("Exercises: \(exerciseItems.count) (\(namesText))")
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
            .onAppear {
                launchPendingWorkoutIfNeeded()
            }
            .onChange(of: state.pendingLaunchID) { _, _ in
                launchPendingWorkoutIfNeeded()
            }
        }
    }

    private func launchPendingWorkoutIfNeeded() {
        guard let id = state.pendingLaunchID else { return }
        state.pendingLaunchID = nil
        if let workout = state.workouts.first(where: { $0.id == id }) {
            startingWorkout = workout
        }
    }

    private func matchesSearch(_ workout: Workout, searchKey: String) -> Bool {
        if workout.name.localizedCaseInsensitiveContains(searchKey) { return true }
        if workout.notes.localizedCaseInsensitiveContains(searchKey) { return true }
        let exerciseNames = workout.exerciseItems.compactMap { item in
            exercisesState.exercises.first { $0.id == item.exerciseID }?.name
        }
        return exerciseNames.contains { $0.localizedCaseInsensitiveContains(searchKey) }
    }
}

// MARK: - Workout Editor

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
    @State private var workoutItems: [WorkoutItem] = []
    @State private var showingPicker = false
    @State private var searchText = ""
    @State private var showDeleteConfirm = false
    // Track which exercise rows have expanded info or sets editor
    @State private var expandedInfoIDs: Set<UUID> = []
    @State private var expandedSetsIDs: Set<UUID> = []
    @State private var editMode: EditMode = .active

    init(title: String, initialWorkout: Workout? = nil, onSave: @escaping (Workout) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.initialWorkout = initialWorkout
        self.onSave = onSave
        self.onDelete = onDelete

        if let workout = initialWorkout {
            _name = State(initialValue: workout.name)
            _notes = State(initialValue: workout.notes)
            _workoutItems = State(initialValue: workout.items)
        }
    }

    /// Ordered distinct loopIDs for color assignment.
    private var orderedLoopIDs: [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for item in workoutItems {
            if case .exercise(let e) = item, let lid = e.loopID, !seen.contains(lid) {
                seen.insert(lid)
                result.append(lid)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $name)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section {
                    if workoutItems.isEmpty {
                        Text("No exercises added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(workoutItems.enumerated()), id: \.element.id) { index, item in
                            switch item {
                            case .exercise(let ex):
                                EditorExerciseRow(
                                    exercise: ex,
                                    index: index,
                                    workoutItems: $workoutItems,
                                    expandedInfoIDs: $expandedInfoIDs,
                                    expandedSetsIDs: $expandedSetsIDs,
                                    orderedLoopIDs: orderedLoopIDs,
                                    muscleGroupsState: muscleGroupsState,
                                    equipmentState: equipmentState,
                                    exercisesState: exercisesState
                                )
                            case .rest(let r):
                                EditorRestRow(rest: r, index: index, workoutItems: $workoutItems)
                            }
                        }
                        .onMove { indices, newOffset in
                            workoutItems.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            workoutItems.append(.rest(RestItem()))
                        }) {
                            Image(systemName: "zzz")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingPicker = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .textCase(nil)
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(searchText: $searchText) { exerciseID in
                    let item = WorkoutExercise(exerciseID: exerciseID)
                    workoutItems.append(.exercise(item))
                }
                .environment(exercisesState)
                .environment(muscleGroupsState)
                .environment(equipmentState)
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
                            items: workoutItems
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

        }
    }
}

// MARK: - Editor Exercise Row

private struct EditorExerciseRow: View {
    let exercise: WorkoutExercise
    let index: Int
    @Binding var workoutItems: [WorkoutItem]
    @Binding var expandedInfoIDs: Set<UUID>
    @Binding var expandedSetsIDs: Set<UUID>
    let orderedLoopIDs: [UUID]
    let muscleGroupsState: MuscleGroupsState
    let equipmentState: EquipmentState
    let exercisesState: ExercisesState

    private var resolvedExercise: Exercise? {
        exercisesState.exercises.first { $0.id == exercise.exerciseID }
    }

    private var isInfoExpanded: Bool { expandedInfoIDs.contains(exercise.id) }
    private var isSetsExpanded: Bool { expandedSetsIDs.contains(exercise.id) }

    private var exerciseLoopColor: Color? {
        guard let lid = exercise.loopID else { return nil }
        return loopColor(for: lid, in: orderedLoopIDs)
    }

    private var adjacentExercise: WorkoutExercise? {
        // Find an adjacent exercise item (ignoring rest rows) for merge targets
        nil // computed inline in swipe actions
    }

    private func exerciseItem(at idx: Int) -> WorkoutExercise? {
        guard idx >= 0 && idx < workoutItems.count else { return nil }
        if case .exercise(let e) = workoutItems[idx] { return e }
        return nil
    }

    private func isExerciseItem(_ item: WorkoutItem) -> Bool {
        if case .exercise(_) = item { return true }
        return false
    }

    private var canMergeUp: Bool {
        (0..<index).reversed().contains { isExerciseItem(workoutItems[$0]) }
    }

    private var canMergeDown: Bool {
        ((index + 1)..<workoutItems.count).contains { isExerciseItem(workoutItems[$0]) }
    }

    private func mergeWith(otherIndex: Int) {
        guard case .exercise(var currentEx) = workoutItems[index],
              case .exercise(var otherEx) = workoutItems[otherIndex] else { return }

        let targetLoopID: UUID
        if let existingLoop = currentEx.loopID {
            targetLoopID = existingLoop
        } else if let existingLoop = otherEx.loopID {
            targetLoopID = existingLoop
        } else {
            targetLoopID = UUID()
        }

        currentEx.loopID = targetLoopID
        otherEx.loopID = targetLoopID
        workoutItems[index] = .exercise(currentEx)
        workoutItems[otherIndex] = .exercise(otherEx)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func removeFromLoop() {
        guard case .exercise(var ex) = workoutItems[index] else { return }
        ex.loopID = nil
        workoutItems[index] = .exercise(ex)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func nearestExerciseIndex(before idx: Int) -> Int? {
        (0..<idx).reversed().first { isExerciseItem(workoutItems[$0]) }
    }

    private func nearestExerciseIndex(after idx: Int) -> Int? {
        ((idx + 1)..<workoutItems.count).first { isExerciseItem(workoutItems[$0]) }
    }

    var body: some View {
        if let ex = resolvedExercise {
            rowContent(ex: ex)
        }
    }

    @ViewBuilder
    private func rowContent(ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Loop color bracket
                if let color = exerciseLoopColor {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 4)
                        .padding(.vertical, 2)
                        .padding(.trailing, 8)
                } else {
                    Color.clear.frame(width: 12)
                }

                // Exercise name and sub-labels
                VStack(alignment: .leading, spacing: 4) {
                    Text(ex.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    // Loop badge
                    if let lid = exercise.loopID {
                        let loopIdx = orderedLoopIDs.firstIndex(of: lid) ?? 0
                        let color = loopColorPalette[loopIdx % loopColorPalette.count]
                        Text("Loop \(loopIdx + 1)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color)
                            .cornerRadius(4)
                    }

                    // Predefined sets summary or Add Sets button
                    if exercise.predefinedSets.isEmpty {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            expandedSetsIDs.insert(exercise.id)
                        }) {
                            Text("+ Add Sets")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    } else {
                        let count = exercise.predefinedSets.count
                        let timedMins = exercise.timedSetDuration / 60
                        let timedSecs = exercise.timedSetDuration % 60
                        let timedLabel = timedMins > 0 ? "\(timedMins)m \(timedSecs)s" : "\(timedSecs)s"
                        let firstReps = exercise.predefinedSets.first?.targetReps ?? 0
                        let summary: String = exercise.useTimedSet
                            ? "\(count) × \(timedLabel)"
                            : (firstReps > 0 ? "\(count) sets" : "\(count) sets")
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if expandedSetsIDs.contains(exercise.id) {
                                expandedSetsIDs.remove(exercise.id)
                            } else {
                                expandedSetsIDs.insert(exercise.id)
                            }
                        }) {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Action buttons — top-aligned with exercise name
                HStack(spacing: 12) {
                    // Info toggle
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if expandedInfoIDs.contains(exercise.id) {
                            expandedInfoIDs.remove(exercise.id)
                        } else {
                            expandedInfoIDs.insert(exercise.id)
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(isInfoExpanded ? .blue : .secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)

                    // Clone
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let cloned = WorkoutExercise(
                            exerciseID: exercise.exerciseID,
                            loopID: exercise.loopID,
                            predefinedSets: exercise.predefinedSets.map { PredefinedSet(targetReps: $0.targetReps) },
                            useTimedSet: exercise.useTimedSet,
                            timedSetDuration: exercise.timedSetDuration
                        )
                        workoutItems.insert(.exercise(cloned), at: index + 1)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)

                    // Delete
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        workoutItems.remove(at: index)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)

                // Expandable muscle/equipment info
                if isInfoExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        let primaryNames = ex.primaryMuscleGroupIDs.compactMap { id in
                            muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                        }
                        let secondaryNames = ex.secondaryMuscleGroupIDs.compactMap { id in
                            muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                        }
                        let allMuscles = (primaryNames + secondaryNames).joined(separator: ", ")
                        if !allMuscles.isEmpty {
                            Text("Muscles: \(allMuscles)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        let equipNames = ex.equipmentIDs.compactMap { id in
                            equipmentState.sortedItems.first { $0.id == id }?.name
                        }.joined(separator: ", ")
                        if !equipNames.isEmpty {
                            Text("Equipment: \(equipNames)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.bottom, 6)
                }

                // Expandable predefined sets editor
                if isSetsExpanded {
                    PredefinedSetsEditor(exercise: exercise, index: index, workoutItems: $workoutItems, expandedSetsIDs: $expandedSetsIDs)
                        .padding(.leading, 12)
                        .padding(.bottom, 8)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if exercise.loopID != nil {
                    Button {
                        removeFromLoop()
                    } label: {
                        Label("Remove from Loop", systemImage: "circle.slash")
                    }
                    .tint(.orange)
                } else {
                    if let downIdx = nearestExerciseIndex(after: index) {
                        Button {
                            mergeWith(otherIndex: downIdx)
                        } label: {
                            Label("Merge Down", systemImage: "arrow.down.to.line")
                        }
                        .tint(.green)
                    }
                    if let upIdx = nearestExerciseIndex(before: index) {
                        Button {
                            mergeWith(otherIndex: upIdx)
                        } label: {
                            Label("Merge Up", systemImage: "arrow.up.to.line")
                        }
                        .tint(Color(red: 0.1, green: 0.6, blue: 0.3))
                    }
                }
            }
    }
}

// MARK: - Predefined Sets Editor

private struct PredefinedSetsEditor: View {
    let exercise: WorkoutExercise
    let index: Int
    @Binding var workoutItems: [WorkoutItem]
    @Binding var expandedSetsIDs: Set<UUID>

    private var setCount: Int { exercise.predefinedSets.count }
    private var timedMinutes: Int { exercise.timedSetDuration / 60 }
    private var timedSeconds: Int { exercise.timedSetDuration % 60 }

    private func update(_ block: (inout WorkoutExercise) -> Void) {
        guard case .exercise(var ex) = workoutItems[index] else { return }
        block(&ex)
        workoutItems[index] = .exercise(ex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Timed toggle
            HStack(spacing: 12) {
                Text("Timed:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("", isOn: Binding(
                    get: { exercise.useTimedSet },
                    set: { newVal in update { ex in ex.useTimedSet = newVal } }
                ))
                .labelsHidden()
                .scaleEffect(0.8)
            }

            if exercise.useTimedSet {
                // Duration steppers: minutes and seconds
                HStack(spacing: 8) {
                    Text("Duration:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    // Minutes
                    Button(action: {
                        guard timedMinutes > 0 else { return }
                        update { ex in ex.timedSetDuration = max(0, ex.timedSetDuration - 60) }
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(timedMinutes > 0 ? .black : .gray)
                    }
                    .buttonStyle(.plain)
                    Text("\(timedMinutes)m")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(minWidth: 24, alignment: .center)
                    Button(action: {
                        update { ex in ex.timedSetDuration += 60 }
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    // Seconds
                    Button(action: {
                        guard timedSeconds > 0 else { return }
                        update { ex in ex.timedSetDuration = max(0, ex.timedSetDuration - 15) }
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(timedSeconds > 0 ? .black : .gray)
                    }
                    .buttonStyle(.plain)
                    Text("\(timedSeconds)s")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(minWidth: 24, alignment: .center)
                    Button(action: {
                        let newSecs = timedSeconds + 15
                        if newSecs >= 60 {
                            update { ex in ex.timedSetDuration = (timedMinutes + 1) * 60 }
                        } else {
                            update { ex in ex.timedSetDuration = timedMinutes * 60 + newSecs }
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Per-set reps rows
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exercise.predefinedSets.enumerated()), id: \.element.id) { setIdx, predSet in
                        HStack(spacing: 8) {
                            Text("Set \(setIdx + 1):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .leading)

                            Button(action: {
                                guard predSet.targetReps > 0 else { return }
                                update { ex in
                                    ex.predefinedSets[setIdx].targetReps = max(0, predSet.targetReps - 1)
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(predSet.targetReps > 0 ? .black : .gray)
                            }
                            .buttonStyle(.plain)

                            Text("\(predSet.targetReps) reps")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(minWidth: 48, alignment: .center)

                            Button(action: {
                                update { ex in
                                    ex.predefinedSets[setIdx].targetReps = predSet.targetReps + 1
                                }
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: {
                                update { ex in ex.predefinedSets.remove(at: setIdx) }
                            }) {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Add set button
            Button(action: {
                let lastReps = exercise.predefinedSets.last?.targetReps ?? 0
                update { ex in ex.predefinedSets.append(PredefinedSet(targetReps: lastReps)) }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Set")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // Remove all sets
            Button(action: {
                update { ex in ex.predefinedSets = [] }
                expandedSetsIDs.remove(exercise.id)
            }) {
                Text("Remove All Sets")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Editor Rest Row

private struct EditorRestRow: View {
    let rest: RestItem
    let index: Int
    @Binding var workoutItems: [WorkoutItem]

    private func update(_ block: (inout RestItem) -> Void) {
        guard case .rest(var r) = workoutItems[index] else { return }
        block(&r)
        workoutItems[index] = .rest(r)
    }

    private var restMinutes: Int { rest.duration / 60 }
    private var restSeconds: Int { rest.duration % 60 }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "zzz")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            Text("Rest")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            // Minutes stepper
            Button(action: {
                guard restMinutes > 0 else { return }
                update { r in r.duration = max(0, r.duration - 60) }
            }) {
                Image(systemName: "minus.circle")
                    .foregroundColor(restMinutes > 0 ? .black : .gray)
            }
            .buttonStyle(.plain)

            Text("\(restMinutes)m")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(minWidth: 28, alignment: .center)

            Button(action: {
                update { r in r.duration += 60 }
            }) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)

            // Seconds stepper
            Button(action: {
                guard restSeconds > 0 else { return }
                update { r in r.duration = max(0, r.duration - 15) }
            }) {
                Image(systemName: "minus.circle")
                    .foregroundColor(restSeconds > 0 ? .black : .gray)
            }
            .buttonStyle(.plain)

            Text("\(restSeconds)s")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(minWidth: 28, alignment: .center)

            Button(action: {
                let newSecs = restSeconds + 15
                if newSecs >= 60 {
                    update { r in r.duration = (restMinutes + 1) * 60 }
                } else {
                    update { r in r.duration = restMinutes * 60 + newSecs }
                }
            }) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                workoutItems.remove(at: index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Exercise Picker

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

    @State private var currentItemIndex: Int = 0
    @State private var timerSeconds: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var timerTask: Task<Void, Never>?
    @State private var expandedInfo: Bool = false
    @State private var sets: [WorkoutSet] = []
    @State private var previousSets: [LoggedSet] = []
    @State private var previousLogDate: Date? = nil
    @State private var notes: String = ""
    @State private var workoutStartTime: Date = Date()
    @State private var exerciseData: [UUID: (sets: [WorkoutSet], notes: String, timerSeconds: Int)] = [:]
    @State private var showingHistory: Bool = false
    // Rest screen state
    @State private var restSecondsRemaining: Int = 60
    @State private var isRestTimerRunning: Bool = false
    @State private var restTimerTask: Task<Void, Never>?

    private var currentItem: WorkoutItem? {
        workout.items[safe: currentItemIndex]
    }

    private var currentExercise: Exercise? {
        guard case .exercise(let we) = currentItem else { return nil }
        return exercisesState.exercises.first { $0.id == we.exerciseID }
    }

    private var currentWorkoutExercise: WorkoutExercise? {
        guard case .exercise(let we) = currentItem else { return nil }
        return we
    }

    private var currentRestItem: RestItem? {
        guard case .rest(let r) = currentItem else { return nil }
        return r
    }

    private var totalItems: Int { workout.items.count }

    public init(workout: Workout) {
        self.workout = workout
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Navigation bar with item count
                HStack {
                    Button(action: { previousItem() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                    }
                    .disabled(currentItemIndex == 0)

                    Spacer()

                    Text("\(currentItemIndex + 1) of \(totalItems)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: { nextItem() }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.black)
                    }
                    .disabled(currentItemIndex == totalItems - 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.98, green: 0.98, blue: 1.0))

                if let restItem = currentRestItem {
                    // REST SCREEN
                    RestScreen(
                        restItem: restItem,
                        secondsRemaining: $restSecondsRemaining,
                        isRunning: $isRestTimerRunning,
                        timerTask: $restTimerTask,
                        onSkip: { nextItem() }
                    )
                } else {
                    // EXERCISE SCREEN
                    ScrollView {
                        VStack(spacing: 16) {
                            if let exercise = currentExercise, let we = currentWorkoutExercise {
                                exerciseContent(exercise: exercise, we: we)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .sheet(isPresented: $showingHistory) {
                        if let exercise = currentExercise {
                            ExerciseHistorySheet(exercise: exercise, logState: logState)
                        }
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
        .onDisappear {
            timerTask?.cancel()
            restTimerTask?.cancel()
        }
    }

    // MARK: Exercise content builder

    @ViewBuilder
    private func exerciseContent(exercise: Exercise, we: WorkoutExercise) -> some View {
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

        // Muscle image data
        let exPrimaryGroups = exercise.primaryMuscleGroupIDs.compactMap { id in
            muscleGroupsState.sortedGroups.first { $0.id == id }
        }
        let exSecondaryGroups = exercise.secondaryMuscleGroupIDs.compactMap { id in
            muscleGroupsState.sortedGroups.first { $0.id == id }
        }
        let exIsFemale = muscleGroupsState.selectedBodyOption == .female
        let exFrontBase = exIsFemale ? "FemaleFrontFullBody" : "MaleFrontFullBody"
        let exBackBase  = exIsFemale ? "FemaleBackFullBody"  : "MaleBackFullBody"
        let exPrimaryAssets = exPrimaryGroups.flatMap { g -> [String] in
            [g.primaryImageAssetName, g.secondaryImageAssetName].compactMap { $0 }.filter { !$0.isEmpty }
        }
        let exFrontMasksPrimary   = exPrimaryAssets.filter { $0.contains("Front") }
        let exBackMasksPrimary    = exPrimaryAssets.filter { $0.contains("Back") && !$0.contains("FullBody") }
        let exSecondaryAssets = exSecondaryGroups.flatMap { g -> [String] in
            [g.primaryImageAssetName, g.secondaryImageAssetName].compactMap { $0 }.filter { !$0.isEmpty }
        }
        let exFrontMasksSecondary = exSecondaryAssets.filter { $0.contains("Front") }
        let exBackMasksSecondary  = exSecondaryAssets.filter { $0.contains("Back") && !$0.contains("FullBody") }

        // Expandable info section
        if expandedInfo {
            VStack(alignment: .leading, spacing: 8) {
                let allMuscles = (exPrimaryGroups + exSecondaryGroups).map(\.name).joined(separator: ", ")
                if !allMuscles.isEmpty {
                    Text("Muscles: \(allMuscles)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    let panelWidth = (geo.size.width - 12) / 2
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            ZStack {
                                Image(exFrontBase).resizable().scaledToFit()
                                ForEach(exFrontMasksPrimary, id: \.self) { mask in
                                    Image(mask).resizable().scaledToFit().blendMode(.screen)
                                }
                                ForEach(exFrontMasksSecondary, id: \.self) { mask in
                                    Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                                }
                            }
                            .frame(width: panelWidth)
                            Text("Front").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        VStack(spacing: 4) {
                            ZStack {
                                Image(exBackBase).resizable().scaledToFit()
                                ForEach(exBackMasksPrimary, id: \.self) { mask in
                                    Image(mask).resizable().scaledToFit().blendMode(.screen)
                                }
                                ForEach(exBackMasksSecondary, id: \.self) { mask in
                                    Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                                }
                            }
                            .frame(width: panelWidth)
                            Text("Back").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 220)
                .padding(.vertical, 4)

                let equipmentNames = exercise.equipmentIDs.compactMap { id in
                    equipmentState.sortedItems.first { $0.id == id }?.name
                }.joined(separator: ", ")
                if !equipmentNames.isEmpty {
                    Text("Equipment: \(equipmentNames)").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)

            Divider().padding(.horizontal, 16)
        }

        // Timer section — flanked by small body thumbnails when info is collapsed
        HStack(spacing: 8) {
            if !expandedInfo {
                ZStack {
                    Image(exFrontBase).resizable().scaledToFit()
                    ForEach(exFrontMasksPrimary, id: \.self) { mask in
                        Image(mask).resizable().scaledToFit().blendMode(.screen)
                    }
                    ForEach(exFrontMasksSecondary, id: \.self) { mask in
                        Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                    }
                }
                .frame(width: 56, height: 80)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: { toggleTimer() }) {
                        Image(systemName: isTimerRunning ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)

                    Text(formatTime(timerSeconds))
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
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            .cornerRadius(8)

            if !expandedInfo {
                ZStack {
                    Image(exBackBase).resizable().scaledToFit()
                    ForEach(exBackMasksPrimary, id: \.self) { mask in
                        Image(mask).resizable().scaledToFit().blendMode(.screen)
                    }
                    ForEach(exBackMasksSecondary, id: \.self) { mask in
                        Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                    }
                }
                .frame(width: 56, height: 80)
            }
        }
        .padding(.horizontal, 16)

        // Sets section
        VStack(spacing: 8) {
            HStack {
                Text("Sets")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Show "predefined" label if targets are set, otherwise show previous session hint
                if !we.predefinedSets.isEmpty {
                    let reps = we.predefinedSets.first?.targetReps ?? 0
                    let label = we.useTimedSet
                        ? "(target: \(we.predefinedSets.count) × \(we.timedSetDuration)s)"
                        : (reps > 0 ? "(target: \(we.predefinedSets.count) × \(reps) reps)" : "(target: \(we.predefinedSets.count) sets)")
                    Text(label)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                } else if !previousSets.isEmpty {
                    let dateLabel: String = {
                        guard let date = previousLogDate else { return "" }
                        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                        if days == 0 { return ", today" }
                        if days == 1 { return ", yesterday" }
                        if days < 30 { return ", \(days)d ago" }
                        return ", \(days / 30)mo ago"
                    }()
                    Text("(previous values\(dateLabel))")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                }

                Spacer()

                // History button
                if lastLoggedSets(for: exercise.id) != nil {
                    Button(action: { showingHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }

                if sets.isEmpty {
                    Button(action: { addSet() }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }
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
                                    .foregroundColor(.primary.opacity(0.6))
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
                                    .foregroundColor(.primary.opacity(0.6))

                                // Predefined reps take precedence over previous-session placeholders
                                let repPlaceholder: String = {
                                    if !we.predefinedSets.isEmpty {
                                        let targetReps = index < we.predefinedSets.count ? we.predefinedSets[index].targetReps : 0
                                        return targetReps > 0 ? "\(targetReps)" : ""
                                    } else if index < previousSets.count && previousSets[index].reps > 0 {
                                        return "\(previousSets[index].reps)"
                                    }
                                    return ""
                                }()

                                TextField(repPlaceholder, text: Binding(
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
                                    .foregroundColor(.primary.opacity(0.6))
                                let weightPlaceholder = index < previousSets.count && previousSets[index].weight > 0
                                    ? String(format: "%.2f", previousSets[index].weight) : ""
                                TextField(weightPlaceholder, text: Binding(
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

                            Button(action: { removeSet(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 20)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button(action: { addSet() }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
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

    // MARK: Navigation

    private func previousItem() {
        guard currentItemIndex > 0 else { return }
        saveCurrentData()
        currentItemIndex -= 1
        loadItemData()
    }

    private func nextItem() {
        guard currentItemIndex < totalItems - 1 else { return }
        saveCurrentData()
        currentItemIndex += 1
        loadItemData()
    }

    private func saveCurrentData() {
        if case .exercise(let we) = currentItem {
            exerciseData[we.exerciseID] = (sets: sets, notes: notes, timerSeconds: timerSeconds)
        }
    }

    private func loadItemData() {
        // Reset rest timer
        restTimerTask?.cancel()
        isRestTimerRunning = false

        if case .rest(let r) = currentItem {
            restSecondsRemaining = r.duration
            isTimerRunning = false
            timerTask?.cancel()
            return
        }

        guard case .exercise(let we) = currentItem else { return }

        if let savedData = exerciseData[we.exerciseID] {
            sets = savedData.sets
            notes = savedData.notes
            timerSeconds = savedData.timerSeconds
            previousSets = []
            previousLogDate = nil
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

    // MARK: Timer

    private func toggleTimer() {
        isTimerRunning.toggle()
        if isTimerRunning { startTimer() } else { timerTask?.cancel() }
    }

    private func startTimer() {
        timerTask = Task {
            while isTimerRunning && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run { timerSeconds += 1 }
                }
            }
        }
    }

    private func resetTimer() {
        isTimerRunning = false
        timerTask?.cancel()
        timerSeconds = 0
    }

    // MARK: Sets

    private func addSet() {
        sets.append(WorkoutSet(reps: 0, weight: 0))
    }

    private func removeSet(at index: Int) {
        guard index < sets.count else { return }
        sets.remove(at: index)
    }

    private func initializeSets() {
        guard case .exercise(let we) = currentItem else { return }

        // Predefined sets take precedence over history
        if !we.predefinedSets.isEmpty {
            sets = we.predefinedSets.map { _ in WorkoutSet(reps: 0, weight: 0) }
            // Still load weight history as placeholders; reps placeholders come from predefined
            if let (logged, logDate) = lastLoggedSetsWithDate(for: we.exerciseID), !logged.isEmpty {
                previousSets = logged
                previousLogDate = logDate
            } else {
                previousSets = []
                previousLogDate = nil
            }
            return
        }

        // No predefined sets — use history placeholders
        guard let (logged, logDate) = lastLoggedSetsWithDate(for: we.exerciseID), !logged.isEmpty else {
            sets = [WorkoutSet(reps: 0, weight: 0)]
            previousSets = []
            previousLogDate = nil
            return
        }
        previousSets = logged
        previousLogDate = logDate
        sets = logged.map { _ in WorkoutSet(reps: 0, weight: 0) }
    }

    private func lastLoggedSetsWithDate(for exerciseID: UUID) -> ([LoggedSet], Date)? {
        guard let log = logState.sortedLogs.first(where: { log in
            log.exercises.contains(where: { $0.exerciseID == exerciseID && !$0.sets.isEmpty })
        }), let ex = log.exercises.first(where: { $0.exerciseID == exerciseID }) else { return nil }
        return ex.sets.isEmpty ? nil : (ex.sets, log.completedAt)
    }

    private func lastLoggedSets(for exerciseID: UUID) -> [LoggedSet]? {
        lastLoggedSetsWithDate(for: exerciseID).map { $0.0 }
    }

    // MARK: Complete

    private func completeWorkout() {
        saveCurrentData()

        var loggedExercises: [LoggedExercise] = []
        for item in workout.items {
            guard case .exercise(let we) = item,
                  let exercise = exercisesState.exercises.first(where: { $0.id == we.exerciseID }),
                  let savedData = exerciseData[we.exerciseID] else { continue }

            let loggedSets = savedData.sets.map { LoggedSet(reps: $0.reps, weight: $0.weight) }
            loggedExercises.append(LoggedExercise(
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                sets: loggedSets,
                notes: savedData.notes
            ))
        }

        let workoutLog = WorkoutLog(
            workoutName: workout.name,
            completedAt: Date(),
            exercises: loggedExercises,
            notes: "",
            duration: Date().timeIntervalSince(workoutStartTime)
        )

        WorkoutLogState.shared.addLog(workoutLog)
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

// MARK: - Rest Screen

private struct RestScreen: View {
    let restItem: RestItem
    @Binding var secondsRemaining: Int
    @Binding var isRunning: Bool
    @Binding var timerTask: Task<Void, Never>?
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "zzz")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            Text("Rest")
                .font(.title)
                .fontWeight(.bold)

            Text(formatTime(secondsRemaining))
                .font(.system(size: 72, weight: .semibold, design: .monospaced))
                .foregroundColor(secondsRemaining <= 10 ? .red : .primary)

            Text("of \(formatTime(restItem.duration))")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 24) {
                Button(action: { toggleTimer() }) {
                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

                Button(action: {
                    resetTimer()
                }) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: { onSkip() }) {
                Text("Skip Rest")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            secondsRemaining = restItem.duration
        }
    }

    private func toggleTimer() {
        isRunning.toggle()
        if isRunning { startTimer() } else { timerTask?.cancel() }
    }

    private func startTimer() {
        timerTask = Task {
            while isRunning && !Task.isCancelled && secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        if secondsRemaining > 0 {
                            secondsRemaining -= 1
                        }
                        if secondsRemaining == 0 {
                            isRunning = false
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                    }
                }
            }
        }
    }

    private func resetTimer() {
        isRunning = false
        timerTask?.cancel()
        secondsRemaining = restItem.duration
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Workout Set Model

private struct WorkoutSet: Identifiable {
    let id: UUID = UUID()
    var reps: Int
    var weight: Double
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

                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Set").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Reps").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
                                        Text("Weight").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    ForEach(Array(entry.sets.enumerated()), id: \.offset) { idx, set in
                                        HStack {
                                            Text("\(idx + 1)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                                            Text("\(set.reps)").font(.caption).frame(maxWidth: .infinity, alignment: .center)
                                            Text(set.weight == 0 ? "—" : String(format: "%.1f lbs", set.weight)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(6)

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
