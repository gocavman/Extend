////
////  WorkoutLogState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation

/// State management for workout logs and history
@Observable
public final class WorkoutLogState {
    public static let shared = WorkoutLogState()
    
    public var logs: [WorkoutLog] = []
    
    private let logsKey = "workout_logs"
    
    private init() {
        loadLogs()
    }
    
    // MARK: - Log Management
    
    /// Add a new workout log
    public func addLog(_ log: WorkoutLog) {
        logs.append(log)
        saveLogs()
    }
    
    /// Update an existing workout log
    public func updateLog(_ log: WorkoutLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
            saveLogs()
        }
    }
    
    /// Delete a workout log
    public func deleteLog(id: UUID) {
        logs.removeAll { $0.id == id }
        saveLogs()
    }
    
    /// Get logs sorted by date (newest first)
    public var sortedLogs: [WorkoutLog] {
        logs.sorted { $0.completedAt > $1.completedAt }
    }
    
    /// Get logs for a specific date (sorted newest to oldest)
    public func logsForDate(_ date: Date) -> [WorkoutLog] {
        let calendar = Calendar.current
        return logs
            .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
            .sorted { $0.completedAt > $1.completedAt }
    }
    
    /// Get logs for a date range
    public func logsInRange(from startDate: Date, to endDate: Date) -> [WorkoutLog] {
        logs.filter { $0.completedAt >= startDate && $0.completedAt <= endDate }
    }
    
    // MARK: - Statistics
    
    /// Total number of workouts logged
    public var totalWorkouts: Int {
        logs.count
    }
    
    /// Current workout streak (consecutive days with workouts)
    public var currentStreak: Int {
        guard !logs.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedDates = logs.map { calendar.startOfDay(for: $0.completedAt) }
            .sorted(by: >)
        
        guard let mostRecent = sortedDates.first else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Check if most recent workout is today or yesterday
        guard mostRecent == today || mostRecent == yesterday else { return 0 }
        
        var streak = 0
        var currentDate = today
        
        for date in sortedDates {
            if calendar.isDate(date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if date < currentDate {
                break
            }
        }
        
        return streak
    }
    
    /// Total time spent working out (in seconds)
    public var totalTime: TimeInterval {
        logs.reduce(0) { $0 + $1.duration }
    }
    
    /// Most frequently performed exercise
    public var favoriteExercise: String? {
        let exerciseCounts = logs.flatMap { $0.exercises }
            .reduce(into: [String: Int]()) { counts, exercise in
                counts[exercise.exerciseName, default: 0] += 1
            }
        
        // Stable sort: highest count wins; ties broken alphabetically so the result
        // doesn't change on every view re-evaluation (dictionary iteration order is
        // non-deterministic in Swift).
        return exerciseCounts
            .sorted { lhs, rhs in lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key }
            .first?.key
    }
    
    /// Most common workout day of week
    public var favoriteDay: String? {
        guard !logs.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let dayCounts = logs.reduce(into: [Int: Int]()) { counts, log in
            let weekday = calendar.component(.weekday, from: log.completedAt)
            counts[weekday, default: 0] += 1
        }
        
        // Stable sort: highest count wins; ties broken by weekday number so the result
        // is deterministic regardless of dictionary iteration order.
        guard let mostCommonDay = dayCounts
            .sorted(by: { lhs, rhs in lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key })
            .first?.key else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let date = calendar.date(from: DateComponents(weekday: mostCommonDay))!
        return formatter.string(from: date)
    }
    
    // MARK: - New Stats

    /// Total volume (sets × reps × weight) logged in the current calendar week (Mon–Sun)
    public var volumeThisWeek: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return logsInRange(from: weekStart, to: now)
            .flatMap { $0.exercises }
            .flatMap { $0.sets }
            .reduce(0) { $0 + Double($1.reps) * $1.weight }
    }

    /// Volume for the previous calendar week — used for trend comparison
    public var volumeLastWeek: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
              let lastWeekEnd   = calendar.date(byAdding: .second, value: -1, to: thisWeekStart) else { return 0 }
        return logsInRange(from: lastWeekStart, to: lastWeekEnd)
            .flatMap { $0.exercises }
            .flatMap { $0.sets }
            .reduce(0) { $0 + Double($1.reps) * $1.weight }
    }

    /// All-time longest consecutive workout streak (in days)
    public var longestStreak: Int {
        guard !logs.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Set(logs.map { calendar.startOfDay(for: $0.completedAt) })
            .sorted()
        var best = 1
        var current = 1
        for i in 1..<uniqueDays.count {
            let prev = uniqueDays[i - 1]
            let curr = uniqueDays[i]
            if calendar.dateComponents([.day], from: prev, to: curr).day == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    /// Number of days in the last 14 with NO workout logged
    public var restDaysLast14: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let activeDays = Set(
            logs.compactMap { log -> Date? in
                let d = calendar.startOfDay(for: log.completedAt)
                return (0..<14).contains(calendar.dateComponents([.day], from: d, to: today).day ?? 99) ? d : nil
            }
        )
        return 14 - activeDays.count
    }

    /// Number of workouts logged in the current calendar week
    public var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return logsInRange(from: weekStart, to: now).count
    }

    /// Workouts logged last calendar week — for trend comparison
    public var workoutsLastWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
              let lastWeekEnd   = calendar.date(byAdding: .second, value: -1, to: thisWeekStart) else { return 0 }
        return logsInRange(from: lastWeekStart, to: lastWeekEnd).count
    }

    /// Heaviest single set weight ever logged, and the exercise name
    public var personalRecord: (exerciseName: String, weight: Double)? {
        var best: (String, Double)? = nil
        for log in logs {
            for ex in log.exercises {
                for s in ex.sets where s.weight > 0 {
                    if best == nil || s.weight > best!.1 {
                        best = (ex.exerciseName, s.weight)
                    }
                }
            }
        }
        return best
    }

    /// Get workout frequency for last N days
    public func workoutFrequency(days: Int) -> [Date: Int] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -days + 1, to: endDate)!
        
        var frequency: [Date: Int] = [:]
        
        var currentDate = startDate
        while currentDate <= endDate {
            let count = logsForDate(currentDate).count
            frequency[currentDate] = count
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return frequency
    }
    
    /// Get muscle group distribution for last N days
    public func muscleGroupDistribution(days: Int, muscleGroupsState: MuscleGroupsState) -> [String: Int] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let recentLogs = logsInRange(from: startDate, to: endDate)
        
        var distribution: [String: Int] = [:]
        
        for log in recentLogs {
            for exercise in log.exercises {
                // This would need to be enhanced to track muscle groups per exercise
                // For now, we'll just count exercises
                distribution[exercise.exerciseName, default: 0] += 1
            }
        }
        
        return distribution
    }
    
    /// Export logs to CSV format
    public func exportToCSV() -> String {
        var csv = "Date,Workout Name,Exercise,Sets,Reps,Weight,Notes,Duration\n"
        
        for log in sortedLogs {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: log.completedAt)
            
            for exercise in log.exercises {
                for (index, set) in exercise.sets.enumerated() {
                    let row = [
                        dateString,
                        log.workoutName,
                        exercise.exerciseName,
                        "\(index + 1)",
                        "\(set.reps)",
                        String(format: "%.2f", set.weight),
                        exercise.notes.replacingOccurrences(of: ",", with: ";"),
                        "\(Int(log.duration))"
                    ].joined(separator: ",")
                    csv += row + "\n"
                }
            }
        }
        
        return csv
    }
    
    // MARK: - Persistence
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
    }
    
    private func loadLogs() {
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([WorkoutLog].self, from: data) {
            logs = decoded
        }
    }
    
    /// Reset all logs (for app reset)
    public func resetLogs() {
        logs = []
        saveLogs()
    }
}
