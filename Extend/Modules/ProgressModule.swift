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
    @State private var showingExportSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Log")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingExportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Calendar View
                    CalendarView(
                        currentMonth: $currentMonth,
                        selectedDate: $selectedDate,
                        logState: logState
                    )
                    .padding(.horizontal, 16)
                    
                    // Selected Date's Workouts
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
                        .padding(.vertical, 40)
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
        .sheet(isPresented: $showingExportSheet) {
            CSVExportView()
                .environment(logState)
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
    
    private let calendar = Calendar.current
    private let columns: [GridItem] = {
        let spacing: CGFloat = 2
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
    }()
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
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
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 4)
            
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
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
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

// MARK: - Workout Log Card

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
    @Environment(\.dismiss) var dismiss
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    
    @State var log: WorkoutLog
    @State private var showDeleteAlert = false
    @State private var isEditing = false
    
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
                    // Workout name (editable) with Edit button
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout Name")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        HStack(alignment: .center, spacing: 12) {
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
                            
                            Button(isEditing ? "Done" : "Edit") {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if isEditing {
                                    logState.updateLog(log)
                                }
                                isEditing.toggle()
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                            .cornerRadius(6)
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
                            Text(exercise.exerciseName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if !exercise.sets.isEmpty {
                                ForEach($exercise.sets, id: \.id) { $set in
                                    HStack {
                                        Text("Set \(exercise.sets.firstIndex(where: { $0.id == set.id })! + 1)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        if isEditing {
                                            TextField("Reps", value: $set.reps, format: .number)
                                                .keyboardType(.numberPad)
                                                .font(.caption)
                                                .frame(width: 40)
                                                .textFieldStyle(.roundedBorder)
                                            
                                            Text("×")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            TextField("Weight", value: $set.weight, format: .number)
                                                .keyboardType(.decimalPad)
                                                .font(.caption)
                                                .frame(width: 50)
                                                .textFieldStyle(.roundedBorder)
                                            
                                            Text("lbs")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        } else {
                                            Spacer()
                                            
                                            Text("\(set.reps) reps")
                                                .font(.caption)
                                            
                                            Text("×")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Text(String(format: "%.1f lbs", set.weight))
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                            
                            if isEditing {
                                TextField("Exercise notes", text: $exercise.notes, axis: .vertical)
                                    .font(.caption)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2, reservesSpace: true)
                            } else if !exercise.notes.isEmpty {
                                Text(exercise.notes)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(isEditing ? "Edit Workout" : log.workoutName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        if isEditing {
                            logState.updateLog(log)
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
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
}

// MARK: - CSV Export View

private struct CSVExportView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(WorkoutLogState.self) var logState
    
    @State private var showingShareSheet = false
    @State private var csvData: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text")
                    .font(.system(size: 64))
                    .foregroundColor(.black)
                
                Text("Export Workout History")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Export all workout logs to CSV format")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    csvData = logState.exportToCSV()
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export CSV")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 32)
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(activityItems: [csvData])
            }
        }
    }
}

// MARK: - Activity View Controller

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

#Preview {
    ProgressModuleView()
        .environment(WorkoutLogState.shared)
        .environment(ExercisesState.shared)
}
