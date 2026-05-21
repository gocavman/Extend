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
    @State private var currentMonth = Date()
    @State private var selectedLog: WorkoutLog?
    /// When false the full month grid collapses to a single week strip
    @State private var isCalendarExpanded: Bool = true
    @State private var showMonthPicker = false
    @State private var showSearch = false
    @State private var searchText = ""

    /// Persisted: "calendar" or "timeline"
    @AppStorage("logViewMode") private var logViewMode: String = "calendar"
    /// Persisted: show 60-day activity ribbon
    @AppStorage("logShowRibbon") private var showRibbon: Bool = false

    private let calendar = Calendar.current

    private var monthYearString: String {
        let formatter = DateFormatter()
        // In collapsed mode show the week range, e.g. "May 12–18"
        if !isCalendarExpanded {
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
        if !isCalendarExpanded {
            // Navigate by week when collapsed
            if let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                selectedDate = prev
                currentMonth = prev
            }
        } else {
            if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
               let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) {
                currentMonth = newMonth
                selectedDate = firstOfMonth
            }
        }
    }

    private func nextMonth() {
        if !isCalendarExpanded {
            if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
                selectedDate = next
                currentMonth = next
            }
        } else {
            if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth),
               let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) {
                currentMonth = newMonth
                selectedDate = firstOfMonth
            }
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
                        .foregroundColor(.black)
                }

                // Activity ribbon toggle
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showRibbon.toggle()
                }) {
                    Image(systemName: showRibbon ? "chart.bar.fill" : "chart.bar")
                        .foregroundColor(showRibbon ? .blue : .black)
                }

                // View mode toggle
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    logViewMode = logViewMode == "calendar" ? "timeline" : "calendar"
                }) {
                    Image(systemName: logViewMode == "calendar" ? "list.bullet.below.rectangle" : "calendar")
                        .foregroundColor(.black)
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
                        .foregroundColor(.black)
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
                        .foregroundColor(.black)
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
                        .foregroundColor(.black)
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
                                logState: logState
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
                                    weekDays: weekDaysForDate(selectedDate)
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
                                        .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 6)
                            }
                        }

                        // Selected Day's Workouts
                        if !logState.logsForDate(selectedDate).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(formattedDate(selectedDate))
                                    .font(.headline)
                                    .padding(.horizontal, 16)

                                ForEach(logState.logsForDate(selectedDate)) { log in
                                    WorkoutLogCard(log: log) {
                                        selectedLog = log
                                    }
                                    .padding(.horizontal, 16)
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
                    } else {
                        // Timeline View
                        TimelineLogView(logState: logState) { log in
                            selectedLog = log
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .sheet(item: $selectedLog) { log in
            WorkoutLogDetailView(log: log)
                .environment(logState)
                .environment(exercisesState)
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerSheet(currentMonth: $currentMonth, selectedDate: $selectedDate)
        }
        .sheet(isPresented: $showSearch) {
            LogSearchView(logState: logState, selectedLog: $selectedLog)
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
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: isCurrentMonth(date),
                            workoutCount: logState.logsForDate(date).count,
                            logs: logState.logsForDate(date)
                        ) {
                            selectedDate = date
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
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
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
    let onTap: () -> Void
    
    private var backgroundColor: Color {
        if workoutCount > 0 {
            // Greener with more workouts
            let intensity = min(Double(workoutCount) / 5.0, 1.0)
            let greenColor = Color(red: 0.4 * (1 - intensity), green: 0.8, blue: 0.4 * (1 - intensity))
            // Fade out color for non-current month
            return isCurrentMonth ? greenColor : greenColor.opacity(0.3)
        } else {
            return isCurrentMonth ? Color(red: 0.98, green: 0.98, blue: 1.0) : Color(red: 0.98, green: 0.98, blue: 1.0).opacity(0.5)
        }
    }
    
    private var textColor: Color {
        if isCurrentMonth {
            return .black
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
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 20, weight: isToday ? .bold : .regular))
                        .foregroundColor(textColor)
                }
                .frame(height: 32)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                
                if !logs.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(logs.prefix(3)) { log in
                            ZStack(alignment: .leading) {
                                ClippedTextLabel(
                                    text: String(log.workoutName.prefix(10)),
                                    fontSize: 9,
                                    textColor: textColor.opacity(isCurrentMonth ? 0.8 : 0.5)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Gradient fade on the right edge to simulate iPhone calendar effect
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
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 85)
            .background(backgroundColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isToday ? Color.black : Color.clear, lineWidth: 2)
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
                    let dayNum = calendar.component(.day, from: day)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedDate = day
                    }) {
                        VStack(spacing: 3) {
                            ZStack {
                                // Selection ring
                                if isSelected {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 34, height: 34)
                                } else if isToday {
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1.5)
                                        .frame(width: 34, height: 34)
                                }
                                Text("\(dayNum)")
                                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isSelected ? .white : .primary)
                            }
                            .frame(width: 34, height: 34)

                            // Workout dot indicator
                            Circle()
                                .fill(count > 0 ? Color(red: 0.2, green: 0.75, blue: 0.35) : Color.clear)
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
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .cornerRadius(12)
    }
}

// MARK: - Workout Log Card

// MARK: - Timeline View

private struct TimelineLogView: View {
    let logState: WorkoutLogState
    let onTap: (WorkoutLog) -> Void

    private static let pageSize = 30  // day-groups per page

    @State private var visibleGroupCount = TimelineLogView.pageSize

    private var allGroupedLogs: [(date: Date, logs: [WorkoutLog])] {
        let sorted = logState.sortedLogs
        var groups: [(date: Date, logs: [WorkoutLog])] = []
        var currentDate: Date? = nil
        var currentGroup: [WorkoutLog] = []
        let calendar = Calendar.current
        for log in sorted {
            let day = calendar.startOfDay(for: log.completedAt)
            if let cd = currentDate, calendar.isDate(day, inSameDayAs: cd) {
                currentGroup.append(log)
            } else {
                if let cd = currentDate { groups.append((date: cd, logs: currentGroup)) }
                currentDate = day
                currentGroup = [log]
            }
        }
        if let cd = currentDate { groups.append((date: cd, logs: currentGroup)) }
        return groups
    }

    private var visibleGroups: [(date: Date, logs: [WorkoutLog])] {
        Array(allGroupedLogs.prefix(visibleGroupCount))
    }

    var body: some View {
        if allGroupedLogs.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 44))
                    .foregroundColor(.gray)
                Text("No workouts logged yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(visibleGroups.enumerated()), id: \.offset) { groupIdx, group in
                    HStack(alignment: .top, spacing: 12) {
                        // Timeline spine
                        VStack(spacing: 0) {
                            // Connector line from previous group (skip for first)
                            if groupIdx > 0 {
                                Rectangle()
                                    .fill(Color(red: 0.82, green: 0.82, blue: 0.84))
                                    .frame(width: 2)
                                    .frame(height: 12)
                            } else {
                                Spacer().frame(height: 12)
                            }
                            // Date bubble
                            Circle()
                                .fill(Color.black)
                                .frame(width: 10, height: 10)
                            // Connector line to next entry
                            Rectangle()
                                .fill(Color(red: 0.82, green: 0.82, blue: 0.84))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }

                        .frame(width: 10)
                        .padding(.leading, 16)

                        // Date + cards
                        VStack(alignment: .leading, spacing: 8) {
                            Text(timelineDateString(group.date))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)

                            ForEach(group.logs) { log in
                                WorkoutLogCard(log: log) { onTap(log) }
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }

                // Load more
                if visibleGroupCount < allGroupedLogs.count {
                    Button(action: {
                        visibleGroupCount += TimelineLogView.pageSize
                    }) {
                        Text("Load older entries")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 42)
                    .padding(.trailing, 16)
                }
            }
        }
    }

    private func timelineDateString(_ date: Date) -> String {
        let calendar = Calendar.current
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
    private var buckets: [(date: Date?, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // End on the last day of the viewed month, capped at today
        let lastOfMonth = calendar.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: calendar.date(from: calendar.dateComponents([.year, .month], from: anchorMonth))!
        ) ?? today
        let anchor = min(lastOfMonth, today)

        // Build 63 real days ending at anchor, oldest first
        let realDays: [(date: Date?, count: Int)] = (0..<63).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: anchor)!
            return (date: date, count: logState.logsForDate(date).count)
        }

        // Find the weekday of the oldest day (1=Sun … 7=Sat) and pad the front
        // so column 0 always lines up under "S" (Sunday)
        let firstDate = realDays.first!.date!
        let weekday = calendar.component(.weekday, from: firstDate) // 1-based
        let paddingCount = weekday - 1  // number of empty cells before first real day
        let padding: [(date: Date?, count: Int)] = Array(repeating: (date: nil, count: -1), count: paddingCount)
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
                            RoundedRectangle(cornerRadius: 2)
                                .fill(bucket.date == nil ? Color.clear : cellColor(bucket.count))
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
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
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
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 16) {
                    // Show lines count for Voice Trainer sessions, exercises count for workouts
                    if log.workoutName.contains("Voice Trainer") || log.workoutName.contains("Trainer Session") {
                        // Extract lines count from notes if available
                        let linesCount = extractLinesCount(from: log.notes)
                        Label("\(linesCount) lines", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
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
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
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
    
    private var exercisesCountLabel: String {
        // For Trainer Sessions, show lines count instead of exercises count
        if log.workoutName.contains("Voice Trainer") || log.workoutName.contains("Trainer Session") {
            let linesCount = extractLinesCount(from: log.notes)
            return "\(linesCount) lines"
        } else {
            return "\(log.exercises.count) exercises"
        }
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
                                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
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
                            
                            Label(exercisesCountLabel, systemImage: "list.bullet")
                                .font(.caption)
                                .foregroundColor(.gray)
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
                                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                    .cornerRadius(6)
                            } else {
                                Text(log.notes)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Divider()
                    
                    // Exercises
                    ForEach($log.exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(exercise.exerciseName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                // Show exercise active time if logged
                                if !isEditing && exercise.activeSeconds > 0 {
                                    Label(formatLogTime(exercise.activeSeconds), systemImage: "stopwatch")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if isEditing {
                                    // Editable active time as m / s
                                    HStack(spacing: 2) {
                                        Image(systemName: "stopwatch")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextField("0", value: Binding(
                                            get: { exercise.activeSeconds / 60 },
                                            set: { exercise.activeSeconds = $0 * 60 + exercise.activeSeconds % 60 }
                                        ), format: .number)
                                            .keyboardType(.numberPad)
                                            .font(.caption)
                                            .frame(width: 30)
                                            .textFieldStyle(.roundedBorder)
                                        Text("min")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextField("0", value: Binding(
                                            get: { exercise.activeSeconds % 60 },
                                            set: { exercise.activeSeconds = exercise.activeSeconds / 60 * 60 + min($0, 59) }
                                        ), format: .number)
                                            .keyboardType(.numberPad)
                                            .font(.caption)
                                            .frame(width: 30)
                                            .textFieldStyle(.roundedBorder)
                                        Text("sec")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        exercise.sets.append(LoggedSet(reps: 0, weight: 0))
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.black)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if !exercise.sets.isEmpty {
                                let hasTimedSets = exercise.sets.contains { $0.timedSeconds > 0 }
                                ForEach(Array(exercise.sets.indices), id: \.self) { index in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        if isEditing {
                                            TextField("Reps", value: $exercise.sets[index].reps, format: .number)
                                                .keyboardType(.numberPad)
                                                .font(.caption)
                                                .frame(width: 40)
                                                .textFieldStyle(.roundedBorder)

                                            Text("×")
                                                .font(.caption)
                                                .foregroundColor(.gray)

                                            TextField("Weight", value: $exercise.sets[index].weight, format: .number)
                                                .keyboardType(.decimalPad)
                                                .font(.caption)
                                                .frame(width: 50)
                                                .textFieldStyle(.roundedBorder)

                                            Text(weightUnit)
                                                .font(.caption)
                                                .foregroundColor(.gray)

                                            // Timed duration as m / s
                                            HStack(spacing: 2) {
                                                Image(systemName: "timer")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                TextField("0", value: Binding(
                                                    get: { exercise.sets[index].timedSeconds / 60 },
                                                    set: { exercise.sets[index].timedSeconds = $0 * 60 + exercise.sets[index].timedSeconds % 60 }
                                                ), format: .number)
                                                    .keyboardType(.numberPad)
                                                    .font(.caption)
                                                    .frame(width: 28)
                                                    .textFieldStyle(.roundedBorder)
                                                Text("min")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                TextField("0", value: Binding(
                                                    get: { exercise.sets[index].timedSeconds % 60 },
                                                    set: { exercise.sets[index].timedSeconds = exercise.sets[index].timedSeconds / 60 * 60 + min($0, 59) }
                                                ), format: .number)
                                                    .keyboardType(.numberPad)
                                                    .font(.caption)
                                                    .frame(width: 28)
                                                    .textFieldStyle(.roundedBorder)
                                                Text("sec")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        } else {
                                            Spacer()

                                            // Timed set duration
                                            if hasTimedSets {
                                                let t = exercise.sets[index].timedSeconds
                                                Text(t > 0 ? formatLogTime(t) : "—")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 44, alignment: .trailing)
                                            }

                                            Text("\(exercise.sets[index].reps) reps")
                                                .font(.caption)

                                            Text("×")
                                                .font(.caption)
                                                .foregroundColor(.gray)

                                            Text(String(format: "%.1f \(weightUnit)", exercise.sets[index].weight))
                                                .font(.caption)
                                        }

                                        if isEditing {
                                            Button(action: {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                exercise.sets.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            if isEditing {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notes")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    TextField("Exercise notes", text: $exercise.notes, axis: .vertical)
                                        .font(.caption)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(2, reservesSpace: true)
                                }
                                .padding(.top, 4)
                            } else if !exercise.notes.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notes")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    Text(exercise.notes)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 4)
                            }

                            // Equipment used section
                            let allEquipment = (exercisesState.exercises.first { $0.id == exercise.exerciseID }?.equipmentIDs ?? [])
                                .compactMap { id in equipmentState.sortedItems.first { $0.id == id } }
                            if !allEquipment.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Equipment Used")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    if isEditing {
                                        HStack(spacing: 6) {
                                            ForEach(allEquipment) { item in
                                                let selected = exercise.usedEquipmentIDs.contains(item.id)
                                                Button(action: {
                                                    if selected {
                                                        exercise.usedEquipmentIDs.removeAll { $0 == item.id }
                                                    } else {
                                                        exercise.usedEquipmentIDs.append(item.id)
                                                    }
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
                                                    .background(selected ? Color.black : Color(red: 0.88, green: 0.88, blue: 0.90))
                                                    .cornerRadius(12)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            Spacer()
                                        }
                                    } else {
                                        let usedEquipment = allEquipment.filter { exercise.usedEquipmentIDs.contains($0.id) }
                                        if usedEquipment.isEmpty {
                                            Text("None recorded")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text(usedEquipment.map { $0.name }.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }

                    // Rest periods
                    restPeriodsSection()
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
                            .foregroundColor(.black)
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
    private func restPeriodsSection() -> some View {
        if !log.restPeriods.isEmpty || isEditing {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Rest Periods")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    if isEditing {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            log.restPeriods.append(LoggedRest(configuredDuration: 60, actualDuration: 60))
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(Array(log.restPeriods.indices), id: \.self) { i in
                    HStack(spacing: 8) {
                        Image(systemName: "zzz")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if isEditing {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Configured")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 2) {
                                    TextField("0", value: Binding(
                                        get: { log.restPeriods[i].configuredDuration / 60 },
                                        set: { log.restPeriods[i].configuredDuration = $0 * 60 + log.restPeriods[i].configuredDuration % 60 }
                                    ), format: .number)
                                        .keyboardType(.numberPad).font(.caption).frame(width: 28).textFieldStyle(.roundedBorder)
                                    Text("min").font(.caption).foregroundColor(.secondary)
                                    TextField("0", value: Binding(
                                        get: { log.restPeriods[i].configuredDuration % 60 },
                                        set: { log.restPeriods[i].configuredDuration = log.restPeriods[i].configuredDuration / 60 * 60 + min($0, 59) }
                                    ), format: .number)
                                        .keyboardType(.numberPad).font(.caption).frame(width: 28).textFieldStyle(.roundedBorder)
                                    Text("sec").font(.caption).foregroundColor(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rested")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 2) {
                                    TextField("0", value: Binding(
                                        get: { log.restPeriods[i].actualDuration / 60 },
                                        set: { log.restPeriods[i].actualDuration = $0 * 60 + log.restPeriods[i].actualDuration % 60 }
                                    ), format: .number)
                                        .keyboardType(.numberPad).font(.caption).frame(width: 28).textFieldStyle(.roundedBorder)
                                    Text("min").font(.caption).foregroundColor(.secondary)
                                    TextField("0", value: Binding(
                                        get: { log.restPeriods[i].actualDuration % 60 },
                                        set: { log.restPeriods[i].actualDuration = log.restPeriods[i].actualDuration / 60 * 60 + min($0, 59) }
                                    ), format: .number)
                                        .keyboardType(.numberPad).font(.caption).frame(width: 28).textFieldStyle(.roundedBorder)
                                    Text("sec").font(.caption).foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                log.restPeriods.remove(at: i)
                            }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Configured: \(formatLogTime(log.restPeriods[i].configuredDuration))")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("Rested: \(formatLogTime(log.restPeriods[i].actualDuration))")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
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
    @Binding var selectedDate: Date
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
                            selectedDate = date
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

private struct LogSearchView: View {
    let logState: WorkoutLogState
    @Binding var selectedLog: WorkoutLog?
    @Environment(\.dismiss) var dismiss

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var results: [WorkoutLog] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return logState.sortedLogs.filter { log in
            if log.workoutName.lowercased().contains(lower) { return true }
            if log.notes.lowercased().contains(lower) { return true }
            if log.exercises.contains(where: { $0.exerciseName.lowercased().contains(lower) }) { return true }
            return false
        }
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
                        Text("Search by workout name,\nexercise, or notes")
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
                    List(results) { log in
                        Button(action: {
                            dismiss()
                            // Brief delay so the search sheet finishes dismissing before the detail sheet opens
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                selectedLog = log
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.workoutName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text(dateFormatter.string(from: log.completedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if !log.exercises.isEmpty {
                                    Text(log.exercises.map { $0.exerciseName }.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

#Preview {
    ProgressModuleView()
        .environment(WorkoutLogState.shared)
        .environment(ExercisesState.shared)
}
