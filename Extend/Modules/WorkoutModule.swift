////
////  WorkoutModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UIKit
import AVFoundation

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

// MARK: - Complex Color Palette

private let complexColorPalette: [Color] = [
    Color(red: 0.85, green: 0.30, blue: 0.60),  // magenta-pink
    Color(red: 0.65, green: 0.40, blue: 0.90),  // purple-violet
    Color(red: 0.90, green: 0.55, blue: 0.10),  // amber-orange
    Color(red: 0.10, green: 0.60, blue: 0.85),  // steel blue
]

private func complexColor(for complexID: UUID, in orderedComplexIDs: [UUID]) -> Color {
    let index = orderedComplexIDs.firstIndex(of: complexID) ?? 0
    return complexColorPalette[index % complexColorPalette.count]
}

// MARK: - PredefinedSet collection helpers

private struct PredefinedSetGroup { var count: Int; var target: SetTarget; var weight: Double }

private extension Array where Element == PredefinedSet {
    /// Compact summary shown on the exercise row, e.g. "3 × 8 reps @ 45 lbs", "8 reps · 29 × 8 reps @ 50 lbs"
    /// Consecutive sets with identical target+weight are collapsed into a single "N × …" group.
    func summaryLabel(weightUnit: String) -> String {
        guard !isEmpty else { return "" }

        func wLabel(_ w: Double) -> String {
            w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%g", w)
        }

        // Build run-length encoded groups of consecutive identical (target, weight) pairs
        var groups: [PredefinedSetGroup] = []
        for s in self {
            if let last = groups.last, last.target == s.target, last.weight == s.weight {
                groups[groups.count - 1].count += 1
            } else {
                groups.append(PredefinedSetGroup(count: 1, target: s.target, weight: s.weight))
            }
        }

        let parts = groups.map { g -> String in
            let targetLabel = g.target.label
            let base = g.count > 1 ? "\(g.count) × \(targetLabel)" : targetLabel
            if g.weight > 0 {
                return "\(base) @ \(wLabel(g.weight)) \(weightUnit)"
            }
            return base
        }
        return parts.joined(separator: " · ")
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
        .foregroundColor(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(UIColor.secondarySystemBackground))
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
                        .foregroundColor(.primary)
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
                                            .foregroundColor(.primary)
                                        Text(workout.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: 70, height: 80)
                                    .background(Color(UIColor.secondarySystemBackground))
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
                                    .foregroundColor(.primary)
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
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)

                                // Stats button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    statsWorkout = workout
                                }) {
                                    Image(systemName: "chart.bar")
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)

                                // Clone button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    state.cloneWorkout(workout)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)

                                // Edit button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    editingWorkout = workout
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.primary)
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
                            // Collect unique non-none timer mode names from all loops
                            let timerModeNames: [String] = {
                                var seen = Set<String>()
                                var names: [String] = []
                                for lid in workout.orderedLoopIDs {
                                    if let mode = workout.loops[lid.uuidString]?.timerMode,
                                       case .none = mode { continue }
                                    if let name = workout.loops[lid.uuidString]?.timerMode?.displayName,
                                       seen.insert(name).inserted {
                                        names.append(name)
                                    }
                                }
                                return names
                            }()
                            // Count how many loops are supersets (2 exercises) vs circuits (3+)
                            let loopMemberCounts: [UUID: Int] = workout.orderedLoopIDs.reduce(into: [:]) { counts, lid in
                                counts[lid] = exerciseItems.filter { $0.loopID == lid }.count
                            }
                            let supersetCount = loopMemberCounts.values.filter { $0 == 2 }.count
                            let circuitCount  = loopMemberCounts.values.filter { $0 >= 3 }.count
                            // Count complexes (groups of 2+ exercises with a shared complexID)
                            let complexMemberCounts: [UUID: Int] = workout.orderedComplexIDs.reduce(into: [:]) { counts, cid in
                                counts[cid] = exerciseItems.filter { $0.complexID == cid }.count
                            }
                            let complexCount = complexMemberCounts.values.filter { $0 >= 2 }.count
                            let hasChips = !exerciseItems.isEmpty || supersetCount > 0 || circuitCount > 0 || complexCount > 0 || totalSets > 0 || !timerModeNames.isEmpty || workout.warmupSeconds > 0 || workout.cooldownSeconds > 0

                            if hasChips {
                                FlowLayout(spacing: 5) {
                                    if !exerciseItems.isEmpty {
                                        WorkoutInfoChip(label: "\(exerciseItems.count) exercise\(exerciseItems.count == 1 ? "" : "s")", icon: "dumbbell")
                                    }
                                    if totalSets > 0 {
                                        WorkoutInfoChip(label: "\(totalSets) set\(totalSets == 1 ? "" : "s")", icon: "list.number")
                                    }
                                    ForEach(timerModeNames, id: \.self) { name in
                                        WorkoutInfoChip(label: name, icon: "timer")
                                    }
                                    if supersetCount > 0 {
                                        WorkoutInfoChip(label: "\(supersetCount) superset\(supersetCount == 1 ? "" : "s")", icon: "arrow.2.circlepath")
                                    }
                                    if circuitCount > 0 {
                                        WorkoutInfoChip(label: "\(circuitCount) circuit\(circuitCount == 1 ? "" : "s")", icon: "arrow.2.circlepath")
                                    }
                                    if complexCount > 0 {
                                        WorkoutInfoChip(label: "\(complexCount) complex\(complexCount == 1 ? "" : "es")", icon: "square.stack.3d.up")
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
                            .tint(.primary)
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
            .fullScreenCover(item: $historyWorkout) { workout in
                WorkoutHistorySheet(workout: workout, logState: WorkoutLogState.shared)
            }
            .fullScreenCover(item: $statsWorkout) { workout in
                WorkoutStatsView(workout: workout)
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
    @State private var editMode: EditMode = .active
    @State private var healthKitActivityType: UInt? = nil
    @State private var loops: [String: WorkoutLoop] = [:]
    @State private var editingLoopID: UUID? = nil
    @State private var complexes: [String: WorkoutComplex] = [:]
    @State private var editingComplexID: UUID? = nil
    @State private var editingSetsExerciseID: UUID? = nil
    @State private var warmupSeconds: Int = 0
    @State private var cooldownSeconds: Int = 0
    @State private var showNotes: Bool = false

    /// Wrapper to use UUID? as sheet item (UUID is not Identifiable by default).
    private struct LoopEditTarget: Identifiable { let id: UUID }
    private var loopEditTarget: Binding<LoopEditTarget?> {
        Binding(
            get: { editingLoopID.map { LoopEditTarget(id: $0) } },
            set: { editingLoopID = $0?.id }
        )
    }

    private struct ComplexEditTarget: Identifiable { let id: UUID }
    private var complexEditTarget: Binding<ComplexEditTarget?> {
        Binding(
            get: { editingComplexID.map { ComplexEditTarget(id: $0) } },
            set: { editingComplexID = $0?.id }
        )
    }

    private struct SetsEditTarget: Identifiable { let id: UUID }
    private var setsEditTarget: Binding<SetsEditTarget?> {
        Binding(
            get: { editingSetsExerciseID.map { SetsEditTarget(id: $0) } },
            set: { editingSetsExerciseID = $0?.id }
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
            _loops = State(initialValue: workout.loops)
            _complexes = State(initialValue: workout.complexes)
            _warmupSeconds = State(initialValue: workout.warmupSeconds)
            _cooldownSeconds = State(initialValue: workout.cooldownSeconds)
            _showNotes = State(initialValue: workout.showNotes)
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

    /// Syncs the complexes dict so it contains exactly one entry per active complexID.
    private func syncComplexesDict() {
        var activeIDs = Set<String>()
        for item in workoutItems {
            if case .exercise(let e) = item, let cid = e.complexID {
                activeIDs.insert(cid.uuidString)
            }
        }
        for key in activeIDs where complexes[key] == nil {
            if let uuid = UUID(uuidString: key) {
                complexes[key] = WorkoutComplex(id: uuid)
            }
        }
        for key in complexes.keys where !activeIDs.contains(key) {
            complexes.removeValue(forKey: key)
        }
    }

    /// Ordered distinct complexIDs for color assignment.
    private var orderedComplexIDs: [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for item in workoutItems {
            if case .exercise(let e) = item, let cid = e.complexID, !seen.contains(cid) {
                seen.insert(cid)
                result.append(cid)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            navigationContent
        }
        .fullScreenCover(isPresented: $showingPicker) {
            ExercisePickerView(searchText: $searchText) { exerciseID in
                let item = WorkoutExercise(exerciseID: exerciseID)
                workoutItems.append(.exercise(item))
            }
            .environment(exercisesState)
            .environment(muscleGroupsState)
            .environment(equipmentState)
        }
        .fullScreenCover(item: loopEditTarget) { target in
            LoopEditorSheet(loopID: target.id, loops: $loops) {
                for i in workoutItems.indices {
                    switch workoutItems[i] {
                    case .exercise(var e) where e.loopID == target.id:
                        e.loopID = nil; workoutItems[i] = .exercise(e)
                    case .rest(var r) where r.loopID == target.id:
                        r.loopID = nil; workoutItems[i] = .rest(r)
                    default: break
                    }
                }
            }
        }
        .fullScreenCover(item: complexEditTarget) { target in
            ComplexEditorSheet(complexID: target.id, complexes: $complexes) {
                for i in workoutItems.indices {
                    if case .exercise(var e) = workoutItems[i], e.complexID == target.id {
                        e.complexID = nil
                        workoutItems[i] = .exercise(e)
                    }
                }
            }
        }
        .fullScreenCover(item: setsEditTarget) { target in
            if let idx = workoutItems.firstIndex(where: {
                if case .exercise(let e) = $0 { return e.id == target.id }
                return false
            }), case .exercise(let ex) = workoutItems[idx] {
                SetsEditorSheet(
                    exercise: ex,
                    index: idx,
                    workoutItems: $workoutItems,
                    complexRounds: ex.complexID.flatMap { complexes[$0.uuidString]?.rounds }
                        ?? ex.loopID.flatMap { loops[$0.uuidString]?.rounds },
                    resolvedExercise: exercisesState.exercises.first { $0.id == ex.exerciseID },
                    equipmentState: equipmentState
                )
            }
        }
    }

    @ViewBuilder
    private var navigationContent: some View {
        Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $name)
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Notes (optional)")
                                .foregroundColor(Color(uiColor: .placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                    }
                    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Toggle("Show notes during workout", isOn: $showNotes)
                    }

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
                                    orderedComplexIDs: orderedComplexIDs,
                                    muscleGroupsState: muscleGroupsState,
                                    equipmentState: equipmentState,
                                    exercisesState: exercisesState,
                                    loops: $loops,
                                    complexes: $complexes,
                                    onEditLoop: { lid in editingLoopID = lid },
                                    onEditComplex: { cid in editingComplexID = cid },
                                    onEditSets: { eid in editingSetsExerciseID = eid }
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
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
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
                        syncComplexesDict()
                        let workout = Workout(
                            id: initialWorkout?.id ?? UUID(),
                            name: name,
                            notes: notes,
                            items: workoutItems,
                            isFavorite: initialWorkout?.isFavorite ?? false,
                            healthKitActivityType: healthKitActivityType,
                            loops: loops,
                            complexes: complexes,
                            warmupSeconds: warmupSeconds,
                            cooldownSeconds: cooldownSeconds,
                            showNotes: showNotes
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

// MARK: - Editor Exercise Row

private struct EditorExerciseRow: View {
    let exercise: WorkoutExercise
    let index: Int
    @Binding var workoutItems: [WorkoutItem]
    @Binding var expandedInfoIDs: Set<UUID>
    let orderedLoopIDs: [UUID]
    let orderedComplexIDs: [UUID]
    let muscleGroupsState: MuscleGroupsState
    let equipmentState: EquipmentState
    let exercisesState: ExercisesState
    @Binding var loops: [String: WorkoutLoop]
    @Binding var complexes: [String: WorkoutComplex]
    let onEditLoop: (UUID) -> Void
    let onEditComplex: (UUID) -> Void
    let onEditSets: (UUID) -> Void

    private var resolvedExercise: Exercise? {
        exercisesState.exercises.first { $0.id == exercise.exerciseID }
    }

    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @State private var showingGroupingSheet = false
    @State private var newLoopID: UUID? = nil

    private var isInfoExpanded: Bool { expandedInfoIDs.contains(exercise.id) }

    private var exerciseLoopColor: Color? {
        guard let lid = exercise.loopID else { return nil }
        return loopColor(for: lid, in: orderedLoopIDs)
    }

    private var exerciseComplexColor: Color? {
        guard let cid = exercise.complexID else { return nil }
        return complexColor(for: cid, in: orderedComplexIDs)
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

    private func removeFromComplex() {
        guard case .exercise(var ex) = workoutItems[index] else { return }
        ex.complexID = nil
        workoutItems[index] = .exercise(ex)
        cleanupSingletonComplexes()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// After any mutation, remove complex dict entries that have no remaining members.
    /// Does NOT strip complexID from exercises — a solo exercise can remain in a complex.
    private func cleanupSingletonComplexes() {
        var counts: [UUID: Int] = [:]
        for item in workoutItems {
            if case .exercise(let e) = item, let cid = e.complexID {
                counts[cid, default: 0] += 1
            }
        }
        for (key, _) in complexes {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 1 {
                complexes.removeValue(forKey: key)
            }
        }
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
        // Clear loopID for any item whose loop has no remaining members
        for i in workoutItems.indices {
            switch workoutItems[i] {
            case .exercise(var e):
                if let lid = e.loopID, counts[lid, default: 0] < 1 {
                    e.loopID = nil
                    workoutItems[i] = .exercise(e)
                }
            case .rest(var r):
                if let lid = r.loopID, counts[lid, default: 0] < 1 {
                    r.loopID = nil
                    workoutItems[i] = .rest(r)
                }
            }
        }
        // Remove stale loop dict entries (no members left)
        for (key, _) in loops {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 1 {
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
                // Color bracket — complex color takes priority over loop color
                if let color = exerciseComplexColor {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 4)
                        .padding(.vertical, 2)
                        .padding(.trailing, 8)
                } else if let color = exerciseLoopColor {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 4)
                        .padding(.vertical, 2)
                        .padding(.trailing, 8)
                } else {
                    Color.clear.frame(width: 12)
                }

                VStack(alignment: .leading, spacing: 4) {
                // Top row: name + ⓘ (expanding) + action buttons
                HStack(alignment: .center, spacing: 8) {
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
                            .foregroundColor(isInfoExpanded ? .primary : .secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Action buttons
                    HStack(spacing: 12) {
                        // Loop grouping button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingGroupingSheet = true
                        }) {
                            Image(systemName: (exercise.loopID != nil || exercise.complexID != nil) ? "link.circle.fill" : "link.circle")
                                .foregroundColor(exercise.complexID != nil ? (exerciseComplexColor ?? .purple) : (exercise.loopID != nil ? (exerciseLoopColor ?? .green) : .secondary))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingGroupingSheet) {
                            ExerciseGroupingSheet(
                                exercise: exercise,
                                index: index,
                                workoutItems: $workoutItems,
                                loops: $loops,
                                complexes: $complexes,
                                onEditComplex: onEditComplex,
                                onNewLoop: { lid in newLoopID = lid }
                            )
                        }

                        // Edit sets (pencil)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEditSets(exercise.id)
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.primary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)

                        // Clone
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            let cloned = WorkoutExercise(
                                exerciseID: exercise.exerciseID,
                                loopID: exercise.loopID,
                                complexID: exercise.complexID,
                                predefinedSets: exercise.predefinedSets.map { PredefinedSet(target: $0.target, weight: $0.weight) }
                            )
                            workoutItems.insert(.exercise(cloned), at: index + 1)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        // Delete
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            workoutItems.remove(at: index)
                            cleanupSingletonLoops()
                            cleanupSingletonComplexes()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Sub-info rows — full width below the name/button bar
                VStack(alignment: .leading, spacing: 4) {
                    // Loop badge — tap to open LoopEditorSheet
                    if let lid = exercise.loopID {
                        let loopIdx = orderedLoopIDs.firstIndex(of: lid) ?? 0
                        let color = loopColorPalette[loopIdx % loopColorPalette.count]
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEditLoop(lid)
                        }) {
                            HStack(spacing: 4) {
                                let loopLabel: String = {
                                    let loop = loops[lid.uuidString]
                                    let rounds = loop?.rounds ?? 1
                                    let mode = loop?.timerMode

                                    func fmt(_ s: Int) -> String {
                                        s >= 60 ? "\(s / 60)m\(s % 60 > 0 ? "\(s % 60)s" : "")" : "\(s)s"
                                    }

                                    var parts: [String] = ["Loop \(loopIdx + 1)"]
                                    if let mode, case .none = mode {} else if let mode {
                                        parts.append(mode.displayName)
                                    }
                                    if rounds > 1 { parts.append("\(rounds)×") }
                                    switch mode {
                                    case .interval(let w, let r), .tabata(let w, let r):
                                        parts.append("\(fmt(w))/\(fmt(r))")
                                    case .emom(let i):
                                        parts.append(fmt(i))
                                    default: break
                                    }
                                    return parts.joined(separator: " · ")
                                }()
                                Text(loopLabel)
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

                    // Complex badge — tap to open ComplexEditorSheet
                    if let cid = exercise.complexID {
                        let complexIdx = orderedComplexIDs.firstIndex(of: cid) ?? 0
                        let color = complexColorPalette[complexIdx % complexColorPalette.count]
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEditComplex(cid)
                        }) {
                            HStack(spacing: 4) {
                                let complexLabel: String = {
                                    let cx = complexes[cid.uuidString]
                                    let rounds = cx?.rounds ?? 5
                                    let secs = cx?.intervalSeconds ?? 45
                                    func fmt(_ s: Int) -> String {
                                        s >= 60 ? "\(s / 60)m\(s % 60 > 0 ? "\(s % 60)s" : "")" : "\(s)s"
                                    }
                                    var parts: [String] = ["Complex \(complexIdx + 1)"]
                                    parts.append(fmt(secs))
                                    if rounds > 1 { parts.append("\(rounds)×") }
                                    return parts.joined(separator: " · ")
                                }()
                                Text(complexLabel)
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
                        Text(exercise.predefinedSets.summaryLabel(weightUnit: weightUnit))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                } // end inner VStack
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
            .fullScreenCover(item: Binding<IdentifiableUUID?>(
                get: { newLoopID.map { IdentifiableUUID(id: $0) } },
                set: { newLoopID = $0?.id }
            )) { target in
                LoopEditorSheet(loopID: target.id, loops: $loops) {
                    for i in workoutItems.indices {
                        switch workoutItems[i] {
                        case .exercise(var e) where e.loopID == target.id:
                            e.loopID = nil; workoutItems[i] = .exercise(e)
                        case .rest(var r) where r.loopID == target.id:
                            r.loopID = nil; workoutItems[i] = .rest(r)
                        default: break
                        }
                    }
                }
            }
    }
}

// MARK: - Sets Editor Sheet

private struct SetsEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let exercise: WorkoutExercise
    let index: Int
    @Binding var workoutItems: [WorkoutItem]
    /// Non-nil when the exercise belongs to a complex or loop — enables the "Fill N×" button.
    let complexRounds: Int?
    /// The resolved Exercise model — used to show name and available equipment.
    let resolvedExercise: Exercise?
    let equipmentState: EquipmentState

    // Local copies edited in the sheet; committed on Save
    @State private var sets: [PredefinedSet] = []
    @State private var selectedEquipmentIDs: Set<UUID> = []

    private func defaultTarget(after sets: [PredefinedSet]) -> SetTarget {
        sets.last?.target ?? .reps(0)
    }

    /// Equipment items assigned to this exercise (respects the exercise's equipmentIDs list).
    private var availableEquipment: [Equipment] {
        guard let ex = resolvedExercise else { return [] }
        return ex.equipmentIDs.compactMap { id in equipmentState.sortedItems.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.primary)
                Spacer()
                Text(resolvedExercise?.name ?? "Exercise")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 16) {
                    if let n = complexRounds, sets.count < n {
                        Button("Fill (×\(n))") {
                            let template = defaultTarget(after: sets)
                            let templateWeight = sets.last?.weight ?? 0
                            while sets.count < n {
                                sets.append(PredefinedSet(target: template, weight: templateWeight))
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .foregroundColor(.primary)
                    }
                    Button {
                        sets.append(PredefinedSet(target: defaultTarget(after: sets), weight: sets.last?.weight ?? 0))
                    } label: {
                        Image(systemName: "plus")
                    }
                    Button("Save") {
                        guard case .exercise(var ex) = workoutItems[index] else { dismiss(); return }
                        ex.predefinedSets = sets
                        ex.defaultEquipmentIDs = Array(selectedEquipmentIDs)
                        workoutItems[index] = .exercise(ex)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .overlay(alignment: .bottom) { Divider() }

            List {
                // ── Equipment section ──────────────────────────────────────
                if !availableEquipment.isEmpty {
                    Section("Equipment") {
                        // Chip-style flow layout matching the live workout UI
                        FlowLayout(spacing: 8) {
                            ForEach(availableEquipment) { item in
                                let selected = selectedEquipmentIDs.contains(item.id)
                                Button {
                                    if selected { selectedEquipmentIDs.remove(item.id) }
                                    else        { selectedEquipmentIDs.insert(item.id) }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 11))
                                            .foregroundColor(selected ? Color(UIColor.systemBackground) : .secondary)
                                        Text(item.name)
                                            .font(.caption)
                                            .foregroundColor(selected ? Color(UIColor.systemBackground) : .secondary)
                                            .fixedSize()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selected ? Color.primary : Color(uiColor: .systemGray5))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Sets section ───────────────────────────────────────────
                Section("Sets") {
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
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .environment(\.editMode, .constant(.active))

            // Footer row with Clear All sets
            HStack {
                Spacer()
                Button(role: .destructive) {
                    sets = []
                } label: {
                    Text("Clear All Sets")
                        .foregroundColor(sets.isEmpty ? .secondary : .red)
                }
                .disabled(sets.isEmpty)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
            .overlay(alignment: .top) { Divider() }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            sets = exercise.predefinedSets
            // Seed equipment: workout-level override first, then exercise defaults
            if !exercise.defaultEquipmentIDs.isEmpty {
                selectedEquipmentIDs = Set(exercise.defaultEquipmentIDs)
            } else if let ex = resolvedExercise, !ex.defaultEquipmentIDs.isEmpty {
                selectedEquipmentIDs = Set(ex.defaultEquipmentIDs)
            }
        }
    }
}

// MARK: - Single Set Editor Row

private struct SetEditorRow: View {
    let setNumber: Int
    @Binding var set: PredefinedSet
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

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

    // Weight wheel: 0, 2.5, 5, 7.5, ... 500 (in 2.5 increments) = 201 items
    private static let weightSteps: [Double] = stride(from: 0.0, through: 500.0, by: 2.5).map { $0 }

    private var weightIndex: Int {
        let idx = Self.weightSteps.firstIndex(where: { $0 >= set.weight }) ?? 0
        return idx
    }

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
                // Reps (left) + Weight (right) side-by-side wheels
                HStack(spacing: 0) {
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
                    .frame(maxWidth: .infinity)
                    .clipped()

                    // Weight wheel (0, 2.5, 5, ... 500)
                    Picker("", selection: Binding(
                        get: { weightIndex },
                        set: { set.weight = Self.weightSteps[$0] }
                    )) {
                        ForEach(Self.weightSteps.indices, id: \.self) { i in
                            let w = Self.weightSteps[i]
                            let label = w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%g", w)
                            Text("\(label) \(weightUnit)").tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 120)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Exercise Grouping Sheet

private struct ExerciseGroupingSheet: View {
    @Environment(\.dismiss) var dismiss
    let exercise: WorkoutExercise
    let index: Int
    @Binding var workoutItems: [WorkoutItem]
    @Binding var loops: [String: WorkoutLoop]
    @Binding var complexes: [String: WorkoutComplex]
    let onEditComplex: (UUID) -> Void
    let onNewLoop: (UUID) -> Void

    // MARK: Helpers

    private func adjacentExerciseIndex(before idx: Int) -> Int? {
        guard idx > 0 else { return nil }
        return (0..<idx).reversed().first { i in
            if case .exercise = workoutItems[i] { return true }
            return false
        }
    }

    private func adjacentExerciseIndex(after idx: Int) -> Int? {
        let start = idx + 1
        guard start < workoutItems.count else { return nil }
        return (start..<workoutItems.count).first { i in
            if case .exercise = workoutItems[i] { return true }
            return false
        }
    }

    // MARK: Complex actions

    private func startNewComplex() {
        let cid = UUID()
        guard index < workoutItems.count,
              case .exercise(var ex) = workoutItems[index] else { return }
        ex.complexID = cid
        workoutItems[index] = .exercise(ex)
        complexes[cid.uuidString] = WorkoutComplex(id: cid)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        onEditComplex(cid)
    }

    private func addToComplex(otherIdx: Int) {
        guard index < workoutItems.count, otherIdx < workoutItems.count,
              case .exercise(var cur) = workoutItems[index],
              case .exercise(var other) = workoutItems[otherIdx] else { return }
        let cid = cur.complexID ?? other.complexID ?? UUID()
        cur.complexID = cid; other.complexID = cid
        workoutItems[index] = .exercise(cur)
        workoutItems[otherIdx] = .exercise(other)
        if complexes[cid.uuidString] == nil { complexes[cid.uuidString] = WorkoutComplex(id: cid) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func removeFromComplex() {
        guard index < workoutItems.count,
              case .exercise(var ex) = workoutItems[index] else { return }
        ex.complexID = nil
        workoutItems[index] = .exercise(ex)
        // Remove complex dict entries that have no remaining members; solo exercises keep their complexID
        var counts: [UUID: Int] = [:]
        for item in workoutItems {
            if case .exercise(let e) = item, let cid = e.complexID { counts[cid, default: 0] += 1 }
        }
        for (key, _) in complexes {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 1 { complexes.removeValue(forKey: key) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    // MARK: Loop actions

    private func startNewLoop() {
        let lid = UUID()
        guard index < workoutItems.count,
              case .exercise(var ex) = workoutItems[index] else { return }
        ex.loopID = lid
        workoutItems[index] = .exercise(ex)
        loops[lid.uuidString] = WorkoutLoop(id: lid)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        onNewLoop(lid)
    }

    private func mergeLoop(with otherIdx: Int) {
        guard index < workoutItems.count, otherIdx < workoutItems.count,
              case .exercise(var cur) = workoutItems[index],
              case .exercise(var other) = workoutItems[otherIdx] else { return }
        let lid = cur.loopID ?? other.loopID ?? UUID()
        cur.loopID = lid; other.loopID = lid
        workoutItems[index] = .exercise(cur)
        workoutItems[otherIdx] = .exercise(other)
        if loops[lid.uuidString] == nil { loops[lid.uuidString] = WorkoutLoop(id: lid) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func removeFromLoop() {
        guard index < workoutItems.count,
              case .exercise(var ex) = workoutItems[index] else { return }
        ex.loopID = nil
        workoutItems[index] = .exercise(ex)
        var counts: [UUID: Int] = [:]
        for item in workoutItems {
            switch item {
            case .exercise(let e): if let lid = e.loopID { counts[lid, default: 0] += 1 }
            case .rest(let r):     if let lid = r.loopID { counts[lid, default: 0] += 1 }
            }
        }
        for i in workoutItems.indices {
            switch workoutItems[i] {
            case .exercise(var e):
                if let lid = e.loopID, (counts[lid] ?? 0) < 1 { e.loopID = nil; workoutItems[i] = .exercise(e) }
            case .rest(var r):
                if let lid = r.loopID, (counts[lid] ?? 0) < 1 { r.loopID = nil; workoutItems[i] = .rest(r) }
            }
        }
        for (key, _) in loops {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 1 { loops.removeValue(forKey: key) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                if exercise.complexID != nil {
                    // Already in a complex — only show remove option
                    Section("Complex") {
                        Button(role: .destructive) { removeFromComplex() } label: {
                            Label("Remove from Complex", systemImage: "rectangle.stack")
                        }
                    }
                } else if exercise.loopID != nil {
                    // Already in a loop — only show remove option
                    Section("Loop") {
                        Button(role: .destructive) { removeFromLoop() } label: {
                            Label("Remove from Loop", systemImage: "arrow.clockwise.circle")
                        }
                    }
                } else {
                    // Not grouped — show all grouping options with a visual separator
                    let upIdx = adjacentExerciseIndex(before: index)
                    let downIdx = adjacentExerciseIndex(after: index)

                    Section("Complex") {
                        Button { startNewComplex() } label: {
                            Label("Start New Complex", systemImage: "rectangle.stack.badge.plus")
                        }
                        if let upIdx {
                            Button { addToComplex(otherIdx: upIdx) } label: {
                                Label("Merge Up", systemImage: "arrow.up.square")
                            }
                        }
                        if let downIdx {
                            Button { addToComplex(otherIdx: downIdx) } label: {
                                Label("Merge Down", systemImage: "arrow.down.square")
                            }
                        }
                    }

                    Section("Loop") {
                        Button { startNewLoop() } label: {
                            Label("Start New Loop", systemImage: "arrow.clockwise.circle")
                        }
                        if let upIdx {
                            Button { mergeLoop(with: upIdx) } label: {
                                Label("Merge Up", systemImage: "arrow.up.circle")
                            }
                        }
                        if let downIdx {
                            Button { mergeLoop(with: downIdx) } label: {
                                Label("Merge Down", systemImage: "arrow.down.circle")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Grouping")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Rest Loop Grouping Sheet

private struct RestLoopGroupingSheet: View {
    @Environment(\.dismiss) var dismiss
    let rest: RestItem
    let index: Int
    @Binding var workoutItems: [WorkoutItem]
    @Binding var loops: [String: WorkoutLoop]

    private func adjacentExerciseIndex(before idx: Int) -> Int? {
        guard idx > 0 else { return nil }
        return (0..<idx).reversed().first { i in
            if case .exercise = workoutItems[i] { return true }
            return false
        }
    }

    private func adjacentExerciseIndex(after idx: Int) -> Int? {
        let start = idx + 1
        guard start < workoutItems.count else { return nil }
        return (start..<workoutItems.count).first { i in
            if case .exercise = workoutItems[i] { return true }
            return false
        }
    }

    private func removeFromLoop() {
        guard case .rest(var r) = workoutItems[index] else { return }
        r.loopID = nil
        workoutItems[index] = .rest(r)
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
                if let lid = e.loopID, (counts[lid] ?? 0) < 1 { e.loopID = nil; workoutItems[i] = .exercise(e) }
            case .rest(var rv):
                if let lid = rv.loopID, (counts[lid] ?? 0) < 1 { rv.loopID = nil; workoutItems[i] = .rest(rv) }
            }
        }
        for (key, _) in loops {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 1 { loops.removeValue(forKey: key) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func mergeLoop(with otherIdx: Int, upIdx: Int?, downIdx: Int?) {
        guard otherIdx < workoutItems.count, index < workoutItems.count,
              case .exercise(var other) = workoutItems[otherIdx],
              case .rest(var selfRest) = workoutItems[index] else { return }
        let lid: UUID
        // If there's an exercise on both sides, link all three
        if let up = upIdx, let down = downIdx,
           up != otherIdx,
           up < workoutItems.count, down < workoutItems.count,
           case .exercise(var above) = workoutItems[up],
           case .exercise(var below) = workoutItems[down] {
            lid = above.loopID ?? below.loopID ?? other.loopID ?? UUID()
            above.loopID = lid; below.loopID = lid
            workoutItems[up] = .exercise(above)
            workoutItems[down] = .exercise(below)
        } else {
            lid = other.loopID ?? UUID()
        }
        other.loopID = lid
        selfRest.loopID = lid
        workoutItems[otherIdx] = .exercise(other)
        workoutItems[index] = .rest(selfRest)
        if loops[lid.uuidString] == nil { loops[lid.uuidString] = WorkoutLoop(id: lid) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Loop") {
                    if rest.loopID != nil {
                        Button(role: .destructive) { removeFromLoop() } label: {
                            Label("Remove from Loop", systemImage: "arrow.clockwise.circle")
                        }
                    } else {
                        let upIdx = adjacentExerciseIndex(before: index)
                        let downIdx = adjacentExerciseIndex(after: index)
                        if let upIdx {
                            Button {
                                mergeLoop(with: upIdx, upIdx: upIdx, downIdx: downIdx)
                            } label: {
                                Label("Merge Up", systemImage: "arrow.up.circle")
                            }
                        }
                        if let downIdx {
                            Button {
                                mergeLoop(with: downIdx, upIdx: upIdx, downIdx: downIdx)
                            } label: {
                                Label("Merge Down", systemImage: "arrow.down.circle")
                            }
                        }
                        if upIdx == nil && downIdx == nil {
                            Text("No adjacent exercises to merge with.")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Loop Grouping")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
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
                if let lid = e.loopID, counts[lid, default: 0] < 1 { e.loopID = nil; workoutItems[i] = .exercise(e) }
            case .rest(var rv):
                if let lid = rv.loopID, counts[lid, default: 0] < 1 { rv.loopID = nil; workoutItems[i] = .rest(rv) }
            }
        }
        for (key, _) in loops {
            if let uid = UUID(uuidString: key), (counts[uid] ?? 0) < 1 { loops.removeValue(forKey: key) }
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
                .sheet(isPresented: $showingLoopMenu) {
                    RestLoopGroupingSheet(
                        rest: rest,
                        index: index,
                        workoutItems: $workoutItems,
                        loops: $loops
                    )
                }

                // Edit button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingEditor = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Clone button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    workoutItems.insert(.rest(RestItem(duration: rest.duration)), at: index + 1)
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.primary)
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
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Edit Rest")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
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
                                    .foregroundColor(.primary)
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
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Add Exercise")
            .tint(.primary)
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
    @Environment(\.scenePhase) var scenePhase
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
    @State private var isTimerRunning: Bool = false
    @State private var expandedInfo: Bool = false
    @State private var sets: [WorkoutSet] = []
    @State private var previousSets: [LoggedSet] = []
    @State private var previousLogDate: Date? = nil
    @State private var notes: String = ""
    @State private var usedEquipmentIDs: Set<UUID> = []
    @State private var exerciseData: [UUID: (sets: [WorkoutSet], notes: String, timerSeconds: Int, usedEquipmentIDs: Set<UUID>, phaseIndex: Int, phaseElapsed: Int, phaseTimerDone: Bool)] = [:]
    /// Wall-clock time when the workout session actually started (after warmup)
    @State private var sessionStartDate: Date? = nil
    /// Records when the app went to background so elapsed time can be recovered on foreground
    @State private var backgroundedAt: Date? = nil
    @State private var showingHistory: Bool = false
    /// Active countdown tasks keyed by WorkoutSet.id — for per-set timed countdowns.
    @State private var setTimerTasks: [UUID: Task<Void, Never>] = [:]
    // Phase timer state (used when workout has a timer mode set)
    @State private var exercisePhases: [WorkoutTimerPhase] = []
    @State private var phaseIndex: Int = 0
    @State private var phaseElapsed: Int = 0
    @State private var phaseTimerRunning: Bool = false
    @State private var notesExpanded: Bool = true
    @State private var phaseTimerTask: Task<Void, Never>? = nil
    @State private var phaseTimerDone: Bool = false
    // Rest screen state
    @State private var restSecondsRemaining: Int = 60
    @State private var isRestTimerRunning: Bool = false
    /// Keyed by RestItem.id — stores (configured, secondsRemaining) when we navigate away
    @State private var restData: [UUID: (configured: Int, remaining: Int)] = [:]
    @State private var showingCancelConfirm: Bool = false
    @State private var showingFinishEarlyConfirm: Bool = false
    // Warmup / cooldown phase
    @State private var warmupCooldownSecondsRemaining: Int = 0
    @State private var warmupCooldownRunning: Bool = false
    @State private var showingWarmup: Bool = false
    @State private var showingCooldown: Bool = false
    // Complex phase state
    /// Which round (0-based) the user is currently on in a complex.
    @State private var complexRound: Int = 0
    /// Seconds remaining on the complex interval countdown for the current round.
    @State private var complexSecondsRemaining: Int = 0
    /// Whether the complex interval countdown is running.
    @State private var complexTimerRunning: Bool = false
    /// Whether the current complex round's timer has expired.
    @State private var complexTimerDone: Bool = false
    /// Tracks the highest round index reached per complex UUID. Used to trim unfinished sets at log time.
    @State private var complexRoundsReached: [UUID: Int] = [:]
    @State private var complexAdvanceRound: Bool = false
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @State private var synthesizer = AVSpeechSynthesizer()

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

    /// Total number of set-rounds for the current loop.
    /// WorkoutLoop.rounds is authoritative. Falls back to max predefined set count, then 1.
    private var loopTotalRounds: Int {
        guard isInLoop else { return 0 }
        // If the loop has an explicit rounds value, use it exclusively.
        if case .exercise(let we) = currentItem,
           let lid = we.loopID,
           let loop = workout.loops[lid.uuidString] {
            return max(loop.rounds, 1)
        }
        // No loop entry — fall back to max predefined set count across members, min 1.
        let predefinedMax = currentLoopIndices.compactMap { idx -> Int? in
            guard case .exercise(let e) = workout.items[idx] else { return nil }
            return e.predefinedSets.isEmpty ? nil : e.predefinedSets.count
        }.max() ?? 0
        return predefinedMax > 0 ? predefinedMax : 1
    }

    // MARK: Complex helpers

    /// The complexID of the current exercise item, if any.
    private var currentComplexID: UUID? {
        guard case .exercise(let we) = currentItem else { return nil }
        return we.complexID
    }

    /// True if the current item belongs to a complex group.
    private var isInComplex: Bool { currentComplexID != nil }

    /// Ordered indices of all exercises in the current complex group.
    private var currentComplexIndices: [Int] {
        guard let cid = currentComplexID else { return [] }
        return workout.items.indices.filter { i in
            if case .exercise(let e) = workout.items[i] { return e.complexID == cid }
            return false
        }
    }

    /// The first index in the current complex group (the "entry point").
    private var complexStartIndex: Int {
        currentComplexIndices.first ?? currentItemIndex
    }

    /// True only when currentItemIndex is at the first item of its complex group.
    private var isAtComplexEntry: Bool {
        isInComplex && currentItemIndex == complexStartIndex
    }

    /// Total rounds defined for the current complex.
    private var complexTotalRounds: Int {
        guard let cid = currentComplexID,
              let cx = workout.complexes[cid.uuidString] else { return 5 }
        return max(cx.rounds, 1)
    }

    /// Nav-bar label: shows loop context when in a loop, otherwise plain "X of Y".
    private var progressLabel: String {
        if showingWarmup { return "Warmup" }
        if showingCooldown { return "Cooldown" }
        if isInComplex && isAtComplexEntry {
            return "Complex · Round \(complexRound + 1) of \(complexTotalRounds)"
        }
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
                let atStart = currentItemIndex == 0 && loopRound == 0 && complexRound == 0
                let multipleItems = totalItems > 1
                HStack {
                    // Left arrow: goes back a round within a complex, or to the previous item
                    if isInComplex && isAtComplexEntry && complexRound > 0 {
                        Button(action: { previousComplexRound() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
                        }
                    } else if multipleItems && !atStart && !showingWarmup && !showingCooldown {
                        Button(action: { previousItem() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
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

                    // Right arrow: visible during warmup (to skip it) and between exercises;
                    // hidden during cooldown, and hidden on the last item when there's no cooldown
                    // (Finish button is the correct exit in those cases)
                    if showingWarmup {
                        Button(action: {
                            showingWarmup = false
                            startExerciseTimerAfterWarmup()
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.primary)
                        }
                    } else if showingCooldown || (isAtLastItem && workout.cooldownSeconds == 0) {
                        Image(systemName: "chevron.right").opacity(0)
                    } else if isInComplex && isAtComplexEntry {
                        // Forward arrow triggers the same logic as the "Next Round" button
                        Button(action: { complexAdvanceRound = true }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.primary)
                        }
                    } else if totalItems > 0 {
                        Button(action: { nextItem() }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.primary)
                        }
                    } else {
                        Image(systemName: "chevron.right").opacity(0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))

                if workout.showNotes && !workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        if notesExpanded {
                            Text(workout.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                notesExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: notesExpanded ? "chevron.up" : "note.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                if showingWarmup {
                    // WARMUP SCREEN
                    WarmupCooldownScreen(
                        label: "Warmup",
                        iconName: "flame.fill",
                        totalSeconds: workout.warmupSeconds,
                        secondsRemaining: $warmupCooldownSecondsRemaining,
                        isRunning: $warmupCooldownRunning,
                        speakCountdown: true,
                        onFinish: {
                            showingWarmup = false
                            startExerciseTimerAfterWarmup()
                        }
                    )
                } else if showingCooldown {
                    // COOLDOWN SCREEN
                    WarmupCooldownScreen(
                        label: "Cooldown",
                        iconName: "snowflake",
                        totalSeconds: workout.cooldownSeconds,
                        secondsRemaining: $warmupCooldownSecondsRemaining,
                        isRunning: $warmupCooldownRunning,
                        autoAdvanceOnComplete: false,
                        onFinish: { showingCooldown = false }
                    )
                } else if let restItem = currentRestItem {
                    // REST SCREEN
                    RestScreen(
                        restItem: restItem,
                        secondsRemaining: $restSecondsRemaining,
                        isRunning: $isRestTimerRunning
                    )
                } else if isInComplex && isAtComplexEntry {
                    // COMPLEX SCREEN — all exercises shown simultaneously
                    ComplexScreen(
                        workout: workout,
                        complexID: currentComplexID!,
                        complexIndices: currentComplexIndices,
                        currentRound: complexRound,
                        totalRounds: complexTotalRounds,
                        secondsRemaining: $complexSecondsRemaining,
                        isTimerRunning: $complexTimerRunning,
                        timerDone: $complexTimerDone,
                        exerciseData: $exerciseData,
                        advanceRound: $complexAdvanceRound,
                        onRoundComplete: {
                            complexTimerDone = false
                            complexTimerRunning = false
                            let isLastRound = complexRound >= complexTotalRounds - 1
                            if isLastRound {
                                // All complex rounds done — record full completion, then advance
                                if let cid = currentComplexID {
                                    complexRoundsReached[cid] = complexTotalRounds
                                }
                                complexRound = 0
                                let nextIndex = (currentComplexIndices.last ?? currentItemIndex) + 1
                                if nextIndex >= totalItems {
                                    triggerCooldownOrComplete()
                                } else {
                                    currentItemIndex = nextIndex
                                    loadItemData()
                                }
                            } else {
                                complexRound += 1
                                // Record new highest round reached
                                if let cid = currentComplexID {
                                    complexRoundsReached[cid] = complexRound
                                }
                                // Reset countdown for next round
                                if let cid = currentComplexID, let cx = workout.complexes[cid.uuidString] {
                                    complexSecondsRemaining = cx.intervalSeconds
                                    complexTimerRunning = true
                                    complexTimerDone = false
                                    let go = AVSpeechUtterance(string: "Go")
                                    go.rate = 0.45
                                    go.pitchMultiplier = 1.15
                                    synthesizer.speak(go)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                        },
                        exercisesState: exercisesState
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
                    .fullScreenCover(isPresented: $showingHistory) {
                        if let exercise = currentExercise {
                            ExerciseHistorySheet(exercise: exercise, logState: logState)
                        }
                    }
                }

            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingCancelConfirm = true }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("🏁 Finish") {
                        let needsConfirm = !showingCooldown && (showingWarmup || !isAtLastItem)
                        if needsConfirm {
                            showingFinishEarlyConfirm = true
                        } else {
                            triggerCooldownOrComplete()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                }
            }
            .alert("Cancel Workout?", isPresented: $showingCancelConfirm) {
                Button("Keep Going", role: .cancel) { }
                Button("Cancel Workout", role: .destructive) { dismiss() }
            } message: {
                Text("Your progress will not be saved.")
            }
            .alert("Finish Early?", isPresented: $showingFinishEarlyConfirm) {
                Button("Keep Going", role: .cancel) { }
                Button("Finish Workout", role: .destructive) {
                    if showingWarmup {
                        showingWarmup = false
                        warmupCooldownRunning = false
                    }
                    completeWorkout()
                }
            } message: {
                Text("The workout isn't done yet. Finish and log it anyway?")
            }
        }
        .onAppear {
            if workout.warmupSeconds > 0 {
                warmupCooldownSecondsRemaining = workout.warmupSeconds
                warmupCooldownRunning = true
                showingWarmup = true
                // Workout timer starts after warmup completes
            } else {
                sessionStartDate = Date()
                isTimerRunning = true
            }
            loadItemData()
            if TimerState.shared.keepScreenOn {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
        .onDisappear {
            cancelPhaseTimer()
            cancelAllSetTimers()
            UIApplication.shared.isIdleTimerDisabled = false
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
        // Recover elapsed time lost while screen was off / app backgrounded
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Record when we left foreground
                if isTimerRunning { backgroundedAt = Date() }
            } else if newPhase == .active {
                // Add the time we were away to the running counter
                if isTimerRunning, let bg = backgroundedAt {
                    let elapsed = Int(Date().timeIntervalSince(bg))
                    if elapsed > 0 { timerSeconds += elapsed }
                }
                backgroundedAt = nil
            }
        }
    }

    // MARK: Exercise content builder

    @ViewBuilder
    private func exerciseContent(exercise: Exercise, we: WorkoutExercise) -> some View {
        // Exercise name with info button — name is truly centered, button is overlaid on the trailing edge
        ZStack {
            Text(exercise.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button(action: { expandedInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)

        // Muscle image data
        let showMuscleImages = muscleGroupsState.selectedBodyOption != .none
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
        // Full Body glow: shown when a FullBody asset is among the primary or secondary muscles
        let exIsFullBody = (exPrimaryAssets + exSecondaryAssets).contains { $0.contains("FullBody") }

        // Custom-muscle groups (user-created, no asset masks): collected for standalone display
        let allGroups = exPrimaryGroups + exSecondaryGroups
        let customImageGroups = allGroups.filter { g in
            (g.primaryImageAssetName ?? "").isEmpty && (g.secondaryImageAssetName ?? "").isEmpty &&
            (g.customPrimaryImageFilename != nil || g.customSecondaryImageFilename != nil)
        }
        // Adaptive background for muscle images: white in light mode, gray in dark mode
        let muscleImageBg = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? .systemGray5 : .white
        })

        // Expandable info section
        if expandedInfo {
            VStack(alignment: .leading, spacing: 8) {
                let allMuscles: String = allGroups.map(\.name).joined(separator: ", ")
                if !allMuscles.isEmpty {
                    Text("Muscles: \(allMuscles)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if showMuscleImages {
                GeometryReader { geo in
                    let panelWidth = (geo.size.width - 12) / 2
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            ZStack {
                                Color(UIColor.secondarySystemBackground)
                                ZStack {
                                    muscleImageBg
                                    if exIsFullBody {
                                        Color.red
                                            .mask(Image(exFrontBase).resizable().scaledToFit())
                                            .blur(radius: 10)
                                            .opacity(0.7)
                                    }
                                    Image(exFrontBase).resizable().scaledToFit()
                                    ForEach(exFrontMasksPrimary, id: \.self) { mask in
                                        Image(mask).resizable().scaledToFit().blendMode(.screen)
                                    }
                                    ForEach(exFrontMasksSecondary, id: \.self) { mask in
                                        Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                                    }
                                }
                                .padding(4)
                            }
                            .frame(width: panelWidth)
                            Text("Front").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        VStack(spacing: 4) {
                            ZStack {
                                Color(UIColor.secondarySystemBackground)
                                ZStack {
                                    muscleImageBg
                                    if exIsFullBody {
                                        Color.red
                                            .mask(Image(exBackBase).resizable().scaledToFit())
                                            .blur(radius: 10)
                                            .opacity(0.7)
                                    }
                                    Image(exBackBase).resizable().scaledToFit()
                                    ForEach(exBackMasksPrimary, id: \.self) { mask in
                                        Image(mask).resizable().scaledToFit().blendMode(.screen)
                                    }
                                    ForEach(exBackMasksSecondary, id: \.self) { mask in
                                        Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                                    }
                                }
                                .padding(4)
                            }
                            .frame(width: panelWidth)
                            Text("Back").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 220)
                .padding(.vertical, 4)
                } // showMuscleImages

                // Custom muscle images (user-uploaded standalone images for user-created muscles)
                if showMuscleImages && !customImageGroups.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(customImageGroups, id: \.id) { g in
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        if let fn = g.customPrimaryImageFilename,
                                           let data = try? Data(contentsOf: MuscleGroup.imageStorageDirectory.appendingPathComponent(fn)),
                                           let ui = UIImage(data: data) {
                                            ZStack {
                                                muscleImageBg
                                                Image(uiImage: ui).resizable().scaledToFit()
                                            }
                                            .frame(width: 90, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        if let fn = g.customSecondaryImageFilename,
                                           let data = try? Data(contentsOf: MuscleGroup.imageStorageDirectory.appendingPathComponent(fn)),
                                           let ui = UIImage(data: data) {
                                            ZStack {
                                                muscleImageBg
                                                Image(uiImage: ui).resizable().scaledToFit()
                                            }
                                            .frame(width: 90, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    Text(g.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Exercise-specific image (static or animated GIF)
                if let fn = exercise.imageFilename,
                   let data = try? Data(contentsOf: Exercise.imageStorageDirectory.appendingPathComponent(fn)) {
                    GIFImageView(data: data)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 4)
                }

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
                if !expandedInfo && showMuscleImages {
                    ZStack {
                        Color(UIColor.secondarySystemBackground)
                        ZStack {
                            muscleImageBg
                            if exIsFullBody {
                                Color.red
                                    .mask(Image(exFrontBase).resizable().scaledToFit())
                                    .blur(radius: 6)
                                    .opacity(0.7)
                            }
                            Image(exFrontBase).resizable().scaledToFit()
                            ForEach(exFrontMasksPrimary, id: \.self) { mask in
                                Image(mask).resizable().scaledToFit().blendMode(.screen)
                            }
                            ForEach(exFrontMasksSecondary, id: \.self) { mask in
                                Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                            }
                        }
                        .padding(3)
                    }
                    .frame(width: 56, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: { toggleTimer() }) {
                            Image(systemName: isTimerRunning ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        Text(formatTime(timerSeconds))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()

                        Button(action: { resetTimer() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)

                if !expandedInfo && showMuscleImages {
                    ZStack {
                        Color(UIColor.secondarySystemBackground)
                        ZStack {
                            muscleImageBg
                            if exIsFullBody {
                                Color.red
                                    .mask(Image(exBackBase).resizable().scaledToFit())
                                    .blur(radius: 6)
                                    .opacity(0.7)
                            }
                            Image(exBackBase).resizable().scaledToFit()
                            ForEach(exBackMasksPrimary, id: \.self) { mask in
                                Image(mask).resizable().scaledToFit().blendMode(.screen)
                            }
                            ForEach(exBackMasksSecondary, id: \.self) { mask in
                                Image(mask).resizable().scaledToFit().opacity(0.8).blendMode(.screen)
                            }
                        }
                        .padding(3)
                    }
                    .frame(width: 56, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Equipment:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(exerciseEquipment) { item in
                        let selected = usedEquipmentIDs.contains(item.id)
                        Button(action: {
                            if selected { usedEquipmentIDs.remove(item.id) }
                            else { usedEquipmentIDs.insert(item.id) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(selected ? Color(UIColor.systemBackground) : .secondary)
                                Text(item.name)
                                    .font(.caption)
                                    .foregroundColor(selected ? Color(UIColor.systemBackground) : .secondary)
                                    .fixedSize()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selected ? Color.primary : Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                .background(Color(UIColor.secondarySystemBackground))
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
        let ringColor: Color = phaseTimerDone ? .green : (isWork ? .primary : .blue)

        VStack(spacing: 16) {
            // Phase label
            Text(phaseTimerDone ? "Done" : (currentPhase?.label ?? ""))
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
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
                if !isAtLastItem {
                    Button(action: { nextItem() }) {
                        Text("Next Exercise")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                } else if workout.cooldownSeconds > 0 {
                    Button(action: { triggerCooldownOrComplete() }) {
                        Text("Continue to Cooldown")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                // At last item with no cooldown: only Finish button in toolbar is shown
            } else {
                HStack(spacing: 32) {
                    // Restart
                    Button(action: { resetPhaseTimer(); startPhaseTick() }) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    // Play / Pause
                    Button(action: {
                        if phaseTimerRunning { pausePhaseTimer() } else { startPhaseTick() }
                    }) {
                        Image(systemName: phaseTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    // Skip
                    Button(action: { skipPhase() }) {
                        Image(systemName: "forward.end.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
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
                    Text("(target: \(we.predefinedSets.summaryLabel(weightUnit: weightUnit)))")
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
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }

                if sets.isEmpty {
                    Button(action: { addSet() }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.primary)
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
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
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
                        .background(Color(UIColor.tertiarySystemBackground))
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
                    .background(Color(UIColor.tertiarySystemBackground))
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
                    .background(Color(UIColor.tertiarySystemBackground))
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
                        .background(rem == 0 ? Color.green.opacity(0.15) : Color(UIColor.secondarySystemBackground))
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
        .background(isActiveRound ? Color.primary.opacity(0.07) : Color.clear)
        .cornerRadius(isActiveRound ? 6 : 0)
        .overlay(
            isActiveRound
                ? RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.55), lineWidth: 1.5)
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

    /// True when the user is on the final item of the workout (or final round of a loop).
    private var isAtLastItem: Bool {
        if isInLoop {
            let loopIndices = currentLoopIndices
            let pos = loopPosition
            let isLastRound = loopRound >= loopTotalRounds - 1
            if !isLastRound { return false }
            // Check if no later active members exist in this round after the current one
            for candidatePos in (pos + 1)..<loopIndices.count {
                if loopMemberActive(at: loopIndices[candidatePos], round: loopRound) { return false }
            }
            // At the last active member of the last round — check nothing follows the loop
            return loopIndices.last.map { $0 >= totalItems - 1 } ?? true
        }
        return currentItemIndex >= totalItems - 1
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
            // All rounds done — can still advance if there's an item after the loop, or to trigger cooldown
            if loopIndices.last.map({ $0 < totalItems - 1 }) ?? false { return true }
            // At the very end of the workout — allow advancing to trigger cooldown
            return true
        }
        // Always allow advancing (at the end it triggers cooldown instead of moving index)
        return true
    }

    private func nextItem() {
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
                let nextIndex = loopIndices.last! + 1
                if nextIndex >= totalItems {
                    // Past the last item — trigger cooldown or complete
                    triggerCooldownOrComplete()
                    return
                }
                currentItemIndex = nextIndex
            }
        } else {
            loopRound = 0
            let nextIndex = currentItemIndex + 1
            if nextIndex >= totalItems {
                // Past the last item — trigger cooldown or complete
                triggerCooldownOrComplete()
                return
            }
            currentItemIndex = nextIndex
            // If we just landed on an item that belongs to a complex, jump to its entry point
            if case .exercise(let we) = workout.items[safe: nextIndex], let cid = we.complexID {
                let firstComplexIdx = workout.items.indices.first { i in
                    if case .exercise(let e) = workout.items[i] { return e.complexID == cid }
                    return false
                } ?? nextIndex
                currentItemIndex = firstComplexIdx
                complexRound = 0
            }
        }

        loadItemData()
    }

    private func triggerCooldownOrComplete() {
        if showingCooldown {
            // Finish pressed while cooldown is showing — complete immediately
            showingCooldown = false
            completeWorkout()
        } else if workout.cooldownSeconds > 0 {
            // Show cooldown first; user must click Finish after to log
            warmupCooldownSecondsRemaining = workout.cooldownSeconds
            warmupCooldownRunning = true
            showingCooldown = true
        } else {
            completeWorkout()
        }
    }

    private func previousComplexRound() {
        guard complexRound > 0 else { return }
        saveCurrentData()
        complexTimerRunning = false
        complexTimerDone = false
        complexRound -= 1
        if let cid = currentComplexID, let cx = workout.complexes[cid.uuidString] {
            complexSecondsRemaining = cx.intervalSeconds
        }
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
            // Skip overwriting for the complex entry point — ComplexExerciseRow writes to exerciseData directly
            guard !(isInComplex && isAtComplexEntry) else { break }
            // Apply placeholder values for any set where the user left the field blank
            var filledSets = sets
            for i in filledSets.indices {
                // Reps: if blank (0), fall back to predefined target then previous log
                if filledSets[i].reps == 0 {
                    if i < we.predefinedSets.count, case .reps(let n) = we.predefinedSets[i].target, n > 0 {
                        filledSets[i].reps = n
                    } else if i < previousSets.count, previousSets[i].reps > 0 {
                        filledSets[i].reps = previousSets[i].reps
                    }
                }
                // Weight: if blank (0), fall back to predefined weight then previous log
                if filledSets[i].weight == 0 {
                    if i < we.predefinedSets.count, we.predefinedSets[i].weight > 0 {
                        filledSets[i].weight = we.predefinedSets[i].weight
                    } else if i < previousSets.count, previousSets[i].weight > 0 {
                        filledSets[i].weight = previousSets[i].weight
                    }
                }
            }
            exerciseData[we.id] = (sets: filledSets, notes: notes, timerSeconds: timerSeconds, usedEquipmentIDs: usedEquipmentIDs, phaseIndex: phaseIndex, phaseElapsed: phaseElapsed, phaseTimerDone: phaseTimerDone)
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

        // If entering a complex at its entry point, seed complex state and all member exercise data
        if isInComplex && isAtComplexEntry {
            complexTimerRunning = false
            complexTimerDone = false
            if let cid = currentComplexID, let cx = workout.complexes[cid.uuidString] {
                complexSecondsRemaining = cx.intervalSeconds
                // Initialize round tracking — will be updated as rounds are completed
                if complexRoundsReached[cid] == nil {
                    complexRoundsReached[cid] = 0
                }
            }
            for idx in currentComplexIndices {
                if case .exercise(let we) = workout.items[idx], exerciseData[we.id] == nil {
                    let cx = currentComplexID.flatMap { workout.complexes[$0.uuidString] }
                    let totalRds = max(cx?.rounds ?? 5, 1)
                    let count = we.predefinedSets.isEmpty ? totalRds : we.predefinedSets.count
                    // Seed equipment: workout-level override → exercise defaults → "None"-only fallback
                    let seededEquipment: Set<UUID>
                    if !we.defaultEquipmentIDs.isEmpty {
                        seededEquipment = Set(we.defaultEquipmentIDs)
                    } else if let exercise = exercisesState.exercises.first(where: { $0.id == we.exerciseID }) {
                        if !exercise.defaultEquipmentIDs.isEmpty {
                            seededEquipment = Set(exercise.defaultEquipmentIDs)
                        } else {
                            let equipment = exercise.equipmentIDs.compactMap { id in equipmentState.sortedItems.first { $0.id == id } }
                            if equipment.count == 1, equipment[0].name.lowercased() == "none" {
                                seededEquipment = [equipment[0].id]
                            } else {
                                seededEquipment = []
                            }
                        }
                    } else {
                        seededEquipment = []
                    }
                    exerciseData[we.id] = (
                        sets: (0..<count).map { i in
                            let defaultReps: Int = {
                                guard i < we.predefinedSets.count,
                                      case .reps(let n) = we.predefinedSets[i].target else { return 0 }
                                return n
                            }()
                            let defaultWeight = i < we.predefinedSets.count ? we.predefinedSets[i].weight : 0
                            return WorkoutSet(reps: defaultReps, weight: defaultWeight)
                        },
                        notes: "",
                        timerSeconds: 0,
                        usedEquipmentIDs: seededEquipment,
                        phaseIndex: 0,
                        phaseElapsed: 0,
                        phaseTimerDone: false
                    )
                }
            }
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
            // Seed equipment: workout-level override → exercise defaults → "None"-only fallback
            if !we.defaultEquipmentIDs.isEmpty {
                // Per-workout equipment override set in the editor
                usedEquipmentIDs = Set(we.defaultEquipmentIDs)
            } else if let exercise = exercisesState.exercises.first(where: { $0.id == we.exerciseID }) {
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
            if !phaseTimerDone && !showingWarmup {
                startPhaseTick()
            }
        } else {
            // Standard stopwatch mode
            cancelPhaseTimer()
            isTimerRunning = showingWarmup ? false : true

            // Auto-start the timed countdown for the first applicable set when loading an exercise
            if !isTimedMode {
                let activeIndex = isInLoop ? loopRound : 0
                if activeIndex < sets.count,
                   activeIndex < we.predefinedSets.count,
                   case .timed = we.predefinedSets[activeIndex].target,
                   !sets[activeIndex].isTimerRunning,
                   sets[activeIndex].timedSecondsRemaining > 0 {
                    // Small delay so the view has settled before the timer fires
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await MainActor.run {
                            toggleSetTimer(setID: sets[activeIndex].id, setIndex: activeIndex)
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

    /// Called when warmup finishes to start whichever timer the current exercise needs.
    private func startExerciseTimerAfterWarmup() {
        guard case .exercise = currentItem else { return }
        sessionStartDate = sessionStartDate ?? Date()
        let go = AVSpeechUtterance(string: "Go")
        go.rate = 0.45
        go.pitchMultiplier = 1.15
        synthesizer.speak(go)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if isTimedMode {
            if !phaseTimerDone { startPhaseTick() }
        } else {
            isTimerRunning = true
        }
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
                var ws = WorkoutSet(reps: 0, weight: predef.weight)
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

                // For complex exercises, trim sets to only the rounds actually completed.
                // If finishing mid-round on the active complex, include the current in-progress
                // round since ComplexExerciseRow has already written its data to exerciseData.
                let setsToLog: [WorkoutSet]
                if let cid = we.complexID {
                    let completedRounds = complexRoundsReached[cid] ?? 0
                    // If this is the complex currently on screen and we have an in-progress round, count it
                    let activeBonus = (isInComplex && currentComplexID == cid && complexRound >= completedRounds) ? 1 : 0
                    let roundsToInclude = completedRounds + activeBonus
                    if roundsToInclude == 0 {
                        // Complex was entered but no data at all — skip
                        continue
                    }
                    setsToLog = Array(savedData.sets.prefix(roundsToInclude))
                } else {
                    setsToLog = savedData.sets
                }

                // Resolve previous log for placeholder fallback
                let prevLogged = lastLoggedSets(for: we.exerciseID) ?? []

                // Include per-set timed duration: initial target minus remaining = elapsed
                // Also apply placeholder values for any set the user left blank
                let loggedSets = setsToLog.enumerated().map { idx, ws -> LoggedSet in
                    var initialTimed = 0
                    if idx < we.predefinedSets.count,
                       case .timed(let s) = we.predefinedSets[idx].target {
                        initialTimed = s
                    }
                    let elapsed = initialTimed > 0 ? max(0, initialTimed - ws.timedSecondsRemaining) : 0

                    // Fill blank reps from predefined target then previous log
                    var reps = ws.reps
                    if reps == 0 {
                        if idx < we.predefinedSets.count, case .reps(let n) = we.predefinedSets[idx].target, n > 0 {
                            reps = n
                        } else if idx < prevLogged.count, prevLogged[idx].reps > 0 {
                            reps = prevLogged[idx].reps
                        }
                    }
                    // Fill blank weight from predefined weight then previous log
                    var weight = ws.weight
                    if weight == 0 {
                        if idx < we.predefinedSets.count, we.predefinedSets[idx].weight > 0 {
                            weight = we.predefinedSets[idx].weight
                        } else if idx < prevLogged.count, prevLogged[idx].weight > 0 {
                            weight = prevLogged[idx].weight
                        }
                    }
                    return LoggedSet(reps: reps, weight: weight, timedSeconds: elapsed)
                }

                loggedExercises.append(LoggedExercise(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    sets: loggedSets,
                    notes: savedData.notes,
                    activeSeconds: savedData.timerSeconds,
                    usedEquipmentIDs: Array(savedData.usedEquipmentIDs),
                    orderIndex: orderIndex,
                    loopID: we.loopID,
                    complexID: we.complexID
                ))

            case .rest(let r):
                let data = restData[r.id]
                let configured = data?.configured ?? r.duration
                let remaining = data?.remaining ?? r.duration
                let actual = max(0, configured - remaining)
                loggedRests.append(LoggedRest(configuredDuration: configured, actualDuration: actual, orderIndex: orderIndex))
            }
        }

        // Use wall-clock elapsed time so complex interval rounds are included in duration.
        // Fall back to summing per-exercise stopwatch values if sessionStartDate was never set.
        let completedAt = Date()
        let totalDuration: TimeInterval
        if let start = sessionStartDate {
            totalDuration = completedAt.timeIntervalSince(start)
        } else {
            totalDuration = TimeInterval(exerciseData.values.reduce(0) { $0 + $1.timerSeconds })
        }

        let workoutLog = WorkoutLog(
            workoutName: workout.name,
            completedAt: completedAt,
            exercises: loggedExercises,
            restPeriods: loggedRests,
            notes: "",
            duration: totalDuration
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

    private var ringProgress: Double {
        guard restItem.duration > 0 else { return 0 }
        return Double(secondsRemaining) / Double(restItem.duration)
    }

    private var ringColor: Color {
        secondsRemaining <= 10 ? .red : Color.primary
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Circular countdown ring
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color(UIColor.tertiarySystemBackground), lineWidth: 10)

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
                        .foregroundColor(.primary)
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
    /// When true, the timer calls onFinish() automatically when it reaches 0.
    /// Set to false for cooldown — user must click Finish manually.
    var autoAdvanceOnComplete: Bool = true
    /// When true, speaks a 3-2-1 countdown during the final 3 seconds.
    var speakCountdown: Bool = false
    let onFinish: () -> Void

    @State private var synthesizer = AVSpeechSynthesizer()

    private var ringProgress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    private var ringColor: Color {
        secondsRemaining <= 10 ? .red : Color.primary
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    @MainActor
    private func speakNumber(_ n: Int) {
        let utterance = AVSpeechUtterance(string: "\(n)")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.15
        synthesizer.speak(utterance)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    @MainActor
    private func primeSynthesizer() {
        let warmup = AVSpeechUtterance(string: "ready")
        warmup.volume = 0
        warmup.rate = AVSpeechUtteranceMaximumSpeechRate
        synthesizer.speak(warmup)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Circular countdown ring
            ZStack {
                Circle()
                    .stroke(Color(UIColor.tertiarySystemBackground), lineWidth: 10)
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
                        .foregroundColor(.primary)
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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: isRunning) { @MainActor in
            guard isRunning else { return }
            // Prime the synthesizer when the countdown feature is enabled,
            // so the audio engine is ready before the first spoken number.
            if speakCountdown && totalSeconds > 3 {
                primeSynthesizer()
            }
            while !Task.isCancelled && secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
                if speakCountdown && secondsRemaining > 0 && secondsRemaining <= 3 {
                    await MainActor.run { speakNumber(secondsRemaining) }
                }
                if secondsRemaining == 0 {
                    isRunning = false
                    if autoAdvanceOnComplete {
                        onFinish()
                    }
                }
            }
        }
    }
}

// MARK: - Complex Screen

private struct ComplexScreen: View {
    let workout: Workout
    let complexID: UUID
    let complexIndices: [Int]
    let currentRound: Int
    let totalRounds: Int
    @Binding var secondsRemaining: Int
    @Binding var isTimerRunning: Bool
    @Binding var timerDone: Bool
    @Binding var exerciseData: [UUID: (sets: [WorkoutSet], notes: String, timerSeconds: Int, usedEquipmentIDs: Set<UUID>, phaseIndex: Int, phaseElapsed: Int, phaseTimerDone: Bool)]
    @Binding var advanceRound: Bool
    let onRoundComplete: () -> Void
    let exercisesState: ExercisesState

    @State private var isCountingDown: Bool = false
    @State private var countdownValue: Int = 3
    // Synthesizer kept as a stored property so ARC doesn't release it mid-speech
    @State private var synthesizer = AVSpeechSynthesizer()

    private var complex: WorkoutComplex? {
        workout.complexes[complexID.uuidString]
    }

    private var totalSeconds: Int { complex?.intervalSeconds ?? 45 }

    private var ringProgress: Double {
        guard totalSeconds > 0 else { return 1 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    private var ringColor: Color {
        secondsRemaining <= 10 ? .red : Color.primary
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60; let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Speak a single number using the stored synthesizer.
    @MainActor
    private func speakNumber(_ n: Int) {
        let utterance = AVSpeechUtterance(string: "\(n)")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.15
        synthesizer.speak(utterance)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Primes the AVSpeechSynthesizer by speaking an inaudible utterance, activating the
    /// audio pipeline so the next real utterance is not clipped or rushed.
    @MainActor
    private func primeSynthesizer() {
        let warmup = AVSpeechUtterance(string: "ready")
        warmup.volume = 0
        warmup.rate = AVSpeechUtteranceMaximumSpeechRate
        synthesizer.speak(warmup)
    }

    /// Runs a 3-2-1 countdown (used when +Round is tapped mid-round with no active timer),
    /// then calls `completion`.
    @MainActor
    private func startInterRoundCountdown(completion: @escaping () -> Void) {
        isCountingDown = true
        countdownValue = 3
        // Pre-reset the timer display so it shows the next round's full duration
        // during the countdown rather than the stale remaining time from the previous round.
        secondsRemaining = totalSeconds
        timerDone = false
        // Prime the synthesizer NOW (on the main thread) so the audio pipeline is fully
        // active before the Task starts. Using a real word at max rate means it plays and
        // finishes in ~100ms, which is exactly the warm-up the engine needs.
        primeSynthesizer()
        Task { @MainActor in
            // Wait for the warmup utterance to complete and the audio engine to settle.
            try? await Task.sleep(nanoseconds: 600_000_000)
            for n in stride(from: 3, through: 1, by: -1) {
                countdownValue = n
                speakNumber(n)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            isCountingDown = false
            completion()
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Timer display — ring or bar depending on complex setting
                if complex?.timerStyle == .bar {
                    // BAR STYLE: slim horizontal strip
                    VStack(spacing: 6) {
                        HStack(spacing: 16) {
                            // Play/pause
                            Button(action: { isTimerRunning.toggle() }) {
                                Image(systemName: isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

                            // Time display
                            Text(timerDone ? "Done!" : formatTime(secondsRemaining))
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .foregroundColor(timerDone ? .green : (secondsRemaining <= 10 ? .red : .primary))
                                .frame(minWidth: 72, alignment: .center)

                            Text("/ \(formatTime(totalSeconds))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            // Reset
                            Button(action: {
                                isTimerRunning = false
                                secondsRemaining = totalSeconds
                                timerDone = false
                            }) {
                                Image(systemName: "arrow.counterclockwise.circle")
                                    .font(.system(size: 26))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(UIColor.tertiarySystemBackground))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(timerDone ? Color.green : ringColor)
                                    .frame(width: geo.size.width * ringProgress, height: 6)
                                    .animation(.linear(duration: 0.5), value: ringProgress)
                            }
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 16)
                    }
                } else {
                    // RING STYLE: compact ring with controls inside
                    ZStack {
                        Circle()
                            .stroke(Color(UIColor.tertiarySystemBackground), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: ringProgress)
                            .stroke(
                                timerDone ? Color.green : ringColor,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: ringProgress)
                        VStack(spacing: 4) {
                            Text(timerDone ? "Done!" : formatTime(secondsRemaining))
                                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                                .foregroundColor(timerDone ? .green : (secondsRemaining <= 10 ? .red : .primary))
                            Text("of \(formatTime(totalSeconds))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            // Controls inside the ring
                            HStack(spacing: 16) {
                                Button(action: { isTimerRunning.toggle() }) {
                                    Image(systemName: isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)
                                Button(action: {
                                    isTimerRunning = false
                                    secondsRemaining = totalSeconds
                                    timerDone = false
                                }) {
                                    Image(systemName: "arrow.counterclockwise.circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(width: 170, height: 170)
                }

                Divider().padding(.horizontal, 16)

                // All exercises in the complex shown simultaneously
                VStack(spacing: 10) {
                    ForEach(complexIndices, id: \.self) { itemIndex in
                        if case .exercise(let we) = workout.items[safe: itemIndex],
                           let exercise = exercisesState.exercises.first(where: { $0.id == we.exerciseID }) {
                            ComplexExerciseRow(
                                exercise: exercise,
                                workoutExercise: we,
                                round: currentRound,
                                exerciseData: $exerciseData
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)

                // +Round / Done button
                let isLastRound = currentRound >= totalRounds - 1
                Button(action: {
                    guard !isCountingDown else { return }
                    if !isLastRound && complex?.roundCountdown == true {
                        isTimerRunning = false
                        startInterRoundCountdown { onRoundComplete() }
                    } else {
                        onRoundComplete()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isCountingDown {
                            Text("\(countdownValue)")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                        } else {
                            Image(systemName: isLastRound ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isLastRound ? "Done" : "Next Round")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(isCountingDown || isLastRound ? .white : Color(UIColor.systemBackground))
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(isCountingDown ? Color.orange : (isLastRound ? Color.green : Color.primary))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .onChange(of: advanceRound) { _, newValue in
            guard newValue, !isCountingDown else {
                advanceRound = false
                return
            }
            advanceRound = false
            let isLastRound = currentRound >= totalRounds - 1
            if !isLastRound && complex?.roundCountdown == true {
                isTimerRunning = false
                startInterRoundCountdown { onRoundComplete() }
            } else {
                onRoundComplete()
            }
        }
        .onAppear {
            secondsRemaining = totalSeconds
            isTimerRunning = true
            timerDone = false
        }
        .task(id: isTimerRunning) { @MainActor in
            guard isTimerRunning else { return }
            while !Task.isCancelled && secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
                // Speak countdown numbers during the last 3 seconds (if enabled and not last round)
                let isLastRound = currentRound >= totalRounds - 1
                if complex?.roundCountdown == true && !isLastRound && secondsRemaining > 0 && secondsRemaining <= 3 {
                    await MainActor.run { speakNumber(secondsRemaining) }
                }
                if secondsRemaining == 0 {
                    isTimerRunning = false
                    timerDone = true
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    if complex?.autoAdvance == true {
                        if !isLastRound {
                            // Small delay so the haptic/done state is visible before advancing
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            onRoundComplete()
                        } else {
                            onRoundComplete()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Complex Exercise Row

private struct ComplexExerciseRow: View {
    let exercise: Exercise
    let workoutExercise: WorkoutExercise
    let round: Int
    @Binding var exerciseData: [UUID: (sets: [WorkoutSet], notes: String, timerSeconds: Int, usedEquipmentIDs: Set<UUID>, phaseIndex: Int, phaseElapsed: Int, phaseTimerDone: Bool)]
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

    private var targetSet: PredefinedSet? {
        guard round < workoutExercise.predefinedSets.count else { return nil }
        return workoutExercise.predefinedSets[round]
    }

    private var repPlaceholder: String {
        guard let target = targetSet, case .reps(let n) = target.target, n > 0 else { return "" }
        return "\(n)"
    }

    private var weightPlaceholder: String {
        guard let target = targetSet, target.weight > 0 else { return "" }
        let w = target.weight
        return w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%g", w)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if let target = targetSet {
                    Text(target.target.label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if round < (exerciseData[workoutExercise.id]?.sets.count ?? 0) {
                HStack(spacing: 12) {
                    // Round label
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Round")
                            .font(.caption2)
                            .foregroundColor(.primary.opacity(0.6))
                        Text("\(round + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 28, alignment: .center)
                            .padding(.horizontal, 6)
                            .background(Color(uiColor: .systemGray5))
                            .cornerRadius(4)
                    }
                    .frame(width: 44)

                    // Reps field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reps")
                            .font(.caption2)
                            .foregroundColor(.primary.opacity(0.6))
                        TextField(repPlaceholder, text: Binding(
                            get: {
                                let reps = exerciseData[workoutExercise.id]?.sets[round].reps ?? 0
                                return reps == 0 ? "" : "\(reps)"
                            },
                            set: { newVal in
                                guard var data = exerciseData[workoutExercise.id] else { return }
                                if let v = Int(newVal) { data.sets[round].reps = v }
                                else if newVal.isEmpty { data.sets[round].reps = 0 }
                                exerciseData[workoutExercise.id] = data
                            }
                        ))
                        .keyboardType(.numberPad)
                        .font(.caption)
                        .frame(minHeight: 28)
                        .padding(.horizontal, 6)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(4)
                    }

                    // Weight field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight (\(weightUnit))")
                            .font(.caption2)
                            .foregroundColor(.primary.opacity(0.6))
                        TextField(weightPlaceholder, text: Binding(
                            get: { exerciseData[workoutExercise.id]?.sets[round].weightText ?? "" },
                            set: { newVal in
                                guard var data = exerciseData[workoutExercise.id] else { return }
                                data.sets[round].weightText = newVal
                                let parsed = Double(newVal.replacingOccurrences(of: ",", with: "."))
                                data.sets[round].weight = parsed ?? data.sets[round].weight
                                exerciseData[workoutExercise.id] = data
                            }
                        ))
                        .keyboardType(.decimalPad)
                        .font(.caption)
                        .frame(minHeight: 28)
                        .padding(.horizontal, 6)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(8)
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
    /// Called when the user deletes this loop; clears loopID from all affected items.
    var onDelete: (() -> Void)? = nil

    @State private var rounds: Int = 1
    @State private var timerModeTag: LoopTimerModeTag = .none
    @State private var intervalWork: Int = 45
    @State private var intervalRest: Int = 15
    @State private var emomDuration: Int = 60
    @State private var showingDeleteConfirm = false

    private enum LoopTimerModeTag: String, CaseIterable, Hashable {
        case none     = "None"
        case interval = "Interval"
        case emom     = "EMOM"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Timer Mode") {
                    Picker("Timer Mode", selection: $timerModeTag) {
                        ForEach(LoopTimerModeTag.allCases, id: \.self) { tag in
                            Text(tag.rawValue).tag(tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(.primary)

                    if timerModeTag == .none {
                        Text("No automatic timing. Use the stopwatch and advance manually.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if timerModeTag == .interval {
                        Text("Timed work/rest cycling per exercise within the loop.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if timerModeTag == .emom {
                        Text("Each exercise gets its own countdown. Complete it before the timer advances.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                if timerModeTag == .interval {
                    Section("Work Duration") {
                        WorkoutDurationStepper(label: "", seconds: $intervalWork)
                    }
                    Section("Rest Duration") {
                        WorkoutDurationStepper(label: "", seconds: $intervalRest)
                    }
                }

                if timerModeTag == .emom {
                    Section("Interval Duration") {
                        WorkoutDurationStepper(label: "", seconds: $emomDuration)
                    }
                }

                Section("Rounds") {
                    Picker("Rounds", selection: $rounds) {
                        ForEach(1...50, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 120)
                    Text("How many times to cycle through all exercises in this loop.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Edit Loop")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                    Button(action: { showingDeleteConfirm = true }) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 22))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let resolvedMode: WorkoutTimerMode = {
                            switch timerModeTag {
                            case .none:     return WorkoutTimerMode.none
                            case .interval: return .interval(workSeconds: intervalWork, restSeconds: intervalRest)
                            case .emom:     return .emom(intervalSeconds: emomDuration)
                            }
                        }()
                        loops[loopID.uuidString] = WorkoutLoop(id: loopID, rounds: rounds, timerMode: resolvedMode)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Loop?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    loops.removeValue(forKey: loopID.uuidString)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will remove the loop grouping from all exercises in it.")
            }
            .onAppear {
                let existing = loops[loopID.uuidString]
                rounds = existing?.rounds ?? 1
                switch existing?.timerMode {
                case .interval(let w, let r):
                    timerModeTag = .interval
                    intervalWork = w
                    intervalRest = r
                case .tabata(let w, let r):
                    // Tabata removed from UI — treat as interval with same work/rest values
                    timerModeTag = .interval
                    intervalWork = w
                    intervalRest = r
                case .emom(let i):
                    timerModeTag = .emom
                    emomDuration = i
                default:
                    timerModeTag = .none
                }
            }
        }
    }
}

// MARK: - Complex Editor Sheet

private struct ComplexEditorSheet: View {
    @Environment(\.dismiss) var dismiss

    let complexID: UUID
    @Binding var complexes: [String: WorkoutComplex]
    /// Called when the user deletes this complex; clears complexID from all affected items.
    var onDelete: (() -> Void)? = nil

    @State private var rounds: Int = 5
    @State private var intervalSeconds: Int = 45
    @State private var autoAdvance: Bool = false
    @State private var roundCountdown: Bool = false
    @State private var timerStyle: ComplexTimerStyle = .ring
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Interval Duration") {
                    WorkoutDurationStepper(label: "", seconds: $intervalSeconds)
                    Text("How long the countdown runs per round. Complete all exercises within this window.")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("Rounds") {
                    Picker("Rounds", selection: $rounds) {
                        ForEach(1...50, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 120)
                    Text("How many times to complete all exercises in this complex.")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("Timer Display") {
                    Picker("Style", selection: $timerStyle) {
                        Text("Ring").tag(ComplexTimerStyle.ring)
                        Text("Bar").tag(ComplexTimerStyle.bar)
                    }
                    .pickerStyle(.segmented)
                    Text("Ring shows a circular countdown. Bar shows a slim horizontal progress strip.")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("Auto-Advance") {
                    Toggle("Advance on interval end", isOn: $autoAdvance)
                    Text("When on, the round advances automatically when the countdown reaches zero.")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("Round Countdown") {
                    Toggle("3-2-1 countdown between rounds", isOn: $roundCountdown)
                    Text("Speaks a 3, 2, 1 countdown before each new round begins.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Edit Complex")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                    Button(action: { showingDeleteConfirm = true }) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 22))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        complexes[complexID.uuidString] = WorkoutComplex(
                            id: complexID,
                            rounds: rounds,
                            intervalSeconds: intervalSeconds,
                            autoAdvance: autoAdvance,
                            roundCountdown: roundCountdown,
                            timerStyle: timerStyle
                        )
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Complex?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    complexes.removeValue(forKey: complexID.uuidString)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will remove the complex grouping from all exercises in it.")
            }
            .onAppear {
                let existing = complexes[complexID.uuidString]
                rounds          = existing?.rounds ?? 5
                intervalSeconds = existing?.intervalSeconds ?? 45
                autoAdvance     = existing?.autoAdvance ?? false
                roundCountdown  = existing?.roundCountdown ?? false
                timerStyle      = existing?.timerStyle ?? .ring
            }
        }
    }
}

// MARK: - Helpers

/// Wraps a UUID so it can be used as a SwiftUI sheet item.
private struct IdentifiableUUID: Identifiable { let id: UUID }

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
                                            Text("Time").font(.caption2).foregroundColor(.secondary).frame(width: 64, alignment: .center)
                                        }
                                        Text("Weight").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    ForEach(Array(entry.sets.groupedRuns().enumerated()), id: \.offset) { _, run in
                                        HStack {
                                            Text(run.label).font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                                            Text("\(run.set.reps)").font(.caption).frame(maxWidth: .infinity, alignment: .center)
                                            if hasTimed {
                                                Text(run.set.timedSeconds > 0 ? formatHistoryTime(run.set.timedSeconds) : "—")
                                                    .font(.caption).foregroundColor(.secondary).frame(width: 64, alignment: .center)
                                            }
                                            Text(run.set.weight == 0 ? "—" : String(format: "%.1f \(weightUnit)", run.set.weight)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
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
            .tint(.primary)
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
