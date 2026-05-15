////
////  StatsChartViews.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit

// MARK: - Time Range Filter

public enum StatsTimeRange: String, CaseIterable {
    case thirtyDays = "30 Days"
    case ninetyDays = "90 Days"
    case allTime    = "All Time"

    var days: Int? {
        switch self {
        case .thirtyDays:  return 30
        case .ninetyDays:  return 90
        case .allTime:     return nil
        }
    }

    var startDate: Date {
        guard let days else { return .distantPast }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
    }
}

// MARK: - Exercise Stats View

struct ExerciseStatsView: View {
    let exercise: Exercise

    @Environment(WorkoutLogState.self) var logState
    @State private var timeRange: StatsTimeRange = .thirtyDays

    // Filtered logs containing this exercise
    private var filteredLogs: [WorkoutLog] {
        let start = timeRange.startDate
        return logState.logs
            .filter { $0.completedAt >= start }
            .filter { $0.exercises.contains(where: { $0.exerciseID == exercise.id }) }
            .sorted { $0.completedAt < $1.completedAt }
    }

    // Per-session data points
    private struct SessionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
        let totalVolume: Double
        let totalReps: Int
    }

    private var sessionPoints: [SessionPoint] {
        filteredLogs.compactMap { log in
            guard let loggedEx = log.exercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
            let sets = loggedEx.sets
            guard !sets.isEmpty else { return nil }
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            let totalVolume = sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            let totalReps = sets.reduce(0) { $0 + $1.reps }
            return SessionPoint(date: log.completedAt, maxWeight: maxWeight, totalVolume: totalVolume, totalReps: totalReps)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(StatsTimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if sessionPoints.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        statsCard(
                            title: "Max Weight",
                            unit: "lbs",
                            points: sessionPoints.map { ($0.date, $0.maxWeight) },
                            color: .blue
                        )

                        statsCard(
                            title: "Total Volume",
                            unit: "lbs",
                            points: sessionPoints.map { ($0.date, $0.totalVolume) },
                            color: Color(red: 0.2, green: 0.65, blue: 0.4)
                        )

                        statsCard(
                            title: "Total Reps",
                            unit: "reps",
                            points: sessionPoints.map { ($0.date, Double($0.totalReps)) },
                            color: Color(red: 0.8, green: 0.4, blue: 0.1)
                        )
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("No Data")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Complete workouts using this exercise to see stats here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Stats card with bar chart + summary row

    @ViewBuilder
    private func statsCard(title: String, unit: String, points: [(Date, Double)], color: Color) -> some View {
        let maxVal = points.map { $0.1 }.max() ?? 1
        let latest = points.last?.1 ?? 0
        let best = points.map { $0.1 }.max() ?? 0
        let avg = points.isEmpty ? 0 : points.map { $0.1 }.reduce(0, +) / Double(points.count)

        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)

            // Bar chart
            BarChartView(points: points, maxValue: maxVal, barColor: color)
                .frame(height: 120)
                .padding(.horizontal, 16)

            // Summary strip
            HStack(spacing: 0) {
                summaryCell(label: "Latest", value: formatVal(latest, unit: unit))
                Divider().frame(height: 28)
                summaryCell(label: "Best", value: formatVal(best, unit: unit))
                Divider().frame(height: 28)
                summaryCell(label: "Avg", value: formatVal(avg, unit: unit))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVal(_ val: Double, unit: String) -> String {
        if val == 0 { return "—" }
        if unit == "reps" {
            return "\(Int(val))"
        }
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) \(unit)"
            : String(format: "%.1f \(unit)", val)
    }
}

// MARK: - Muscle Stats View

struct MuscleStatsView: View {
    let muscleGroup: MuscleGroup

    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    @State private var timeRange: StatsTimeRange = .thirtyDays

    // Exercise IDs targeting this muscle (primary or secondary)
    private var targetExerciseIDs: Set<UUID> {
        Set(exercisesState.exercises
            .filter {
                $0.primaryMuscleGroupIDs.contains(muscleGroup.id) ||
                $0.secondaryMuscleGroupIDs.contains(muscleGroup.id)
            }
            .map { $0.id })
    }

    private struct WeekBucket: Identifiable {
        let id = UUID()
        let weekStart: Date
        let sessions: Int
        let totalVolume: Double
    }

    private var weekBuckets: [WeekBucket] {
        let ids = targetExerciseIDs
        guard !ids.isEmpty else { return [] }

        let start = timeRange.startDate
        let relevantLogs = logState.logs
            .filter { $0.completedAt >= start }
            .filter { log in log.exercises.contains(where: { ids.contains($0.exerciseID) }) }

        // Group by week start (Monday)
        let calendar = Calendar(identifier: .gregorian)
        var byWeek: [Date: (sessions: Int, volume: Double)] = [:]

        for log in relevantLogs {
            let weekday = calendar.component(.weekday, from: log.completedAt) // 1=Sun
            let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
            let monday = calendar.date(byAdding: .day, value: daysToMonday, to: calendar.startOfDay(for: log.completedAt))!

            let volume = log.exercises
                .filter { ids.contains($0.exerciseID) }
                .flatMap { $0.sets }
                .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

            byWeek[monday, default: (0, 0.0)].sessions += 1
            byWeek[monday, default: (0, 0.0)].volume += volume
        }

        // Also increment sessions correctly (sessions = distinct days in that week that had a workout targeting this muscle)
        // Rebuild: distinct log dates per week
        var byWeekSessions: [Date: Set<Date>] = [:]
        var byWeekVolume: [Date: Double] = [:]
        for log in relevantLogs {
            let weekday = calendar.component(.weekday, from: log.completedAt)
            let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
            let monday = calendar.date(byAdding: .day, value: daysToMonday, to: calendar.startOfDay(for: log.completedAt))!
            let day = calendar.startOfDay(for: log.completedAt)
            byWeekSessions[monday, default: []].insert(day)

            let volume = log.exercises
                .filter { ids.contains($0.exerciseID) }
                .flatMap { $0.sets }
                .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            byWeekVolume[monday, default: 0] += volume
        }

        return byWeekSessions.keys.sorted().map { monday in
            WeekBucket(
                weekStart: monday,
                sessions: byWeekSessions[monday]?.count ?? 0,
                totalVolume: byWeekVolume[monday] ?? 0
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(StatsTimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if weekBuckets.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        muscleStatsCard(
                            title: "Sessions Trained",
                            unit: "sessions",
                            points: weekBuckets.map { ($0.weekStart, Double($0.sessions)) },
                            color: .blue
                        )

                        muscleStatsCard(
                            title: "Total Volume",
                            unit: "lbs",
                            points: weekBuckets.map { ($0.weekStart, $0.totalVolume) },
                            color: Color(red: 0.2, green: 0.65, blue: 0.4)
                        )
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(muscleGroup.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("No Data")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Log workouts with exercises targeting this muscle to see stats here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private func muscleStatsCard(title: String, unit: String, points: [(Date, Double)], color: Color) -> some View {
        let maxVal = points.map { $0.1 }.max() ?? 1
        let total = points.map { $0.1 }.reduce(0, +)
        let avg = points.isEmpty ? 0 : total / Double(points.count)
        let best = points.map { $0.1 }.max() ?? 0

        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)

            BarChartView(points: points, maxValue: maxVal, barColor: color, labelMode: .week)
                .frame(height: 120)
                .padding(.horizontal, 16)

            HStack(spacing: 0) {
                summaryCell(label: "Total", value: formatVal(total, unit: unit))
                Divider().frame(height: 28)
                summaryCell(label: "Best Week", value: formatVal(best, unit: unit))
                Divider().frame(height: 28)
                summaryCell(label: "Avg/Week", value: formatVal(avg, unit: unit))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVal(_ val: Double, unit: String) -> String {
        if val == 0 { return "—" }
        if unit == "sessions" { return "\(Int(val))" }
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) \(unit)"
            : String(format: "%.1f \(unit)", val)
    }
}

// MARK: - Reusable Bar Chart

enum BarLabelMode {
    case date   // Shows abbreviated date (e.g. "Jan 5")
    case week   // Shows "Wk N" label
}

struct BarChartView: View {
    let points: [(Date, Double)]
    let maxValue: Double
    let barColor: Color
    var labelMode: BarLabelMode = .date

    private var displayPoints: [(Date, Double)] {
        // Cap to a reasonable number of bars for readability
        if points.count <= 20 { return points }
        // Downsample by taking evenly spaced points
        let step = points.count / 20
        return stride(from: 0, to: points.count, by: max(step, 1)).map { points[$0] }
    }

    var body: some View {
        GeometryReader { geo in
            let count = displayPoints.count
            guard count > 0, maxValue > 0 else {
                Rectangle().fill(Color(uiColor: .systemGray5)).cornerRadius(4)
                return
            }

            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let labelHeight: CGFloat = 18
            let chartHeight = totalHeight - labelHeight
            let barSpacing: CGFloat = count > 12 ? 2 : 4
            let barWidth = max(4, (totalWidth - barSpacing * CGFloat(count - 1)) / CGFloat(count))

            ZStack(alignment: .bottomLeading) {
                // Horizontal grid lines (3 lines)
                VStack(spacing: 0) {
                    ForEach([1.0, 0.5], id: \.self) { fraction in
                        Spacer()
                        Rectangle()
                            .fill(Color(uiColor: .systemGray5))
                            .frame(height: 1)
                            .offset(y: -labelHeight)
                        Spacer()
                    }
                }
                .frame(height: totalHeight - labelHeight)
                .frame(maxWidth: .infinity, alignment: .top)

                // Bars + labels
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(displayPoints.indices, id: \.self) { i in
                        let (date, val) = displayPoints[i]
                        let fraction = maxValue > 0 ? val / maxValue : 0
                        let barH = max(2, chartHeight * CGFloat(fraction))

                        VStack(spacing: 2) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor.opacity(0.85))
                                .frame(width: barWidth, height: barH)
                            Text(barLabel(for: date, index: i, total: count))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .frame(width: barWidth)
                                .lineLimit(1)
                        }
                        .frame(height: totalHeight)
                    }
                }
            }
        }
    }

    private func barLabel(for date: Date, index: Int, total: Int) -> String {
        // Only show labels for first, middle, last (to avoid crowding)
        let showIndices: Set<Int> = [0, total / 2, total - 1]
        guard showIndices.contains(index) else { return "" }

        switch labelMode {
        case .date:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        case .week:
            return "W\(index + 1)"
        }
    }
}
