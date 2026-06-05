import SwiftUI

// MARK: - Plan Module View (entry point, shown as fullScreenCover from ProgressModule)

/// Wrapper so fullScreenCover(item:) captures the plan correctly at trigger time.
private struct PlanEditorItem: Identifiable {
    let id: UUID
    let plan: TrainingPlan?  // nil = new plan
}

struct PlanModuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TrainingPlanState.self) private var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState

    @State private var planEditorItem: PlanEditorItem? = nil
    @State private var showingManagePlans = false

    var body: some View {
        NavigationStack {
            Group {
                if planState.plans.isEmpty {
                    emptyState
                } else {
                    planContent
                }
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            planEditorItem = PlanEditorItem(id: UUID(), plan: nil)
                        } label: {
                            Label("New Plan", systemImage: "plus")
                        }
                        if !planState.plans.isEmpty {
                            Button {
                                showingManagePlans = true
                            } label: {
                                Label("Manage Plans", systemImage: "list.bullet")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            // Full-screen plan editor (new or edit) — item: binding guarantees correct capture
            .fullScreenCover(item: $planEditorItem) { item in
                PlanEditorSheet(
                    plan: item.plan,
                    onSave: { saved in
                        if item.plan != nil {
                            planState.updatePlan(saved)
                        } else {
                            planState.addPlan(saved)
                            planState.setActive(id: saved.id)
                        }
                    },
                    onDelete: item.plan != nil ? { id in planState.removePlan(id: id) } : nil
                )
                .environment(workoutsState)
                .environment(exercisesState)
            }
            // Full-screen manage plans
            .fullScreenCover(isPresented: $showingManagePlans) {
                ManagePlansSheet(onEdit: { plan in
                    showingManagePlans = false
                    // Small delay so the first cover dismisses before the next presents
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        planEditorItem = PlanEditorItem(id: plan.id, plan: plan)
                    }
                })
                .environment(planState)
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.secondary)
            Text("No Training Plan")
                .font(.title3).fontWeight(.semibold)
            Text("Create a plan to schedule workouts and exercises across the week.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                planEditorItem = PlanEditorItem(id: UUID(), plan: nil)
            }) {
                Label("Create Your First Plan", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Plan Content

    private var planContent: some View {
        VStack(spacing: 0) {
            // Active plan header
            if let plan = planState.activePlan {
                activePlanHeader(plan: plan)
            }

            Divider()

            // Content: repeating plans show the current week; fixed plans show all weeks
            if let plan = planState.activePlan {
                if plan.weeks > 0 {
                    FullProgramView(plan: plan)
                        .environment(planState)
                        .environment(workoutsState)
                        .environment(exercisesState)
                } else {
                    WeekView(plan: plan)
                        .environment(planState)
                        .environment(workoutsState)
                        .environment(exercisesState)
                }
            }
        }
    }

    private func activePlanHeader(plan: TrainingPlan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.headline)
                Text(plan.weeks == 0 ? "Repeating weekly" : "\(plan.weeks) week\(plan.weeks == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                planEditorItem = PlanEditorItem(id: plan.id, plan: plan)
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
    }

}

// MARK: - Week View (This Week tab)

private struct WeekView: View {
    @Environment(TrainingPlanState.self) private var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState

    let plan: TrainingPlan

    @State private var editingDay: PlanDay? = nil
    @State private var editingWeekIndex: Int? = nil

    private let calendar = Calendar.current

    private var currentWeekIndex: Int {
        let start = calendar.startOfDay(for: plan.startDate)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return max(0, days / 7)
    }

    private var weekDays: [Date] {
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(weekDays, id: \.self) { date in
                    let weekday = calendar.component(.weekday, from: date) - 1
                    let planDay = plan.planDay(for: date)
                    let isToday = calendar.isDateInToday(date)

                    DayCard(
                        date: date,
                        planDay: planDay,
                        isToday: isToday,
                        workoutsState: workoutsState,
                        exercisesState: exercisesState
                    ) {
                        editingDay = planDay.isEmpty
                            ? PlanDay(dayOfWeek: weekday)
                            : planDay
                        editingWeekIndex = plan.weeks > 0 ? currentWeekIndex : nil
                    }
                }
            }
            .padding(16)
        }
        .fullScreenCover(item: $editingDay) { day in
            DayEditorSheet(
                day: day,
                weekIndex: editingWeekIndex,
                plan: plan
            ) { updatedDay, applyToAll in
                var updated = plan
                if applyToAll {
                    updated.applyToAllWeeks(updatedDay)
                } else {
                    // Repeating plan uses week 0; fixed plan uses current week
                    let wi = editingWeekIndex ?? 0
                    updated.setDay(updatedDay, forWeek: wi)
                }
                planState.updatePlan(updated)
            }
            .environment(workoutsState)
            .environment(exercisesState)
        }
    }
}

// MARK: - Day Card

private struct DayCard: View {
    let date: Date
    let planDay: PlanDay
    let isToday: Bool
    let workoutsState: WorkoutsState
    let exercisesState: ExercisesState
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    private var dateNumber: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }

    private var workouts: [Workout] {
        planDay.workoutIDs.compactMap { id in workoutsState.workouts.first { $0.id == id } }
    }

    private var exercises: [Exercise] {
        planDay.exerciseIDs.compactMap { id in
            exercisesState.exercises.first { $0.id == id }
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Date column
                VStack(spacing: 2) {
                    Text(dayLabel)
                        .font(.caption2)
                        .foregroundColor(isToday ? .accentColor : .secondary)
                    Text(dateNumber)
                        .font(.headline)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundColor(isToday ? .accentColor : .primary)
                }
                .frame(width: 36)

                // Content column
                VStack(alignment: .leading, spacing: 6) {
                    if planDay.isEmpty {
                        Text("Rest day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(workouts) { w in
                            HStack(spacing: 6) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                Text(w.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        if !exercises.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(exercises.map { $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        if !planDay.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(planDay.note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        isToday
                            ? RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1.5)
                            : nil
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full Program View

private struct FullProgramView: View {
    @Environment(TrainingPlanState.self) private var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState

    let plan: TrainingPlan

    @State private var editingDay: PlanDay? = nil
    @State private var editingWeekIndex: Int? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<plan.weeks, id: \.self) { weekIdx in
                    WeekSection(
                        plan: plan,
                        weekIndex: weekIdx
                    ) { day, wi in
                        editingDay = day
                        editingWeekIndex = wi
                    }
                }
            }
            .padding(16)
        }
        .fullScreenCover(item: $editingDay) { day in
            DayEditorSheet(
                day: day,
                weekIndex: editingWeekIndex,
                plan: plan
            ) { updatedDay, applyToAll in
                var updated = plan
                if applyToAll {
                    updated.applyToAllWeeks(updatedDay)
                } else {
                    updated.setDay(updatedDay, forWeek: editingWeekIndex ?? 0)
                }
                planState.updatePlan(updated)
            }
            .environment(workoutsState)
            .environment(exercisesState)
        }
    }
}

private struct WeekSection: View {
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState

    let plan: TrainingPlan
    let weekIndex: Int
    let onEditDay: (PlanDay, Int?) -> Void

    private let calendar = Calendar.current

    /// Returns the date for day offset (0–6) within this week, where 0 = plan.startDate's weekday.
    private func date(forDayIndex index: Int) -> Date {
        let start = calendar.startOfDay(for: plan.startDate)
        return calendar.date(byAdding: .day, value: weekIndex * 7 + index, to: start) ?? start
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Week \(weekIndex + 1)")
                    .font(.headline)
                let firstDay = date(forDayIndex: 0)
                let lastDay = date(forDayIndex: 6)
                let fmt = DateFormatter()
                let _ = { fmt.dateFormat = "MMM d" }()
                Text("· \(fmt.string(from: firstDay))–\(calendar.component(.day, from: lastDay))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            ForEach(0..<7, id: \.self) { dayIndex in
                let actualDate = date(forDayIndex: dayIndex)
                let dayOfWeek = calendar.component(.weekday, from: actualDate) - 1  // 0=Sun..6=Sat
                let day: PlanDay = {
                    let key = String(weekIndex)
                    if let overrides = plan.weekOverrides[key],
                       let d = overrides.first(where: { $0.dayOfWeek == dayOfWeek }) {
                        return d
                    }
                    return PlanDay(dayOfWeek: dayOfWeek)
                }()
                let isToday = calendar.isDateInToday(actualDate)

                Button(action: { onEditDay(day, weekIndex) }) {
                    HStack {
                        // Day label + date number column
                        VStack(spacing: 1) {
                            Text(dayOfWeek.dayOfWeekLabel)
                                .font(.caption2)
                                .foregroundColor(isToday ? .accentColor : .secondary)
                            Text("\(calendar.component(.day, from: actualDate))")
                                .font(.caption)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundColor(isToday ? .accentColor : .primary)
                        }
                        .frame(width: 32, alignment: .center)

                        if day.isEmpty {
                            Text("Rest")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                let dayWorkouts = day.workoutIDs.compactMap { id in
                                    workoutsState.workouts.first { $0.id == id }
                                }
                                ForEach(dayWorkouts) { w in
                                    Text(w.name).font(.caption).fontWeight(.semibold)
                                }
                                if !day.exerciseIDs.isEmpty {
                                    let names = day.exerciseIDs.compactMap { id in
                                        exercisesState.exercises.first { $0.id == id }?.name
                                    }
                                    Text(names.joined(separator: ", "))
                                        .font(.caption2).foregroundColor(.secondary).lineLimit(2)
                                }
                                if !day.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(day.note).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(UIColor.tertiarySystemBackground))
                            .overlay(
                                isToday ? RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 1.5) : nil
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Day Editor Sheet

struct DayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState

    let day: PlanDay
    let weekIndex: Int?   // nil = repeating plan (week 0)
    let plan: TrainingPlan
    /// Called with the updated day and whether to apply to all weeks.
    let onSave: (PlanDay, Bool) -> Void

    @State private var editedDay: PlanDay
    @State private var applyToAll: Bool = false
    @State private var showingWorkoutPicker = false
    @State private var showingExercisePicker = false

    init(day: PlanDay, weekIndex: Int?, plan: TrainingPlan, onSave: @escaping (PlanDay, Bool) -> Void) {
        self.day = day
        self.weekIndex = weekIndex
        self.plan = plan
        self.onSave = onSave
        _editedDay = State(initialValue: day)
    }

    /// For fixed multi-week plans only — show the scope picker.
    private var isFixedPlan: Bool { plan.weeks > 0 }

    private var dayTitle: String {
        let base = day.dayOfWeek.dayOfWeekFullLabel
        if let wi = weekIndex { return "Week \(wi + 1) – \(base)" }
        return base
    }

    private var selectedWorkouts: [Workout] {
        editedDay.workoutIDs.compactMap { id in workoutsState.workouts.first { $0.id == id } }
    }

    private var selectedExercises: [Exercise] {
        editedDay.exerciseIDs.compactMap { id in exercisesState.exercises.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            List {
                // Workouts section
                Section("Workouts") {
                    ForEach(selectedWorkouts) { w in
                        HStack {
                            Label(w.name, systemImage: "dumbbell.fill")
                                .font(.subheadline)
                            Spacer()
                            Button(action: { editedDay.workoutIDs.removeAll { $0 == w.id } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button(action: { showingWorkoutPicker = true }) {
                        Label("Add Workout", systemImage: "plus")
                            .foregroundColor(.accentColor)
                    }
                }

                // Exercises section
                Section {
                    ForEach(selectedExercises) { ex in
                        HStack {
                            Text(ex.name).font(.subheadline)
                            Spacer()
                            Button(action: {
                                editedDay.exerciseIDs.removeAll { $0 == ex.id }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button(action: { showingExercisePicker = true }) {
                        Label("Add Exercise", systemImage: "plus")
                            .foregroundColor(.accentColor)
                    }
                } header: {
                    Text("Exercises")
                }

                // Note section
                Section("Note") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $editedDay.note)
                            .font(.subheadline)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                        if editedDay.note.isEmpty {
                            Text("e.g. Active recovery, go for a walk…")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                }

                // Apply scope — only shown for fixed multi-week plans
                if isFixedPlan {
                    Section {
                        Toggle(isOn: $applyToAll) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apply to all weeks")
                                    .font(.subheadline)
                                Text("Copy this day's schedule to every week in the plan")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Clear day
                if !editedDay.isEmpty {
                    Section {
                        Button(role: .destructive, action: {
                            editedDay.workoutIDs = []
                            editedDay.exerciseIDs = []
                            editedDay.note = ""
                        }) {
                            Label("Clear Day (Rest)", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(editedDay, applyToAll)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            // Full-screen workout picker
            .fullScreenCover(isPresented: $showingWorkoutPicker) {
                WorkoutPickerSheet(selectedIDs: $editedDay.workoutIDs)
                    .environment(workoutsState)
            }
            // Full-screen exercise picker
            .fullScreenCover(isPresented: $showingExercisePicker) {
                ExercisePickerSheet(selectedIDs: $editedDay.exerciseIDs)
                    .environment(exercisesState)
            }
        }
    }
}

// MARK: - Workout Picker Sheet (multi-select)

private struct WorkoutPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutsState.self) private var workoutsState
    @Binding var selectedIDs: [UUID]
    @State private var searchText = ""

    private var filtered: [Workout] {
        let sorted = workoutsState.workouts.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                SearchField(text: $searchText, placeholder: "Search workouts...")
                    .listRowSeparator(.hidden)
                ForEach(filtered) { workout in
                    let isSelected = selectedIDs.contains(workout.id)
                    Button(action: {
                        if isSelected {
                            selectedIDs.removeAll { $0 == workout.id }
                        } else {
                            selectedIDs.append(workout.id)
                        }
                    }) {
                        HStack {
                            Text(workout.name)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Exercise Picker Sheet

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExercisesState.self) private var exercisesState
    @Binding var selectedIDs: [UUID]
    @State private var searchText = ""

    private var filtered: [Exercise] {
        let sorted = exercisesState.exercises.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                SearchField(text: $searchText, placeholder: "Search exercises...")
                    .listRowSeparator(.hidden)
                ForEach(filtered) { exercise in
                    let isSelected = selectedIDs.contains(exercise.id)
                    Button(action: {
                        if isSelected {
                            selectedIDs.removeAll { $0 == exercise.id }
                        } else {
                            selectedIDs.append(exercise.id)
                        }
                    }) {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Plan Editor Sheet (create / edit a plan)

struct PlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let plan: TrainingPlan?
    let onSave: (TrainingPlan) -> Void
    let onDelete: ((UUID) -> Void)?

    @State private var name: String
    @State private var startDate: Date
    @State private var isRepeating: Bool
    @State private var weeks: Int
    @State private var showingDeleteAlert = false

    init(plan: TrainingPlan?, onSave: @escaping (TrainingPlan) -> Void, onDelete: ((UUID) -> Void)? = nil) {
        self.plan = plan
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: plan?.name ?? "")
        _startDate = State(initialValue: plan?.startDate ?? Date())
        _isRepeating = State(initialValue: (plan?.weeks ?? 0) == 0)
        _weeks = State(initialValue: (plan?.weeks ?? 0) > 0 ? plan!.weeks : 4)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Details") {
                    TextField("Plan name", text: $name)
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                }

                Section("Duration") {
                    Toggle("Repeat forever", isOn: $isRepeating)
                    if !isRepeating {
                        Stepper("Duration: \(weeks) week\(weeks == 1 ? "" : "s")", value: $weeks, in: 1...52)
                    }
                }

                // Delete button only shown when editing an existing plan
                if onDelete != nil {
                    Section {
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete Plan", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(plan == nil ? "New Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Plan?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let p = plan { onDelete?(p.id) }
                    dismiss()
                }
            } message: {
                Text("This will permanently delete \"\(plan?.name ?? "")\".")
            }
        }
    }

    private func save() {
        var saved = plan ?? TrainingPlan(name: name, startDate: startDate, weeks: isRepeating ? 0 : weeks)
        saved.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.startDate = startDate
        saved.weeks = isRepeating ? 0 : weeks
        onSave(saved)
        dismiss()
    }
}

// MARK: - Manage Plans Sheet

private struct ManagePlansSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TrainingPlanState.self) private var planState
    let onEdit: (TrainingPlan) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(planState.plans) { plan in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(.subheadline)
                                .fontWeight(planState.activePlanID == plan.id ? .bold : .regular)
                            Text(plan.weeks == 0 ? "Repeating" : "\(plan.weeks) weeks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if planState.activePlanID == plan.id {
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        // Pencil icon to edit
                        Button(action: { onEdit(plan) }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        planState.setActive(id: plan.id)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            planState.removePlan(id: plan.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            onEdit(plan)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
