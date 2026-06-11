import SwiftUI

// MARK: - Plan Module View (entry point — Manage Plans root with push to day view)

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
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }
    @Environment(VoiceTrainerState.self) private var voiceTrainerState

    @State private var planEditorItem: PlanEditorItem? = nil
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            planListRoot
                .navigationDestination(for: TrainingPlan.self) { plan in
                    PlanDaysView(plan: plan)
                        .environment(planState)
                        .environment(workoutsState)
                        .environment(exercisesState)
                        .environment(voiceTrainerState)
                }
        }
        .preferredColorScheme(preferredScheme)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        // Full-screen plan editor (new or edit)
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
                onDelete: item.plan != nil ? { id in
                    planState.removePlan(id: id)
                    // If we were viewing this plan's days, pop back
                    navigationPath = NavigationPath()
                } : nil
            )
            .environment(workoutsState)
            .environment(exercisesState)
            .preferredColorScheme(preferredScheme)
        }
    }

    // MARK: - Plan List Root (Manage Plans)

    private var planListRoot: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            if planState.plans.isEmpty {
                emptyState
            } else {
                planList
            }
        }
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    planEditorItem = PlanEditorItem(id: UUID(), plan: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var planList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(planState.plans) { plan in
                    planRow(plan: plan)
                }
            }
            .padding(16)
        }
    }

    private func planRow(plan: TrainingPlan) -> some View {
        let isActive = planState.activePlanID == plan.id
        return HStack {
            // Tappable area — pushes to plan days view
            Button {
                navigationPath.append(plan)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(.subheadline)
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(.primary)
                        Text(plan.weeks == 0 ? "Repeating weekly" : "\(plan.weeks) week\(plan.weeks == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Trailing action buttons
            HStack(spacing: 8) {
                // Activate / Active badge
                Button {
                    let newID: UUID? = isActive ? nil : plan.id
                    planState.setActive(id: newID)
                } label: {
                    Text(isActive ? "Active" : "Activate")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isActive ? Color.accentColor : Color(UIColor.tertiarySystemBackground))
                        .foregroundColor(isActive ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Edit plan name/settings
                Button {
                    planEditorItem = PlanEditorItem(id: plan.id, plan: plan)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.secondary)
            Text("No Training Plans")
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
}

// MARK: - Plan Days View (pushed from Manage Plans)

/// Shows the week or full program for a given plan.
private struct PlanDaysView: View {
    @Environment(TrainingPlanState.self) private var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

    let plan: TrainingPlan

    @State private var planEditorItem: PlanEditorItem? = nil

    /// The live version of this plan from state (so edits reflect immediately).
    private var livePlan: TrainingPlan {
        planState.plans.first { $0.id == plan.id } ?? plan
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            if livePlan.weeks > 0 {
                FullProgramView(plan: livePlan)
                    .environment(planState)
                    .environment(workoutsState)
                    .environment(exercisesState)
            } else {
                WeekView(plan: livePlan)
                    .environment(planState)
                    .environment(workoutsState)
                    .environment(exercisesState)
            }
        }
        .navigationTitle(livePlan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    planEditorItem = PlanEditorItem(id: livePlan.id, plan: livePlan)
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .fullScreenCover(item: $planEditorItem) { item in
            PlanEditorSheet(
                plan: item.plan,
                onSave: { saved in planState.updatePlan(saved) },
                onDelete: { id in planState.removePlan(id: id) }
            )
            .environment(workoutsState)
            .environment(exercisesState)
            .preferredColorScheme(preferredScheme)
        }
    }
}

// MARK: - Week View (This Week tab)

private struct WeekView: View {
    @Environment(TrainingPlanState.self) private var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @Environment(TimerState.self) private var timerState

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
                        exercisesState: exercisesState,
                        voiceTrainerState: voiceTrainerState,
                        timerState: timerState
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
            .environment(voiceTrainerState)
            .environment(timerState)
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
    let voiceTrainerState: VoiceTrainerState
    let timerState: TimerState
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

    private var voiceActivities: [VoiceTrainerConfig] {
        planDay.voiceActivityIDs.compactMap { id in
            voiceTrainerState.savedConfigurations.first { $0.id == id }
        }
    }

    private var timers: [TimerConfig] {
        planDay.timerIDs.compactMap { id in timerState.configs.first { $0.id == id } }
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
                                    .foregroundColor(.primary)
                                Text(exercises.map { $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                        }
                        if !voiceActivities.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text(voiceActivities.map { $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                        }
                        if !timers.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text(timers.map { $0.name.isEmpty ? $0.type.rawValue : $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.primary)
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
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @Environment(TimerState.self) private var timerState

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
            .environment(voiceTrainerState)
            .environment(timerState)
        }
    }
}

private struct WeekSection: View {
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @Environment(TimerState.self) private var timerState

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
                                    Label(w.name, systemImage: "dumbbell.fill")
                                        .font(.caption).fontWeight(.semibold).foregroundColor(.primary)
                                }
                                if !day.exerciseIDs.isEmpty {
                                    let names = day.exerciseIDs.compactMap { id in
                                        exercisesState.exercises.first { $0.id == id }?.name
                                    }
                                    Label(names.joined(separator: ", "), systemImage: "figure.strengthtraining.traditional")
                                        .font(.caption2).foregroundColor(.primary).lineLimit(2)
                                }
                                if !day.voiceActivityIDs.isEmpty {
                                    let names = day.voiceActivityIDs.compactMap { id in
                                        voiceTrainerState.savedConfigurations.first { $0.id == id }?.name
                                    }
                                    Label(names.joined(separator: ", "), systemImage: "waveform")
                                        .font(.caption2).foregroundColor(.primary).lineLimit(2)
                                }
                                if !day.timerIDs.isEmpty {
                                    let names = day.timerIDs.compactMap { id -> String? in
                                        guard let c = timerState.configs.first(where: { $0.id == id }) else { return nil }
                                        return c.name.isEmpty ? c.type.rawValue : c.name
                                    }
                                    Label(names.joined(separator: ", "), systemImage: "timer")
                                        .font(.caption2).foregroundColor(.primary).lineLimit(2)
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
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @Environment(TimerState.self) private var timerState
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

    let day: PlanDay
    let weekIndex: Int?   // nil = repeating plan (week 0)
    let plan: TrainingPlan
    /// Called with the updated day and whether to apply to all weeks.
    let onSave: (PlanDay, Bool) -> Void

    @State private var editedDay: PlanDay
    @State private var applyToAll: Bool = false
    @State private var showingWorkoutPicker = false
    @State private var showingExercisePicker = false
    @State private var showingVoicePicker = false
    @State private var showingTimerPicker = false

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
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.startDate)
        let weekIdx = weekIndex ?? 0
        let startWeekday = calendar.component(.weekday, from: start) - 1 // 0 = Sunday
        var dayOffset = day.dayOfWeek - startWeekday
        if dayOffset < 0 { dayOffset += 7 }
        let date = calendar.date(byAdding: .day, value: weekIdx * 7 + dayOffset, to: start) ?? start
        let formatted = date.formatted(.dateTime.month(.abbreviated).day())
        if let wi = weekIndex { return "Week \(wi + 1) · \(base), \(formatted)" }
        return "\(base), \(formatted)"
    }

    private var selectedWorkouts: [Workout] {
        editedDay.workoutIDs.compactMap { id in workoutsState.workouts.first { $0.id == id } }
    }

    private var selectedExercises: [Exercise] {
        editedDay.exerciseIDs.compactMap { id in exercisesState.exercises.first { $0.id == id } }
    }

    private var selectedVoiceActivities: [VoiceTrainerConfig] {
        editedDay.voiceActivityIDs.compactMap { id in voiceTrainerState.savedConfigurations.first { $0.id == id } }
    }

    private var selectedTimers: [TimerConfig] {
        editedDay.timerIDs.compactMap { id in timerState.configs.first { $0.id == id } }
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

                // Voice Activities section
                Section("Voice Trainer Activities") {
                    ForEach(selectedVoiceActivities) { config in
                        HStack {
                            Label(config.name, systemImage: "waveform")
                                .font(.subheadline)
                            Spacer()
                            Button(action: { editedDay.voiceActivityIDs.removeAll { $0 == config.id } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button(action: { showingVoicePicker = true }) {
                        Label("Add Voice Activity", systemImage: "plus")
                            .foregroundColor(.accentColor)
                    }
                }

                // Timers section
                Section("Timers") {
                    ForEach(selectedTimers) { config in
                        HStack {
                            Label(config.name.isEmpty ? config.type.rawValue : config.name, systemImage: config.type.iconName)
                                .font(.subheadline)
                            Spacer()
                            Button(action: { editedDay.timerIDs.removeAll { $0 == config.id } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button(action: { showingTimerPicker = true }) {
                        Label("Add Timer", systemImage: "plus")
                            .foregroundColor(.accentColor)
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

                // Clear day
                if !editedDay.isEmpty {
                    Section {
                        Button(role: .destructive, action: {
                            editedDay.workoutIDs = []
                            editedDay.exerciseIDs = []
                            editedDay.voiceActivityIDs = []
                            editedDay.timerIDs = []
                            editedDay.note = ""
                        }) {
                            Label("Clear Day (Rest)", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
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
            // Full-screen voice activity picker
            .fullScreenCover(isPresented: $showingVoicePicker) {
                VoiceActivityPickerSheet(selectedIDs: $editedDay.voiceActivityIDs)
                    .environment(voiceTrainerState)
            }
            // Full-screen timer picker
            .fullScreenCover(isPresented: $showingTimerPicker) {
                TimerPickerSheet(selectedIDs: $editedDay.timerIDs)
                    .environment(timerState)
            }
        } // NavigationStack
        .preferredColorScheme(preferredScheme)
    }
}

// MARK: - Workout Picker Sheet (multi-select)

private struct WorkoutPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutsState.self) private var workoutsState
    @Binding var selectedIDs: [UUID]
    @State private var searchText = ""
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

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
        .preferredColorScheme(preferredScheme)
    }
}

// MARK: - Exercise Picker Sheet

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExercisesState.self) private var exercisesState
    @Binding var selectedIDs: [UUID]
    @State private var searchText = ""
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

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
        .preferredColorScheme(preferredScheme)
    }
}

// MARK: - Voice Activity Picker Sheet

private struct VoiceActivityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @Binding var selectedIDs: [UUID]
    @State private var searchText = ""
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

    private var filtered: [VoiceTrainerConfig] {
        let sorted = voiceTrainerState.savedConfigurations.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                SearchField(text: $searchText, placeholder: "Search voice activities...")
                    .listRowSeparator(.hidden)
                if filtered.isEmpty {
                    Text("No saved voice activities")
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                }
                ForEach(filtered) { config in
                    let isSelected = selectedIDs.contains(config.id)
                    Button(action: {
                        if isSelected {
                            selectedIDs.removeAll { $0 == config.id }
                        } else {
                            selectedIDs.append(config.id)
                        }
                    }) {
                        HStack {
                            Label(config.name, systemImage: "waveform")
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
            .navigationTitle("Select Voice Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(preferredScheme)
    }
}

// MARK: - Timer Picker Sheet (multi-select)

private struct TimerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TimerState.self) private var timerState
    @Binding var selectedIDs: [UUID]
    @State private var searchText = ""
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

    private var filtered: [TimerConfig] {
        let sorted = timerState.configs.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            let label = $0.name.isEmpty ? $0.type.rawValue : $0.name
            return label.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                SearchField(text: $searchText, placeholder: "Search timers...")
                    .listRowSeparator(.hidden)
                if filtered.isEmpty {
                    Text("No saved timers")
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                }
                ForEach(filtered) { config in
                    let label = config.name.isEmpty ? config.type.rawValue : config.name
                    let isSelected = selectedIDs.contains(config.id)
                    Button(action: {
                        if isSelected {
                            selectedIDs.removeAll { $0 == config.id }
                        } else {
                            selectedIDs.append(config.id)
                        }
                    }) {
                        HStack {
                            Label(label, systemImage: config.type.iconName)
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
            .navigationTitle("Select Timers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(preferredScheme)
    }
}

// MARK: - Plan Editor Sheet (create / edit a plan)

struct PlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

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
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
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
        .preferredColorScheme(preferredScheme)
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

// MARK: - Today's Plan Module

/// Module for viewing and launching today's planned activities from the navbar.
public struct TodaysPlanModule: AppModule {
    public let id: UUID = ModuleIDs.todaysPlan
    public let displayName: String = "Plan"
    public let iconName: String = "calendar.badge.checkmark"
    public let description: String = "View and launch today's planned activities"

    public var order: Int = 14
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(TodaysPlanModuleView())
    }
}

struct TodaysPlanModuleView: View {
    @Environment(TrainingPlanState.self) private var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @Environment(TimerState.self) private var timerState
    @Environment(ModuleState.self) private var moduleState
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var startingWorkout: Workout? = nil
    @State private var showPlan = false

    private var planDay: PlanDay? { planState.planDay(for: selectedDate) }

    /// Names of logs completed on selectedDate for checkmark display
    private var completedLogNames: Set<String> {
        let cal = Calendar.current
        let logs = WorkoutLogState.shared.logs.filter { cal.isDate($0.completedAt, inSameDayAs: selectedDate) }
        return Set(logs.map { $0.workoutName })
    }

    private func isCompleted(workoutName name: String) -> Bool {
        completedLogNames.contains(name)
    }

    private func isVoiceCompleted(_ config: VoiceTrainerConfig) -> Bool {
        completedLogNames.contains("Trainer – \(config.name)")
    }

    private func isTimerCompleted(_ config: TimerConfig) -> Bool {
        let displayName = config.name.isEmpty ? config.type.rawValue : config.name
        return completedLogNames.contains("\(config.type.rawValue) – \(displayName)")
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                // Custom header row (replaces NavigationStack title + toolbar)
                HStack {
                    Text("Today's Plan")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showPlan = true
                    } label: {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Date navigation bar
                HStack {
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(selectedDate, style: .date)
                        .font(.headline)
                    Spacer()
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if let pd = planDay, !pd.isEmpty {
                    List {
                        let workouts = pd.workoutIDs.compactMap { id in workoutsState.workouts.first { $0.id == id } }
                        if !workouts.isEmpty {
                            Section("Workouts") {
                                ForEach(workouts) { w in
                                    Button {
                                        startingWorkout = w
                                    } label: {
                                        HStack {
                                            Label(w.name, systemImage: "dumbbell.fill")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if isCompleted(workoutName: w.name) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        let exercises = pd.exerciseIDs.compactMap { id in exercisesState.exercises.first { $0.id == id } }
                        if !exercises.isEmpty {
                            Section("Exercises") {
                                ForEach(exercises) { ex in
                                    Button {
                                        startingWorkout = Workout(
                                            name: "\(ex.name)",
                                            notes: "",
                                            items: [.exercise(WorkoutExercise(exerciseID: ex.id))]
                                        )
                                    } label: {
                                        HStack {
                                            Label(ex.name, systemImage: "figure.strengthtraining.traditional")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if isCompleted(workoutName: "\(ex.name)") {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        let configs = pd.voiceActivityIDs.compactMap { id in voiceTrainerState.savedConfigurations.first { $0.id == id } }
                        if !configs.isEmpty {
                            Section("Voice Activities") {
                                ForEach(configs) { c in
                                    Button {
                                        voiceTrainerState.pendingLaunchID = c.id
                                        moduleState.selectModule(ModuleIDs.voiceTrainer)
                                    } label: {
                                        HStack {
                                            Label(c.name, systemImage: "waveform")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if isVoiceCompleted(c) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        let timerConfigs = pd.timerIDs.compactMap { id in timerState.configs.first { $0.id == id } }
                        if !timerConfigs.isEmpty {
                            Section("Timers") {
                                ForEach(timerConfigs) { c in
                                    Button {
                                        timerState.pendingLaunchID = c.id
                                        moduleState.selectModule(ModuleIDs.timer)
                                    } label: {
                                        HStack {
                                            Label(c.name.isEmpty ? c.type.rawValue : c.name, systemImage: c.type.iconName)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if isTimerCompleted(c) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.systemBackground))
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(planState.activePlan == nil ? "No active plan" : "Rest day")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } // VStack
        } // ZStack
        .fullScreenCover(isPresented: $showPlan) {
            PlanModuleView()
                .environment(planState)
                .environment(workoutsState)
                .environment(exercisesState)
                .environment(voiceTrainerState)
                .preferredColorScheme(preferredScheme)
        }
        .fullScreenCover(item: $startingWorkout) { workout in
            StartWorkoutView(workout: workout)
                .environment(moduleState)
                .environment(exercisesState)
                .environment(MuscleGroupsState.shared)
                .environment(EquipmentState.shared)
                .environment(WorkoutLogState.shared)
        }
    }
}
