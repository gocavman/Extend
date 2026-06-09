////
////  WorkoutLogState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation
import HealthKit

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

/// State management for workout logs and history
@Observable
public final class WorkoutLogState {
    public static let shared = WorkoutLogState()
    
    public var logs: [WorkoutLog] = []
    public var journalEntries: [JournalEntry] = []

    private let logsKey = "workout_logs"
    private let journalKey = "journal_entries"

    private init() {
        loadLogs()
        loadJournalEntries()
    }
    
    // MARK: - Log Management
    
    /// Add a new workout log and optionally export it to Apple Health.
    /// Pass `activityType` as the HKWorkoutActivityType raw value (nil → .other).
    public func addLog(_ log: WorkoutLog, exportToHealthKit: Bool = false, activityTypeRaw: UInt? = nil) {
        var log = log
        log.healthKitActivityTypeRaw = activityTypeRaw
        logs.append(log)
        saveLogs()
        // Refresh widget so completion checkboxes update immediately
        TrainingPlanState.shared.refreshWidgetSnapshot()

        if exportToHealthKit {
            Task {
                await exportLogToHealthKit(log, activityTypeRaw: activityTypeRaw)
            }
        }
    }

    /// Exports any logs that have never been sent to Apple Health (healthKitUUID == nil).
    /// Called during Sync Now so logs created while export was disabled get back-filled.
    @MainActor
    public func exportPendingLogsToHealthKit() async {
        guard HealthKitState.shared.exportStrengthWorkouts else { return }
        guard HealthKitService.shared.isAvailable else { return }
        let pending = logs.filter { $0.healthKitUUID == nil }
        for log in pending {
            await exportLogToHealthKit(log, activityTypeRaw: log.healthKitActivityTypeRaw)
        }
    }

    /// Exports a single WorkoutLog to Apple Health.
    /// Updates the stored log with the returned HKWorkout UUID for deduplication.
    @MainActor
    private func exportLogToHealthKit(_ log: WorkoutLog, activityTypeRaw: UInt? = nil) async {
        guard HealthKitState.shared.exportStrengthWorkouts else { return }
        guard HealthKitService.shared.isAvailable else { return }
        guard log.healthKitUUID == nil else { return } // already exported

        let startDate = log.completedAt.addingTimeInterval(-log.duration)
        let calories = HealthKitService.shared.estimatedCalories(durationSeconds: log.duration)
        let activityType = HKWorkoutActivityTypeHelper.hkType(from: activityTypeRaw)

        do {
            if let hkUUID = try await HealthKitService.shared.exportStrengthWorkout(
                startDate: startDate,
                endDate: log.completedAt,
                totalEnergyBurned: calories,
                activityType: activityType
            ) {
                // Persist the HKWorkout UUID back to the log
                if let index = logs.firstIndex(where: { $0.id == log.id }) {
                    logs[index].healthKitUUID = hkUUID
                    saveLogs()
                }
            }
        } catch {
            // Non-fatal: HealthKit export failure should not surface to the user
        }
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

    /// Volume per calendar week for the past N weeks (oldest first). Each element is (weekLabel, volume).
    public func volumeByWeek(weeks: Int) -> [(label: String, volume: Double)] {
        volumeByWeek(weeks: weeks, workoutName: nil, exerciseID: nil)
    }

    /// Volume per calendar week filtered by optional workout name and/or exercise ID.
    public func volumeByWeek(weeks: Int, workoutName: String?, exerciseID: UUID?) -> [(label: String, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return (0..<weeks).reversed().map { offset in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart)!
            let weekEnd = offset == 0 ? now : calendar.date(byAdding: .second, value: -1, to:
                calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!)!
            var weekLogs = logsInRange(from: weekStart, to: weekEnd)
            if let name = workoutName {
                weekLogs = weekLogs.filter { $0.workoutName == name }
            }
            let volume = weekLogs
                .flatMap { $0.exercises }
                .filter { exerciseID == nil || $0.exerciseID == exerciseID }
                .flatMap { $0.sets }
                .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            return (label: formatter.string(from: weekStart), volume: volume)
        }
    }

    /// Workout count per day of week (Sun=1…Sat=7), sorted by weekday order.
    public var workoutCountByDayOfWeek: [(label: String, count: Int)] {
        let calendar = Calendar.current
        var counts = [Int: Int]()
        for log in logs {
            let wd = calendar.component(.weekday, from: log.completedAt)
            counts[wd, default: 0] += 1
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        // Sunday=1 … Saturday=7
        return (1...7).map { wd in
            let date = calendar.date(from: DateComponents(weekday: wd))!
            return (label: formatter.string(from: date), count: counts[wd] ?? 0)
        }
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

    /// Best weight ever logged for a specific exercise ID
    public func bestWeight(exerciseID: UUID) -> Double? {
        var best: Double? = nil
        for log in logs {
            for ex in log.exercises where ex.exerciseID == exerciseID {
                for s in ex.sets where s.weight > 0 {
                    if best == nil || s.weight > best! { best = s.weight }
                }
            }
        }
        return best
    }

    /// Top exercises by best logged weight, limited to N
    public func topExercisesByWeight(limit: Int) -> [(exerciseID: UUID, exerciseName: String, weight: Double)] {
        var seen: [UUID: (String, Double)] = [:]
        for log in logs {
            for ex in log.exercises {
                for s in ex.sets where s.weight > 0 {
                    if let existing = seen[ex.exerciseID] {
                        if s.weight > existing.1 { seen[ex.exerciseID] = (ex.exerciseName, s.weight) }
                    } else {
                        seen[ex.exerciseID] = (ex.exerciseName, s.weight)
                    }
                }
            }
        }
        return seen.map { (exerciseID: $0.key, exerciseName: $0.value.0, weight: $0.value.1) }
            .sorted { $0.weight > $1.weight }
            .prefix(limit)
            .map { $0 }
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
    
    // MARK: - 1RM Estimation

    /// Epley formula: weight × (1 + reps / 30). Accurate for 3–10 rep range.
    private static func epley(weight: Double, reps: Int) -> Double {
        guard reps >= 3, reps <= 10, weight > 0 else { return 0 }
        return weight * (1 + Double(reps) / 30.0)
    }

    /// Returns per-session best estimated 1RM for a given exercise, sorted chronologically.
    public func oneRMHistory(exerciseID: UUID) -> [(date: Date, value: Double)] {
        sortedLogs
            .reversed()   // oldest → newest
            .compactMap { log -> (Date, Double)? in
                guard let ex = log.exercises.first(where: { $0.exerciseID == exerciseID }),
                      !ex.sets.isEmpty else { return nil }
                let best = ex.sets.compactMap { s -> Double? in
                    let v = Self.epley(weight: s.weight, reps: s.reps)
                    return v > 0 ? v : nil
                }.max()
                guard let best else { return nil }
                return (log.completedAt, best)
            }
    }

    /// Best all-time estimated 1RM for a given exercise.
    public func bestEstimated1RM(exerciseID: UUID) -> Double? {
        oneRMHistory(exerciseID: exerciseID).map { $0.value }.max()
    }

    /// Top-N exercises by all-time best estimated 1RM (exercise ID + best value).
    public func topExercisesBy1RM(limit: Int = 5) -> [(exerciseID: UUID, exerciseName: String, estimated1RM: Double)] {
        var best: [UUID: (name: String, value: Double)] = [:]
        for log in logs {
            for ex in log.exercises {
                for s in ex.sets {
                    let v = Self.epley(weight: s.weight, reps: s.reps)
                    guard v > 0 else { continue }
                    if best[ex.exerciseID] == nil || v > best[ex.exerciseID]!.value {
                        best[ex.exerciseID] = (ex.exerciseName, v)
                    }
                }
            }
        }
        return best
            .sorted { $0.value.value > $1.value.value }
            .prefix(limit)
            .map { (exerciseID: $0.key, exerciseName: $0.value.name, estimated1RM: $0.value.value) }
    }

    /// Export logs to CSV format
    public func exportToCSV() -> String {
        // Wrap a field in quotes and escape any internal quotes
        func escape(_ value: String) -> String {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let weightUnit = UserDefaults.standard.string(forKey: "weightUnit") ?? "lbs"
        var csv = "Date,Workout Name,Row Type,Exercise,Set,Reps,Weight (\(weightUnit)),Active Time (s),Rest Configured (s),Rest Actual (s),Notes,Log Duration (s)\n"

        for log in sortedLogs {
            let dateString = dateFormatter.string(from: log.completedAt)

            if log.exercises.isEmpty {
                // Timer or other non-exercise log — emit a single summary row
                let row = [
                    escape(dateString),
                    escape(log.workoutName),
                    "\"session\"",
                    "\"\"", "\"\"", "\"\"", "\"\"", "\"\"", "\"\"", "\"\"",
                    escape(log.notes),
                    "\(Int(log.duration))"
                ].joined(separator: ",")
                csv += row + "\n"
            } else {
                for exercise in log.exercises {
                    if exercise.sets.isEmpty {
                        let row = [
                            escape(dateString),
                            escape(log.workoutName),
                            "\"exercise\"",
                            escape(exercise.exerciseName),
                            "\"\"", "\"\"", "\"\"",
                            "\(exercise.activeSeconds)",
                            "\"\"", "\"\"",
                            escape(exercise.notes),
                            "\(Int(log.duration))"
                        ].joined(separator: ",")
                        csv += row + "\n"
                    } else {
                        for (index, set) in exercise.sets.enumerated() {
                            let row = [
                                escape(dateString),
                                escape(log.workoutName),
                                "\"exercise\"",
                                escape(exercise.exerciseName),
                                "\(index + 1)",
                                "\(set.reps)",
                                String(format: "%.2f", set.weight),
                                "\(exercise.activeSeconds)",
                                "\"\"", "\"\"",
                                escape(exercise.notes),
                                "\(Int(log.duration))"
                            ].joined(separator: ",")
                            csv += row + "\n"
                        }
                    }
                }

                // Rest periods
                for (index, rest) in log.restPeriods.enumerated() {
                    let row = [
                        escape(dateString),
                        escape(log.workoutName),
                        "\"rest\"",
                        "\"Rest \(index + 1)\"",
                        "\"\"", "\"\"", "\"\"", "\"\"",
                        "\(rest.configuredDuration)",
                        "\(rest.actualDuration)",
                        "\"\"",
                        "\(Int(log.duration))"
                    ].joined(separator: ",")
                    csv += row + "\n"
                }
            }
        }

        // Journal entries
        if !journalEntries.isEmpty {
            csv += "\n\"--- Journal Entries ---\"\n"
            csv += "Date,Title,Body\n"
            for entry in sortedJournalEntries {
                let dateString = dateFormatter.string(from: entry.date)
                let row = [escape(dateString), escape(entry.title), escape(entry.body)].joined(separator: ",")
                csv += row + "\n"
            }
        }

        return csv
    }

    /// Write CSV to a temp file and return the URL for sharing
    public func exportToCSVFileURL() -> URL? {
        let csv = exportToCSV()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let fileName = "Extend_Workout_History_\(formatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
    
    // MARK: - Journal Entries

    public func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.append(entry)
        saveJournalEntries()
    }

    public func updateJournalEntry(_ entry: JournalEntry) {
        if let idx = journalEntries.firstIndex(where: { $0.id == entry.id }) {
            journalEntries[idx] = entry
            saveJournalEntries()
        }
    }

    public func deleteJournalEntry(id: UUID) {
        journalEntries.removeAll { $0.id == id }
        saveJournalEntries()
    }

    /// Journal entries for a specific date, sorted newest first
    public func journalEntriesForDate(_ date: Date) -> [JournalEntry] {
        let calendar = Calendar.current
        return journalEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    /// All journal entries sorted newest first
    public var sortedJournalEntries: [JournalEntry] {
        journalEntries.sorted { $0.date > $1.date }
    }

    // MARK: - Persistence
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            defaults.set(encoded, forKey: logsKey)
        }
    }
    
    private func loadLogs() {
        if let data = defaults.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([WorkoutLog].self, from: data) {
            logs = decoded
        }
    }

    private func saveJournalEntries() {
        if let encoded = try? JSONEncoder().encode(journalEntries) {
            defaults.set(encoded, forKey: journalKey)
        }
    }

    private func loadJournalEntries() {
        if let data = defaults.data(forKey: journalKey),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            journalEntries = decoded
        }
    }
    
    /// Reset all logs (for app reset)
    public func resetLogs() {
        logs = []
        saveLogs()
        journalEntries = []
        saveJournalEntries()
    }

    #if DEBUG
    /// Bulk-inserts logs without HealthKit export. Used by developer test data generator.
    public func bulkAddLogs(_ newLogs: [WorkoutLog]) {
        logs.append(contentsOf: newLogs)
        saveLogs()
    }
    #endif

    // MARK: - HealthKit Import

    /// Fetches cardio workouts from Apple Health since the last import date
    /// and adds any that aren't already in the log.
    @MainActor
    public func importFromHealthKit() async {
        let hkState = HealthKitState.shared
        guard hkState.anyImportEnabled else { return }
        guard HealthKitService.shared.isAvailable else { return }

        let since = hkState.lastImportDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let activityTypes = HealthKitService.shared.enabledActivityTypes(state: hkState)

        do {
            let hkWorkouts = try await HealthKitService.shared.fetchCardioWorkouts(
                since: since,
                activityTypes: activityTypes
            )

            // Collect UUIDs already in the log so we don't duplicate
            let existingUUIDs = Set(logs.compactMap { $0.healthKitUUID })

            var addedAny = false
            for hkWorkout in hkWorkouts {
                guard !existingUUIDs.contains(hkWorkout.uuid) else { continue }
                let newLog = HealthKitService.shared.workoutLog(from: hkWorkout)
                logs.append(newLog)
                addedAny = true
            }

            if addedAny {
                saveLogs()
            }
            hkState.lastImportDate = Date()
        } catch {
            // Non-fatal: import failure is silent
        }
    }
}
