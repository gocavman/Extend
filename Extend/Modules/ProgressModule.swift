////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Module for tracking workout progress and viewing workout history
public struct ProgressModule: AppModule {
    public let id: UUID = ModuleIDs.progress
    public let displayName: String = "Log"
    public let iconName: String = "chart.line.uptrend.xyaxis"
    public let description: String = "Track progress and view workout history"
    
    public var order: Int = 3
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(ProgressModuleView())
    }
}

private struct ProgressModuleView: View {
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(TrainingPlanState.self) var planState
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(WaterState.self) var waterState
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    private var preferredScheme: ColorScheme? { appColorScheme == "dark" ? .dark : appColorScheme == "light" ? .light : nil }

    @State private var showPlan = false
    @State private var selectedDate = Date()
    /// Whether the user has explicitly tapped a day. False when just browsing months.
    @State private var hasSelectedDate = true
    @State private var currentMonth = Date()
    @State private var selectedLog: WorkoutLog?
    @State private var selectedJournalEntry: JournalEntry? = nil
    @State private var showJournalEditor = false
    @State private var journalEditorDate: Date = Date()
    /// When false the full month grid collapses to a single week strip
    @State private var isCalendarExpanded: Bool = true
    @State private var showMonthPicker = false
    @State private var showSearch = false
    @State private var searchText = ""

    /// Persisted: "calendar" or "timeline"
    @AppStorage("logViewMode") private var logViewMode: String = "calendar"
    /// Persisted: show 60-day activity ribbon
    @AppStorage("logShowRibbon") private var showRibbon: Bool = false
    /// Persisted calendar visibility filters
    @AppStorage("calendarShowWorkouts") private var showWorkouts: Bool = true
    @AppStorage("calendarShowJournals") private var showJournals: Bool = true
    @AppStorage("calendarShowPlans")    private var showPlans:    Bool = true
    @AppStorage("calendarShowWater")    private var showWater:    Bool = true
    /// Week vs month scope in list (timeline) view
    @AppStorage("logListShowWeek") private var listShowWeek: Bool = false
    @State private var showFilterPopover: Bool = false
    @State private var waterHistoryDate: IdentifiableDate? = nil

    private let calendar = Calendar.current

    private var monthYearString: String {
        let formatter = DateFormatter()
        // Show week range when: calendar is collapsed, or list view is in week scope
        let showingWeekRange = (logViewMode == "calendar" && !isCalendarExpanded) ||
                               (logViewMode == "timeline" && listShowWeek)
        if showingWeekRange {
            let weekDays = weekDaysForDate(selectedDate)
            guard let first = weekDays.first, let last = weekDays.last else {
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: currentMonth)
            }
            let mf = DateFormatter(); mf.dateFormat = "MMM d"
            let ml = DateFormatter(); ml.dateFormat = "d"
            let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
            if sameMonth {
                return "\(mf.string(from: first))–\(ml.string(from: last))"
            } else {
                let mfl = DateFormatter(); mfl.dateFormat = "MMM d"
                return "\(mf.string(from: first))–\(mfl.string(from: last))"
            }
        }
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    /// Returns the 7 dates for the week containing `date` (Sun–Sat).
    private func weekDaysForDate(_ date: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }
    }

    private func previousMonth() {
        let navigateByWeek = (logViewMode == "calendar" && !isCalendarExpanded) ||
                             (logViewMode == "timeline" && listShowWeek)
        if navigateByWeek {
            if let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                selectedDate = prev
                currentMonth = prev
            }
        } else {
            if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                currentMonth = newMonth
                applyDefaultSelection(for: newMonth)
            }
        }
    }

    private func nextMonth() {
        let navigateByWeek = (logViewMode == "calendar" && !isCalendarExpanded) ||
                             (logViewMode == "timeline" && listShowWeek)
        if navigateByWeek {
            if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
                selectedDate = next
                currentMonth = next
            }
        } else {
            if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                currentMonth = newMonth
                applyDefaultSelection(for: newMonth)
            }
        }
    }

    /// If navigating to the current month, select today. Otherwise clear the selection.
    private func applyDefaultSelection(for month: Date) {
        let isCurrentMonth = calendar.isDate(month, equalTo: Date(), toGranularity: .month)
        if isCurrentMonth {
            selectedDate = Date()
            hasSelectedDate = true
        } else {
            hasSelectedDate = false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: title + action icons
            HStack(spacing: 14) {
                Text("Log")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Search
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSearch = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 22, height: 22, alignment: .center)
                        .foregroundColor(.primary)
                }

                // New journal entry
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedJournalEntry = nil
                    journalEditorDate = hasSelectedDate ? selectedDate : Date()
                    showJournalEditor = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 22, height: 22, alignment: .center)
                        .foregroundColor(.primary)
                }

                // Training plan
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showPlan = true
                }) {
                    Image(systemName: "calendar.badge.checkmark")
                        .frame(width: 22, height: 22, alignment: .center)
                        .foregroundColor(planState.activePlan != nil ? Color(red: 1.0, green: 0.55, blue: 0.0) : .primary)
                }

                // Activity ribbon toggle
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showRibbon.toggle()
                }) {
                    Image(systemName: showRibbon ? "rectangle.grid.2x2.fill" : "rectangle.grid.2x2")
                        .frame(width: 22, height: 22, alignment: .center)
                        .foregroundColor(showRibbon ? .green : .primary)
                }

                // View mode toggle
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if logViewMode == "calendar" {
                        // Default list scope to week when switching from collapsed calendar
                        listShowWeek = !isCalendarExpanded
                        logViewMode = "timeline"
                    } else {
                        logViewMode = "calendar"
                    }
                }) {
                    Image(systemName: logViewMode == "calendar" ? "list.bullet.rectangle" : "calendar")
                        .frame(width: 22, height: 22, alignment: .center)
                        .foregroundColor(.primary)
                }
                
                // Calendar visibility filter
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showFilterPopover = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .frame(width: 22, height: 22, alignment: .center)
                        .foregroundColor((!showWorkouts || !showJournals || !showPlans || !showWater) ? .accentColor : .primary)
                }
                .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                    CalendarFilterPopover(
                        showWorkouts: $showWorkouts,
                        showJournals: $showJournals,
                        showPlans: $showPlans,
                        showWater: $showWater
                    )
                    .presentationCompactAdaptation(.popover)
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Row 2: month navigation (has all the room it needs)
            HStack(spacing: 4) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    previousMonth()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                }

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showMonthPicker = true
                }) {
                    Text(monthYearString)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    nextMonth()
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // Activity ribbon (optional)
                    if showRibbon {
                        ActivityRibbonView(logState: logState, anchorMonth: currentMonth, showWorkouts: showWorkouts, showJournals: showJournals, showPlans: showPlans, showWater: showWater)
                            .padding(.horizontal, 16)
                    }

                    if logViewMode == "calendar" {
                        if isCalendarExpanded {
                            // Full month grid
                            CalendarView(
                                currentMonth: $currentMonth,
                                selectedDate: $selectedDate,
                                logState: logState,
                                hasSelectedDate: hasSelectedDate,
                                showWorkouts: showWorkouts,
                                showJournals: showJournals,
                                showPlans: showPlans,
                                showWater: showWater,
                                onDaySelected: { hasSelectedDate = true }
                            ) {
                                // Collapse when a day is tapped
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    isCalendarExpanded = false
                                }
                            }
                            .padding(.horizontal, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            // Compact week strip + expand button
                            VStack(spacing: 0) {
                                WeekStripView(
                                    selectedDate: $selectedDate,
                                    logState: logState,
                                    weekDays: weekDaysForDate(selectedDate),
                                    showWorkouts: showWorkouts,
                                    showJournals: showJournals,
                                    showPlans: showPlans,
                                    showWater: showWater,
                                    onDaySelected: { hasSelectedDate = true }
                                )
                                .padding(.horizontal, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))

                                // Expand chevron pill
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        isCalendarExpanded = true
                                        currentMonth = selectedDate
                                    }
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 4)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 6)
                            }
                        }

                        // Selected Day's entries — only shown when a day has been explicitly tapped
                        if hasSelectedDate {
                            let dayLogs = logState.logsForDate(selectedDate)
                            let dayJournal = logState.journalEntriesForDate(selectedDate)
                            let dayPlanDay = planState.planDay(for: selectedDate)
                            let dayWaterOz = waterState.totalOzForDate(selectedDate)
                            let hasWater = dayWaterOz > 0
                            if !dayLogs.isEmpty || !dayJournal.isEmpty || hasWater {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(formattedDate(selectedDate))
                                        .font(.headline)
                                        .padding(.horizontal, 16)

                                    // Plan card — shown when this day has a planned workout
                                    if let pd = dayPlanDay, !pd.isEmpty {
                                        PlanDayCard(planDay: pd, planName: planState.activePlan?.name ?? "")
                                            .padding(.horizontal, 16)
                                    }

                                    // Interleave workouts and journal entries sorted by time
                                    let workoutItems: [(date: Date, view: AnyView)] = dayLogs.map { log in
                                        (date: log.completedAt, view: AnyView(
                                            WorkoutLogCard(log: log) { selectedLog = log }
                                                .padding(.horizontal, 16)
                                        ))
                                    }
                                    let journalItems: [(date: Date, view: AnyView)] = dayJournal.map { entry in
                                        (date: entry.date, view: AnyView(
                                            JournalEntryCard(entry: entry) {
                                                selectedJournalEntry = entry
                                            }
                                            .padding(.horizontal, 16)
                                        ))
                                    }
                                    let combined = (workoutItems + journalItems).sorted { $0.date > $1.date }
                                    ForEach(Array(combined.enumerated()), id: \.offset) { _, item in
                                        item.view
                                    }

                                    // Water summary row — tappable, opens filtered history
                                    if hasWater {
                                        WaterDaySummaryRow(
                                            oz: dayWaterOz,
                                            goal: waterState.dailyGoalOz,
                                            unit: waterState.unit
                                        ) {
                                            waterHistoryDate = IdentifiableDate(date: selectedDate)
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            } else {
                                VStack(spacing: 12) {
                                    // Plan card for this day (if any)
                                    if let pd = dayPlanDay, !pd.isEmpty {
                                        PlanDayCard(planDay: pd, planName: planState.activePlan?.name ?? "")
                                            .padding(.horizontal, 16)
                                    }

                                    VStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 44))
                                            .foregroundColor(.gray)

                                        Text("No workouts logged")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)

                                        Text("for \(formattedDate(selectedDate))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, isCalendarExpanded ? 40 : 24)
                                }
                            }
                        }
                    } else {
                        // Timeline View — week or month scope with toggle
                        TimelineLogView(
                            logState: logState,
                            month: currentMonth,
                            selectedDate: selectedDate,
                            showWeek: $listShowWeek,
                            showWorkouts: showWorkouts,
                            showJournals: showJournals,
                            showPlans: showPlans,
                            showWater: showWater
                        ) { log in
                            selectedLog = log
                        } onJournalTap: { entry in
                            selectedJournalEntry = entry
                        } onWaterTap: { date in
                            waterHistoryDate = IdentifiableDate(date: date)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .fullScreenCover(item: $selectedLog) { log in
            WorkoutLogDetailView(log: log)
                .environment(logState)
                .environment(exercisesState)
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerSheet(currentMonth: $currentMonth, onNavigate: applyDefaultSelection)
        }
        .sheet(isPresented: $showSearch) {
            LogSearchView(logState: logState,
                          selectedJournalEntry: $selectedJournalEntry)
        }
        .fullScreenCover(isPresented: $showJournalEditor) {
            JournalEntryEditorSheet(
                logState: logState,
                existingEntry: selectedJournalEntry,
                initialDate: journalEditorDate
            )
        }
        .fullScreenCover(item: $selectedJournalEntry) { entry in
            JournalEntryEditorSheet(
                logState: logState,
                existingEntry: entry,
                initialDate: entry.date
            )
        }
        .fullScreenCover(isPresented: $showPlan) {
            PlanModuleView()
                .environment(planState)
                .environment(workoutsState)
                .environment(exercisesState)
                .preferredColorScheme(preferredScheme)
        }
        .fullScreenCover(item: $waterHistoryDate) { id in
            NavigationStack {
                WaterHistorySheet(filterDate: id.date)
                    .environment(waterState)
            }
        }

    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Calendar View

private struct CalendarView: View {
    @Environment(TrainingPlanState.self) var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let logState: WorkoutLogState
    var hasSelectedDate: Bool = true
    var showWorkouts: Bool = true
    var showJournals: Bool = true
    var showPlans: Bool = true
    var showWater: Bool = true
    /// Called when user explicitly taps a day — lets parent mark a day as selected
    var onDaySelected: (() -> Void)? = nil
    /// Called after a day is selected — lets the parent collapse the calendar
    var onDayTapped: (() -> Void)? = nil

    private let calendar = Calendar.current
    private let columns: [GridItem] = {
        let spacing: CGFloat = 2
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
    }()
    
    private var days: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) else {
            return []
        }
        
        // Calculate how many weeks we need to show the entire month
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysInMonth = calendar.component(.day, from: monthLastDay)
        let totalDaysNeeded = firstWeekday - 1 + daysInMonth // days before month start + days in month
        let weeksNeeded = Int(ceil(Double(totalDaysNeeded) / 7.0))
        let totalCells = weeksNeeded * 7
        
        var dates: [Date?] = []
        var current = monthFirstWeek.start
        
        while dates.count < totalCells {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return dates
    }
    
    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let cellHeight: CGFloat = sizeClass == .regular ? 140 : 85
        VStack(spacing: 8) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
            }

            // Days grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        DayCell(
                            date: date,
                            isSelected: hasSelectedDate && calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: isCurrentMonth(date),
                            workoutCount: showWorkouts ? logState.logsForDate(date).count : 0,
                            logs: showWorkouts ? logState.logsForDate(date) : [],
                            journalEntries: showJournals ? logState.journalEntriesForDate(date) : [],
                            planName: {
                                guard showPlans, let pd = planState.planDay(for: date), let plan = planState.activePlan else { return nil }
                                let totalItems = pd.workoutIDs.count + pd.exerciseIDs.count
                                if totalItems == 1 {
                                    if let wid = pd.workoutIDs.first,
                                       let name = workoutsState.workouts.first(where: { $0.id == wid })?.name {
                                        return name
                                    }
                                    if let eid = pd.exerciseIDs.first,
                                       let name = exercisesState.exercises.first(where: { $0.id == eid })?.name {
                                        return name
                                    }
                                }
                                return plan.name
                            }(),
                            showWater: showWater,
                            waterOz: showWater ? WaterState.shared.totalOzForDate(date) : 0,
                            cellHeight: cellHeight
                        ) {
                            selectedDate = date
                            onDaySelected?()
                            onDayTapped?()
                        }
                    } else {
                        Color.clear
                            .frame(height: cellHeight)
                    }
                }
            }
        }
        .padding(2)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

}

// MARK: - Plan Day Card (shown in selected-day detail)

private struct PlanDayCard: View {
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState

    let planDay: PlanDay
    let planName: String

    private var workouts: [Workout] {
        planDay.workoutIDs.compactMap { id in workoutsState.workouts.first { $0.id == id } }
    }

    private var exercises: [Exercise] {
        planDay.exerciseIDs.compactMap { id in exercisesState.exercises.first { $0.id == id } }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Orange left accent edge
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 1.0, green: 0.55, blue: 0.0))
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.caption)
                        .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.0))
                    Text(planName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.0))
                }

                if !workouts.isEmpty {
                    ForEach(workouts) { w in
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(w.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }

                if !exercises.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption2)
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
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(planDay.note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Day Cell

private struct DayCellLabel {
    let text: String
    let isJournal: Bool
    let isPlan: Bool
    let isWater: Bool
    let isOverflow: Bool
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let workoutCount: Int
    let logs: [WorkoutLog]
    var journalEntries: [JournalEntry] = []
    var planName: String? = nil
    var showWater: Bool = true
    var waterOz: Double = 0
    var cellHeight: CGFloat = 85
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    private var hasWorkout: Bool { workoutCount > 0 }

    // Build up to 3 labels: workouts first, then journals, then plan.
    // If total > 3, slot 3 becomes "+N more" overflow label (iOS Calendar style).
    private var cellLabels: [DayCellLabel] {
        let hasWaterEntry = showWater && waterOz > 0
        let waterCount = hasWaterEntry ? 1 : 0
        let total = logs.count + journalEntries.count + (planName != nil ? 1 : 0) + waterCount
        var result: [DayCellLabel] = []

        if total <= 3 {
            // All items fit
            let maxOther = (planName != nil ? 1 : 0) + waterCount > 0 ? 3 - (planName != nil ? 1 : 0) - waterCount : 3
            for log in logs.prefix(max(0, maxOther)) {
                result.append(DayCellLabel(text: log.workoutName, isJournal: false, isPlan: false, isWater: false, isOverflow: false))
            }
            if result.count < maxOther {
                for entry in journalEntries.prefix(maxOther - result.count) {
                    result.append(DayCellLabel(text: entry.title, isJournal: true, isPlan: false, isWater: false, isOverflow: false))
                }
            }
            if let name = planName {
                result.append(DayCellLabel(text: name, isJournal: false, isPlan: true, isWater: false, isOverflow: false))
            }
            if hasWaterEntry {
                let label = String(format: "%.0f oz", waterOz)
                result.append(DayCellLabel(text: label, isJournal: false, isPlan: false, isWater: true, isOverflow: false))
            }
        } else {
            // Overflow: show 2 real items, then "+N more" in slot 3
            var filled = 0
            for log in logs.prefix(2) where filled < 2 {
                result.append(DayCellLabel(text: log.workoutName, isJournal: false, isPlan: false, isWater: false, isOverflow: false))
                filled += 1
            }
            if filled < 2 {
                for entry in journalEntries.prefix(2 - filled) {
                    result.append(DayCellLabel(text: entry.title, isJournal: true, isPlan: false, isWater: false, isOverflow: false))
                    filled += 1
                }
            }
            result.append(DayCellLabel(text: "+\(total - 2) more", isJournal: false, isPlan: false, isWater: false, isOverflow: true))
        }
        return result
    }

    private var backgroundColor: Color {
        isCurrentMonth ? Color(UIColor.secondarySystemBackground) : Color(UIColor.secondarySystemBackground).opacity(0.5)
    }

    private var textColor: Color {
        isCurrentMonth ? .primary : .gray
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 2) {
                // Day number — smaller to leave more room for labels
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
                            .frame(width: iPad ? 42 : 26, height: iPad ? 42 : 26)
                    }
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: iPad ? 24 : 15, weight: isToday ? .bold : .regular))
                        .foregroundColor(textColor)
                }
                .frame(height: iPad ? 42 : 26)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

                // Name labels: iOS Calendar-style colored capsule pills
                // ClippedTextLabel (UILabel-backed) inside a fixed-height frame handles
                // containment without "..." — gradient fades the right edge into the pill color.
                if !cellLabels.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(Array(cellLabels.enumerated()), id: \.offset) { _, item in
                            let pillBg: Color = item.isOverflow
                                ? Color(UIColor.tertiarySystemFill)
                                : (item.isPlan
                                    ? Color(red: 1.0, green: 0.55, blue: 0.0).opacity(isCurrentMonth ? 0.18 : 0.08)
                                    : (item.isJournal
                                        ? Color(red: 0.4, green: 0.35, blue: 0.75).opacity(isCurrentMonth ? 0.18 : 0.08)
                                        : (item.isWater
                                            ? Color(red: 0.2, green: 0.55, blue: 1.0).opacity(isCurrentMonth ? 0.18 : 0.08)
                                            : Color(red: 0.2, green: 0.75, blue: 0.35).opacity(isCurrentMonth ? 0.18 : 0.08))))
                            // Text: darker in light mode, lighter in dark mode for readability
                            let textOpacity: Double = isCurrentMonth ? 1 : 0.5
                            let pillText: Color = item.isOverflow
                                ? Color.secondary
                                : (item.isPlan
                                    ? (colorScheme == .dark
                                        ? Color(red: 1.0, green: 0.72, blue: 0.3).opacity(textOpacity)
                                        : Color(red: 0.75, green: 0.38, blue: 0.0).opacity(textOpacity))
                                    : (item.isJournal
                                        ? (colorScheme == .dark
                                            ? Color(red: 0.65, green: 0.60, blue: 1.0).opacity(textOpacity)
                                            : Color(red: 0.28, green: 0.22, blue: 0.60).opacity(textOpacity))
                                        : (item.isWater
                                            ? (colorScheme == .dark
                                                ? Color(red: 0.55, green: 0.78, blue: 1.0).opacity(textOpacity)
                                                : Color(red: 0.08, green: 0.35, blue: 0.80).opacity(textOpacity))
                                            : (colorScheme == .dark
                                                ? Color(red: 0.35, green: 0.90, blue: 0.50).opacity(textOpacity)
                                                : Color(red: 0.08, green: 0.50, blue: 0.18).opacity(textOpacity)))))
                            ZStack(alignment: .leading) {
                                ClippedTextLabel(
                                    text: item.text,
                                    fontSize: iPad ? 14 : 9,
                                    textColor: pillText
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Gradient fades into pill background color (not cell background)
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: pillBg.opacity(0), location: 0),
                                        .init(color: pillBg, location: 1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 15)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .frame(height: iPad ? 20 : 13)
                            .clipped()
                            .background(Capsule().fill(pillBg))
                        }
                    }
                    .padding(.horizontal, 3)
                }

                // Dot row: green = workout, purple = journal, orange = plan, blue = water
                HStack(spacing: 3) {
                    if workoutCount > 0 {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.75, blue: 0.35).opacity(isCurrentMonth ? 1 : 0.4))
                            .frame(width: iPad ? 8 : 5, height: iPad ? 8 : 5)
                    }
                    if !journalEntries.isEmpty {
                        Circle()
                            .fill(Color(red: 0.4, green: 0.35, blue: 0.75).opacity(isCurrentMonth ? 0.85 : 0.4))
                            .frame(width: iPad ? 8 : 5, height: iPad ? 8 : 5)
                    }
                    if planName != nil {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(isCurrentMonth ? 0.85 : 0.4))
                            .frame(width: iPad ? 8 : 5, height: iPad ? 8 : 5)
                    }
                    if showWater && WaterState.shared.totalOzForDate(date) > 0 {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.55, blue: 1.0).opacity(isCurrentMonth ? 0.85 : 0.4))
                            .frame(width: iPad ? 8 : 5, height: iPad ? 8 : 5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: cellHeight)
            .background(backgroundColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isToday ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week Strip View

/// Compact week strip shown when the calendar is collapsed.
private struct WeekStripView: View {
    @Environment(TrainingPlanState.self) var planState
    @Binding var selectedDate: Date
    let logState: WorkoutLogState
    let weekDays: [Date]
    var showWorkouts: Bool = true
    var showJournals: Bool = true
    var showPlans: Bool = true
    var showWater: Bool = true
    var onDaySelected: (() -> Void)? = nil

    private let calendar = Calendar.current

    private var dayLetters: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }

    var body: some View {
        VStack(spacing: 4) {
            // Day-of-week letter headers
            HStack(spacing: 0) {
                ForEach(Array(dayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day number circles
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(day)
                    let count = showWorkouts ? logState.logsForDate(day).count : 0
                    let journalCount = showJournals ? logState.journalEntriesForDate(day).count : 0
                    let hasPlan = showPlans && planState.planDay(for: day) != nil
                    let dayNum = calendar.component(.day, from: day)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedDate = day
                        onDaySelected?()
                    }) {
                        VStack(spacing: 3) {
                            ZStack {
                                // Selection ring
                                if isSelected {
                                    Circle()
                                        .fill(Color.primary)
                                        .frame(width: 34, height: 34)
                                } else if isToday {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 1.5)
                                        .frame(width: 34, height: 34)
                                }
                                Text("\(dayNum)")
                                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isSelected ? Color(UIColor.systemBackground) : .primary)
                            }
                            .frame(width: 34, height: 34)

                            // Dots: green = workout, purple = journal, orange = plan, blue = water
                            HStack(spacing: 3) {
                                if count > 0 {
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.75, blue: 0.35))
                                        .frame(width: 5, height: 5)
                                }
                                if journalCount > 0 {
                                    Circle()
                                        .fill(Color(red: 0.4, green: 0.35, blue: 0.75))
                                        .frame(width: 5, height: 5)
                                }
                                if hasPlan {
                                    Circle()
                                        .fill(Color(red: 1.0, green: 0.55, blue: 0.0))
                                        .frame(width: 5, height: 5)
                                }
                                if showWater && WaterState.shared.totalOzForDate(day) > 0 {
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.55, blue: 1.0))
                                        .frame(width: 5, height: 5)
                                }
                                // Placeholder to keep height consistent when no dots
                                if count == 0 && journalCount == 0 && !hasPlan && !(showWater && WaterState.shared.totalOzForDate(day) > 0) {
                                    Color.clear.frame(width: 5, height: 5)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Workout Log Card

// MARK: - Timeline View

/// An item in the timeline — a workout log, journal entry, or plan day
private enum TimelineItem {
    case workout(WorkoutLog)
    case journal(JournalEntry)
    case plan(PlanDay, planName: String)
    case water(oz: Double, goal: Double, unit: WaterUnit, date: Date)

    var date: Date {
        switch self {
        case .workout(let l): return l.completedAt
        case .journal(let e): return e.date
        case .plan(_, _): return Date()  // replaced per-day during grouping
        case .water(_, _, _, let d): return d
        }
    }
}

private struct TimelineLogView: View {
    @Environment(TrainingPlanState.self) var planState
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(ExercisesState.self) var exercisesState
    let logState: WorkoutLogState
    let month: Date
    let selectedDate: Date
    @Binding var showWeek: Bool
    var showWorkouts: Bool = true
    var showJournals: Bool = true
    var showPlans: Bool = true
    var showWater: Bool = true
    let onTap: (WorkoutLog) -> Void
    var onJournalTap: ((JournalEntry) -> Void)? = nil
    var onWaterTap: ((Date) -> Void)? = nil

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// All calendar days in the current scope (week or month), sorted descending
    private var scopeDays: [Date] {
        if showWeek {
            return weekDays.reversed()
        } else {
            let comps = calendar.dateComponents([.year, .month], from: month)
            guard let firstOfMonth = calendar.date(from: comps),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth) else { return [] }
            let dayCount = calendar.dateComponents([.day], from: firstOfMonth, to: endOfMonth).day ?? 0
            return (0...dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: firstOfMonth) }.reversed()
        }
    }

    private var groupedItems: [(date: Date, items: [TimelineItem])] {
        let start: Date
        let end: Date
        if showWeek {
            guard let first = weekDays.first, let last = weekDays.last else { return [] }
            start = calendar.startOfDay(for: first)
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) ?? last
        } else {
            let comps = calendar.dateComponents([.year, .month], from: month)
            let firstOfMonth = calendar.date(from: comps) ?? month
            start = calendar.startOfDay(for: firstOfMonth)
            end = calendar.date(byAdding: DateComponents(month: 1), to: firstOfMonth) ?? month
        }

        let filteredLogs = logState.sortedLogs.filter { $0.completedAt >= start && $0.completedAt < end }
        let filteredJournal = logState.sortedJournalEntries.filter { $0.date >= start && $0.date < end }

        // Build a dict of day → [logs/journal items]
        var dayItems: [Date: [TimelineItem]] = [:]
        if showWorkouts {
            for log in filteredLogs {
                let day = calendar.startOfDay(for: log.completedAt)
                dayItems[day, default: []].append(.workout(log))
            }
        }
        if showJournals {
            for entry in filteredJournal {
                let day = calendar.startOfDay(for: entry.date)
                dayItems[day, default: []].append(.journal(entry))
            }
        }

        // Add plan days into the dict (only non-empty days within scope)
        if showPlans {
            if let activePlan = planState.activePlan, let planName = planState.activePlan?.name {
                var current = start
                while current < end {
                    let day = calendar.startOfDay(for: current)
                    if planState.planDay(for: day) != nil {
                        let pd = activePlan.planDay(for: day)
                        if !pd.isEmpty {
                            dayItems[day, default: []].append(.plan(pd, planName: planName))
                        }
                    }
                    current = calendar.date(byAdding: .day, value: 1, to: current) ?? end
                }
            }
        }

        // Add water entries (one row per day that has water logged)
        if showWater {
            var current = start
            while current < end {
                let day = calendar.startOfDay(for: current)
                let oz = WaterState.shared.totalOzForDate(day)
                if oz > 0 {
                    let goal = WaterState.shared.dailyGoalOz
                    let unit = WaterState.shared.unit
                    dayItems[day, default: []].append(.water(oz: oz, goal: goal, unit: unit, date: day))
                }
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? end
            }
        }

        // Sort each day's items (workout/journal first, plan last)
        let sortedDays = dayItems.keys.sorted { $0 > $1 }
        return sortedDays.map { day in
            var items = dayItems[day] ?? []
            // Keep workouts & journals sorted by time desc, plan appended at end
            let nonPlan = items.filter { if case .plan = $0 { return false }; return true }
                               .sorted { $0.date > $1.date }
            let plans = items.filter { if case .plan = $0 { return true }; return false }
            items = nonPlan + plans
            return (date: day, items: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scope toggle
            Picker("Scope", selection: $showWeek) {
                Text("Week").tag(true)
                Text("Month").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if groupedItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 44))
                        .foregroundColor(.gray)
                    Text("No entries")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(showWeek ? "this week" : "this month")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groupedItems.enumerated()), id: \.offset) { groupIdx, group in
                        HStack(alignment: .top, spacing: 12) {
                            // Timeline spine
                            VStack(spacing: 0) {
                                if groupIdx > 0 {
                                    Rectangle()
                                        .fill(Color(red: 0.82, green: 0.82, blue: 0.84))
                                        .frame(width: 2)
                                        .frame(height: 12)
                                } else {
                                    Spacer().frame(height: 12)
                                }
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 10, height: 10)
                                Rectangle()
                                    .fill(Color(red: 0.82, green: 0.82, blue: 0.84))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(width: 10)
                            .padding(.leading, 16)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(timelineDateString(group.date))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)

                                ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                                    switch item {
                                    case .workout(let log):
                                        WorkoutLogCard(log: log) { onTap(log) }
                                    case .journal(let entry):
                                        JournalEntryCard(entry: entry) { onJournalTap?(entry) }
                                    case .plan(let pd, let planName):
                                        PlanDayCard(planDay: pd, planName: planName)
                                            .environment(workoutsState)
                                            .environment(exercisesState)
                                    case .water(let oz, let goal, let unit, let date):
                                        WaterDaySummaryRow(oz: oz, goal: goal, unit: unit) {
                                            onWaterTap?(date)
                                        }
                                    }
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
    }

    private func timelineDateString(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Activity Ribbon View

private struct ActivityRibbonView: View {
    @Environment(TrainingPlanState.self) var planState
    @Environment(\.horizontalSizeClass) private var sizeClass
    let logState: WorkoutLogState
    let anchorMonth: Date
    var showWorkouts: Bool = true
    var showJournals: Bool = true
    var showPlans: Bool = true
    var showWater: Bool = true

    private var iPad: Bool { sizeClass == .regular }
    private var cellSize: CGFloat { iPad ? 18 : 11 }
    private var cellSpacing: CGFloat { iPad ? 5 : 3 }

    // Nil entries = padding cells before the first real day
    private var buckets: [(date: Date?, workoutCount: Int, hasJournal: Bool, hasPlan: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // End on the last day of the viewed month (future months just show 0-count cells)
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorMonth))!
        let lastOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth) ?? today
        let anchor = lastOfMonth

        // Build 63 real days ending at anchor, oldest first
        let realDays: [(date: Date?, workoutCount: Int, hasJournal: Bool, hasPlan: Bool)] = (0..<63).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: anchor)!
            guard date <= today else { return (date: date, workoutCount: 0, hasJournal: false, hasPlan: false) }
            let wCount = showWorkouts ? logState.logsForDate(date).count : 0
            let jCount = showJournals ? logState.journalEntriesForDate(date).count : 0
            let plan = showPlans && planState.planDay(for: date) != nil
            return (date: date, workoutCount: wCount, hasJournal: jCount > 0, hasPlan: plan)
        }

        // Find the weekday of the oldest day (1=Sun … 7=Sat) and pad the front
        // so column 0 always lines up under "S" (Sunday)
        let firstDate = realDays.first!.date!
        let weekday = calendar.component(.weekday, from: firstDate) // 1-based
        let paddingCount = weekday - 1  // number of empty cells before first real day
        let padding: [(date: Date?, workoutCount: Int, hasJournal: Bool, hasPlan: Bool)] = Array(
            repeating: (date: nil, workoutCount: -1, hasJournal: false, hasPlan: false), count: paddingCount)
        return padding + realDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Week-day header
            HStack(spacing: cellSpacing) {
                ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: iPad ? 13 : 9))
                        .foregroundColor(.secondary)
                        .frame(width: cellSize, alignment: .center)
                }
            }

            // Grid — rows of 7, oldest top-left, aligned to weekday columns
            let rows = buckets.chunked(into: 7)
            VStack(spacing: cellSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: cellSpacing) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, bucket in
                            ZStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(bucket.date == nil ? Color.clear : cellColor(bucket.workoutCount))
                                    .frame(width: cellSize, height: cellSize)
                                // Purple dot for journal days (top-right corner)
                                if bucket.hasJournal {
                                    Circle()
                                        .fill(Color(red: 0.4, green: 0.35, blue: 0.75).opacity(0.9))
                                        .frame(width: cellSize * 0.38, height: cellSize * 0.38)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                        .padding(1)
                                }
                                // Orange dot for planned days (bottom-right corner)
                                if bucket.hasPlan && bucket.date != nil {
                                    Circle()
                                        .fill(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.9))
                                        .frame(width: cellSize * 0.38, height: cellSize * 0.38)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                        .padding(1)
                                }
                                // Blue dot for water days (bottom-left corner)
                                if showWater, let date = bucket.date, WaterState.shared.totalOzForDate(date) > 0 {
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.55, blue: 1.0).opacity(0.9))
                                        .frame(width: cellSize * 0.38, height: cellSize * 0.38)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                        .padding(1)
                                }
                            }
                            .frame(width: cellSize, height: cellSize)
                        }
                        // Pad short final row to keep alignment
                        if week.count < 7 {
                            ForEach(0..<(7 - week.count), id: \.self) { _ in
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func cellColor(_ count: Int) -> Color {
        switch count {
        case 0:       return Color(red: 0.88, green: 0.88, blue: 0.90)
        case 1:       return Color(red: 0.4,  green: 0.75, blue: 0.4)
        case 2:       return Color(red: 0.2,  green: 0.65, blue: 0.2)
        default:      return Color(red: 0.05, green: 0.5,  blue: 0.05)
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Journal Entry Card

private struct JournalEntryCard: View {
    let entry: JournalEntry
    let onTap: () -> Void

    private var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: entry.date)
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 0) {
                // Purple left accent edge
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.4, green: 0.35, blue: 0.75))
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.75))
                            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text(timeString)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if !entry.body.isEmpty {
                        Text(entry.body)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(12)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Journal Entry Editor Sheet

private struct JournalEntryEditorSheet: View {
    let logState: WorkoutLogState
    var existingEntry: JournalEntry?
    var initialDate: Date

    @Environment(\.dismiss) var dismiss

    @State private var entryTitle: String = ""
    @State private var entryBody: String = ""
    @State private var entryDate: Date = Date()
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Date picker row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date & Time")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        DatePicker("", selection: $entryDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider().padding(.horizontal, 16)

                    // Title field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        TextField("Add a title…", text: $entryTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    Divider().padding(.horizontal, 16)

                    // Body text editor
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $entryBody)
                                .font(.body)
                                .frame(minHeight: 260)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                            if entryBody.isEmpty {
                                Text("Add notes here...")
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    // Delete button (edit mode only)
                    if existingEntry != nil {
                        Divider().padding(.horizontal, 16)
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Entry")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 14)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle(existingEntry == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if var existing = existingEntry {
                            existing.date = entryDate
                            existing.title = entryTitle
                            existing.body = entryBody
                            logState.updateJournalEntry(existing)
                        } else {
                            logState.addJournalEntry(JournalEntry(date: entryDate, title: entryTitle, body: entryBody))
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(entryTitle.isEmpty && entryBody.isEmpty)
                }
            }
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .confirmationDialog("Delete this journal entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry = existingEntry {
                        logState.deleteJournalEntry(id: entry.id)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                entryDate = initialDate
                if let entry = existingEntry {
                    entryTitle = entry.title
                    entryBody = entry.body
                    entryDate = entry.date
                }
            }
        }
    }
}

// MARK: - Log Card

private struct WorkoutLogCard: View {
    let log: WorkoutLog
    let onTap: () -> Void
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: log.completedAt)
    }
    
    private var durationString: String {
        let minutes = Int(log.duration / 60)
        let seconds = Int(log.duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
    
    private func extractLinesCount(from notes: String) -> Int {
        // First try to find "Total Lines Read:" which explicitly states the count
        if let totalLinesRange = notes.range(of: "Total Lines Read: ") {
            let afterTotal = notes[totalLinesRange.upperBound...]
            if let endRange = afterTotal.range(of: "\n") {
                let totalText = String(afterTotal[..<endRange.lowerBound])
                if let count = Int(totalText) {
                    return count
                }
            } else {
                // No newline, so the number goes to end of string
                if let count = Int(String(afterTotal).trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return count
                }
            }
        }
        
        // Fallback: Count commas in old format "Lines: " section
        if let linesRange = notes.range(of: "Lines: ") {
            let afterLines = notes[linesRange.upperBound...]
            if let endRange = afterLines.range(of: "\n") {
                let linesText = String(afterLines[..<endRange.lowerBound])
                // Count commas and add 1 (number of items = commas + 1)
                let commaCount = linesText.filter { $0 == "," }.count
                return commaCount > 0 ? commaCount + 1 : 1
            }
        }
        return 0
    }
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 0) {
                // Green left accent edge
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.2, green: 0.75, blue: 0.35))
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(log.workoutName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(timeString)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    HStack(spacing: 16) {
                        if !log.exercises.isEmpty {
                            Label("\(log.exercises.count) exercises", systemImage: "list.bullet")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Label(durationString, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout Log Detail View

private struct WorkoutLogDetailView: View {
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(\.dismiss) var dismiss
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(EquipmentState.self) var equipmentState
    
    @State var log: WorkoutLog
    @State private var showDeleteAlert = false
    @State private var isEditing = false
    @State private var editingSnapshot: WorkoutLog? = nil
    
    // Helper computed properties for duration components
    private var hoursBinding: Binding<Int> {
        Binding(
            get: { Int(log.duration) / 3600 },
            set: { hours in
                let minutes = Int(log.duration) % 3600 / 60
                let seconds = Int(log.duration) % 60
                log.duration = TimeInterval(hours * 3600 + minutes * 60 + seconds)
            }
        )
    }
    
    private var minutesBinding: Binding<Int> {
        Binding(
            get: { (Int(log.duration) % 3600) / 60 },
            set: { mins in
                let hours = Int(log.duration) / 3600
                let seconds = Int(log.duration) % 60
                log.duration = TimeInterval(hours * 3600 + mins * 60 + seconds)
            }
        )
    }
    
    private var secondsBinding: Binding<Int> {
        Binding(
            get: { Int(log.duration) % 60 },
            set: { secs in
                let hours = Int(log.duration) / 3600
                let minutes = (Int(log.duration) % 3600) / 60
                log.duration = TimeInterval(hours * 3600 + minutes * 60 + secs)
            }
        )
    }

    /// Unified ordered list of exercises and rests, sorted by their original workout position.
    /// Exercises that share a loopID are grouped together; the first one in the group carries
    /// a loop header. Falls back to array order when orderIndex values are all 0 (old logs).
    private enum OrderedLogItem {
        case exercise(index: Int)   // index into log.exercises
        case rest(index: Int)       // index into log.restPeriods
        case loopHeader(loopID: UUID, exerciseIndices: [Int])
        case complexHeader(complexID: UUID, exerciseIndices: [Int])
    }

    private var orderedItems: [OrderedLogItem] {
        // If any item has a non-zero orderIndex, use proper ordering.
        // Otherwise fall back to exercises-then-rests (legacy logs).
        let hasOrdering = log.exercises.contains { $0.orderIndex != 0 } ||
                          log.restPeriods.contains { $0.orderIndex != 0 }

        guard hasOrdering else {
            // Legacy: exercises first, then rests
            var items: [OrderedLogItem] = []
            var seenLoops: Set<UUID> = []
            var seenComplexes: Set<UUID> = []
            for (i, ex) in log.exercises.enumerated() {
                if let lid = ex.loopID {
                    if seenLoops.contains(lid) { continue }
                    seenLoops.insert(lid)
                    let indices = log.exercises.indices.filter { log.exercises[$0].loopID == lid }
                    items.append(.loopHeader(loopID: lid, exerciseIndices: indices))
                    for idx in indices { items.append(.exercise(index: idx)) }
                } else if let cid = ex.complexID {
                    if seenComplexes.contains(cid) { continue }
                    seenComplexes.insert(cid)
                    let indices = log.exercises.indices.filter { log.exercises[$0].complexID == cid }
                    items.append(.complexHeader(complexID: cid, exerciseIndices: indices))
                    for idx in indices { items.append(.exercise(index: idx)) }
                } else {
                    items.append(.exercise(index: i))
                }
            }
            for i in log.restPeriods.indices { items.append(.rest(index: i)) }
            return items
        }

        // Build a combined list sorted by orderIndex
        struct Slot { var orderIndex: Int; var item: OrderedLogItem }
        var slots: [Slot] = []

        var seenLoops: Set<UUID> = []
        var seenComplexes: Set<UUID> = []

        for (i, ex) in log.exercises.enumerated() {
            if let lid = ex.loopID {
                if seenLoops.contains(lid) { continue }
                seenLoops.insert(lid)
                let indices = log.exercises.indices.filter { log.exercises[$0].loopID == lid }
                let minOrder = indices.map { log.exercises[$0].orderIndex }.min() ?? ex.orderIndex
                slots.append(Slot(orderIndex: minOrder, item: .loopHeader(loopID: lid, exerciseIndices: indices)))
                for idx in indices {
                    slots.append(Slot(orderIndex: log.exercises[idx].orderIndex, item: .exercise(index: idx)))
                }
            } else if let cid = ex.complexID {
                if seenComplexes.contains(cid) { continue }
                seenComplexes.insert(cid)
                let indices = log.exercises.indices.filter { log.exercises[$0].complexID == cid }
                let minOrder = indices.map { log.exercises[$0].orderIndex }.min() ?? ex.orderIndex
                slots.append(Slot(orderIndex: minOrder, item: .complexHeader(complexID: cid, exerciseIndices: indices)))
                for idx in indices {
                    slots.append(Slot(orderIndex: log.exercises[idx].orderIndex, item: .exercise(index: idx)))
                }
            } else {
                slots.append(Slot(orderIndex: ex.orderIndex, item: .exercise(index: i)))
            }
        }
        for (i, rest) in log.restPeriods.enumerated() {
            slots.append(Slot(orderIndex: rest.orderIndex, item: .rest(index: i)))
        }

        return slots.sorted { $0.orderIndex < $1.orderIndex }.map { $0.item }
    }
    
    private func extractLinesCount(from notes: String) -> Int {
        // First try to find "Total Lines Read:" which explicitly states the count
        if let totalLinesRange = notes.range(of: "Total Lines Read: ") {
            let afterTotal = notes[totalLinesRange.upperBound...]
            if let endRange = afterTotal.range(of: "\n") {
                let totalText = String(afterTotal[..<endRange.lowerBound])
                if let count = Int(totalText) {
                    return count
                }
            } else {
                // No newline, so the number goes to end of string
                if let count = Int(String(afterTotal).trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return count
                }
            }
        }
        
        // Fallback: Count commas in old format "Lines: " section
        if let linesRange = notes.range(of: "Lines: ") {
            let afterLines = notes[linesRange.upperBound...]
            if let endRange = afterLines.range(of: "\n") {
                let linesText = String(afterLines[..<endRange.lowerBound])
                // Count commas and add 1 (number of items = commas + 1)
                let commaCount = linesText.filter { $0 == "," }.count
                return commaCount > 0 ? commaCount + 1 : 1
            }
        }
        return 0
    }
    
    /// Swaps the orderIndex of the item at `position` in orderedItems with its neighbor
    /// at `position + delta` (delta = -1 for up, +1 for down).
    private func moveOrderedItem(at position: Int, delta: Int) {
        let items = orderedItems
        let target = position + delta
        guard items.indices.contains(position), items.indices.contains(target) else { return }

        func orderIndex(for item: OrderedLogItem) -> Int {
            switch item {
            case .exercise(let i): return log.exercises[i].orderIndex
            case .rest(let i): return log.restPeriods[i].orderIndex
            case .loopHeader(_, let indices): return indices.map { log.exercises[$0].orderIndex }.min() ?? 0
            case .complexHeader(_, let indices): return indices.map { log.exercises[$0].orderIndex }.min() ?? 0
            }
        }

        let srcOrder = orderIndex(for: items[position])
        let dstOrder = orderIndex(for: items[target])

        // Swap orderIndex values between the two items
        func applyOrder(_ item: OrderedLogItem, newOrder: Int) {
            switch item {
            case .exercise(let i): log.exercises[i].orderIndex = newOrder
            case .rest(let i): log.restPeriods[i].orderIndex = newOrder
            case .loopHeader(_, let indices):
                // Offset all exercises in the group by the same delta
                let baseOrder = indices.map { log.exercises[$0].orderIndex }.min() ?? 0
                let diff = newOrder - baseOrder
                for i in indices { log.exercises[i].orderIndex += diff }
            case .complexHeader(_, let indices):
                let baseOrder = indices.map { log.exercises[$0].orderIndex }.min() ?? 0
                let diff = newOrder - baseOrder
                for i in indices { log.exercises[i].orderIndex += diff }
            }
        }

        applyOrder(items[position], newOrder: dstOrder)
        applyOrder(items[target], newOrder: srcOrder)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var exercisesCountLabel: String? {
        guard !log.exercises.isEmpty else {
            return nil
        }
        return "\(log.exercises.count) exercises"
    }
    
    private var dateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: log.completedAt)
    }
    
    private var durationString: String {
        let hours = Int(log.duration / 3600)
        let minutes = Int(log.duration.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(log.duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Workout name (editable)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout Name")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)

                        if isEditing {
                            TextField("Workout name", text: $log.workoutName)
                                .font(.subheadline)
                                .textFieldStyle(.roundedBorder)
                                .padding(8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(6)
                        } else {
                            Text(log.workoutName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Date and duration
                    VStack(alignment: .leading, spacing: 8) {
                        if isEditing {
                            DatePicker("Date & Time", selection: $log.completedAt, displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline)
                        } else {
                            Text(dateTimeString)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            if isEditing {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Duration (hh:mm:ss)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    HStack(spacing: 8) {
                                        // Hours
                                        VStack(alignment: .center, spacing: 2) {
                                            Text("Hours")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            TextField("0", value: hoursBinding, format: .number)
                                                .keyboardType(.numberPad)
                                                .font(.caption)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 50)
                                        }
                                        
                                        // Minutes
                                        VStack(alignment: .center, spacing: 2) {
                                            Text("Mins")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            TextField("0", value: minutesBinding, format: .number)
                                                .keyboardType(.numberPad)
                                                .font(.caption)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 50)
                                        }
                                        
                                        // Seconds
                                        VStack(alignment: .center, spacing: 2) {
                                            Text("Secs")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            TextField("0", value: secondsBinding, format: .number)
                                                .keyboardType(.numberPad)
                                                .font(.caption)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 50)
                                        }
                                    }
                                }
                            } else {
                                Label("Duration: \(durationString)", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if let label = exercisesCountLabel {
                                Label(label, systemImage: "list.bullet")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Divider()
                    
                    // Workout Notes
                    if !log.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout Notes")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            if isEditing {
                                TextEditor(text: $log.notes)
                                    .font(.caption)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(6)
                            } else {
                                Text(log.notes)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Divider()
                    
                    // Exercises, rests, and loop headers in original workout order
                    let snapshot = orderedItems
                    ForEach(Array(snapshot.enumerated()), id: \.offset) { pos, item in
                        switch item {
                        case .loopHeader(_, let indices):
                            // Loop header: superset for 2, circuit for 3+
                            let loopLabel = indices.count == 2 ? "Loop / Superset" : "Loop / Circuit"
                            HStack(spacing: 6) {
                                if isEditing {
                                    reorderButtons(pos: pos, total: snapshot.count)
                                }
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(loopLabel)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Text("(\(indices.count) exercises)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        case .complexHeader(_, let indices):
                            HStack(spacing: 6) {
                                if isEditing {
                                    reorderButtons(pos: pos, total: snapshot.count)
                                }
                                Image(systemName: "square.stack.3d.up")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Complex")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Text("(\(indices.count) exercises)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        case .exercise(let exIdx):
                            exerciseRow(exIdx: exIdx, pos: pos, total: snapshot.count)

                        case .rest(let restIdx):
                            restRow(restIdx: restIdx, pos: pos, total: snapshot.count)
                        }
                    }

                    // In edit mode also show an add-rest button at the bottom
                    if isEditing {
                        HStack {
                            Spacer()
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                let maxOrder = (log.exercises.map(\.orderIndex) + log.restPeriods.map(\.orderIndex)).max() ?? -1
                                log.restPeriods.append(LoggedRest(configuredDuration: 60, actualDuration: 60, orderIndex: maxOrder + 1))
                            }) {
                                Label("Add Rest", systemImage: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(isEditing ? "Edit Workout" : log.workoutName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            if let snapshot = editingSnapshot {
                                log = snapshot
                            }
                            editingSnapshot = nil
                            isEditing = false
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isEditing {
                            // Save
                            logState.updateLog(log)
                            editingSnapshot = nil
                            isEditing = false
                        } else {
                            // Enter edit mode — snapshot current state
                            editingSnapshot = log
                            isEditing = true
                        }
                    }) {
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .foregroundColor(.primary)
                    }

                    Button(role: .destructive, action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Delete Workout Log?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    logState.deleteLog(id: log.id)
                    dismiss()
                }
            } message: {
                Text("This will permanently delete this workout log.")
            }
        }
    }

    @ViewBuilder
    private func reorderButtons(pos: Int, total: Int) -> some View {
        VStack(spacing: 0) {
            Button(action: { moveOrderedItem(at: pos, delta: -1) }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pos > 0 ? .secondary : .secondary.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(pos == 0)
            Button(action: { moveOrderedItem(at: pos, delta: 1) }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pos < total - 1 ? .secondary : .secondary.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(pos == total - 1)
        }
        .frame(width: 20)
    }

    @ViewBuilder
    private func exerciseRow(exIdx: Int, pos: Int = 0, total: Int = 1) -> some View {
        // We need a binding to the exercise at this index
        let exercise = log.exercises[exIdx]
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isEditing {
                    reorderButtons(pos: pos, total: total)
                }
                Text(exercise.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if !isEditing && exercise.activeSeconds > 0 {
                    Label(formatLogTime(exercise.activeSeconds), systemImage: "stopwatch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isEditing {
                    HStack(spacing: 2) {
                        Image(systemName: "stopwatch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0", value: Binding(
                            get: { log.exercises[exIdx].activeSeconds / 60 },
                            set: { log.exercises[exIdx].activeSeconds = $0 * 60 + log.exercises[exIdx].activeSeconds % 60 }
                        ), format: .number)
                            .keyboardType(.numberPad).font(.caption).frame(width: 30).textFieldStyle(.roundedBorder)
                        Text("min").font(.caption).foregroundColor(.secondary)
                        TextField("0", value: Binding(
                            get: { log.exercises[exIdx].activeSeconds % 60 },
                            set: { log.exercises[exIdx].activeSeconds = log.exercises[exIdx].activeSeconds / 60 * 60 + min($0, 59) }
                        ), format: .number)
                            .keyboardType(.numberPad).font(.caption).frame(width: 30).textFieldStyle(.roundedBorder)
                        Text("sec").font(.caption).foregroundColor(.secondary)
                    }

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        log.exercises[exIdx].sets.append(LoggedSet(reps: 0, weight: 0))
                    }) {
                        Image(systemName: "plus.circle.fill").foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !exercise.sets.isEmpty {
                let hasTimedSets = exercise.sets.contains { $0.timedSeconds > 0 }
                if isEditing {
                    ForEach(Array(exercise.sets.indices), id: \.self) { index in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Reps", value: Binding(
                                get: { log.exercises[exIdx].sets[index].reps },
                                set: { log.exercises[exIdx].sets[index].reps = $0 }
                            ), format: .number)
                                .keyboardType(.numberPad).font(.caption).frame(width: 40).textFieldStyle(.roundedBorder)
                            Text("×").font(.caption).foregroundColor(.gray)
                            TextField("Weight", value: Binding(
                                get: { log.exercises[exIdx].sets[index].weight },
                                set: { log.exercises[exIdx].sets[index].weight = $0 }
                            ), format: .number)
                                .keyboardType(.decimalPad).font(.caption).frame(width: 50).textFieldStyle(.roundedBorder)
                            Text(weightUnit).font(.caption).foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "timer").font(.caption2).foregroundColor(.secondary)
                                TextField("0", value: Binding(
                                    get: { log.exercises[exIdx].sets[index].timedSeconds / 60 },
                                    set: { log.exercises[exIdx].sets[index].timedSeconds = $0 * 60 + log.exercises[exIdx].sets[index].timedSeconds % 60 }
                                ), format: .number)
                                    .keyboardType(.numberPad).font(.caption).frame(width: 30).textFieldStyle(.roundedBorder)
                                Text("min").font(.caption).foregroundColor(.secondary)
                                TextField("0", value: Binding(
                                    get: { log.exercises[exIdx].sets[index].timedSeconds % 60 },
                                    set: { log.exercises[exIdx].sets[index].timedSeconds = log.exercises[exIdx].sets[index].timedSeconds / 60 * 60 + min($0, 59) }
                                ), format: .number)
                                    .keyboardType(.numberPad).font(.caption).frame(width: 30).textFieldStyle(.roundedBorder)
                                Text("sec").font(.caption).foregroundColor(.secondary)
                            }
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                log.exercises[exIdx].sets.remove(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    ForEach(Array(exercise.sets.groupedRuns().enumerated()), id: \.offset) { _, run in
                        HStack {
                            Text(run.label)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(run.set.reps) reps").font(.caption)
                            Text("×").font(.caption).foregroundColor(.gray)
                            Text(String(format: "%.1f \(weightUnit)", run.set.weight)).font(.caption)
                            if hasTimedSets {
                                Text(run.set.timedSeconds > 0 ? formatLogTime(run.set.timedSeconds) : "—")
                                    .font(.caption).foregroundColor(.secondary).frame(width: 64, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notes").font(.caption2).fontWeight(.semibold).foregroundColor(.gray)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: Binding(
                            get: { log.exercises[exIdx].notes },
                            set: { log.exercises[exIdx].notes = $0 }
                        ))
                        .font(.caption)
                        .frame(minHeight: 52)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(6)
                        if log.exercises[exIdx].notes.isEmpty {
                            Text("Exercise notes")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.top, 12)
                                .padding(.leading, 8)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.top, 4)
            } else if !exercise.notes.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Text("Notes: ").font(.caption).fontWeight(.semibold).foregroundColor(.gray)
                    Text(exercise.notes).font(.caption).foregroundColor(.gray)
                }
                .padding(.top, 4)
            }

            let allEquipment = (exercisesState.exercises.first { $0.id == exercise.exerciseID }?.equipmentIDs ?? [])
                .compactMap { id in equipmentState.sortedItems.first { $0.id == id } }
            if !allEquipment.isEmpty {
                let usedEquipment = allEquipment.filter { exercise.usedEquipmentIDs.contains($0.id) }
                if isEditing || !usedEquipment.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if isEditing {
                            Text("Equipment Used").font(.caption2).fontWeight(.semibold).foregroundColor(.gray)
                            HStack(spacing: 6) {
                                ForEach(allEquipment) { item in
                                    let selected = exercise.usedEquipmentIDs.contains(item.id)
                                    Button(action: {
                                        if selected {
                                            log.exercises[exIdx].usedEquipmentIDs.removeAll { $0 == item.id }
                                        } else {
                                            log.exercises[exIdx].usedEquipmentIDs.append(item.id)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 11))
                                                .foregroundColor(selected ? Color(UIColor.systemBackground) : .primary)
                                            Text(item.name).font(.caption).foregroundColor(selected ? Color(UIColor.systemBackground) : .primary)
                                        }
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(selected ? Color.primary : Color.primary.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        } else {
                            HStack(alignment: .top, spacing: 0) {
                                Text("Equipment: ").font(.caption).fontWeight(.semibold).foregroundColor(.gray)
                                Text(usedEquipment.map { $0.name }.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func restRow(restIdx: Int, pos: Int = 0, total: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if isEditing {
                    reorderButtons(pos: pos, total: total)
                }
                Image(systemName: "zzz")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Rest")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                if isEditing {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        log.restPeriods.remove(at: restIdx)
                    }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration").font(.caption2).foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            TextField("0", value: Binding(
                                get: { log.restPeriods[restIdx].actualDuration / 60 },
                                set: { log.restPeriods[restIdx].actualDuration = $0 * 60 + log.restPeriods[restIdx].actualDuration % 60 }
                            ), format: .number)
                                .keyboardType(.numberPad).font(.caption).frame(width: 28).textFieldStyle(.roundedBorder)
                            Text("min").font(.caption).foregroundColor(.secondary)
                            TextField("0", value: Binding(
                                get: { log.restPeriods[restIdx].actualDuration % 60 },
                                set: { log.restPeriods[restIdx].actualDuration = log.restPeriods[restIdx].actualDuration / 60 * 60 + min($0, 59) }
                            ), format: .number)
                                .keyboardType(.numberPad).font(.caption).frame(width: 28).textFieldStyle(.roundedBorder)
                            Text("sec").font(.caption).foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Configured: \(formatLogTime(log.restPeriods[restIdx].configuredDuration))")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("Rested: \(formatLogTime(log.restPeriods[restIdx].actualDuration))")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    private func formatLogTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}



// MARK: - Clipped Text Label

private struct ClippedTextLabel: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: Color

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.adjustsFontSizeToFitWidth = false
        label.minimumScaleFactor = 1.0
        label.allowsDefaultTighteningForTruncation = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
        uiView.font = UIFont.systemFont(ofSize: fontSize)
        uiView.textColor = UIColor(textColor)
    }
}

private struct MonthYearPickerSheet: View {
    @Binding var currentMonth: Date
    let onNavigate: (Date) -> Void
    @Environment(\.dismiss) var dismiss
    private let calendar = Calendar.current

    private static let monthNames = DateFormatter().monthSymbols ?? (1...12).map { "\($0)" }
    private static let currentYear = Calendar.current.component(.year, from: Date())
    private static let years = Array((2000...currentYear + 1))

    @State private var selectedMonth: Int = 0
    @State private var selectedYear: Int = 0

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Month wheel
                Picker("Month", selection: $selectedMonth) {
                    ForEach(0..<12, id: \.self) { i in
                        Text(Self.monthNames[i]).tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                // Year wheel
                Picker("Year", selection: $selectedYear) {
                    ForEach(Self.years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .navigationTitle("Jump to Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Go") {
                        var comps = DateComponents()
                        comps.year = selectedYear
                        comps.month = selectedMonth + 1
                        comps.day = 1
                        if let date = calendar.date(from: comps) {
                            currentMonth = date
                            onNavigate(date)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(280)])
        .onAppear {
            selectedMonth = calendar.component(.month, from: currentMonth) - 1
            selectedYear = calendar.component(.year, from: currentMonth)
        }
    }
}

private enum SearchResult {
    case workout(WorkoutLog)
    case journal(JournalEntry)
    var date: Date {
        switch self { case .workout(let l): return l.completedAt; case .journal(let e): return e.date }
    }
}

private struct LogSearchView: View {
    let logState: WorkoutLogState
    @Binding var selectedJournalEntry: JournalEntry?
    @Environment(\.dismiss) var dismiss
    @Environment(ExercisesState.self) var exercisesState

    @State private var query = ""
    @State private var selectedLog: WorkoutLog? = nil
    @FocusState private var isFocused: Bool

    private var results: [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        let workouts: [SearchResult] = logState.sortedLogs.compactMap { log in
            if log.workoutName.lowercased().contains(lower) { return .workout(log) }
            if log.notes.lowercased().contains(lower) { return .workout(log) }
            if log.exercises.contains(where: { $0.exerciseName.lowercased().contains(lower) }) { return .workout(log) }
            return nil
        }
        let journal: [SearchResult] = logState.sortedJournalEntries.compactMap { entry in
            if entry.title.lowercased().contains(lower) { return .journal(entry) }
            if entry.body.lowercased().contains(lower) { return .journal(entry) }
            return nil
        }
        return (workouts + journal).sorted { $0.date > $1.date }
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search logs…", text: $query)
                        .focused($isFocused)
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button(action: { query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                        Text("Search by workout name,\nexercise, notes, or journal")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    Spacer()
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                        Text("No results for \"\(query)\"")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                    Spacer()
                } else {
                    List(Array(results.enumerated()), id: \.offset) { _, result in
                        Button(action: {
                            switch result {
                            case .workout(let log): selectedLog = log
                            case .journal(let entry):
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    selectedJournalEntry = entry
                                }
                            }
                        }) {
                            switch result {
                            case .workout(let log):
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(log.workoutName)
                                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                                    Text(dateFormatter.string(from: log.completedAt))
                                        .font(.caption).foregroundColor(.secondary)
                                    if !log.exercises.isEmpty {
                                        Text(log.exercises.map { $0.exerciseName }.joined(separator: ", "))
                                            .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            case .journal(let entry):
                                HStack(spacing: 8) {
                                    Image(systemName: "note.text")
                                        .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.75))
                                        .font(.subheadline)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title.isEmpty ? "Untitled" : entry.title)
                                            .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                                        Text(dateFormatter.string(from: entry.date))
                                            .font(.caption).foregroundColor(.secondary)
                                        if !entry.body.isEmpty {
                                            Text(entry.body)
                                                .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
            .fullScreenCover(item: $selectedLog) { log in
                WorkoutLogDetailView(log: log)
                    .environment(logState)
                    .environment(exercisesState)
            }
        }
    }
}

// MARK: - Calendar Filter Popover

private struct CalendarFilterPopover: View {
    @Binding var showWorkouts: Bool
    @Binding var showJournals: Bool
    @Binding var showPlans: Bool
    @Binding var showWater: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Show in Calendar")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Divider()

            filterRow(label: "Workouts", systemImage: "dumbbell.fill",
                      color: Color(red: 0.2, green: 0.75, blue: 0.35), isOn: $showWorkouts)
            Divider().padding(.leading, 48)
            filterRow(label: "Journals", systemImage: "note.text",
                      color: Color(red: 0.4, green: 0.35, blue: 0.75), isOn: $showJournals)
            Divider().padding(.leading, 48)
            filterRow(label: "Plans", systemImage: "calendar.badge.checkmark",
                      color: Color(red: 1.0, green: 0.55, blue: 0.0), isOn: $showPlans)
            Divider().padding(.leading, 48)
            filterRow(label: "Water", systemImage: "drop.fill",
                      color: Color(red: 0.2, green: 0.55, blue: 1.0), isOn: $showWater)

            Divider()
        }
        .frame(width: 220)
    }

    @ViewBuilder
    private func filterRow(label: String, systemImage: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(label)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                if isOn.wrappedValue {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Identifiable wrapper for Date (used for fullScreenCover(item:))

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Water day summary row (used in calendar day detail)

private struct WaterDaySummaryRow: View {
    let oz: Double
    let goal: Double
    let unit: WaterUnit
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let waterBlue = Color(red: 0.2, green: 0.55, blue: 1.0)

    var body: some View {
        let display = unit.fromOz(oz)
        let goalDisplay = unit.fromOz(goal)
        let metGoal = oz >= goal
        let pillText = colorScheme == .dark
            ? Color(red: 0.55, green: 0.78, blue: 1.0)
            : Color(red: 0.08, green: 0.35, blue: 0.80)

        Button(action: onTap) {
            HStack(spacing: 0) {
                // Blue left accent edge
                RoundedRectangle(cornerRadius: 2)
                    .fill(waterBlue)
                    .frame(width: 4)
                    .padding(.vertical, 2)

                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(waterBlue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 20)

                    Text(String(format: "%.0f / %.0f %@", display, goalDisplay, unit.displayName))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(pillText)

                    Spacer()

                    if metGoal {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(waterBlue)
                            .font(.system(size: 13))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(pillText.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProgressModuleView()
        .environment(WorkoutLogState.shared)
        .environment(ExercisesState.shared)
}
