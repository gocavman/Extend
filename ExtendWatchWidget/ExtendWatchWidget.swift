////
////  ExtendWatchWidget.swift
////  ExtendWatchWidget
////
////  Watch complications with simplified appearance system.
////

import Foundation
import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Configuration

private let appGroupID              = "group.com.cavanmannenbach.extend"
private let snapshotKey             = "widget_plan_snapshot"
private let multidayKey             = "widget_plan_multiday"
private let stepsSettingsKey        = "watch_steps_settings"
private let complicationShapesKey   = "watch_complication_shapes"
private let waterTodayOzKey         = "water_today_oz"
private let waterTodayDateKey       = "water_today_date"
private let waterGoalOzKey          = "water_goal_oz"
private let waterUnitKey            = "water_unit"

private var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

// MARK: - Type Definitions (Local to Widget Extension)
// NOTE: Make sure WidgetDataBridge.swift is NOT in ExtendWatchWidget target!
// These types should ONLY exist here for the widget extension.

struct WidgetPlanItem: Codable {
    let name: String
    let icon: String
    let isCompleted: Bool
}

struct WidgetPlanSnapshot: Codable {
    let planName: String?
    let date: Date
    let items: [WidgetPlanItem]
    let isRestDay: Bool
}

enum WatchDistanceUnit: String, Codable, CaseIterable {
    case km = "km", miles = "mi"
}

struct WatchStepsSettings: Codable {
    var stepsGoal: Double
    var distanceGoal: Double
    var distanceUnit: WatchDistanceUnit
    static let `default` = WatchStepsSettings(
        stepsGoal: 10_000, distanceGoal: 8.0, distanceUnit: .km
    )
}

struct WatchComplicationShapeSettings: Codable {
    var stepsShape: String
    var distanceShape: String
    var stepsAndDistanceShape: String
    var waterShape: String
    var planShape: String

    var stepsColor: String = ""
    var distanceColor: String = ""
    var stepsAndDistanceColor: String = ""
    var waterColor: String = ""
    var planColor: String = ""

    static let `default` = WatchComplicationShapeSettings(
        stepsShape: "", distanceShape: "", stepsAndDistanceShape: "", waterShape: "", planShape: ""
    )
}

/// Maps a stored color name to a SwiftUI Color. Empty → nil (use watch-face accent).
fileprivate func complicationColor(_ name: String) -> Color? {
    switch name {
    case "white":  return .white
    case "orange": return .orange
    case "blue":   return .blue
    case "green":  return .green
    case "pink":   return .pink
    case "yellow": return .yellow
    default:       return nil
    }
}

fileprivate extension View {
    /// Applies an explicit complication color, or falls back to the watch-face accent
    /// when no color is selected.
    @ViewBuilder
    func applyTint(_ color: Color?) -> some View {
        if let color {
            self.foregroundStyle(color).tint(color)
        } else {
            self.widgetAccentable()
        }
    }
}

// MARK: - Read Helpers

private func readWidgetSnapshot() -> WidgetPlanSnapshot {
    if let data = sharedDefaults.data(forKey: snapshotKey),
       let decoded = try? JSONDecoder().decode(WidgetPlanSnapshot.self, from: data) {
        return decoded
    }
    return WidgetPlanSnapshot(planName: nil, date: Date(), items: [], isRestDay: true)
}

private func readMultiDaySnapshots() -> [WidgetPlanSnapshot] {
    if let data = sharedDefaults.data(forKey: multidayKey),
       let decoded = try? JSONDecoder().decode([WidgetPlanSnapshot].self, from: data) {
        return decoded
    }
    return []
}

private func readTodayPlanSnapshot() -> WidgetPlanSnapshot {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    if let match = readMultiDaySnapshots().first(where: { cal.isDate($0.date, inSameDayAs: today) }) {
        return match
    }
    return readWidgetSnapshot()
}

private func readWatchStepsSettings() -> WatchStepsSettings {
    if let data = sharedDefaults.data(forKey: stepsSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchStepsSettings.self, from: data) {
        return decoded
    }
    return .default
}

private func readWatchComplicationShapeSettings() -> WatchComplicationShapeSettings {
    if let data = sharedDefaults.data(forKey: complicationShapesKey),
       let decoded = try? JSONDecoder().decode(WatchComplicationShapeSettings.self, from: data) {
        return decoded
    }
    return .default
}

private func readWaterTodayOz() -> Double {
    guard let stored = sharedDefaults.object(forKey: waterTodayDateKey) as? Date,
          Calendar.current.isDate(stored, inSameDayAs: Date()) else { return 0 }
    return sharedDefaults.double(forKey: waterTodayOzKey)
}

private func readWaterGoalOz() -> Double {
    let v = sharedDefaults.double(forKey: waterGoalOzKey)
    return v > 0 ? v : 64.0
}

private func readWaterUnit() -> String {
    sharedDefaults.string(forKey: waterUnitKey) ?? "oz"
}

// MARK: - Rising-fill Shape View

struct ComplicationFillShape: View {
    let fraction: Double
    let shape: String

    /// Shapes whose bounding box reaches the corners get clipped by the
    /// circular complication mask. Scale them down so the inscribed bounding
    /// box fits inside the circle.
    private var fitScale: CGFloat {
        switch shape {
        case "square.fill":   return 0.71   // 1/√2
        case "triangle.fill": return 0.75
        case "pentagon.fill": return 0.86
        case "octagon.fill":  return 0.93
        case "shield.fill":   return 0.90
        case "heart.fill":    return 0.95
        default:              return 1.0
        }
    }

    var body: some View {
        ZStack {
            // Background (empty portion)
            Image(systemName: shape)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary.opacity(0.3))

            // Filled portion (adapts to watch face color)
            GeometryReader { geo in
                let fillH = geo.size.height * CGFloat(min(fraction, 1.0))
                Rectangle()
                    .fill(.primary)
                    .frame(height: max(0, fillH))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .mask {
                Image(systemName: shape)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .scaleEffect(fitScale)
        .widgetAccentable() // 🎨 Adapts to watch face color
    }
}

// MARK: - Plan Complication

struct WatchPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPlanSnapshot
    let shape: String
    let color: String
}

struct WatchPlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchPlanEntry {
        WatchPlanEntry(
            date: Date(),
            snapshot: WidgetPlanSnapshot(
                planName: "My Plan",
                date: Date(),
                items: [
                    WidgetPlanItem(name: "Morning Run", icon: "dumbbell.fill", isCompleted: true),
                    WidgetPlanItem(name: "Pull-ups", icon: "figure.strengthtraining.traditional", isCompleted: false),
                ],
                isRestDay: false
            ),
            shape: "",
            color: ""
        )
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchPlanEntry) -> Void) {
        let settings = readWatchComplicationShapeSettings()
        completion(WatchPlanEntry(
            date: Date(),
            snapshot: readTodayPlanSnapshot(),
            shape: settings.planShape,
            color: settings.planColor
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlanEntry>) -> Void) {
        let snapshot = readTodayPlanSnapshot()
        let settings = readWatchComplicationShapeSettings()
        let shape = settings.planShape
        let color = settings.planColor
        let now = Date()
        let cal = Calendar.current

        var entries: [WatchPlanEntry] = []
        for hour in 0..<12 {
            if let d = cal.date(byAdding: .hour, value: hour, to: now) {
                entries.append(WatchPlanEntry(date: d, snapshot: snapshot, shape: shape, color: color))
            }
        }

        if let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            let tomorrow = readMultiDaySnapshots().first { cal.isDate($0.date, inSameDayAs: nextMidnight) }
                ?? WidgetPlanSnapshot(planName: snapshot.planName, date: nextMidnight, items: [], isRestDay: true)
            entries.append(WatchPlanEntry(date: nextMidnight, snapshot: tomorrow, shape: shape, color: color))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PlanComplicationView: View {
    var entry: WatchPlanEntry
    @Environment(\.widgetFamily) var family

    private var completedCount: Int { entry.snapshot.items.filter { $0.isCompleted }.count }
    private var totalCount: Int { entry.snapshot.items.count }
    private var fraction: Double {
        if totalCount > 0 { return Double(completedCount) / Double(totalCount) }
        return entry.snapshot.isRestDay ? 1.0 : 0.0
    }
    private var tint: Color? { complicationColor(entry.color) }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circularView.containerBackground(.background, for: .widget)
            case .accessoryRectangular: rectangularView.containerBackground(.background, for: .widget)
            default: circularView.containerBackground(.background, for: .widget)
            }
        }
        .widgetURL(URL(string: "extendwatch://plan")!)
    }

    private var circularView: some View {
        ZStack {
            if !entry.shape.isEmpty {
                ComplicationFillShape(fraction: fraction, shape: entry.shape)
                    .applyTint(tint)
            } else {
                Gauge(value: fraction) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .applyTint(tint)
            }

            if entry.shape.isEmpty {
                Text(entry.snapshot.isRestDay ? "Rest" : "\(completedCount)/\(totalCount)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .applyTint(tint)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = entry.snapshot.planName {
                Text(name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if entry.snapshot.isRestDay {
                Text("Rest Day").font(.body.weight(.semibold)).applyTint(tint)
            } else if totalCount > 0 {
                Text("\(completedCount) of \(totalCount) done")
                    .font(.body.weight(.semibold))
                    .applyTint(tint)
            } else {
                Text("No activities").font(.body).foregroundStyle(.secondary)
            }
        }
    }
}

struct PlanComplication: Widget {
    let kind = "PlanComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchPlanProvider()) { entry in
            PlanComplicationView(entry: entry)
        }
        .configurationDisplayName("Today's Plan")
        .description("Shows progress on today's planned activities")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Water Complication

struct WatchWaterEntry: TimelineEntry {
    let date: Date
    let todayOz: Double
    let goalOz: Double
    let unit: String
    let shape: String
    let color: String
}

struct WatchWaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchWaterEntry {
        WatchWaterEntry(date: Date(), todayOz: 48, goalOz: 64, unit: "oz", shape: "", color: "")
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchWaterEntry) -> Void) {
        let settings = readWatchComplicationShapeSettings()
        completion(WatchWaterEntry(
            date: Date(),
            todayOz: readWaterTodayOz(),
            goalOz: readWaterGoalOz(),
            unit: readWaterUnit(),
            shape: settings.waterShape,
            color: settings.waterColor
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWaterEntry>) -> Void) {
        let now = Date()
        let cal = Calendar.current
        let settings = readWatchComplicationShapeSettings()
        let shape = settings.waterShape
        let color = settings.waterColor

        var entries: [WatchWaterEntry] = []
        for hour in 0..<6 {
            if let d = cal.date(byAdding: .hour, value: hour, to: now) {
                entries.append(WatchWaterEntry(
                    date: d,
                    todayOz: readWaterTodayOz(),
                    goalOz: readWaterGoalOz(),
                    unit: readWaterUnit(),
                    shape: shape,
                    color: color
                ))
            }
        }

        if let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            entries.append(WatchWaterEntry(date: nextMidnight, todayOz: 0, goalOz: readWaterGoalOz(), unit: readWaterUnit(), shape: shape, color: color))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WaterComplicationView: View {
    var entry: WatchWaterEntry
    @Environment(\.widgetFamily) var family

    private var fraction: Double { min(entry.todayOz / max(entry.goalOz, 1), 1.0) }
    private var displayValue: String {
        if entry.unit == "mL" {
            return String(format: "%.0f", entry.todayOz * 29.5735)
        }
        return entry.todayOz >= 10 ? String(format: "%.0f", entry.todayOz) : String(format: "%.1f", entry.todayOz)
    }
    private var tint: Color? { complicationColor(entry.color) }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circularView.containerBackground(.background, for: .widget)
            case .accessoryRectangular: rectangularView.containerBackground(.background, for: .widget)
            default: circularView.containerBackground(.background, for: .widget)
            }
        }
        .widgetURL(URL(string: "extendwatch://water")!)
    }

    private var circularView: some View {
        ZStack {
            if !entry.shape.isEmpty {
                ComplicationFillShape(fraction: fraction, shape: entry.shape)
                    .applyTint(tint)
            } else {
                Gauge(value: fraction) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .applyTint(tint)
            }

            if entry.shape.isEmpty {
                VStack(spacing: 0) {
                    Text(displayValue)
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .applyTint(tint)
                    Text(entry.unit)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Water")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text("\(displayValue) \(entry.unit)")
                .font(.title3.weight(.semibold).monospacedDigit())
                .applyTint(tint)
            Text("of \(Int(entry.goalOz)) \(entry.unit)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct WaterComplication: Widget {
    let kind = "ExtendWatch.Water"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWaterProvider()) { entry in
            WaterComplicationView(entry: entry)
        }
        .configurationDisplayName("Water")
        .description("Shows today's water intake")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Steps/Distance Complications

enum StepsDisplayMode { case stepsOnly, distanceOnly, both }

struct WatchStepsEntry: TimelineEntry {
    let date: Date
    let steps: Double
    let distanceKm: Double
    let settings: WatchStepsSettings
    let shape: String
    let color: String
    let mode: StepsDisplayMode
}

class WatchStepsProvider: TimelineProvider {
    let mode: StepsDisplayMode
    init(mode: StepsDisplayMode) { self.mode = mode }

    private let store = HKHealthStore()
    private let stepsKey = "cached_steps"
    private let distanceKey = "cached_distance_km"
    private let cacheDateKey = "steps_cache_date"

    private func freshCachedSteps() -> (steps: Double, km: Double) {
        let d = sharedDefaults
        guard let cachedDate = d.object(forKey: cacheDateKey) as? Date,
              Calendar.current.isDate(cachedDate, inSameDayAs: Date()) else { return (0, 0) }
        return (d.double(forKey: stepsKey), d.double(forKey: distanceKey))
    }

    func placeholder(in context: Context) -> WatchStepsEntry {
        WatchStepsEntry(
            date: Date(), steps: 7342, distanceKm: 5.8,
            settings: .default, shape: "", color: "", mode: mode
        )
    }

    private func shapeAndColor(for shapes: WatchComplicationShapeSettings) -> (shape: String, color: String) {
        switch mode {
        case .stepsOnly:    return (shapes.stepsShape,            shapes.stepsColor)
        case .distanceOnly: return (shapes.distanceShape,         shapes.distanceColor)
        case .both:         return (shapes.stepsAndDistanceShape, shapes.stepsAndDistanceColor)
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStepsEntry) -> Void) {
        let cached = freshCachedSteps()
        let sc = shapeAndColor(for: readWatchComplicationShapeSettings())
        completion(WatchStepsEntry(
            date: Date(),
            steps: cached.steps,
            distanceKm: cached.km,
            settings: readWatchStepsSettings(),
            shape: sc.shape,
            color: sc.color,
            mode: mode
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStepsEntry>) -> Void) {
        let settings = readWatchStepsSettings()
        let sc = shapeAndColor(for: readWatchComplicationShapeSettings())

        Task {
            let steps = await querySum(type: HKQuantityType(.stepCount), unit: .count())
            let km = await querySum(type: HKQuantityType(.distanceWalkingRunning), unit: .meter()) / 1000.0
            let d = sharedDefaults
            d.set(steps, forKey: stepsKey)
            d.set(km, forKey: distanceKey)
            d.set(Calendar.current.startOfDay(for: Date()), forKey: cacheDateKey)

            let now = Date()
            let cal = Calendar.current

            var entries: [WatchStepsEntry] = [
                WatchStepsEntry(
                    date: now, steps: steps, distanceKm: km,
                    settings: settings, shape: sc.shape, color: sc.color, mode: mode
                )
            ]

            if let nextMidnight = cal.nextDate(
                after: now,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) {
                entries.append(WatchStepsEntry(
                    date: nextMidnight, steps: 0, distanceKm: 0,
                    settings: settings, shape: sc.shape, color: sc.color, mode: mode
                ))
            }

            let next = cal.date(byAdding: .minute, value: 15, to: now) ?? now
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }

    private func querySum(type: HKQuantityType, unit: HKUnit) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            store.execute(HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, s, _ in
                cont.resume(returning: s?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            })
        }
    }
}

struct StepsComplicationView: View {
    var entry: WatchStepsEntry
    @Environment(\.widgetFamily) var family

    private var settings: WatchStepsSettings { entry.settings }
    private var mode: StepsDisplayMode { entry.mode }
    private var displayDist: Double {
        settings.distanceUnit == .km ? entry.distanceKm : entry.distanceKm / 1.60934
    }
    private var stepsFrac: Double { min(entry.steps / max(settings.stepsGoal, 1), 1.0) }
    private var distFrac: Double { min(displayDist / max(settings.distanceGoal, 0.001), 1.0) }
    private var ringFrac: Double { mode == .distanceOnly ? distFrac : stepsFrac }
    private var tint: Color? { complicationColor(entry.color) }

    private func fmt(_ v: Double) -> String { v >= 1000 ? String(format: "%.1fk", v / 1000) : String(Int(v)) }
    private func fmtDist(_ v: Double) -> String { String(format: "%.1f", v) }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangularView
            default: circularView
            }
        }
        .widgetURL(URL(string: "extendwatch://steps")!)
    }

    private var circularView: some View {
        ZStack {
            if !entry.shape.isEmpty {
                ComplicationFillShape(fraction: ringFrac, shape: entry.shape)
                    .applyTint(tint)
            } else {
                Gauge(value: ringFrac) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .applyTint(tint)
            }

            if entry.shape.isEmpty {
                VStack(spacing: 0) {
                    switch mode {
                    case .stepsOnly:
                        Text(fmt(entry.steps))
                            .font(.system(size: 15, weight: .bold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .applyTint(tint)
                    case .distanceOnly:
                        Text(fmtDist(displayDist))
                            .font(.system(size: 15, weight: .bold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .applyTint(tint)
                        Text(settings.distanceUnit.rawValue)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    case .both:
                        Text(fmt(entry.steps))
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .applyTint(tint)
                        Text("\(fmtDist(displayDist))\(settings.distanceUnit.rawValue)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch mode {
            case .stepsOnly:
                HStack(spacing: 4) {
                    Text("Steps").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(fmt(entry.steps))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .applyTint(tint)
                }
                Gauge(value: stepsFrac) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .applyTint(tint)
                Text("Goal: \(fmt(settings.stepsGoal)) steps")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

            case .distanceOnly:
                HStack(spacing: 4) {
                    Text("Distance").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text("\(fmtDist(displayDist)) \(settings.distanceUnit.rawValue)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .applyTint(tint)
                }
                Gauge(value: distFrac) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .applyTint(tint)
                Text("Goal: \(fmtDist(settings.distanceGoal)) \(settings.distanceUnit.rawValue)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

            case .both:
                HStack(spacing: 4) {
                    Text(fmt(entry.steps))
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .applyTint(tint)
                    Spacer()
                    Text("/ \(fmt(settings.stepsGoal))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Text("\(fmtDist(displayDist)) \(settings.distanceUnit.rawValue)")
                        .font(.system(size: 12).monospacedDigit())
                        .applyTint(tint)
                    Spacer()
                    Text("/ \(fmtDist(settings.distanceGoal))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct StepsComplication: Widget {
    let kind = "ExtendWatch.StepsRing"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider(mode: .stepsOnly)) { entry in
            StepsComplicationView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Shows today's step count")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct DistanceComplication: Widget {
    let kind = "ExtendWatch.DistanceRing"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider(mode: .distanceOnly)) { entry in
            StepsComplicationView(entry: entry)
        }
        .configurationDisplayName("Distance")
        .description("Shows today's distance walked/run")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct StepsAndDistanceComplication: Widget {
    let kind = "ExtendWatch.StepsAndDistance"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider(mode: .both)) { entry in
            StepsComplicationView(entry: entry)
        }
        .configurationDisplayName("Steps & Distance")
        .description("Shows both steps and distance")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
