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
    /// Week vs month scope in list (timeline) view
    @State private var listShowWeek: Bool = false

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
                        .foregroundColor(.primary)
                }

                // Activity ribbon toggle
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showRibbon.toggle()
                }) {
                    Image(systemName: showRibbon ? "chart.bar.fill" : "chart.bar")
                        .foregroundColor(showRibbon ? .blue : .primary)
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
                    Image(systemName: logViewMode == "calendar" ? "list.bullet.below.rectangle" : "calendar")
                        .foregroundColor(.primary)
                }

                // Export
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let url = logState.exportToCSVFileURL() {
                        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            var presenter = root
                            while let presented = presenter.presentedViewController {
                                presenter = presented
                            }
                            presenter.present(ac, animated: true)
                        }
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
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
                        ActivityRibbonView(logState: logState, anchorMonth: currentMonth)
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
                                onDaySelected: { hasSelectedDate = true }
                            ) {
                                // Collapse when a day is tapped
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    isCalendarExpanded = false
                                }
                            }
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            // Compact week strip + expand button
                            VStack(spacing: 0) {
                                WeekStripView(
                                    selectedDate: $selectedDate,
                                    logState: logState,
                                    weekDays: weekDaysForDate(selectedDate),
                                    onDaySelected: { hasSelectedDate = true }
                                )
                                .padding(.horizontal, 16)
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
                            if !dayLogs.isEmpty || !dayJournal.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(formattedDate(selectedDate))
                                        .font(.headline)
                                        .padding(.horizontal, 16)

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
                                }
                            } else {
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
                    } else {
                        // Timeline View — week or month scope with toggle
                        TimelineLogView(
                            logState: logState,
                            month: currentMonth,
                            selectedDate: selectedDate,
                            showWeek: $listShowWeek
                        ) { log in
                            selectedLog = log
                        } onJournalTap: { entry in
                            selectedJournalEntry = entry
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

    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Calendar View

private struct CalendarView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let logState: WorkoutLogState
    var hasSelectedDate: Bool = true
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
    
    var body: some View {
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
                            workoutCount: logState.logsForDate(date).count,
                            logs: logState.logsForDate(date),
                            journalEntries: logState.journalEntriesForDate(date)
                        ) {
                            selectedDate = date
                            onDaySelected?()
                            onDayTapped?()
                        }
                    } else {
                        Color.clear
                            .frame(height: 85)
                    }
                }
            }
        }
        .padding(2)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let workoutCount: Int
    let logs: [WorkoutLog]
    var journalEntries: [JournalEntry] = []
    let onTap: () -> Void

    private var hasJournalOnly: Bool { workoutCount == 0 && !journalEntries.isEmpty }

    private var backgroundColor: Color {
        if workoutCount > 0 {
            // Greener with more workouts
            let intensity = min(Double(workoutCount) / 5.0, 1.0)
            let greenColor = Color(red: 0.4 * (1 - intensity), green: 0.8, blue: 0.4 * (1 - intensity))
            // Fade out color for non-current month
            return isCurrentMonth ? greenColor : greenColor.opacity(0.3)
        } else {
            return isCurrentMonth ? Color(UIColor.secondarySystemBackground) : Color(UIColor.secondarySystemBackground).opacity(0.5)
        }
    }
    
    private var hasWorkout: Bool { workoutCount > 0 }

    private var textColor: Color {
        if hasWorkout {
            // Always use dark text on green backgrounds for readability
            return Color(UIColor.darkText)
        } else if isCurrentMonth {
            return .primary
        } else {
            return .gray
        }
    }
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(hasWorkout ? Color(UIColor.darkText) : Color.primary, lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 20, weight: isToday ? .bold : .regular))
                        .foregroundColor(textColor)
                }
                .frame(height: 32)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                
                // Workout name labels
                let allLabels: [(text: String, isJournal: Bool)] =
                    logs.prefix(3).map { (text: String($0.workoutName.prefix(10)), isJournal: false) } +
                    (logs.count < 3 ? journalEntries.prefix(3 - logs.count).map { (text: String($0.title.prefix(10)), isJournal: true) } : [])

                if !allLabels.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(Array(allLabels.enumerated()), id: \.offset) { _, item in
                            ZStack(alignment: .leading) {
                                ClippedTextLabel(
                                    text: item.text,
                                    fontSize: 9,
                                    textColor: (item.isJournal
                                        ? Color(red: 0.4, green: 0.35, blue: 0.75)
                                        : textColor)
                                        .opacity(isCurrentMonth ? 0.85 : 0.45)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)

                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: backgroundColor, location: 1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 15)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .frame(height: 11)
                            .clipped()
                        }
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                } else if hasJournalOnly {
                    // Journal-only day: show a small purple dot
                    Circle()
                        .fill(Color(red: 0.4, green: 0.35, blue: 0.75).opacity(isCurrentMonth ? 0.75 : 0.35))
                        .frame(width: 6, height: 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 85)
            .background(backgroundColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isToday ? (hasWorkout ? Color(UIColor.darkText) : Color.primary) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week Strip View

/// Compact week strip shown when the calendar is collapsed.
private struct WeekStripView: View {
    @Binding var selectedDate: Date
    let logState: WorkoutLogState
    let weekDays: [Date]
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
                    let count = logState.logsForDate(day).count
                    let journalCount = logState.journalEntriesForDate(day).count
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

                            // Dot indicator: green for workouts, purple for journal-only, clear for nothing
                            Circle()
                                .fill(count > 0
                                    ? Color(red: 0.2, green: 0.75, blue: 0.35)
                                    : journalCount > 0
                                        ? Color(red: 0.4, green: 0.35, blue: 0.75)
                                        : Color.clear)
                                .frame(width: 5, height: 5)
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

/// An item in the timeline — either a workout log or a journal entry
private enum TimelineItem {
    case workout(WorkoutLog)
    case journal(JournalEntry)

    var date: Date {
        switch self {
        case .workout(let l): return l.completedAt
        case .journal(let e): return e.date
        }
    }
}

private struct TimelineLogView: View {
    let logState: WorkoutLogState
    let month: Date
    let selectedDate: Date
    @Binding var showWeek: Bool
    let onTap: (WorkoutLog) -> Void
    var onJournalTap: ((JournalEntry) -> Void)? = nil

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
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
        let allItems: [TimelineItem] = (filteredLogs.map { TimelineItem.workout($0) } +
                                        filteredJournal.map { TimelineItem.journal($0) })
            .sorted { $0.date > $1.date }

        var groups: [(date: Date, items: [TimelineItem])] = []
        var currentDay: Date? = nil
        var currentGroup: [TimelineItem] = []
        for item in allItems {
            let day = calendar.startOfDay(for: item.date)
            if let cd = currentDay, calendar.isDate(day, inSameDayAs: cd) {
                currentGroup.append(item)
            } else {
                if let cd = currentDay { groups.append((date: cd, items: currentGroup)) }
                currentDay = day
                currentGroup = [item]
            }
        }
        if let cd = currentDay { groups.append((date: cd, items: currentGroup)) }
        return groups
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
    let logState: WorkoutLogState
    let anchorMonth: Date

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    // Nil entries = padding cells before the first real day
    private var buckets: [(date: Date?, workoutCount: Int, journalOnly: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // End on the last day of the viewed month (future months just show 0-count cells)
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorMonth))!
        let lastOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth) ?? today
        let anchor = lastOfMonth

        // Build 63 real days ending at anchor, oldest first
        let realDays: [(date: Date?, workoutCount: Int, journalOnly: Bool)] = (0..<63).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: anchor)!
            guard date <= today else { return (date: date, workoutCount: 0, journalOnly: false) }
            let wCount = logState.logsForDate(date).count
            let jCount = logState.journalEntriesForDate(date).count
            return (date: date, workoutCount: wCount, journalOnly: jCount > 0)
        }

        // Find the weekday of the oldest day (1=Sun … 7=Sat) and pad the front
        // so column 0 always lines up under "S" (Sunday)
        let firstDate = realDays.first!.date!
        let weekday = calendar.component(.weekday, from: firstDate) // 1-based
        let paddingCount = weekday - 1  // number of empty cells before first real day
        let padding: [(date: Date?, workoutCount: Int, journalOnly: Bool)] = Array(
            repeating: (date: nil, workoutCount: -1, journalOnly: false), count: paddingCount)
        return padding + realDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Week-day header
            HStack(spacing: cellSpacing) {
                ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: 9))
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
                                // Purple dot overlay for journal-only days
                                if bucket.journalOnly {
                                    Circle()
                                        .fill(Color(red: 0.4, green: 0.35, blue: 0.75).opacity(0.85))
                                        .frame(width: cellSize * 0.45, height: cellSize * 0.45)
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
                        TextEditor(text: $entryBody)
                            .font(.body)
                            .frame(minHeight: 260)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
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
                    TextField("Exercise notes", text: Binding(
                        get: { log.exercises[exIdx].notes },
                        set: { log.exercises[exIdx].notes = $0 }
                    ), axis: .vertical)
                        .font(.caption).textFieldStyle(.roundedBorder).lineLimit(2, reservesSpace: true)
                }
                .padding(.top, 4)
            } else if !exercise.notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notes").font(.caption2).fontWeight(.semibold).foregroundColor(.gray)
                    Text(exercise.notes).font(.caption).foregroundColor(.gray)
                }
                .padding(.top, 4)
            }

            let allEquipment = (exercisesState.exercises.first { $0.id == exercise.exerciseID }?.equipmentIDs ?? [])
                .compactMap { id in equipmentState.sortedItems.first { $0.id == id } }
            if !allEquipment.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Equipment Used").font(.caption2).fontWeight(.semibold).foregroundColor(.gray)
                    if isEditing {
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
                        let usedEquipment = allEquipment.filter { exercise.usedEquipmentIDs.contains($0.id) }
                        if usedEquipment.isEmpty {
                            Text("None recorded").font(.caption).foregroundColor(.secondary)
                        } else {
                            Text(usedEquipment.map { $0.name }.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
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

#Preview {
    ProgressModuleView()
        .environment(WorkoutLogState.shared)
        .environment(ExercisesState.shared)
}
