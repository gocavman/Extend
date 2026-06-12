////
////  ExtendWatchWidget.swift
////  ExtendWatchWidget
////
////  Complication code for the Extend Watch Widget Extension.
////  Both the Plan Ring and Steps Ring complications live here.
////

import Foundation
import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Shared data bridge (read-only, no WidgetKit write calls)

private let appGroupID       = "group.com.cavanmannenbach.extend"
private let snapshotKey      = "widget_plan_snapshot"
private let multidayKey      = "widget_plan_multiday"
private let stepsSettingsKey = "watch_steps_settings"

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
        switch family {
        case .accessoryCircular:    circularView.containerBackground(.background, for: .widget)
        case .accessoryRectangular: rectangularView.containerBackground(.background, for: .widget)
        default:                    circularView.containerBackground(.background, for: .widget)
        }
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

struct WatchStepsEntry: TimelineEntry {
    let date: Date
    let steps: Double
    let distanceKm: Double
    let settings: WatchStepsSettings
}

struct WatchStepsProvider: TimelineProvider {
    private let store = HKHealthStore()
    private let stepsKey    = "watch_cached_steps"
    private let distanceKey = "watch_cached_distance_km"

    func placeholder(in context: Context) -> WatchStepsEntry {
        WatchStepsEntry(date: Date(), steps: 7342, distanceKm: 5.8, settings: .default)
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchStepsEntry) -> Void) {
        let s = readWatchStepsSettings()
        let d = UserDefaults(suiteName: appGroupID) ?? .standard
        completion(WatchStepsEntry(date: Date(), steps: d.double(forKey: stepsKey), distanceKm: d.double(forKey: distanceKey), settings: s))
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
            completion(Timeline(entries: [WatchStepsEntry(date: now, steps: steps, distanceKm: km, settings: settings)], policy: .after(next)))
        }
    }
    private func querySum(type: HKQuantityType, unit: HKUnit) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let cal = Calendar.current
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
    private var settings: WatchStepsSettings { entry.settings }
    private var displayKm: Double { entry.distanceKm }
    private var displayMiles: Double { entry.distanceKm / 1.60934 }
    private var displayDist: Double { settings.distanceUnit == .km ? displayKm : displayMiles }
    private var fraction: Double {
        switch settings.mode {
        case .stepsOnly:    return min(entry.steps / max(settings.stepsGoal, 1), 1.0)
        case .distanceOnly: return min(displayDist / max(settings.distanceGoal, 0.001), 1.0)
        case .both:         return min(entry.steps / max(settings.stepsGoal, 1), 1.0)
        }
    }
    private func fmt(_ v: Double) -> String { v >= 1000 ? String(format: "%.1fk", v/1000) : String(Int(v)) }
    private var label: String {
        switch settings.mode {
        case .stepsOnly:    return fmt(entry.steps)
        case .distanceOnly: return String(format: "%.1f", displayDist)
        case .both:         return fmt(entry.steps)
        }
    }
    var body: some View {
        ZStack {
            Gauge(value: fraction) { EmptyView() }.gaugeStyle(.accessoryCircularCapacity).tint(fraction >= 1.0 ? .green : .orange)
            VStack(spacing: 0) {
                Image(systemName: settings.mode == .distanceOnly ? "location.fill" : "figure.walk").font(.system(size: 10, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                if settings.mode == .both {
                    Text("\(String(format: "%.1f", displayDist))\(settings.distanceUnit.rawValue)").font(.system(size: 8).monospacedDigit()).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                }
            }.foregroundColor(fraction >= 1.0 ? .green : .primary)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct StepsComplication: Widget {
    let kind = "ExtendWatch.StepsRing"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider()) { entry in StepsComplicationView(entry: entry) }
            .configurationDisplayName("Steps & Distance")
            .description("Shows today's steps or distance as a ring.")
            .supportedFamilies([.accessoryCircular])
    }
}
