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
    case sevenDays  = "7D"
    case oneMonth   = "1M"
    case threeMonth = "3M"
    case sixMonth   = "6M"
    case oneYear    = "1Y"
    case allTime    = "All"

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .sevenDays:   return cal.date(byAdding: .day,   value: -7,  to: now) ?? .distantPast
        case .oneMonth:    return cal.date(byAdding: .month, value: -1,  to: now) ?? .distantPast
        case .threeMonth:  return cal.date(byAdding: .month, value: -3,  to: now) ?? .distantPast
        case .sixMonth:    return cal.date(byAdding: .month, value: -6,  to: now) ?? .distantPast
        case .oneYear:     return cal.date(byAdding: .year,  value: -1,  to: now) ?? .distantPast
        case .allTime:     return .distantPast
        }
    }
}

// MARK: - Exercise Stats View

struct ExerciseStatsView: View {
    let exercise: Exercise

    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(WorkoutLogState.self) var logState
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: StatsTimeRange = .oneMonth

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
        let estimated1RM: Double   // 0 if no qualifying sets
    }

    private static func epley(weight: Double, reps: Int) -> Double {
        guard reps >= 3, reps <= 10, weight > 0 else { return 0 }
        return weight * (1 + Double(reps) / 30.0)
    }

    private var sessionPoints: [SessionPoint] {
        filteredLogs.compactMap { log in
            guard let loggedEx = log.exercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
            let sets = loggedEx.sets
            guard !sets.isEmpty else { return nil }
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            let totalVolume = sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            let totalReps = sets.reduce(0) { $0 + $1.reps }
            let best1RM = sets.compactMap { s -> Double? in
                let v = Self.epley(weight: s.weight, reps: s.reps)
                return v > 0 ? v : nil
            }.max() ?? 0
            return SessionPoint(date: log.completedAt, maxWeight: maxWeight, totalVolume: totalVolume, totalReps: totalReps, estimated1RM: best1RM)
        }
    }

    var body: some View {
        NavigationStack {
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
                            unit: weightUnit,
                            points: sessionPoints.map { ($0.date, $0.maxWeight) },
                            color: .blue
                        )

                        statsCard(
                            title: "Total Volume",
                            unit: weightUnit,
                            points: sessionPoints.map { ($0.date, $0.totalVolume) },
                            color: Color(red: 0.2, green: 0.65, blue: 0.4)
                        )

                        statsCard(
                            title: "Total Reps",
                            unit: "reps",
                            points: sessionPoints.map { ($0.date, Double($0.totalReps)) },
                            color: Color(red: 0.8, green: 0.4, blue: 0.1)
                        )

                        statsCard(
                            title: "Est. 1 Rep Max",
                            unit: weightUnit,
                            points: sessionPoints.compactMap { $0.estimated1RM > 0 ? ($0.date, $0.estimated1RM) : nil },
                            color: Color(red: 0.6, green: 0.2, blue: 0.8)
                        )
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        } // NavigationStack
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
        let hasData = points.contains(where: { $0.1 > 0 })

        if !hasData {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } else {
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

    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: StatsTimeRange = .oneMonth

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
        let muscleID = muscleGroup.id

        let start = timeRange.startDate
        let relevantLogs = logState.logs
            .filter { $0.completedAt >= start }
            .filter { log in
                // Regular logs: exercises targeting this muscle
                log.exercises.contains(where: { ids.contains($0.exerciseID) }) ||
                // VoiceTrainer logs: muscle group directly assigned to config
                (log.logType == .voiceTrainer &&
                 (log.primaryMuscleGroupIDs.contains(muscleID) || log.secondaryMuscleGroupIDs.contains(muscleID)))
            }

        guard !relevantLogs.isEmpty else { return [] }

        // Group by week start (Monday), distinct log dates per week
        let calendar = Calendar(identifier: .gregorian)
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
        NavigationStack {
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
                            unit: weightUnit,
                            points: weekBuckets.map { ($0.weekStart, $0.totalVolume) },
                            color: Color(red: 0.2, green: 0.65, blue: 0.4)
                        )
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(muscleGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        } // NavigationStack
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
        let hasData = points.contains(where: { $0.1 > 0 })

        if !hasData {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } else {
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
        if points.count <= 20 { return points }
        let step = points.count / 20
        return stride(from: 0, to: points.count, by: max(step, 1)).map { points[$0] }
    }

    var body: some View {
        GeometryReader { geo in
            let count = displayPoints.count
            if count == 0 || maxValue <= 0 {
                Rectangle()
                    .fill(Color(uiColor: .systemGray5))
                    .cornerRadius(4)
            } else {
                let totalWidth  = geo.size.width
                let totalHeight = geo.size.height
                let labelHeight: CGFloat = 14
                // The chart area sits above the label strip — baseline is exact pixel
                let baseline    = totalHeight - labelHeight
                let chartHeight = baseline
                let barSpacing: CGFloat = count > 12 ? 2 : 4
                let barWidth = max(4, (totalWidth - barSpacing * CGFloat(count - 1)) / CGFloat(count))
                let fractions: [CGFloat] = displayPoints.map { CGFloat(maxValue > 0 ? $0.1 / maxValue : 0) }

                ZStack(alignment: .topLeading) {
                    // All bars rendered in a single Canvas — pixel-perfect baseline alignment
                    Canvas { ctx, size in
                        // Grid lines at 100% and 50%
                        for frac in [1.0, 0.5] as [CGFloat] {
                            let y = baseline - frac * chartHeight
                            var line = Path()
                            line.move(to: CGPoint(x: 0, y: y))
                            line.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(line, with: .color(Color(uiColor: .systemGray5)), lineWidth: 1)
                        }

                        // Bars
                        for i in fractions.indices {
                            let barH  = fractions[i] * chartHeight
                            let barX  = CGFloat(i) * (barWidth + barSpacing)
                            let barY  = baseline - barH          // top-left corner of bar
                            let rect  = CGRect(x: barX, y: barY, width: barWidth, height: barH)
                            let rr    = Path(roundedRect: rect, cornerRadius: 3)
                            ctx.fill(rr, with: .color(barColor.opacity(0.85)))
                        }
                    }
                    .frame(width: totalWidth, height: totalHeight)

                    // Value labels — drawn as SwiftUI Text so they scale with Dynamic Type
                    // Positioned absolutely inside the bar using known bar geometry
                    ForEach(displayPoints.indices, id: \.self) { i in
                        let val    = displayPoints[i].1
                        let barH   = fractions[i] * chartHeight
                        let barX   = CGFloat(i) * (barWidth + barSpacing)
                        let showValue = barWidth >= 18 && barH >= 22
                        if showValue {
                            Text(formatBarValue(val))
                                .font(.system(size: min(barWidth * 0.42, 13), weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(width: barWidth - 2)
                                // Center the text within the bar vertically
                                .position(x: barX + barWidth / 2,
                                          y: baseline - barH / 2)
                        }
                    }

                    // Date / week labels along the bottom
                    ForEach(displayPoints.indices, id: \.self) { i in
                        let label = barLabel(for: displayPoints[i].0, index: i, total: count)
                        if !label.isEmpty {
                            let barX = CGFloat(i) * (barWidth + barSpacing)
                            Text(label)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(width: barWidth)
                                .position(x: barX + barWidth / 2,
                                          y: baseline + labelHeight / 2)
                        }
                    }

                    // Trend line (Catmull-Rom curve through bar tops)
                    if count > 1 {
                        let overflow: CGFloat = 8
                        TrendLineOverlay(
                            fractions: fractions.map { Double($0) },
                            barWidth: barWidth,
                            barSpacing: barSpacing,
                            chartHeight: chartHeight,
                            baseline: baseline,
                            overflow: overflow,
                            color: barColor
                        )
                        .frame(width: totalWidth, height: totalHeight)
                        .padding(-overflow)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private func formatBarValue(_ val: Double) -> String {
        if val >= 1000 {
            return String(format: "%.0fk", val / 1000)
        }
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val))"
            : String(format: "%.1f", val)
    }

    private func barLabel(for date: Date, index: Int, total: Int) -> String {
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

// MARK: - Trend line drawn over bars using a smooth Catmull-Rom curve

private struct TrendLineOverlay: View {
    let fractions: [Double]
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let chartHeight: CGFloat
    let baseline: CGFloat     // y of the bar floor in the original (non-expanded) coordinate space
    let overflow: CGFloat
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard fractions.count > 1 else { return }

            // X center of each bar — shift right by overflow since canvas is expanded on all sides
            let xs: [CGFloat] = fractions.indices.map { i in
                overflow + CGFloat(i) * (barWidth + barSpacing) + barWidth / 2
            }
            // Y = top of each bar — clamp to [top of chart, baseline] so Catmull-Rom control
            // points never push the curve below zero or above the chart ceiling
            let chartFloor = overflow + baseline
            let chartCeiling = overflow
            let ys: [CGFloat] = fractions.map { f in
                let y = overflow + baseline - CGFloat(f) * chartHeight
                return min(chartFloor, max(chartCeiling, y))
            }

            let points = zip(xs, ys).map { CGPoint(x: $0, y: $1) }

            // Build a smooth Catmull-Rom path through the bar-top midpoints
            var path = Path()
            path.move(to: points[0])

            for i in 0 ..< points.count - 1 {
                let p0 = points[max(i - 1, 0)]
                let p1 = points[i]
                let p2 = points[min(i + 1, points.count - 1)]
                let p3 = points[min(i + 2, points.count - 1)]

                // Clamp control point Y to chart bounds so the curve never dips below
                // the baseline or above the top of the chart area
                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6,
                    y: min(chartFloor, max(chartCeiling, p1.y + (p2.y - p0.y) / 6))
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6,
                    y: min(chartFloor, max(chartCeiling, p2.y - (p3.y - p1.y) / 6))
                )
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }

            // Draw a subtle glow shadow first, then the line itself
            ctx.stroke(
                path,
                with: .color(color.opacity(0.18)),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
            ctx.stroke(
                path,
                with: .color(color.opacity(0.75)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )

            // Dot at each data point
            for pt in points {
                let dotRect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(color))
                let innerRect = CGRect(x: pt.x - 1.5, y: pt.y - 1.5, width: 3, height: 3)
                ctx.fill(Path(ellipseIn: innerRect), with: .color(.white))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Equipment Stats View

struct EquipmentStatsView: View {
    let equipment: Equipment

    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: StatsTimeRange = .oneMonth

    /// Exercises that use this piece of equipment
    private var linkedExercises: [Exercise] {
        exercisesState.exercises.filter { $0.equipmentIDs.contains(equipment.id) }
    }

    private var linkedExerciseIDs: Set<UUID> {
        Set(linkedExercises.map { $0.id })
    }

    /// Logs within the time range that contain at least one linked exercise, or a VoiceTrainer log using this equipment
    private var filteredLogs: [WorkoutLog] {
        let start = timeRange.startDate
        let equipID = equipment.id
        return logState.logs
            .filter { $0.completedAt >= start }
            .filter { log in
                log.exercises.contains(where: { linkedExerciseIDs.contains($0.exerciseID) }) ||
                (log.logType == .voiceTrainer && log.logEquipmentIDs.contains(equipID))
            }
            .sorted { $0.completedAt < $1.completedAt }
    }

    private struct WeekBucket: Identifiable {
        let id = UUID()
        let weekStart: Date
        var sessions: Int
        var totalVolume: Double
    }

    private var weekBuckets: [WeekBucket] {
        guard !filteredLogs.isEmpty else { return [] }
        let cal = Calendar.current
        var dict: [Date: WeekBucket] = [:]
        for log in filteredLogs {
            let start = cal.dateInterval(of: .weekOfYear, for: log.completedAt)?.start ?? log.completedAt
            let volume = log.exercises
                .filter { linkedExerciseIDs.contains($0.exerciseID) }
                .flatMap { $0.sets }
                .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            if dict[start] != nil {
                dict[start]!.sessions += 1
                dict[start]!.totalVolume += volume
            } else {
                dict[start] = WeekBucket(weekStart: start, sessions: 1, totalVolume: volume)
            }
        }
        return dict.values.sorted { $0.weekStart < $1.weekStart }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Time range picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(StatsTimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if weekBuckets.isEmpty {
                        equipmentEmptyState
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            equipmentStatsCard(
                                title: "Sessions Used",
                                unit: "sessions",
                                points: weekBuckets.map { ($0.weekStart, Double($0.sessions)) },
                                color: .blue
                            )
                            equipmentStatsCard(
                                title: "Total Volume",
                                unit: weightUnit,
                                points: weekBuckets.map { ($0.weekStart, $0.totalVolume) },
                                color: Color(red: 0.2, green: 0.65, blue: 0.4)
                            )
                        }
                    }

                    // Linked exercises list
                    if !linkedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exercises Using This Equipment")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                            ForEach(linkedExercises) { exercise in
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(equipment.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
        } // NavigationStack
    }

    private var equipmentEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("No Data")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Log workouts with exercises using this equipment to see stats here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private func equipmentStatsCard(title: String, unit: String, points: [(Date, Double)], color: Color) -> some View {
        let hasData = points.contains(where: { $0.1 > 0 })
        if !hasData {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } else {
            let maxVal = points.map { $0.1 }.max() ?? 1
            let total  = points.map { $0.1 }.reduce(0, +)
            let avg    = points.isEmpty ? 0 : total / Double(points.count)
            let best   = points.map { $0.1 }.max() ?? 0
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                BarChartView(points: points, maxValue: maxVal, barColor: color, labelMode: .week)
                    .frame(height: 120)
                    .padding(.horizontal, 16)
                HStack(spacing: 0) {
                    equipmentSummaryCell(label: "Total",     value: equipmentFormatVal(total, unit: unit))
                    Divider().frame(height: 28)
                    equipmentSummaryCell(label: "Best Week", value: equipmentFormatVal(best,  unit: unit))
                    Divider().frame(height: 28)
                    equipmentSummaryCell(label: "Avg/Week",  value: equipmentFormatVal(avg,   unit: unit))
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
    }

    private func equipmentSummaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func equipmentFormatVal(_ val: Double, unit: String) -> String {
        if val == 0 { return "—" }
        if unit == "sessions" { return "\(Int(val))" }
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) \(unit)"
            : String(format: "%.1f \(unit)", val)
    }
}

// MARK: - Workout History Sheet

struct WorkoutHistorySheet: View {
    @Environment(\.dismiss) var dismiss
    let workout: Workout
    let logState: WorkoutLogState

    private var history: [WorkoutLog] {
        logState.sortedLogs.filter { $0.workoutName == workout.name }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.secondary)
                        Text("No History")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Complete this workout to see history here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(history) { log in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text(log.completedAt, style: .date)
                                        .font(.subheadline).fontWeight(.semibold)
                                    Text(log.completedAt, style: .time)
                                        .font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    if log.duration > 0 {
                                        Label(formatDuration(log.duration), systemImage: "clock")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                ForEach(log.exercises) { ex in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ex.exerciseName)
                                            .font(.caption).fontWeight(.semibold)
                                        ForEach(Array(ex.sets.groupedRuns().enumerated()), id: \.offset) { _, run in
                                            HStack {
                                                Text(run.label)
                                                    .font(.caption2).foregroundColor(.secondary)
                                                Spacer()
                                                Text("\(run.set.reps) reps")
                                                    .font(.caption2)
                                                if run.set.weight > 0 {
                                                    Text("· \(String(format: "%.1f", run.set.weight))")
                                                        .font(.caption2).foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .padding(6)
                                    .background(Color(uiColor: .systemGray6))
                                    .cornerRadius(6)
                                }
                                if !log.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Notes: \(log.notes)")
                                        .font(.caption2).foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Workout Stats View

struct WorkoutStatsView: View {
    let workout: Workout
    @Environment(WorkoutLogState.self) var logState
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: StatsTimeRange = .oneMonth
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

    private struct SessionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let duration: Double      // seconds
        let exerciseCount: Int
        let totalSets: Int
        let totalVolume: Double   // sum of reps × weight across all sets
        let maxWeight: Double     // heaviest single set weight logged
    }

    private var sessionPoints: [SessionPoint] {
        let start = timeRange.startDate
        return logState.logs
            .filter { $0.workoutName == workout.name && $0.completedAt >= start }
            .sorted { $0.completedAt < $1.completedAt }
            .map { log in
                let allSets = log.exercises.flatMap { $0.sets }
                let volume = allSets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
                let maxW = allSets.map { $0.weight }.max() ?? 0
                return SessionPoint(
                    date: log.completedAt,
                    duration: log.duration,
                    exerciseCount: log.exercises.count,
                    totalSets: allSets.count,
                    totalVolume: volume,
                    maxWeight: maxW
                )
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(StatsTimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if sessionPoints.isEmpty {
                        workoutEmptyState
                    } else {
                        workoutStatsCard(
                            title: "Duration (mins)",
                            unit: "min",
                            points: sessionPoints.map { ($0.date, $0.duration / 60) },
                            color: .blue
                        )
                        workoutStatsCard(
                            title: "Total Sets",
                            unit: "sets",
                            points: sessionPoints.map { ($0.date, Double($0.totalSets)) },
                            color: Color(red: 0.2, green: 0.65, blue: 0.4)
                        )
                        workoutStatsCard(
                            title: "Exercises Done",
                            unit: "exercises",
                            points: sessionPoints.map { ($0.date, Double($0.exerciseCount)) },
                            color: Color(red: 0.8, green: 0.4, blue: 0.1)
                        )
                        workoutStatsCard(
                            title: "Total Volume",
                            unit: weightUnit,
                            points: sessionPoints.map { ($0.date, $0.totalVolume) },
                            color: Color(red: 0.5, green: 0.2, blue: 0.8)
                        )
                        workoutStatsCard(
                            title: "Max Weight",
                            unit: weightUnit,
                            points: sessionPoints.map { ($0.date, $0.maxWeight) },
                            color: Color(red: 0.85, green: 0.2, blue: 0.35)
                        )
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var workoutEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("No Data")
                .font(.headline).foregroundColor(.secondary)
            Text("Complete this workout to see stats here.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    @ViewBuilder
    private func workoutStatsCard(title: String, unit: String, points: [(Date, Double)], color: Color) -> some View {
        let hasData = points.contains(where: { $0.1 > 0 })
        if !hasData {
            HStack {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("No data").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        } else {
            let maxVal = points.map { $0.1 }.max() ?? 1
            let latest = points.last?.1 ?? 0
            let best   = points.map { $0.1 }.max() ?? 0
            let avg    = points.isEmpty ? 0 : points.map { $0.1 }.reduce(0, +) / Double(points.count)
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.subheadline).fontWeight(.semibold).padding(.horizontal, 16)
                BarChartView(points: points, maxValue: maxVal, barColor: color)
                    .frame(height: 120).padding(.horizontal, 16)
                HStack(spacing: 0) {
                    workoutSummaryCell(label: "Latest", value: workoutFormatVal(latest, unit: unit))
                    Divider().frame(height: 28)
                    workoutSummaryCell(label: "Best",   value: workoutFormatVal(best,   unit: unit))
                    Divider().frame(height: 28)
                    workoutSummaryCell(label: "Avg",    value: workoutFormatVal(avg,    unit: unit))
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
    }

    private func workoutSummaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func workoutFormatVal(_ val: Double, unit: String) -> String {
        if val == 0 { return "—" }
        if unit == "sets" || unit == "exercises" { return "\(Int(val))" }
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) \(unit)" : String(format: "%.1f \(unit)", val)
    }
}

// MARK: - Timer History Sheet

struct TimerHistorySheet: View {
    @Environment(\.dismiss) var dismiss
    let config: TimerConfig
    let logState: WorkoutLogState

    private var history: [WorkoutLog] {
        logState.sortedLogs.filter { $0.workoutName.hasSuffix("– \(config.name)") && !$0.workoutName.hasPrefix("Trainer") }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .light)).foregroundColor(.secondary)
                        Text("No History").font(.headline).foregroundColor(.secondary)
                        Text("Complete this timer to see history here.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(history) { log in
                            HStack(spacing: 6) {
                                Text(log.completedAt, style: .date)
                                    .font(.subheadline).fontWeight(.semibold)
                                Text(log.completedAt, style: .time)
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                if log.duration > 0 {
                                    Label(formatDuration(log.duration), systemImage: "clock")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Timer Stats View

struct TimerStatsView: View {
    let config: TimerConfig
    @Environment(WorkoutLogState.self) var logState
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: StatsTimeRange = .oneMonth

    private var sessionPoints: [(Date, Double)] {
        let start = timeRange.startDate
        return logState.logs
            .filter { $0.workoutName.hasSuffix("– \(config.name)") && !$0.workoutName.hasPrefix("Trainer") && $0.completedAt >= start }
            .sorted { $0.completedAt < $1.completedAt }
            .map { ($0.completedAt, $0.duration / 60) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(StatsTimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 16)

                    if sessionPoints.isEmpty {
                        timerEmptyState
                    } else {
                        timerStatsCard(
                            title: "Duration (mins)", unit: "min",
                            points: sessionPoints, color: .blue
                        )
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var timerEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light)).foregroundColor(.secondary)
            Text("No Data").font(.headline).foregroundColor(.secondary)
            Text("Complete this timer to see stats here.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    @ViewBuilder
    private func timerStatsCard(title: String, unit: String, points: [(Date, Double)], color: Color) -> some View {
        let hasData = points.contains(where: { $0.1 > 0 })
        if !hasData {
            HStack {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("No data").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        } else {
            let maxVal = points.map { $0.1 }.max() ?? 1
            let total  = points.map { $0.1 }.reduce(0, +)
            let best   = points.map { $0.1 }.max() ?? 0
            let avg    = points.isEmpty ? 0 : total / Double(points.count)
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.subheadline).fontWeight(.semibold).padding(.horizontal, 16)
                BarChartView(points: points, maxValue: maxVal, barColor: color)
                    .frame(height: 120).padding(.horizontal, 16)
                HStack(spacing: 0) {
                    timerSummaryCell(label: "Total",   value: timerFormatVal(total, unit: unit))
                    Divider().frame(height: 28)
                    timerSummaryCell(label: "Best",    value: timerFormatVal(best,  unit: unit))
                    Divider().frame(height: 28)
                    timerSummaryCell(label: "Avg",     value: timerFormatVal(avg,   unit: unit))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10).padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
    }

    private func timerSummaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func timerFormatVal(_ val: Double, unit: String) -> String {
        if val == 0 { return "—" }
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) \(unit)" : String(format: "%.1f \(unit)", val)
    }
}

// MARK: - Voice Trainer History Sheet

struct VoiceTrainerHistorySheet: View {
    @Environment(\.dismiss) var dismiss
    let config: VoiceTrainerConfig
    let logState: WorkoutLogState

    private var history: [WorkoutLog] {
        logState.sortedLogs.filter { $0.workoutName == "Trainer – \(config.name)" }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .light)).foregroundColor(.secondary)
                        Text("No History").font(.headline).foregroundColor(.secondary)
                        Text("Complete a session with this trainer to see history here.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(history) { log in
                            HStack(spacing: 6) {
                                Text(log.completedAt, style: .date)
                                    .font(.subheadline).fontWeight(.semibold)
                                Text(log.completedAt, style: .time)
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                if log.duration > 0 {
                                    Label(formatDuration(log.duration), systemImage: "clock")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Voice Trainer Stats View

struct VoiceTrainerStatsView: View {
    let config: VoiceTrainerConfig
    @Environment(WorkoutLogState.self) var logState
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: StatsTimeRange = .oneMonth

    private var sessionPoints: [(Date, Double)] {
        let start = timeRange.startDate
        return logState.logs
            .filter { $0.workoutName == "Trainer – \(config.name)" && $0.completedAt >= start }
            .sorted { $0.completedAt < $1.completedAt }
            .map { ($0.completedAt, $0.duration / 60) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(StatsTimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 16)

                    if sessionPoints.isEmpty {
                        trainerEmptyState
                    } else {
                        trainerStatsCard(
                            title: "Session Duration (mins)", unit: "min",
                            points: sessionPoints, color: .blue
                        )
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var trainerEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light)).foregroundColor(.secondary)
            Text("No Data").font(.headline).foregroundColor(.secondary)
            Text("Complete a session with this trainer to see stats here.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    @ViewBuilder
    private func trainerStatsCard(title: String, unit: String, points: [(Date, Double)], color: Color) -> some View {
        let hasData = points.contains(where: { $0.1 > 0 })
        if !hasData {
            HStack {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("No data").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        } else {
            let maxVal = points.map { $0.1 }.max() ?? 1
            let total  = points.map { $0.1 }.reduce(0, +)
            let best   = points.map { $0.1 }.max() ?? 0
            let avg    = points.isEmpty ? 0 : total / Double(points.count)
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.subheadline).fontWeight(.semibold).padding(.horizontal, 16)
                BarChartView(points: points, maxValue: maxVal, barColor: color)
                    .frame(height: 120).padding(.horizontal, 16)
                HStack(spacing: 0) {
                    trainerSummaryCell(label: "Total",   value: trainerFormatVal(total, unit: unit))
                    Divider().frame(height: 28)
                    trainerSummaryCell(label: "Best",    value: trainerFormatVal(best,  unit: unit))
                    Divider().frame(height: 28)
                    trainerSummaryCell(label: "Avg",     value: trainerFormatVal(avg,   unit: unit))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10).padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
    }

    private func trainerSummaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func trainerFormatVal(_ val: Double, unit: String) -> String {
        if val == 0 { return "—" }
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) \(unit)" : String(format: "%.1f \(unit)", val)
    }
}
