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
        
        return exerciseCounts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Most common workout day of week
    public var favoriteDay: String? {
        guard !logs.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let dayCounts = logs.reduce(into: [Int: Int]()) { counts, log in
            let weekday = calendar.component(.weekday, from: log.completedAt)
            counts[weekday, default: 0] += 1
        }
        
        guard let mostCommonDay = dayCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let date = calendar.date(from: DateComponents(weekday: mostCommonDay))!
        return formatter.string(from: date)
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
