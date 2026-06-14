////
////  ExtendWatchWidget.swift
////  ExtendWatchWidget
////
////  Complication code for the Extend Watch Widget Extension.
////  Plan Ring, Steps Ring, and Water Ring complications.
////

import Foundation
import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Shared data bridge (read-only)

private let appGroupID       = "group.com.cavanmannenbach.extend"
private let snapshotKey      = "widget_plan_snapshot"
private let multidayKey      = "widget_plan_multiday"
private let stepsSettingsKey = "watch_steps_settings"
private let waterTodayOzKey  = "water_today_oz"
private let waterGoalOzKey   = "water_goal_oz"
private let waterUnitKey     = "water_unit"

public struct WidgetPlanItem: Codable {
    public let name: String
    public let icon: String
    public let isCompleted: Bool
    public init(name: String, icon: String, isCompleted: Bool = false) {
        self.name = name; self.icon = icon; self.isCompleted = isCompleted
    }
}

public struct WidgetPlanSnapshot: Codable {
    public let planName: String?
    public let date: Date
    public let items: [WidgetPlanItem]
    public let isRestDay: Bool
}

public enum WatchStepsMode: String, Codable, CaseIterable {
    case stepsOnly = "steps", distanceOnly = "distance", both = "both"
    public var displayName: String {
        switch self {
        case .stepsOnly: return "Steps"
        case .distanceOnly: return "Distance"
        case .both: return "Steps & Distance"
        }
    }
}

public enum WatchDistanceUnit: String, Codable, CaseIterable {
    case km = "km", miles = "mi"
}

public struct WatchStepsSettings: Codable {
    public var mode: WatchStepsMode
    public var stepsGoal: Double
    public var distanceGoal: Double
    public var distanceUnit: WatchDistanceUnit
    public static let `default` = WatchStepsSettings(mode: .stepsOnly, stepsGoal: 10_000, distanceGoal: 8.0, distanceUnit: .km)
}

func readWidgetSnapshot() -> WidgetPlanSnapshot {
    let d = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = d.data(forKey: snapshotKey), let decoded = try? JSONDecoder().decode(WidgetPlanSnapshot.self, from: data) { return decoded }
    return WidgetPlanSnapshot(planName: nil, date: Date(), items: [], isRestDay: true)
}

func readMultiDaySnapshots() -> [WidgetPlanSnapshot] {
    let d = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = d.data(forKey: multidayKey), let decoded = try? JSONDecoder().decode([WidgetPlanSnapshot].self, from: data) { return decoded }
    return []
}

func readWatchStepsSettings() -> WatchStepsSettings {
    let d = UserDefaults(suiteName: appGroupID) ?? .standard
    if let data = d.data(forKey: stepsSettingsKey), let decoded = try? JSONDecoder().decode(WatchStepsSettings.self, from: data) { return decoded }
    return .default
}

func readWaterTodayOz() -> Double {
    (UserDefaults(suiteName: appGroupID) ?? .standard).double(forKey: waterTodayOzKey)
}

func readWaterGoalOz() -> Double {
    let v = (UserDefaults(suiteName: appGroupID) ?? .standard).double(forKey: waterGoalOzKey)
    return v > 0 ? v : 64.0
}

func readWaterUnit() -> String {
    (UserDefaults(suiteName: appGroupID) ?? .standard).string(forKey: waterUnitKey) ?? "oz"
}

// MARK: - Plan Complication

struct WatchPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPlanSnapshot
}

struct WatchPlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchPlanEntry {
        WatchPlanEntry(date: Date(), snapshot: WidgetPlanSnapshot(planName: "My Plan", date: Date(), items: [
            WidgetPlanItem(name: "Morning Run", icon: "dumbbell.fill", isCompleted: true),
            WidgetPlanItem(name: "Pull-ups",    icon: "figure.strengthtraining.traditional", isCompleted: false),
        ], isRestDay: false))
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchPlanEntry) -> Void) {
        completion(WatchPlanEntry(date: Date(), snapshot: readWidgetSnapshot()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlanEntry>) -> Void) {
        let snapshot = readWidgetSnapshot()
        let now = Date()
        var entries: [WatchPlanEntry] = []
        for hour in 0..<12 {
            if let d = Calendar.current.date(byAdding: .hour, value: hour, to: now) { entries.append(WatchPlanEntry(date: d, snapshot: snapshot)) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PlanComplicationView: View {
    var entry: WatchPlanEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:    circularView.containerBackground(.background, for: .widget)
            case .accessoryRectangular: rectangularView.containerBackground(.background, for: .widget)
            default:                    circularView.containerBackground(.background, for: .widget)
            }
        }
        .widgetURL(URL(string: "extendwatch://plan")!)
    }
    private var completedCount: Int { entry.snapshot.items.filter { $0.isCompleted }.count }
    private var totalCount: Int     { entry.snapshot.items.count }
    private var fraction: Double    { totalCount > 0 ? Double(completedCount) / Double(totalCount) : (entry.snapshot.isRestDay ? 1.0 : 0.0) }
    private var circularView: some View {
        ZStack {
            Gauge(value: fraction) { EmptyView() }.gaugeStyle(.accessoryCircularCapacity).tint(entry.snapshot.isRestDay ? .green : .blue)
            if entry.snapshot.isRestDay {
                VStack(spacing: 0) {
                    Image(systemName: "zzz").font(.system(size: 12, weight: .bold))
                    Text("Rest").font(.system(size: 9, weight: .medium))
                }.foregroundColor(.green)
            } else if totalCount == 0 {
                Image(systemName: "calendar").font(.system(size: 14)).foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: fraction >= 1.0 ? "checkmark" : "calendar.badge.checkmark").font(.system(size: 10, weight: .bold))
                    Text("\(completedCount)/\(totalCount)").font(.system(size: 10, weight: .semibold).monospacedDigit())
                }.foregroundColor(fraction >= 1.0 ? .green : .primary)
            }
        }
    }
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.checkmark").font(.system(size: 11, weight: .semibold))
                Text(entry.snapshot.planName ?? "Today's Plan").font(.system(size: 11, weight: .bold)).lineLimit(1)
                Spacer()
                if !entry.snapshot.isRestDay && totalCount > 0 {
                    Text("\(completedCount)/\(totalCount)").font(.system(size: 10).monospacedDigit()).foregroundColor(.secondary)
                }
            }.foregroundColor(.primary)
            if entry.snapshot.isRestDay {
                HStack(spacing: 4) {
                    Image(systemName: "zzz").font(.system(size: 10))
                    Text("Rest day").font(.system(size: 10))
                }.foregroundColor(.secondary)
            } else {
                ForEach(entry.snapshot.items.prefix(3), id: \.name) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.icon).font(.system(size: 9)).foregroundColor(.secondary).frame(width: 12)
                        Text(item.name).font(.system(size: 10)).lineLimit(1)
                        Spacer()
                        if item.isCompleted { Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundColor(.green) }
                    }
                }
            }
        }
    }
}

struct PlanComplication: Widget {
    let kind = "ExtendWatch.PlanRing"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchPlanProvider()) { entry in PlanComplicationView(entry: entry) }
            .configurationDisplayName("Today's Plan")
            .description("Shows your training plan completion ring.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Steps / Distance Complication

// MARK: - Steps / Distance Complication (3 separate widgets for distinct picker entries)

enum StepsDisplayMode: String, CaseIterable {
    case stepsOnly    = "steps"
    case distanceOnly = "distance"
    case both         = "both"
}

struct WatchStepsEntry: TimelineEntry {
    let date: Date
    let steps: Double
    let distanceKm: Double
    let settings: WatchStepsSettings
    let mode: StepsDisplayMode
}

struct WatchStepsProvider: TimelineProvider {
    let mode: StepsDisplayMode

    private let store       = HKHealthStore()
    private let stepsKey    = "watch_cached_steps"
    private let distanceKey = "watch_cached_distance_km"

    func placeholder(in context: Context) -> WatchStepsEntry {
        WatchStepsEntry(date: Date(), steps: 7342, distanceKm: 5.8, settings: .default, mode: mode)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStepsEntry) -> Void) {
        let d = UserDefaults(suiteName: appGroupID) ?? .standard
        completion(WatchStepsEntry(date: Date(), steps: d.double(forKey: stepsKey), distanceKm: d.double(forKey: distanceKey), settings: readWatchStepsSettings(), mode: mode))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStepsEntry>) -> Void) {
        let settings = readWatchStepsSettings()
        Task {
            let steps = await querySum(type: HKQuantityType(.stepCount), unit: .count())
            let km    = await querySum(type: HKQuantityType(.distanceWalkingRunning), unit: .meter()) / 1000.0
            let d = UserDefaults(suiteName: appGroupID) ?? .standard
            d.set(steps, forKey: stepsKey); d.set(km, forKey: distanceKey)
            let now  = Date()
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
            completion(Timeline(entries: [
                WatchStepsEntry(date: now, steps: steps, distanceKm: km, settings: settings, mode: mode)
            ], policy: .after(next)))
        }
    }

    private func querySum(type: HKQuantityType, unit: HKUnit) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let cal   = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let pred  = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
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
    private var mode: StepsDisplayMode       { entry.mode }
    private var displayDist: Double {
        settings.distanceUnit == .km ? entry.distanceKm : entry.distanceKm / 1.60934
    }
    private var stepsFrac: Double { min(entry.steps / max(settings.stepsGoal, 1), 1.0) }
    private var distFrac:  Double { min(displayDist / max(settings.distanceGoal, 0.001), 1.0) }

    // Each mode gets a distinct accent color so they're visually unambiguous in the picker.
    private var accentColor: Color {
        switch mode {
        case .stepsOnly:    return .orange
        case .distanceOnly: return .cyan
        case .both:         return .indigo
        }
    }

    private func fmt(_ v: Double) -> String { v >= 1000 ? String(format: "%.1fk", v / 1000) : String(Int(v)) }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangularView
            default:                    circularView
            }
        }
        .widgetURL(URL(string: "extendwatch://steps")!)
    }

    private var circularView: some View {
        let ringFrac = mode == .distanceOnly ? distFrac : stepsFrac
        return ZStack {
            Gauge(value: ringFrac) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(ringFrac >= 1.0 ? .green : accentColor)
            VStack(spacing: 0) {
                if mode != .both {
                    Image(systemName: mode == .distanceOnly ? "location.fill" : "figure.walk")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(mode == .distanceOnly ? String(format: "%.1f", displayDist) : fmt(entry.steps))
                    .font(.system(size: mode == .both ? 12 : 10, weight: .bold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.7)
                if mode == .both {
                    Text("\(String(format: "%.1f", displayDist))\(settings.distanceUnit.rawValue)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .foregroundColor(ringFrac >= 1.0 ? .green : .primary)
        }
        .containerBackground(.background, for: .widget)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch mode {
            case .stepsOnly:
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk").font(.system(size: 11, weight: .semibold)).foregroundColor(accentColor)
                    Text("Steps").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(fmt(entry.steps)).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundColor(stepsFrac >= 1.0 ? .green : .primary)
                }
                Gauge(value: stepsFrac) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(stepsFrac >= 1.0 ? .green : accentColor)
                Text("Goal: \(fmt(settings.stepsGoal)) steps").font(.system(size: 10)).foregroundColor(.secondary)

            case .distanceOnly:
                HStack(spacing: 4) {
                    Image(systemName: "location.fill").font(.system(size: 11, weight: .semibold)).foregroundColor(accentColor)
                    Text("Distance").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(String(format: "%.2f", displayDist) + " " + settings.distanceUnit.rawValue)
                        .font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundColor(distFrac >= 1.0 ? .green : .primary)
                }
                Gauge(value: distFrac) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(distFrac >= 1.0 ? .green : accentColor)
                Text("Goal: \(String(format: "%.1f", settings.distanceGoal)) \(settings.distanceUnit.rawValue)").font(.system(size: 10)).foregroundColor(.secondary)

            case .both:
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk").font(.system(size: 10, weight: .semibold)).foregroundColor(.orange)
                    Text(fmt(entry.steps)).font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundColor(stepsFrac >= 1.0 ? .green : .primary)
                    Spacer()
                    Text("/ \(fmt(settings.stepsGoal))").font(.system(size: 10)).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "location.fill").font(.system(size: 10, weight: .semibold)).foregroundColor(.cyan)
                    Text(String(format: "%.2f", displayDist) + " " + settings.distanceUnit.rawValue)
                        .font(.system(size: 12).monospacedDigit()).foregroundColor(distFrac >= 1.0 ? .green : .primary)
                    Spacer()
                    Text("/ \(String(format: "%.1f", settings.distanceGoal))").font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct StepsComplication: Widget {
    let kind = "ExtendWatch.StepsRing"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider(mode: .stepsOnly)) { entry in StepsComplicationView(entry: entry) }
            .configurationDisplayName("Steps")
            .description("Shows today's step count as a ring.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct DistanceComplication: Widget {
    let kind = "ExtendWatch.DistanceRing"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider(mode: .distanceOnly)) { entry in StepsComplicationView(entry: entry) }
            .configurationDisplayName("Distance")
            .description("Shows today's walking/running distance as a ring.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct StepsAndDistanceComplication: Widget {
    let kind = "ExtendWatch.StepsDistanceRing"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider(mode: .both)) { entry in StepsComplicationView(entry: entry) }
            .configurationDisplayName("Steps & Distance")
            .description("Shows today's step count and distance.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Water Complication

struct WatchWaterEntry: TimelineEntry {
    let date: Date
    let todayOz: Double
    let goalOz: Double
    let unit: String
}

struct WatchWaterProvider: TimelineProvider {
    private let store = HKHealthStore()

    func placeholder(in context: Context) -> WatchWaterEntry {
        WatchWaterEntry(date: Date(), todayOz: 40, goalOz: 64, unit: "oz")
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchWaterEntry) -> Void) {
        completion(WatchWaterEntry(date: Date(), todayOz: readWaterTodayOz(), goalOz: readWaterGoalOz(), unit: readWaterUnit()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWaterEntry>) -> Void) {
        Task {
            let oz = await queryWaterOz()
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            completion(Timeline(entries: [
                WatchWaterEntry(date: Date(), todayOz: oz, goalOz: readWaterGoalOz(), unit: readWaterUnit())
            ], policy: .after(next)))
        }
    }
    private func queryWaterOz() async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return readWaterTodayOz() }
        let type = HKQuantityType(.dietaryWater)
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            store.execute(HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, s, _ in
                let litres = s?.sumQuantity()?.doubleValue(for: .liter()) ?? 0
                cont.resume(returning: litres > 0 ? litres * 33.814 : readWaterTodayOz())
            })
        }
    }
}

struct WaterComplicationView: View {
    var entry: WatchWaterEntry
    @Environment(\.widgetFamily) var family

    private var waterColor: Color { Color(red: 0.2, green: 0.55, blue: 1.0) }
    private var fillFraction: Double { min(entry.todayOz / max(entry.goalOz, 1), 1.0) }
    private var shortLabel: String {
        if entry.unit == "mL" {
            let ml = entry.todayOz * 29.5735
            if ml >= 1000 { return String(format: "%.1fL", ml / 1000) }
            return String(format: "%.0f", ml)
        }
        return entry.todayOz >= 10 ? String(format: "%.0f", entry.todayOz) : String(format: "%.1f", entry.todayOz)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangularView
            default:                    circularView
            }
        }
        .widgetURL(URL(string: "extendwatch://water")!)
    }

    private var circularView: some View {
        ZStack {
            Gauge(value: fillFraction) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(fillFraction >= 1.0 ? .green : waterColor)
            VStack(spacing: 0) {
                Image(systemName: "drop.fill").font(.system(size: 10, weight: .semibold))
                Text(shortLabel).font(.system(size: 10, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundColor(fillFraction >= 1.0 ? .green : waterColor)
        }
        .containerBackground(.background, for: .widget)
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Gauge(value: fillFraction) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(fillFraction >= 1.0 ? .green : waterColor)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill").font(.system(size: 11, weight: .semibold))
                    Text("Water").font(.system(size: 11, weight: .bold))
                }.foregroundColor(waterColor)
                Text("\(shortLabel) \(entry.unit) today").font(.system(size: 10).monospacedDigit()).foregroundColor(.secondary)
                Text("\(Int(fillFraction * 100))% of goal").font(.system(size: 10, weight: .semibold).monospacedDigit()).foregroundColor(fillFraction >= 1.0 ? .green : .primary)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct WaterComplication: Widget {
    let kind = "ExtendWatch.Water"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWaterProvider()) { entry in
            WaterComplicationView(entry: entry)
        }
        .configurationDisplayName("Water")
        .description("Shows today's water intake. Tap to open Extend.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Previews

private let previewSettings = WatchStepsSettings(
    mode: .stepsOnly, stepsGoal: 10_000, distanceGoal: 8.0, distanceUnit: .km
)

#Preview("Steps – circular", as: .accessoryCircular) {
    StepsComplication()
} timeline: {
    WatchStepsEntry(date: .now, steps: 12456, distanceKm: 8.73, settings: previewSettings, mode: .stepsOnly)
}

#Preview("Distance – circular", as: .accessoryCircular) {
    DistanceComplication()
} timeline: {
    WatchStepsEntry(date: .now, steps: 12456, distanceKm: 8.73, settings: previewSettings, mode: .distanceOnly)
}

#Preview("Steps & Distance – circular", as: .accessoryCircular) {
    StepsAndDistanceComplication()
} timeline: {
    WatchStepsEntry(date: .now, steps: 12456, distanceKm: 8.73, settings: previewSettings, mode: .both)
}

#Preview("Steps & Distance – rectangular", as: .accessoryRectangular) {
    StepsAndDistanceComplication()
} timeline: {
    WatchStepsEntry(date: .now, steps: 12456, distanceKm: 8.73, settings: previewSettings, mode: .both)
}
