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

// MARK: - PredefinedSet collection helpers

private extension Array where Element == PredefinedSet {
    /// Compact summary shown on the exercise row, e.g. "3 × 8 reps", "3 × 30s", "8 reps / 30s / 8 reps"
    var summaryLabel: String {
        guard !isEmpty else { return "" }
        // Check if all sets are the same type and value
        let labels = map { $0.target.label }
        let allSame = Set(labels).count == 1
        if allSame {
            return "\(count) × \(labels[0])"
        } else {
            // Mixed — show each set's label joined
            return labels.joined(separator: " · ")
        }
    }
}

// MARK: - Flow Layout

/// Wraps chips left-to-right, flowing onto new lines as needed.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Workout Info Chip

private struct WorkoutInfoChip: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.40))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(red: 0.92, green: 0.92, blue: 0.94))
        .cornerRadius(5)
    }
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
    @State private var historyWorkout: Workout?
    @State private var statsWorkout: Workout?

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
                        VStack(alignment: .leading, spacing: 4) {
                            // Top row: play icon, name, action buttons
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.black)
                                    .font(.system(size: 20))

                                Text(workout.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
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

                                // History button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    historyWorkout = workout
                                }) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)

                                // Stats button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    statsWorkout = workout
                                }) {
                                    Image(systemName: "chart.bar")
                                        .foregroundColor(.black)
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

                            // Notes line (only shown when non-empty)
                            if !workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(workout.notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            // Info chips — full width, wrapping
                            let exerciseItems = workout.exerciseItems
                            let totalSets = exerciseItems.reduce(0) { $0 + $1.predefinedSets.count }
                            let hasTimer = { if case .none = workout.timerMode { return false }; return true }()
                            // Count how many loops are supersets (2 exercises) vs circuits (3+)
                            let loopMemberCounts: [UUID: Int] = workout.orderedLoopIDs.reduce(into: [:]) { counts, lid in
                                counts[lid] = exerciseItems.filter { $0.loopID == lid }.count
                            }
                            let supersetCount = loopMemberCounts.values.filter { $0 == 2 }.count
                            let circuitCount  = loopMemberCounts.values.filter { $0 >= 3 }.count
                            let hasChips = !exerciseItems.isEmpty || supersetCount > 0 || circuitCount > 0 || totalSets > 0 || hasTimer || workout.warmupSeconds > 0 || workout.cooldownSeconds > 0

                            if hasChips {
                                FlowLayout(spacing: 5) {
                                    if !exerciseItems.isEmpty {
                                        WorkoutInfoChip(label: "\(exerciseItems.count) exercise\(exerciseItems.count == 1 ? "" : "s")", icon: "dumbbell")
                                    }
                                    if totalSets > 0 {
                                        WorkoutInfoChip(label: "\(totalSets) set\(totalSets == 1 ? "" : "s")", icon: "list.number")
                                    }
                                    if hasTimer {
                                        WorkoutInfoChip(label: workout.timerMode.displayName, icon: "timer")
                                    }
                                    if supersetCount > 0 {
                                        WorkoutInfoChip(label: "\(supersetCount) superset\(supersetCount == 1 ? "" : "s")", icon: "arrow.2.circlepath")
                                    }
                                    if circuitCount > 0 {
                                        WorkoutInfoChip(label: "\(circuitCount) circuit\(circuitCount == 1 ? "" : "s")", icon: "arrow.2.circlepath")
                                    }
                                    if workout.warmupSeconds > 0 {
                                        WorkoutInfoChip(label: "Warmup", icon: "flame")
                                    }
                                    if workout.cooldownSeconds > 0 {
                                        WorkoutInfoChip(label: "Cooldown", icon: "snowflake")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            startingWorkout = workout
                        }
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
            .fullScreenCover(isPresented: $showingAdd) {
                WorkoutEditor(title: "Add Workout") { workout in
                    state.addWorkout(workout)
                }
                .environment(exercisesState)
            }
            .fullScreenCover(item: $editingWorkout) { workout in
                WorkoutEditor(title: "Edit Workout", initialWorkout: workout) { updated in
                    state.updateWorkout(updated)
                } onDelete: {
                    state.removeWorkout(id: workout.id)
                }
                .environment(exercisesState)
            }
            .fullScreenCover(item: $startingWorkout) { workout in
                StartWorkoutView(workout: workout)
                    .environment(exercisesState)
                    .environment(MuscleGroupsState.shared)
                    .environment(EquipmentState.shared)
                    .environment(WorkoutLogState.shared)
            }
            .sheet(item: $historyWorkout) { workout in
                WorkoutHistorySheet(workout: workout, logState: WorkoutLogState.shared)
            }
            .sheet(item: $statsWorkout) { workout in
                NavigationStack {
                    WorkoutStatsView(workout: workout)
                        .environment(WorkoutLogState.shared)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { statsWorkout = nil }
                            }
                        }
                }
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
    @State private var editMode: EditMode = .active
    @State private var healthKitActivityType: UInt? = nil
    @State private var timerMode: WorkoutTimerMode = .none
    @State private var autoAdvance: Bool = false
    @State private var loops: [String: WorkoutLoop] = [:]
    @State private var editingLoopID: UUID? = nil
    @State private var warmupSeconds: Int = 0
    @State private var cooldownSeconds: Int = 0

    /// Wrapper to use UUID? as sheet item (UUID is not Identifiable by default).
    private struct LoopEditTarget: Identifiable { let id: UUID }
    private var loopEditTarget: Binding<LoopEditTarget?> {
        Binding(
            get: { editingLoopID.map { LoopEditTarget(id: $0) } },
            set: { editingLoopID = $0?.id }
        )
    }

    /// Tag enum for the timer mode picker (avoids associated-value issues with Picker).
    private enum WorkoutTimerModeTag: Hashable { case none, interval, tabata, emom }
    private var timerModeBinding: Binding<WorkoutTimerModeTag> {
        Binding(
            get: {
                switch timerMode {
                case .none:     return .none
                case .interval: return .interval
                case .tabata:   return .tabata
                case .emom:     return .emom
                }
            },
            set: { tag in
                switch tag {
                case .none:     timerMode = WorkoutTimerMode.none
                case .interval:
                    if case .interval = timerMode { } else {
                        timerMode = .interval(workSeconds: 45, restSeconds: 15)
                    }
                case .tabata:   timerMode = .tabata
                case .emom:     timerMode = .emom
                }
            }
        )
    }

    init(title: String, initialWorkout: Workout? = nil, onSave: @escaping (Workout) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.initialWorkout = initialWorkout
        self.onSave = onSave
        self.onDelete = onDelete

        if let workout = initialWorkout {
            _name = State(initialValue: workout.name)
            _notes = State(initialValue: workout.notes)
            _workoutItems = State(initialValue: workout.items)
            _healthKitActivityType = State(initialValue: workout.healthKitActivityType)
            _timerMode = State(initialValue: workout.timerMode)
            _autoAdvance = State(initialValue: workout.autoAdvance)
            _loops = State(initialValue: workout.loops)
            _warmupSeconds = State(initialValue: workout.warmupSeconds)
            _cooldownSeconds = State(initialValue: workout.cooldownSeconds)
        }
    }

    /// Syncs the loops dict so it contains exactly one entry per active loopID.
    private func syncLoopsDict() {
        var activeIDs = Set<String>()
        for item in workoutItems {
            switch item {
            case .exercise(let e): if let lid = e.loopID { activeIDs.insert(lid.uuidString) }
            case .rest(let r):     if let lid = r.loopID { activeIDs.insert(lid.uuidString) }
            }
        }
        for key in activeIDs where loops[key] == nil {
            if let uuid = UUID(uuidString: key) {
                loops[key] = WorkoutLoop(id: uuid)
            }
        }
        for key in loops.keys where !activeIDs.contains(key) {
            loops.removeValue(forKey: key)
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
                        .lineLimit(1...6)

                    // Warmup + Cooldown side by side
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("Warmup")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            HStack(spacing: 0) {
                                Picker("", selection: Binding(
                                    get: { warmupSeconds / 60 },
                                    set: { warmupSeconds = $0 * 60 + (warmupSeconds % 60) }
                                )) {
                                    ForEach(0..<60) { m in Text("\(m) min").tag(m) }
                                }
                                .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()
                                Picker("", selection: Binding(
                                    get: { (warmupSeconds % 60) / 5 },
                                    set: { warmupSeconds = (warmupSeconds / 60) * 60 + $0 * 5 }
                                )) {
                                    ForEach(0..<12) { i in Text("\(i * 5) sec").tag(i) }
                                }
                                .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()
                            }
                        }

                        Divider()

                        VStack(spacing: 2) {
                            Text("Cooldown")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            HStack(spacing: 0) {
                                Picker("", selection: Binding(
                                    get: { cooldownSeconds / 60 },
                                    set: { cooldownSeconds = $0 * 60 + (cooldownSeconds % 60) }
                                )) {
                                    ForEach(0..<60) { m in Text("\(m) min").tag(m) }
                                }
                                .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()
                                Picker("", selection: Binding(
                                    get: { (cooldownSeconds % 60) / 5 },
                                    set: { cooldownSeconds = (cooldownSeconds / 60) * 60 + $0 * 5 }
                                )) {
                                    ForEach(0..<12) { i in Text("\(i * 5) sec").tag(i) }
                                }
                                .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()
                            }
                        }
                    }
                    .frame(height: 110)

                    // Timer mode picker
                    Picker("Timer Mode", selection: timerModeBinding) {
                        Text("None").tag(WorkoutTimerModeTag.none)
                        Text("Interval").tag(WorkoutTimerModeTag.interval)
                        Text("Tabata").tag(WorkoutTimerModeTag.tabata)
                        Text("EMOM").tag(WorkoutTimerModeTag.emom)
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)

                    // Timer mode descriptions
                    if case .none = timerMode {
                        Text("No automatic timing. Use the stopwatch and advance manually.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    // Interval work/rest duration side by side
                    if case .interval(let w, let r) = timerMode {
                        Text("Countdown per set with a rest between sets.")
                            .font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("Work Duration")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                WorkoutDurationStepper(label: "", seconds: Binding(
                                    get: { w },
                                    set: { timerMode = .interval(workSeconds: $0, restSeconds: r) }
                                ))
                            }
                            Divider()
                            VStack(spacing: 2) {
                                Text("Rest Duration")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                WorkoutDurationStepper(label: "", seconds: Binding(
                                    get: { r },
                                    set: { timerMode = .interval(workSeconds: w, restSeconds: $0) }
                                ))
                            }
                        }
                        .frame(height: 110)
                    }

                    // Tabata note
                    if case .tabata = timerMode {
                        Text("Fixed 20 seconds work / 10 seconds rest per set.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    // EMOM note
                    if case .emom = timerMode {
                        Text("Fixed 60 seconds per set, no rest between sets.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    // Auto-advance toggle — only when a timer is active
                    if case .none = timerMode { } else {
                        Toggle("Auto-advance to next exercise", isOn: $autoAdvance)
                    }
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
                                    orderedLoopIDs: orderedLoopIDs,
                                    muscleGroupsState: muscleGroupsState,
                                    equipmentState: equipmentState,
                                    exercisesState: exercisesState,
                                    loops: $loops,
                                    onEditLoop: { lid in editingLoopID = lid }
                                )
                            case .rest(let r):
                                EditorRestRow(
                                    rest: r,
                                    index: index,
                                    workoutItems: $workoutItems,
                                    orderedLoopIDs: orderedLoopIDs,
                                    loops: $loops,
                                    onEditLoop: { lid in editingLoopID = lid }
                                )
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

                if HealthKitState.shared.exportStrengthWorkouts {
                    Section("Apple Health Activity") {
                        HKActivityTypePicker(rawValue: $healthKitActivityType)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .fullScreenCover(isPresented: $showingPicker) {
                ExercisePickerView(searchText: $searchText) { exerciseID in
                    let item = WorkoutExercise(exerciseID: exerciseID)
                    workoutItems.append(.exercise(item))
                }
                .environment(exercisesState)
                .environment(muscleGroupsState)
                .environment(equipmentState)
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
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
                        syncLoopsDict()
                        let workout = Workout(
                            id: initialWorkout?.id ?? UUID(),
                            name: name,
                            notes: notes,
                            items: workoutItems,
                            isFavorite: initialWorkout?.isFavorite ?? false,
                            healthKitActivityType: healthKitActivityType,
                            timerMode: timerMode,
                            autoAdvance: autoAdvance,
                            loops: loops,
                            warmupSeconds: warmupSeconds,
                            cooldownSeconds: cooldownSeconds
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
            .sheet(item: loopEditTarget) { target in
                LoopEditorSheet(loopID: target.id, loops: $loops, workoutTimerMode: timerMode)
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
    let orderedLoopIDs: [UUID]
    let muscleGroupsState: MuscleGroupsState
    let equipmentState: EquipmentState
    let exercisesState: ExercisesState
    @Binding var loops: [String: WorkoutLoop]
    let onEditLoop: (UUID) -> Void

    private var resolvedExercise: Exercise? {
        exercisesState.exercises.first { $0.id == exercise.exerciseID }
    }

    @State private var showingSetsEditor = false
    @State private var showingLoopMenu = false

    private var isInfoExpanded: Bool { expandedInfoIDs.contains(exercise.id) }

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
        if loops[targetLoopID.uuidString] == nil {
            loops[targetLoopID.uuidString] = WorkoutLoop(id: targetLoopID)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func removeFromLoop() {
        guard case .exercise(var ex) = workoutItems[index] else { return }
        ex.loopID = nil
        workoutItems[index] = .exercise(ex)
        cleanupSingletonLoops()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// After any mutation, clear loopID from items that are the sole remaining member of their loop.
    private func cleanupSingletonLoops() {
        // Count members per loopID (exercises and rests both count)
        var counts: [UUID: Int] = [:]
        for item in workoutItems {
            switch item {
            case .exercise(let e): if let lid = e.loopID { counts[lid, default: 0] += 1 }
            case .rest(let r):     if let lid = r.loopID { counts[lid, default: 0] += 1 }
            }
        }
        // Clear loopID for any item whose loop has fewer than 2 members
        for i in workoutItems.indices {
            switch workoutItems[i] {
            case .exercise(var e):
                if let lid = e.loopID, counts[lid, default: 0] < 2 {
                    e.loopID = nil
                    workoutItems[i] = .exercise(e)
                }
            case .rest(var r):
                if let lid = r.loopID, counts[lid, default: 0] < 2 {
                    r.loopID = nil
                    workoutItems[i] = .rest(r)
                }
            }
        }
        // Remove stale loop dict entries
        for (key, _) in loops {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 2 {
                loops.removeValue(forKey: key)
            }
        }
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
                    // Name row with inline ⓘ button
                    HStack(spacing: 6) {
                        Text(ex.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    // Loop badge — tap to open LoopEditorSheet
                    if let lid = exercise.loopID {
                        let loopIdx = orderedLoopIDs.firstIndex(of: lid) ?? 0
                        let color = loopColorPalette[loopIdx % loopColorPalette.count]
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEditLoop(lid)
                        }) {
                            HStack(spacing: 4) {
                                Text("Loop \(loopIdx + 1)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    // Predefined sets summary (read-only label; pencil button opens editor)
                    if exercise.predefinedSets.isEmpty {
                        Text("No sets defined")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(exercise.predefinedSets.summaryLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Action buttons — top-aligned with exercise name
                HStack(spacing: 12) {
                    // Loop grouping button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingLoopMenu = true
                    }) {
                        Image(systemName: exercise.loopID != nil ? "link.circle.fill" : "link.circle")
                            .foregroundColor(exercise.loopID != nil ? (exerciseLoopColor ?? .green) : .secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Loop Grouping", isPresented: $showingLoopMenu, titleVisibility: .visible) {
                        if exercise.loopID != nil {
                            Button("Remove from Loop", role: .destructive) {
                                removeFromLoop()
                            }
                        } else {
                            // Capture stable copies so subscript access is safe regardless of timing
                            let items = workoutItems
                            let idx = index
                            if idx < items.count {
                                let upIdx: Int? = idx > 0
                                    ? (0..<idx).reversed().first { i in
                                        guard case .exercise = items[i] else { return false }
                                        return true
                                      }
                                    : nil
                                if let upIdx {
                                    Button("Merge Up") {
                                        guard idx < workoutItems.count, upIdx < workoutItems.count,
                                              case .exercise(var cur) = workoutItems[idx],
                                              case .exercise(var other) = workoutItems[upIdx] else { return }
                                        let lid = cur.loopID ?? other.loopID ?? UUID()
                                        cur.loopID = lid; other.loopID = lid
                                        workoutItems[idx] = .exercise(cur)
                                        workoutItems[upIdx] = .exercise(other)
                                        if loops[lid.uuidString] == nil { loops[lid.uuidString] = WorkoutLoop(id: lid) }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                }
                                let downStart = min(idx + 1, items.count)
                                let downIdx: Int? = downStart < items.count
                                    ? (downStart..<items.count).first { i in
                                        guard case .exercise = items[i] else { return false }
                                        return true
                                      }
                                    : nil
                                if let downIdx {
                                    Button("Merge Down") {
                                        guard idx < workoutItems.count, downIdx < workoutItems.count,
                                              case .exercise(var cur) = workoutItems[idx],
                                              case .exercise(var other) = workoutItems[downIdx] else { return }
                                        let lid = cur.loopID ?? other.loopID ?? UUID()
                                        cur.loopID = lid; other.loopID = lid
                                        workoutItems[idx] = .exercise(cur)
                                        workoutItems[downIdx] = .exercise(other)
                                        if loops[lid.uuidString] == nil { loops[lid.uuidString] = WorkoutLoop(id: lid) }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }

                    // Edit sets (pencil)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingSetsEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)

                    // Clone
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let cloned = WorkoutExercise(
                            exerciseID: exercise.exerciseID,
                            loopID: exercise.loopID,
                            predefinedSets: exercise.predefinedSets.map { PredefinedSet(target: $0.target) }
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
                        cleanupSingletonLoops()
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


            }
            .fullScreenCover(isPresented: $showingSetsEditor) {
                SetsEditorSheet(exercise: exercise, index: index, workoutItems: $workoutItems)
            }
    }
}

// MARK: - Sets Editor Sheet

private struct SetsEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let exercise: WorkoutExercise
    let index: Int
    @Binding var workoutItems: [WorkoutItem]

    // Local copy edited in the sheet; committed on Done
    @State private var sets: [PredefinedSet] = []

    private func defaultTarget(after sets: [PredefinedSet]) -> SetTarget {
        sets.last?.target ?? .reps(0)
    }

    var body: some View {
        NavigationStack {
            List {
                if sets.isEmpty {
                    Text("No sets yet — tap + to add one.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                        SetEditorRow(setNumber: idx + 1, set: Binding(
                            get: { sets[idx] },
                            set: { sets[idx] = $0 }
                        ))
                    }
                    .onDelete { offsets in sets.remove(atOffsets: offsets) }
                    .onMove  { from, to  in sets.move(fromOffsets: from, toOffset: to) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            sets.append(PredefinedSet(target: defaultTarget(after: sets)))
                        }) {
                            Image(systemName: "plus")
                        }
                        Button("Save") {
                            // Write back to the workout items
                            guard case .exercise(var ex) = workoutItems[index] else { dismiss(); return }
                            ex.predefinedSets = sets
                            workoutItems[index] = .exercise(ex)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        sets = []
                    } label: {
                        Text("Clear All")
                    }
                    .disabled(sets.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
            }
            .onAppear { sets = exercise.predefinedSets }
        }
    }
}

// MARK: - Single Set Editor Row

private struct SetEditorRow: View {
    let setNumber: Int
    @Binding var set: PredefinedSet

    private var isTimed: Bool {
        if case .timed = set.target { return true }
        return false
    }

    private var repCount: Int {
        if case .reps(let n) = set.target { return n }
        return 0
    }

    private var totalSeconds: Int {
        if case .timed(let s) = set.target { return s }
        return 30
    }

    private var timedMinutes: Int { totalSeconds / 60 }
    private var timedSeconds: Int { totalSeconds % 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Set label + type toggle
            HStack {
                Text("Set \(setNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Picker("", selection: Binding(
                    get: { isTimed },
                    set: { timed in
                        if timed {
                            set.target = .timed(seconds: max(15, totalSeconds))
                        } else {
                            set.target = .reps(repCount)
                        }
                    }
                )) {
                    Text("Reps").tag(false)
                    Text("Timed").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // Value picker wheels
            if isTimed {
                HStack(spacing: 0) {
                    // Minutes wheel (0–59)
                    Picker("", selection: Binding(
                        get: { timedMinutes },
                        set: { set.target = .timed(seconds: $0 * 60 + timedSeconds) }
                    )) {
                        ForEach(0..<60) { m in
                            Text("\(m) min").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    // Seconds wheel (0, 5, 10, ... 55)
                    Picker("", selection: Binding(
                        get: { timedSeconds / 5 },
                        set: { set.target = .timed(seconds: timedMinutes * 60 + $0 * 5) }
                    )) {
                        ForEach(0..<12) { i in
                            Text("\(i * 5) sec").tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 120)
            } else {
                // Reps wheel (0–100)
                Picker("", selection: Binding(
                    get: { repCount },
                    set: { set.target = .reps($0) }
                )) {
                    ForEach(0...100, id: \.self) { n in
                        Text("\(n) reps").tag(n)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Editor Rest Row

private struct EditorRestRow: View {
    let rest: RestItem
    let index: Int
    @Binding var workoutItems: [WorkoutItem]
    let orderedLoopIDs: [UUID]
    @Binding var loops: [String: WorkoutLoop]
    let onEditLoop: (UUID) -> Void
    @State private var showingEditor = false
    @State private var showingLoopMenu = false

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    private var restLoopColor: Color? {
        guard let lid = rest.loopID else { return nil }
        return loopColor(for: lid, in: orderedLoopIDs)
    }

    private func removeFromLoop() {
        guard case .rest(var r) = workoutItems[index] else { return }
        r.loopID = nil
        workoutItems[index] = .rest(r)
        // Clean up singleton loops across all items
        var counts: [UUID: Int] = [:]
        for item in workoutItems {
            switch item {
            case .exercise(let e): if let lid = e.loopID { counts[lid, default: 0] += 1 }
            case .rest(let rv):    if let lid = rv.loopID { counts[lid, default: 0] += 1 }
            }
        }
        for i in workoutItems.indices {
            switch workoutItems[i] {
            case .exercise(var e):
                if let lid = e.loopID, counts[lid, default: 0] < 2 { e.loopID = nil; workoutItems[i] = .exercise(e) }
            case .rest(var rv):
                if let lid = rv.loopID, counts[lid, default: 0] < 2 { rv.loopID = nil; workoutItems[i] = .rest(rv) }
            }
        }
        for (key, _) in loops {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 2 { loops.removeValue(forKey: key) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Loop color bracket — mirrors EditorExerciseRow
            if let color = restLoopColor {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4)
                    .padding(.vertical, 2)
                    .padding(.trailing, 8)
            } else {
                Color.clear.frame(width: 12)
            }

            HStack(spacing: 10) {
                Image(systemName: "zzz")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Rest")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatDuration(rest.duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Loop badge — tap to open LoopEditorSheet
                    if let lid = rest.loopID {
                        let loopIdx = orderedLoopIDs.firstIndex(of: lid) ?? 0
                        let color = loopColorPalette[loopIdx % loopColorPalette.count]
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEditLoop(lid)
                        }) {
                            HStack(spacing: 4) {
                                Text("Loop \(loopIdx + 1)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Link button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingLoopMenu = true
                }) {
                    Image(systemName: rest.loopID != nil ? "link.circle.fill" : "link.circle")
                        .foregroundColor(rest.loopID != nil ? (restLoopColor ?? .green) : .secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Loop Grouping", isPresented: $showingLoopMenu, titleVisibility: .visible) {
                    if rest.loopID != nil {
                        Button("Remove from Loop", role: .destructive) {
                            removeFromLoop()
                        }
                    } else {
                        let items = workoutItems
                        let idx = index
                        let upIdx: Int? = idx > 0
                            ? (0..<idx).reversed().first { i in
                                guard case .exercise = items[i] else { return false }
                                return true
                              }
                            : nil
                        let downStart = min(idx + 1, items.count)
                        let downIdx: Int? = downStart < items.count
                            ? (downStart..<items.count).first { i in
                                guard case .exercise = items[i] else { return false }
                                return true
                              }
                            : nil
                        if let upIdx {
                            Button("Merge Up") {
                                guard upIdx < workoutItems.count, idx < workoutItems.count,
                                      case .exercise(var above) = workoutItems[upIdx],
                                      case .rest(var selfRest) = workoutItems[idx] else { return }
                                let lid: UUID
                                if let downIdx, downIdx < workoutItems.count,
                                   case .exercise(var below) = workoutItems[downIdx] {
                                    lid = above.loopID ?? below.loopID ?? UUID()
                                    above.loopID = lid
                                    below.loopID = lid
                                    workoutItems[upIdx] = .exercise(above)
                                    workoutItems[downIdx] = .exercise(below)
                                } else {
                                    lid = above.loopID ?? UUID()
                                    above.loopID = lid
                                    workoutItems[upIdx] = .exercise(above)
                                }
                                selfRest.loopID = lid
                                workoutItems[idx] = .rest(selfRest)
                                if loops[lid.uuidString] == nil { loops[lid.uuidString] = WorkoutLoop(id: lid) }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                        if let downIdx {
                            Button("Merge Down") {
                                guard downIdx < workoutItems.count, idx < workoutItems.count,
                                      case .exercise(var below) = workoutItems[downIdx],
                                      case .rest(var selfRest) = workoutItems[idx] else { return }
                                let lid: UUID
                                if let upIdx, upIdx < workoutItems.count,
                                   case .exercise(var above) = workoutItems[upIdx] {
                                    lid = above.loopID ?? below.loopID ?? UUID()
                                    above.loopID = lid
                                    below.loopID = lid
                                    workoutItems[upIdx] = .exercise(above)
                                    workoutItems[downIdx] = .exercise(below)
                                } else {
                                    lid = below.loopID ?? UUID()
                                    below.loopID = lid
                                    workoutItems[downIdx] = .exercise(below)
                                }
                                selfRest.loopID = lid
                                workoutItems[idx] = .rest(selfRest)
                                if loops[lid.uuidString] == nil { loops[lid.uuidString] = WorkoutLoop(id: lid) }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                // Edit button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingEditor = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

                // Clone button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    workoutItems.insert(.rest(RestItem(duration: rest.duration)), at: index + 1)
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

                // Delete button
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
        .fullScreenCover(isPresented: $showingEditor) {
            RestEditorSheet(rest: rest) { updated in
                guard case .rest = workoutItems[index] else { return }
                workoutItems[index] = .rest(updated)
            }
        }
    }
}

// MARK: - Rest Editor Sheet

private struct RestEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let rest: RestItem
    let onSave: (RestItem) -> Void

    @State private var minutes: Int
    @State private var secondsIndex: Int   // index into 0,5,10,...,55

    init(rest: RestItem, onSave: @escaping (RestItem) -> Void) {
        self.rest = rest
        self.onSave = onSave
        _minutes = State(initialValue: rest.duration / 60)
        _secondsIndex = State(initialValue: (rest.duration % 60) / 5)
    }

    private var totalSeconds: Int { minutes * 60 + secondsIndex * 5 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 0) {
                        Picker("", selection: $minutes) {
                            ForEach(0..<60) { m in Text("\(m) min").tag(m) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("", selection: $secondsIndex) {
                            ForEach(0..<12) { i in Text("\(i * 5) sec").tag(i) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 120)
                } header: {
                    Text("Rest Duration")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Edit Rest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var updated = rest
                        updated.duration = totalSeconds
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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
            .filter { exercise in
                if exercise.name.localizedCaseInsensitiveContains(trimmed) { return true }
                let muscleNames = (exercise.primaryMuscleGroupIDs + exercise.secondaryMuscleGroupIDs)
                    .compactMap { id in muscleGroupsState.sortedGroups.first { $0.id == id }?.name }
                if muscleNames.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) { return true }
                let equipmentNames = exercise.equipmentIDs
                    .compactMap { id in equipmentState.items.first { $0.id == id }?.name }
                if equipmentNames.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) { return true }
                return false
            }
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
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
    /// Which set-round (0-based) we are on when cycling through a loop group.
    @State private var loopRound: Int = 0
    @State private var timerSeconds: Int = 0
    @State private var isTimerRunning: Bool = true
    @State private var expandedInfo: Bool = false
    @State private var sets: [WorkoutSet] = []
    @State private var previousSets: [LoggedSet] = []
    @State private var previousLogDate: Date? = nil
    @State private var notes: String = ""
    @State private var usedEquipmentIDs: Set<UUID> = []
    @State private var exerciseData: [UUID: (sets: [WorkoutSet], notes: String, timerSeconds: Int, usedEquipmentIDs: Set<UUID>, phaseIndex: Int, phaseElapsed: Int, phaseTimerDone: Bool)] = [:]
    @State private var showingHistory: Bool = false
    /// Active countdown tasks keyed by WorkoutSet.id — for per-set timed countdowns.
    @State private var setTimerTasks: [UUID: Task<Void, Never>] = [:]
    // Phase timer state (used when workout has a timer mode set)
    @State private var exercisePhases: [WorkoutTimerPhase] = []
    @State private var phaseIndex: Int = 0
    @State private var phaseElapsed: Int = 0
    @State private var phaseTimerRunning: Bool = false
    @State private var phaseTimerTask: Task<Void, Never>? = nil
    @State private var phaseTimerDone: Bool = false
    // Rest screen state
    @State private var restSecondsRemaining: Int = 60
    @State private var isRestTimerRunning: Bool = false
    /// Keyed by RestItem.id — stores (configured, secondsRemaining) when we navigate away
    @State private var restData: [UUID: (configured: Int, remaining: Int)] = [:]
    @State private var showingCancelConfirm: Bool = false
    // Warmup / cooldown phase
    @State private var warmupCooldownSecondsRemaining: Int = 0
    @State private var warmupCooldownRunning: Bool = false
    @State private var showingWarmup: Bool = false
    @State private var showingCooldown: Bool = false

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

    private var currentTimerMode: WorkoutTimerMode {
        guard let we = currentWorkoutExercise else { return WorkoutTimerMode.none }
        return workout.effectiveTimerMode(for: we)
    }

    private var isTimedMode: Bool {
        if case .none = currentTimerMode { return false }
        return true
    }

    private var totalItems: Int { workout.items.count }

    // MARK: Loop helpers

    /// The loopID of the current item (works for both exercise and rest items).
    private var currentLoopID: UUID? {
        switch currentItem {
        case .exercise(let we): return we.loopID
        case .rest(let r):      return r.loopID
        case .none:             return nil
        }
    }

    /// Indices in workout.items that belong to the same loop as the current item, in order.
    /// Includes both exercise and rest items that share the loop ID.
    private var currentLoopIndices: [Int] {
        guard let lid = currentLoopID else { return [] }
        return workout.items.indices.filter { i in
            switch workout.items[i] {
            case .exercise(let e): return e.loopID == lid
            case .rest(let r):     return r.loopID == lid
            }
        }
    }

    /// True if the current item is part of a loop group.
    private var isInLoop: Bool { !currentLoopIndices.isEmpty }

    /// Position of the current item within its loop group (0-based).
    private var loopPosition: Int {
        currentLoopIndices.firstIndex(of: currentItemIndex) ?? 0
    }

    /// Total number of set-rounds for the current loop (prefer WorkoutLoop.rounds, fall back to max predefined sets, min 1).
    private var loopTotalRounds: Int {
        guard isInLoop else { return 0 }
        // Fallback: max predefined set count across all loop members
        let predefinedMax = currentLoopIndices.compactMap { idx -> Int? in
            guard case .exercise(let e) = workout.items[idx] else { return nil }
            return e.predefinedSets.isEmpty ? nil : e.predefinedSets.count
        }.max() ?? 0
        let fallback = predefinedMax > 0 ? predefinedMax : 1
        // Explicit WorkoutLoop.rounds takes precedence, but keep predefined max if it's higher
        if case .exercise(let we) = currentItem,
           let lid = we.loopID,
           let loop = workout.loops[lid.uuidString] {
            return Swift.max(loop.rounds, fallback)
        }
        return fallback
    }

    /// Nav-bar label: shows loop context when in a loop, otherwise plain "X of Y".
    private var progressLabel: String {
        if isInLoop {
            // Count only exercise members for the "Ex X of Y" label
            let exerciseIndices = currentLoopIndices.filter {
                if case .exercise = workout.items[$0] { return true }
                return false
            }
            let exercisePos = (exerciseIndices.firstIndex(of: currentItemIndex) ?? 0) + 1
            let exerciseTotal = max(exerciseIndices.count, 1)
            let round = loopRound + 1
            let rounds = loopTotalRounds
            if rounds > 1 {
                return "Round \(round) of \(rounds) · Ex \(exercisePos) of \(exerciseTotal)"
            } else {
                return "Loop · Ex \(exercisePos) of \(exerciseTotal)"
            }
        }
        return "\(currentItemIndex + 1) of \(totalItems)"
    }

    public init(workout: Workout) {
        self.workout = workout
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Navigation bar with item count
                let atStart = currentItemIndex == 0 && loopRound == 0
                let atEnd = !canGoNext
                let singleItem = totalItems <= 1
                HStack {
                    // Left arrow: hidden when only 1 item or at the very start
                    if !singleItem && !atStart {
                        Button(action: { previousItem() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                        }
                    } else {
                        // Invisible placeholder keeps the label centred
                        Image(systemName: "chevron.left").opacity(0)
                    }

                    Spacer()

                    Text(progressLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    // Right arrow: hidden when only 1 item or on the last item
                    if !singleItem && !atEnd {
                        Button(action: { nextItem() }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.black)
                        }
                    } else {
                        Image(systemName: "chevron.right").opacity(0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.98, green: 0.98, blue: 1.0))

                if showingWarmup {
                    // WARMUP SCREEN
                    WarmupCooldownScreen(
                        label: "Warmup",
                        iconName: "flame.fill",
                        totalSeconds: workout.warmupSeconds,
                        secondsRemaining: $warmupCooldownSecondsRemaining,
                        isRunning: $warmupCooldownRunning,
                        onFinish: { showingWarmup = false }
                    )
                } else if showingCooldown {
                    // COOLDOWN SCREEN
                    WarmupCooldownScreen(
                        label: "Cooldown",
                        iconName: "snowflake",
                        totalSeconds: workout.cooldownSeconds,
                        secondsRemaining: $warmupCooldownSecondsRemaining,
                        isRunning: $warmupCooldownRunning,
                        onFinish: {
                            showingCooldown = false
                            completeWorkout()
                        }
                    )
                } else if let restItem = currentRestItem {
                    // REST SCREEN
                    RestScreen(
                        restItem: restItem,
                        secondsRemaining: $restSecondsRemaining,
                        isRunning: $isRestTimerRunning,
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

            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingCancelConfirm = true }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("🏁 Finish") {
                        if workout.cooldownSeconds > 0 {
                            warmupCooldownSecondsRemaining = workout.cooldownSeconds
                            warmupCooldownRunning = true
                            showingCooldown = true
                        } else {
                            completeWorkout()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                }
            }
            .alert("Cancel Workout?", isPresented: $showingCancelConfirm) {
                Button("Keep Going", role: .cancel) { }
                Button("Cancel Workout", role: .destructive) { dismiss() }
            } message: {
                Text("Your progress will not be saved.")
            }
        }
        .onAppear {
            if workout.warmupSeconds > 0 {
                warmupCooldownSecondsRemaining = workout.warmupSeconds
                warmupCooldownRunning = true
                showingWarmup = true
            }
            loadItemData()
        }
        .onDisappear {
            cancelPhaseTimer()
            cancelAllSetTimers()
        }
        // SwiftUI manages this task's lifecycle: starts when isTimerRunning becomes true,
        // cancels automatically when it becomes false or the view disappears.
        .task(id: isTimerRunning) {
            guard isTimerRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                timerSeconds += 1
            }
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
                let allMuscles: String = (exPrimaryGroups + exSecondaryGroups).map(\.name).joined(separator: ", ")
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
                    //Text("Equipment: \(equipmentNames)").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)

            Divider().padding(.horizontal, 16)
        }

        // Timer section — phase ring when in timed mode, stopwatch otherwise
        if isTimedMode {
            exercisePhaseTimerView()
                .padding(.horizontal, 16)
        } else {
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
        }

        setsSection(exercise: exercise, we: we)

        // Equipment used section — compact tag chips, only shown when exercise has equipment assigned
        let exerciseEquipment = exercise.equipmentIDs.compactMap { id in
            equipmentState.sortedItems.first { $0.id == id }
        }
        if !exerciseEquipment.isEmpty {
            HStack(spacing: 6) {
                Text("Equipment:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(exerciseEquipment) { item in
                    let selected = usedEquipmentIDs.contains(item.id)
                    Button(action: {
                        if selected { usedEquipmentIDs.remove(item.id) }
                        else { usedEquipmentIDs.insert(item.id) }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11))
                                .foregroundColor(selected ? .white : .secondary)
                            Text(item.name)
                                .font(.caption)
                                .foregroundColor(selected ? .white : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selected ? Color.black : Color(red: 0.93, green: 0.93, blue: 0.95))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }

        // Notes section
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField("Add notes...", text: $notes, axis: .vertical)
                .lineLimit(1...6)
                .font(.caption)
                .padding(8)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Phase Timer View

    @ViewBuilder
    private func exercisePhaseTimerView() -> some View {
        let phases = exercisePhases
        let currentPhase: WorkoutTimerPhase? = phaseIndex < phases.count ? phases[phaseIndex] : nil
        let phaseDuration = currentPhase?.duration ?? 1
        let remaining = max(0, phaseDuration - phaseElapsed)
        let progress: Double = phaseDuration > 0 ? Double(phaseElapsed) / Double(phaseDuration) : 1.0
        let isWork = currentPhase?.isWork ?? true
        let ringColor: Color = phaseTimerDone ? .green : (isWork ? .black : .blue)

        VStack(spacing: 16) {
            // Phase label
            Text(phaseTimerDone ? (workout.autoAdvance ? "Advancing..." : "Done") : (currentPhase?.label ?? ""))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(phaseTimerDone ? .green : .primary)

            // Circular progress ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)

                // Center content
                if phaseTimerDone {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.green)
                        if !workout.autoAdvance {
                            Text("Tap to continue")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(remaining >= 60
                         ? String(format: "%d:%02d", remaining / 60, remaining % 60)
                         : "\(remaining)s")
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(remaining <= 5 && remaining > 0 ? .red : .primary)
                }
            }
            .frame(width: 200, height: 200)

            // Controls
            if phaseTimerDone {
                if !workout.autoAdvance {
                    Button(action: { nextItem() }) {
                        Text("Next Exercise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 32) {
                    // Restart
                    Button(action: { resetPhaseTimer(); startPhaseTick() }) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)

                    // Play / Pause
                    Button(action: {
                        if phaseTimerRunning { pausePhaseTimer() } else { startPhaseTick() }
                    }) {
                        Image(systemName: phaseTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)

                    // Skip
                    Button(action: { skipPhase() }) {
                        Image(systemName: "forward.end.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .cornerRadius(12)
    }

    // MARK: Sets Section

    @ViewBuilder
    private func setsSection(exercise: Exercise, we: WorkoutExercise) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Sets")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if !we.predefinedSets.isEmpty {
                    Text("(target: \(we.predefinedSets.summaryLabel))")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                } else if !previousSets.isEmpty {
                    let dateLabel: String = {
                        guard let date = previousLogDate else { return "" }
                        let cal = Calendar.current
                        let startOfLog = cal.startOfDay(for: date)
                        let startOfToday = cal.startOfDay(for: Date())
                        let days = cal.dateComponents([.day], from: startOfLog, to: startOfToday).day ?? 0
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
                        setRow(index: index, set: set, we: we)
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
    }

    @ViewBuilder private func setRow(index: Int, set: WorkoutSet, we: WorkoutExercise) -> some View {
        let isActiveRound = isInLoop && index == loopRound
        let isTimed: Bool = {
            guard !we.predefinedSets.isEmpty, index < we.predefinedSets.count else { return false }
            if case .timed = we.predefinedSets[index].target { return true }
            return false
        }()

        let repPlaceholder: String = {
            if !we.predefinedSets.isEmpty && index < we.predefinedSets.count {
                if case .reps(let n) = we.predefinedSets[index].target, n > 0 { return "\(n)" }
                return ""
            } else if index < previousSets.count && previousSets[index].reps > 0 {
                return "\(previousSets[index].reps)"
            }
            return ""
        }()
        let weightPlaceholder = index < previousSets.count && previousSets[index].weight > 0
            ? String(format: "%.2f", previousSets[index].weight) : ""

        VStack(alignment: .leading, spacing: 6) {
            // Set / Reps / Weight / Delete row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.6))
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .center)
                        .padding(.horizontal, 6)
                        .background(Color(red: 0.98, green: 0.98, blue: 1.0))
                        .cornerRadius(4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.6))
                    TextField(repPlaceholder, text: Binding(
                        get: { set.reps == 0 ? "" : "\(set.reps)" },
                        set: {
                            if let v = Int($0) { sets[index].reps = v }
                            else if $0.isEmpty { sets[index].reps = 0 }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .font(.caption)
                    .frame(minHeight: 28)
                    .padding(.horizontal, 6)
                    .background(Color(red: 0.98, green: 0.98, blue: 1.0))
                    .cornerRadius(4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.6))
                    TextField(weightPlaceholder, text: Binding(
                        get: { sets[index].weightText },
                        set: { sets[index].weightText = $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .font(.caption)
                    .frame(minHeight: 28)
                    .padding(.horizontal, 6)
                    .background(Color(red: 0.98, green: 0.98, blue: 1.0))
                    .cornerRadius(4)
                    .onSubmit {
                        let parsed = Double(sets[index].weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        sets[index].weight = parsed
                        if parsed == 0 { sets[index].weightText = "" }
                    }
                    .onChange(of: sets[index].weightText) { _, newVal in
                        // Allow digits and at most one decimal separator; commit to weight on every valid change
                        let parsed = Double(newVal.replacingOccurrences(of: ",", with: "."))
                        sets[index].weight = parsed ?? sets[index].weight
                    }
                }

                Button(action: { removeSet(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }

            // Timed countdown row — shown below when this set's target is timed (hidden in phase-timer mode)
            if isTimed && !isTimedMode {
                HStack(spacing: 10) {
                    Text("Timer")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.6))
                        .frame(width: 36, alignment: .leading)

                    Button(action: { toggleSetTimer(setID: set.id, setIndex: index) }) {
                        Image(systemName: set.isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(set.timedSecondsRemaining == 0 ? .green : .black)
                    }
                    .buttonStyle(.plain)

                    let rem = set.timedSecondsRemaining
                    Text(rem >= 60
                         ? String(format: "%d:%02d", rem / 60, rem % 60)
                         : "\(rem)s")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(rem == 0 ? Color.green.opacity(0.15) : Color(red: 0.98, green: 0.98, blue: 1.0))
                        .cornerRadius(6)

                    Button(action: { resetSetTimer(setIndex: index, predefinedSets: we.predefinedSets) }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(isActiveRound ? 6 : 0)
        .background(isActiveRound ? Color.black.opacity(0.07) : Color.clear)
        .cornerRadius(isActiveRound ? 6 : 0)
        .overlay(
            isActiveRound
                ? RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.55), lineWidth: 1.5)
                : nil
        )
    }

    // MARK: Navigation

    /// Whether a loop member at the given index is still active for the given round.
    /// Rest items are always active. Exercises are active if the round hasn't exceeded their set count.
    private func loopMemberActive(at itemIndex: Int, round: Int) -> Bool {
        switch workout.items[itemIndex] {
        case .rest:
            return true  // rest items are always visited every round
        case .exercise(let e):
            let memberRounds = e.predefinedSets.isEmpty ? loopTotalRounds : e.predefinedSets.count
            return round < memberRounds
        }
    }

    private var canGoNext: Bool {
        if isInLoop {
            let loopIndices = currentLoopIndices
            let pos = loopPosition
            let isLastRound = loopRound >= loopTotalRounds - 1

            // Check if any later member in this round is still active
            for candidatePos in (pos + 1)..<loopIndices.count {
                if loopMemberActive(at: loopIndices[candidatePos], round: loopRound) { return true }
            }
            // No more active members this round — can go next if there are more rounds
            if !isLastRound { return true }
            // All rounds done — can still advance if there's an item after the loop
            return loopIndices.last.map { $0 < totalItems - 1 } ?? false
        }
        return currentItemIndex < totalItems - 1
    }

    private func nextItem() {
        guard canGoNext else { return }
        saveCurrentData()

        if isInLoop {
            let loopIndices = currentLoopIndices
            let pos = loopPosition
            let isLastRound  = loopRound >= loopTotalRounds - 1

            // Find the next member in this round that is still active
            var nextPos: Int? = nil
            for candidatePos in (pos + 1)..<loopIndices.count {
                if loopMemberActive(at: loopIndices[candidatePos], round: loopRound) {
                    nextPos = candidatePos
                    break
                }
            }

            if let nextPos {
                // Move to the next active member at the same round
                currentItemIndex = loopIndices[nextPos]
            } else if !isLastRound {
                // All active members done for this round — start next round at first active member
                let nextRound = loopRound + 1
                var firstActivePos: Int? = nil
                for candidatePos in 0..<loopIndices.count {
                    if loopMemberActive(at: loopIndices[candidatePos], round: nextRound) {
                        firstActivePos = candidatePos
                        break
                    }
                }
                loopRound += 1
                currentItemIndex = loopIndices[firstActivePos ?? 0]
            } else {
                // All rounds done — exit the loop to the item after it
                loopRound = 0
                currentItemIndex = loopIndices.last! + 1
            }
        } else {
            loopRound = 0
            currentItemIndex += 1
        }

        loadItemData()
    }

    private func previousItem() {
        saveCurrentData()

        if isInLoop {
            let loopIndices = currentLoopIndices
            let pos = loopPosition

            if pos > 0 {
                // Move to previous member at same round
                currentItemIndex = loopIndices[pos - 1]
            } else if loopRound > 0 {
                // Go back to last member of previous round
                loopRound -= 1
                currentItemIndex = loopIndices.last!
            } else {
                // At the very start of the loop — go to item before the loop
                if let firstLoopIdx = loopIndices.first, firstLoopIdx > 0 {
                    loopRound = 0
                    currentItemIndex = firstLoopIdx - 1
                }
            }
        } else {
            guard currentItemIndex > 0 else { return }
            loopRound = 0
            currentItemIndex -= 1
        }

        loadItemData()
    }

    private func saveCurrentData() {
        cancelAllSetTimers()
        cancelPhaseTimer()
        isTimerRunning = false
        isRestTimerRunning = false
        switch currentItem {
        case .exercise(let we):
            exerciseData[we.id] = (sets: sets, notes: notes, timerSeconds: timerSeconds, usedEquipmentIDs: usedEquipmentIDs, phaseIndex: phaseIndex, phaseElapsed: phaseElapsed, phaseTimerDone: phaseTimerDone)
        case .rest(let r):
            restData[r.id] = (configured: r.duration, remaining: restSecondsRemaining)
        case .none:
            break
        }
    }

    private func loadItemData() {
        // Reset rest timer state (RestScreen's .task handles its own lifecycle)
        isRestTimerRunning = false

        if case .rest(let r) = currentItem {
            restSecondsRemaining = r.duration
            isTimerRunning = false
            return
        }

        guard case .exercise(let we) = currentItem else { return }

        if let savedData = exerciseData[we.id] {
            sets = savedData.sets
            notes = savedData.notes
            timerSeconds = savedData.timerSeconds
            usedEquipmentIDs = savedData.usedEquipmentIDs
            phaseIndex = savedData.phaseIndex
            phaseElapsed = savedData.phaseElapsed
            phaseTimerDone = savedData.phaseTimerDone
            previousSets = []
            previousLogDate = nil
        } else {
            sets = []
            notes = ""
            timerSeconds = 0
            phaseIndex = 0
            phaseElapsed = 0
            phaseTimerDone = false
            // Seed equipment from the exercise's defaults; fall back to "None"-only auto-select
            if let exercise = exercisesState.exercises.first(where: { $0.id == we.exerciseID }) {
                if !exercise.defaultEquipmentIDs.isEmpty {
                    usedEquipmentIDs = Set(exercise.defaultEquipmentIDs)
                } else {
                    // Legacy fallback: auto-select if "None" is the only assigned equipment
                    let equipment = exercise.equipmentIDs.compactMap { id in equipmentState.sortedItems.first { $0.id == id } }
                    if equipment.count == 1, equipment[0].name.lowercased() == "none" {
                        usedEquipmentIDs = [equipment[0].id]
                    } else {
                        usedEquipmentIDs = []
                    }
                }
            } else {
                usedEquipmentIDs = []
            }
            initializeSets()
        }

        expandedInfo = false

        if isTimedMode {
            // Phase timer mode: build phases and start the tick
            exercisePhases = buildExercisePhases(for: we, mode: currentTimerMode)
            isTimerRunning = false  // disable stopwatch in timed mode
            if !phaseTimerDone {
                startPhaseTick()
            }
        } else {
            // Standard stopwatch mode
            cancelPhaseTimer()
            isTimerRunning = true

            // Auto-start the timed countdown for the active loop round, if applicable
            if !isTimedMode, isInLoop, loopRound < sets.count {
                if loopRound < we.predefinedSets.count,
                   case .timed = we.predefinedSets[loopRound].target {
                    // Small delay so the view has settled before the timer fires
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await MainActor.run {
                            toggleSetTimer(setID: sets[loopRound].id, setIndex: loopRound)
                        }
                    }
                }
            }
        }
    }

    // MARK: Timer

    private func toggleTimer() {
        isTimerRunning.toggle()
    }

    private func resetTimer() {
        isTimerRunning = false
        timerSeconds = 0
    }

    // MARK: Phase timer (workout-level timed mode)

    private func buildExercisePhases(for we: WorkoutExercise, mode: WorkoutTimerMode) -> [WorkoutTimerPhase] {
        guard mode.workSeconds > 0 else { return [] }
        // In a loop each visit = one round = one set slot; phase timer covers just this visit.
        // Outside loops, cover all sets in one go.
        let setCount: Int
        if isInLoop {
            setCount = 1
        } else {
            setCount = max(1, we.predefinedSets.isEmpty ? sets.count : we.predefinedSets.count)
        }
        let totalRounds = isInLoop ? loopTotalRounds : setCount
        var phases: [WorkoutTimerPhase] = []
        for i in 0..<setCount {
            let setIdx = isInLoop ? loopRound : i
            let workLabel: String
            if isInLoop {
                workLabel = totalRounds > 1 ? "Set \(loopRound + 1) of \(totalRounds) — Work" : "Work"
            } else {
                workLabel = setCount == 1 ? "Work" : "Set \(i + 1) of \(setCount) — Work"
            }
            phases.append(WorkoutTimerPhase(label: workLabel, duration: mode.workSeconds, isWork: true, setIndex: setIdx))
            if mode.restSeconds > 0 && i < setCount - 1 {
                let restLabel = setCount == 1 ? "Rest" : "Set \(i + 1) of \(setCount) — Rest"
                phases.append(WorkoutTimerPhase(label: restLabel, duration: mode.restSeconds, isWork: false, setIndex: setIdx))
            }
        }
        return phases
    }

    private func startPhaseTick() {
        guard !phaseTimerRunning else { return }
        phaseTimerRunning = true
        phaseTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run { tickPhase() }
            }
        }
    }

    private func pausePhaseTimer() {
        phaseTimerTask?.cancel()
        phaseTimerTask = nil
        phaseTimerRunning = false
    }

    private func resetPhaseTimer() {
        pausePhaseTimer()
        phaseIndex = 0
        phaseElapsed = 0
        phaseTimerDone = false
    }

    private func cancelPhaseTimer() {
        resetPhaseTimer()
        exercisePhases = []
    }

    private func skipPhase() {
        let nextIdx = phaseIndex + 1
        if nextIdx < exercisePhases.count {
            phaseIndex = nextIdx
            phaseElapsed = 0
        } else {
            allPhasesDone()
        }
    }

    private func tickPhase() {
        guard !phaseTimerDone, phaseIndex < exercisePhases.count else { return }
        phaseElapsed += 1
        if phaseElapsed >= exercisePhases[phaseIndex].duration {
            let nextIdx = phaseIndex + 1
            if nextIdx < exercisePhases.count {
                phaseIndex = nextIdx
                phaseElapsed = 0
            } else {
                allPhasesDone()
            }
        }
    }

    private func allPhasesDone() {
        pausePhaseTimer()
        phaseTimerDone = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if workout.autoAdvance && canGoNext {
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    // Guard: only advance if phaseTimerDone is still true (user hasn't navigated away)
                    guard phaseTimerDone else { return }
                    nextItem()
                }
            }
        }
    }

    // MARK: Per-set timed countdown

    private func toggleSetTimer(setID: UUID, setIndex: Int) {
        guard setIndex < sets.count else { return }
        if sets[setIndex].isTimerRunning {
            // Pause
            setTimerTasks[setID]?.cancel()
            setTimerTasks[setID] = nil
            sets[setIndex].isTimerRunning = false
        } else {
            // Start (reset to predefined duration if at 0)
            sets[setIndex].isTimerRunning = true
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        guard setIndex < sets.count, sets[setIndex].isTimerRunning else { return }
                        if sets[setIndex].timedSecondsRemaining > 0 {
                            sets[setIndex].timedSecondsRemaining -= 1
                        }
                        if sets[setIndex].timedSecondsRemaining == 0 {
                            sets[setIndex].isTimerRunning = false
                            setTimerTasks[setID]?.cancel()
                            setTimerTasks[setID] = nil
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                    }
                }
            }
            setTimerTasks[setID] = task
        }
    }

    private func resetSetTimer(setIndex: Int, predefinedSets: [PredefinedSet]) {
        guard setIndex < sets.count else { return }
        let setID = sets[setIndex].id
        setTimerTasks[setID]?.cancel()
        setTimerTasks[setID] = nil
        sets[setIndex].isTimerRunning = false
        if setIndex < predefinedSets.count, case .timed(let s) = predefinedSets[setIndex].target {
            sets[setIndex].timedSecondsRemaining = s
        }
    }

    private func cancelAllSetTimers() {
        for (_, task) in setTimerTasks { task.cancel() }
        setTimerTasks.removeAll()
        for i in sets.indices { sets[i].isTimerRunning = false }
    }

    // MARK: Sets

    private func addSet() {
        sets.append(WorkoutSet(reps: 0, weight: 0))
    }

    private func removeSet(at index: Int) {
        guard index < sets.count else { return }
        sets.remove(at: index)
    }

    /// How many sets to pre-seed for this exercise when it is part of a timed loop.
    /// Exercises with predefined sets get one slot per predefined set (= one per round they're active).
    /// Exercises with no predefined sets get one slot per round they'll be visited (loopTotalRounds).
    private func exerciseRoundsInLoop(_ we: WorkoutExercise) -> Int {
        guard isInLoop else { return 1 }
        if !we.predefinedSets.isEmpty { return we.predefinedSets.count }
        return loopTotalRounds
    }

    private func initializeSets() {
        guard case .exercise(let we) = currentItem else { return }

        // Predefined sets take precedence over history
        if !we.predefinedSets.isEmpty {
            sets = we.predefinedSets.map { predef -> WorkoutSet in
                var ws = WorkoutSet(reps: 0, weight: 0)
                if case .timed(let s) = predef.target {
                    ws.timedSecondsRemaining = s
                }
                return ws
            }
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

        // In a loop with a timer mode: seed one set per round this exercise participates in.
        // Use the exercise's own predefined set count if available; otherwise just 1 per round it's active for.
        if isInLoop && isTimedMode {
            let exerciseRounds = exerciseRoundsInLoop(we)
            sets = (0..<exerciseRounds).map { _ in WorkoutSet(reps: 0, weight: 0) }
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
        var loggedRests: [LoggedRest] = []

        for (orderIndex, item) in workout.items.enumerated() {
            switch item {
            case .exercise(let we):
                guard let exercise = exercisesState.exercises.first(where: { $0.id == we.exerciseID }),
                      let savedData = exerciseData[we.id] else { continue }

                // Include per-set timed duration: initial target minus remaining = elapsed
                let loggedSets = savedData.sets.enumerated().map { idx, ws -> LoggedSet in
                    var initialTimed = 0
                    if idx < we.predefinedSets.count,
                       case .timed(let s) = we.predefinedSets[idx].target {
                        initialTimed = s
                    }
                    let elapsed = initialTimed > 0 ? max(0, initialTimed - ws.timedSecondsRemaining) : 0
                    return LoggedSet(reps: ws.reps, weight: ws.weight, timedSeconds: elapsed)
                }

                loggedExercises.append(LoggedExercise(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    sets: loggedSets,
                    notes: savedData.notes,
                    activeSeconds: savedData.timerSeconds,
                    usedEquipmentIDs: Array(savedData.usedEquipmentIDs),
                    orderIndex: orderIndex,
                    loopID: we.loopID
                ))

            case .rest(let r):
                let data = restData[r.id]
                let configured = data?.configured ?? r.duration
                let remaining = data?.remaining ?? r.duration
                let actual = max(0, configured - remaining)
                loggedRests.append(LoggedRest(configuredDuration: configured, actualDuration: actual, orderIndex: orderIndex))
            }
        }

        // Total active duration = sum of per-exercise stopwatch values
        let totalActiveSeconds = exerciseData.values.reduce(0) { $0 + $1.timerSeconds }

        let workoutLog = WorkoutLog(
            workoutName: workout.name,
            completedAt: Date(),
            exercises: loggedExercises,
            restPeriods: loggedRests,
            notes: "",
            duration: TimeInterval(totalActiveSeconds)
        )

        WorkoutLogState.shared.addLog(
            workoutLog,
            exportToHealthKit: HealthKitState.shared.exportStrengthWorkouts,
            activityTypeRaw: workout.healthKitActivityType
        )
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
    let onSkip: () -> Void

    private var ringProgress: Double {
        guard restItem.duration > 0 else { return 0 }
        return Double(secondsRemaining) / Double(restItem.duration)
    }

    private var ringColor: Color {
        secondsRemaining <= 10 ? .red : Color.black.opacity(0.85)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Circular countdown ring
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color(red: 0.93, green: 0.93, blue: 0.95), lineWidth: 10)

                // Progress ring — drains as rest time decreases
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: ringProgress)

                // Inner content
                VStack(spacing: 4) {
                    Image(systemName: "zzz")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.secondary)

                    Text(formatTime(secondsRemaining))
                        .font(.system(size: 52, weight: .semibold, design: .monospaced))
                        .foregroundColor(secondsRemaining <= 10 ? .red : .primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text("of \(formatTime(restItem.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 240, height: 240)

            Text("Rest")
                .font(.title)
                .fontWeight(.bold)

            HStack(spacing: 24) {
                Button(action: { isRunning.toggle() }) {
                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

                Button(action: {
                    isRunning = false
                    secondsRemaining = restItem.duration
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
            isRunning = true
        }
        .task(id: isRunning) {
            guard isRunning else { return }
            while !Task.isCancelled && secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
                if secondsRemaining == 0 {
                    isRunning = false
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Warmup / Cooldown Screen

private struct WarmupCooldownScreen: View {
    let label: String
    let iconName: String
    let totalSeconds: Int
    @Binding var secondsRemaining: Int
    @Binding var isRunning: Bool
    let onFinish: () -> Void

    private var ringProgress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    private var ringColor: Color {
        secondsRemaining <= 10 ? .red : Color.black.opacity(0.85)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Circular countdown ring
            ZStack {
                Circle()
                    .stroke(Color(red: 0.93, green: 0.93, blue: 0.95), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: ringProgress)
                VStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.secondary)
                    Text(formatTime(secondsRemaining))
                        .font(.system(size: 52, weight: .semibold, design: .monospaced))
                        .foregroundColor(secondsRemaining <= 10 ? .red : .primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("of \(formatTime(totalSeconds))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 240, height: 240)

            Text(label)
                .font(.title)
                .fontWeight(.bold)

            HStack(spacing: 24) {
                Button(action: { isRunning.toggle() }) {
                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

                Button(action: {
                    isRunning = false
                    secondsRemaining = totalSeconds
                }) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: { onFinish() }) {
                Text("Skip \(label)")
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
        .task(id: isRunning) {
            guard isRunning else { return }
            while !Task.isCancelled && secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
                if secondsRemaining == 0 {
                    isRunning = false
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onFinish()
                }
            }
        }
    }
}

// MARK: - Workout Set Model

private struct WorkoutSet: Identifiable {
    let id: UUID = UUID()
    var reps: Int
    var weight: Double
    /// Raw text the user is typing into the weight field — avoids mid-entry decimal formatting.
    var weightText: String = ""
    /// For timed sets: countdown remaining in seconds. Starts at the predefined duration.
    var timedSecondsRemaining: Int = 0
    /// Whether this set's countdown is currently running.
    var isTimerRunning: Bool = false
}

// MARK: - Workout Timer Phase

/// A single timed phase within an exercise's phase sequence (Work or Rest).
private struct WorkoutTimerPhase {
    let label: String     // e.g. "Work", "Set 2 of 3 — Rest"
    let duration: Int     // seconds
    let isWork: Bool      // true = work phase, false = rest phase
    let setIndex: Int     // 0-based set index this phase belongs to
}

// MARK: - Workout Duration Stepper

/// Compact +/- button stepper for minutes and seconds.
/// Minutes step by 1, seconds step by 5. Used in WorkoutEditor and LoopEditorSheet.
private struct WorkoutDurationStepper: View {
    let label: String
    @Binding var seconds: Int

    private var minutes: Int { seconds / 60 }
    private var secs: Int    { seconds % 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label).font(.subheadline)
            }
            HStack(spacing: 0) {
                // Minutes wheel (0–59)
                Picker("", selection: Binding(
                    get: { minutes },
                    set: { seconds = $0 * 60 + secs }
                )) {
                    ForEach(0..<60) { m in
                        Text("\(m) min").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                // Seconds wheel (0, 5, 10, ... 55)
                Picker("", selection: Binding(
                    get: { secs / 5 },
                    set: { seconds = minutes * 60 + $0 * 5 }
                )) {
                    ForEach(0..<12) { i in
                        Text("\(i * 5) sec").tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 100)
        }
    }
}

// MARK: - Loop Editor Sheet

private struct LoopEditorSheet: View {
    @Environment(\.dismiss) var dismiss

    let loopID: UUID
    @Binding var loops: [String: WorkoutLoop]
    /// The workout-level timer mode, shown in the "Inherit" description.
    let workoutTimerMode: WorkoutTimerMode

    @State private var rounds: Int = 1
    @State private var timerModeTag: LoopTimerModeTag = .inherit
    @State private var intervalWork: Int = 45
    @State private var intervalRest: Int = 15

    private enum LoopTimerModeTag: String, CaseIterable, Hashable {
        case inherit = "Inherit from Workout"
        case none    = "None"
        case interval = "Interval"
        case tabata  = "Tabata"
        case emom    = "EMOM"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Loop Rounds") {
                    HStack {
                        Text("Rounds")
                        Spacer()
                        Button(action: { if rounds > 1 { rounds -= 1 } }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(rounds > 1 ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                        Text("\(rounds)")
                            .font(.title2).fontWeight(.semibold).monospacedDigit()
                            .frame(minWidth: 36, alignment: .center)
                        Button(action: { rounds += 1 }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2).foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("How many times to cycle through all exercises in this loop.")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("Timer Mode") {
                    Picker("Timer Mode", selection: $timerModeTag) {
                        ForEach(LoopTimerModeTag.allCases, id: \.self) { tag in
                            Text(tag.rawValue).tag(tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)

                    if timerModeTag == .inherit {
                        Text("Uses the workout-level timer mode: \(workoutTimerMode.displayName).")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if timerModeTag == .interval {
                        WorkoutDurationStepper(label: "Work Duration", seconds: $intervalWork)
                        WorkoutDurationStepper(label: "Rest Duration", seconds: $intervalRest)
                    }
                    if timerModeTag == .tabata {
                        Text("Fixed 20s work / 10s rest per set.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if timerModeTag == .emom {
                        Text("Fixed 60 seconds per exercise, no rest.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Edit Loop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let resolvedMode: WorkoutTimerMode? = {
                            switch timerModeTag {
                            case .inherit:  return nil
                            case .none:     return WorkoutTimerMode.none
                            case .interval: return .interval(workSeconds: intervalWork, restSeconds: intervalRest)
                            case .tabata:   return .tabata
                            case .emom:     return .emom
                            }
                        }()
                        loops[loopID.uuidString] = WorkoutLoop(id: loopID, rounds: rounds, timerMode: resolvedMode)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                let existing = loops[loopID.uuidString]
                rounds = existing?.rounds ?? 1
                if let mode = existing?.timerMode {
                    switch mode {
                    case .none:
                        timerModeTag = .none
                    case .interval(let w, let r):
                        timerModeTag = .interval
                        intervalWork = w
                        intervalRest = r
                    case .tabata:
                        timerModeTag = .tabata
                    case .emom:
                        timerModeTag = .emom
                    }
                } else {
                    timerModeTag = .inherit
                }
            }
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
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(\.dismiss) var dismiss

    let exercise: Exercise
    let logState: WorkoutLogState

    private var history: [(date: Date, sets: [LoggedSet], notes: String, activeSeconds: Int)] {
        logState.sortedLogs.compactMap { log in
            guard let ex = log.exercises.first(where: { $0.exerciseID == exercise.id }),
                  !ex.sets.isEmpty else { return nil }
            return (date: log.completedAt, sets: ex.sets, notes: ex.notes, activeSeconds: ex.activeSeconds)
        }
    }

    private var best1RM: Double? { logState.bestEstimated1RM(exerciseID: exercise.id) }

    private func formatHistoryTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
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
                        // 1RM summary header
                        if let rm = best1RM {
                            HStack(spacing: 12) {
                                Image(systemName: "medal.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Est. 1 Rep Max")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f \(weightUnit)", rm))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                }
                                Spacer()
                                Text("Epley formula")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                            .listRowBackground(Color(uiColor: .systemGray6))
                        }

                        ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text(entry.date, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(entry.date, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if entry.activeSeconds > 0 {
                                        Label(formatHistoryTime(entry.activeSeconds), systemImage: "stopwatch")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                let hasTimed = entry.sets.contains { $0.timedSeconds > 0 }
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Set").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Reps").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
                                        if hasTimed {
                                            Text("Time").font(.caption2).foregroundColor(.secondary).frame(width: 44, alignment: .center)
                                        }
                                        Text("Weight").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    ForEach(Array(entry.sets.enumerated()), id: \.offset) { idx, set in
                                        HStack {
                                            Text("\(idx + 1)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                                            Text("\(set.reps)").font(.caption).frame(maxWidth: .infinity, alignment: .center)
                                            if hasTimed {
                                                Text(set.timedSeconds > 0 ? formatHistoryTime(set.timedSeconds) : "—")
                                                    .font(.caption).foregroundColor(.secondary).frame(width: 44, alignment: .center)
                                            }
                                            Text(set.weight == 0 ? "—" : String(format: "%.1f \(weightUnit)", set.weight)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
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
