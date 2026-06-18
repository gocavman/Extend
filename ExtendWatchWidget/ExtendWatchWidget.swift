////
////  ExtendWatchWidget.swift
////  ExtendWatchWidget
////
////  Watch complications: Plan Ring, Steps, Distance, Steps & Distance, Water.
////  Reads shared state (plan snapshots, water totals, appearance settings)
////  from the App Group container. The iPhone pushes those values over
////  WatchConnectivity (see Extend/Sync/WatchConnectivityReceiver.swift).
////

import Foundation
import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Shared data bridge (read-only)

private let appGroupID              = "group.com.cavanmannenbach.extend"
private let snapshotKey             = "widget_plan_snapshot"
private let multidayKey             = "widget_plan_multiday"
private let stepsSettingsKey        = "watch_steps_settings"
private let complicationSettingsKey = "watch_complication_settings"
private let waterTodayOzKey         = "water_today_oz"
private let waterTodayDateKey       = "water_today_date"
private let waterGoalOzKey          = "water_goal_oz"
private let waterUnitKey            = "water_unit"

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

public enum WatchDistanceUnit: String, Codable, CaseIterable {
    case km = "km", miles = "mi"
}

/// Mirrors the iPhone-side type. Fields and order must match exactly so the
/// shared JSON in the App Group / WatchConnectivity payload decodes cleanly.
public struct WatchStepsSettings: Codable {
    public var stepsGoal: Double
    public var distanceGoal: Double
    public var distanceUnit: WatchDistanceUnit
    public static let `default` = WatchStepsSettings(
        stepsGoal: 10_000, distanceGoal: 8.0, distanceUnit: .km
    )
}

// MARK: Appearance settings (mirrored from iPhone)

public enum ComplicationColorPreset: String, Codable, CaseIterable {
    case orange, blue, green, red, purple, yellow, cyan, pink, mint, indigo
}

public enum ComplicationStyle: String, Codable, CaseIterable {
    case ring, fill
}

public struct ComplicationAppearance: Codable, Equatable {
    public var colorPreset: ComplicationColorPreset
    public var style: ComplicationStyle
    public var shape: String

    public static let defaultSteps = ComplicationAppearance(colorPreset: .orange, style: .ring, shape: "circle.fill")
    public static let defaultWater = ComplicationAppearance(colorPreset: .blue,   style: .ring, shape: "circle.fill")
    public static let defaultPlan  = ComplicationAppearance(colorPreset: .blue,   style: .ring, shape: "circle.fill")
}

public struct WatchComplicationUserSettings: Codable, Equatable {
    public var stepsOnly: ComplicationAppearance
    public var distanceOnly: ComplicationAppearance
    public var stepsAndDistance: ComplicationAppearance
    public var water: ComplicationAppearance
    public var plan: ComplicationAppearance

    public static let `default` = WatchComplicationUserSettings(
        stepsOnly:        .defaultSteps,
        distanceOnly:     .defaultSteps,
        stepsAndDistance: .defaultSteps,
        water:            .defaultWater,
        plan:             .defaultPlan
    )
}

// MARK: Read helpers

private var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

func readWidgetSnapshot() -> WidgetPlanSnapshot {
    if let data = sharedDefaults.data(forKey: snapshotKey),
       let decoded = try? JSONDecoder().decode(WidgetPlanSnapshot.self, from: data) {
        return decoded
    }
    return WidgetPlanSnapshot(planName: nil, date: Date(), items: [], isRestDay: true)
}

func readMultiDaySnapshots() -> [WidgetPlanSnapshot] {
    if let data = sharedDefaults.data(forKey: multidayKey),
       let decoded = try? JSONDecoder().decode([WidgetPlanSnapshot].self, from: data) {
        return decoded
    }
    return []
}

/// Picks today's snapshot from the multi-day window the iPhone pushes via
/// WatchConnectivity. The single-day `widget_plan_snapshot` key is never
/// written on the watch side, so reading it directly always yielded the
/// empty default (showing "Rest" in the complication).
func readTodayPlanSnapshot() -> WidgetPlanSnapshot {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    if let match = readMultiDaySnapshots().first(where: { cal.isDate($0.date, inSameDayAs: today) }) {
        return match
    }
    // Fall back to whatever the watch app may have cached.
    return readWidgetSnapshot()
}

func readWatchStepsSettings() -> WatchStepsSettings {
    if let data = sharedDefaults.data(forKey: stepsSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchStepsSettings.self, from: data) {
        return decoded
    }
    return .default
}

func readWatchComplicationSettings() -> WatchComplicationUserSettings {
    if let data = sharedDefaults.data(forKey: complicationSettingsKey),
       let decoded = try? JSONDecoder().decode(WatchComplicationUserSettings.self, from: data) {
        return decoded
    }
    return .default
}

func readWaterTodayOz() -> Double {
    guard let stored = sharedDefaults.object(forKey: waterTodayDateKey) as? Date,
          Calendar.current.isDate(stored, inSameDayAs: Date()) else { return 0 }
    return sharedDefaults.double(forKey: waterTodayOzKey)
}

func readWaterGoalOz() -> Double {
    let v = sharedDefaults.double(forKey: waterGoalOzKey)
    return v > 0 ? v : 64.0
}

func readWaterUnit() -> String {
    sharedDefaults.string(forKey: waterUnitKey) ?? "oz"
}

// MARK: - Appearance helpers

func complicationColor(_ preset: ComplicationColorPreset, fraction: Double) -> Color {
    if fraction >= 1.0 { return .green }
    switch preset {
    case .orange: return .orange
    case .blue:   return Color(red: 0.2, green: 0.55, blue: 1.0)
    case .green:  return .green
    case .red:    return .red
    case .purple: return .purple
    case .yellow: return .yellow
    case .cyan:   return .cyan
    case .pink:   return .pink
    case .mint:   return .mint
    case .indigo: return .indigo
    }
}

/// Rising-fill SF Symbol shape used when ComplicationStyle == .fill.
struct ComplicationFillShape: View {
    let fraction: Double
    let color: Color
    let shape: String

    var body: some View {
        ZStack {
            Image(systemName: shape)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(color.opacity(0.15))

            GeometryReader { geo in
                let fillH = geo.size.height * CGFloat(min(fraction, 1.0))
                Rectangle()
                    .fill(color.opacity(0.9))
                    .frame(height: max(0, fillH))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .mask {
                Image(systemName: shape)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

// MARK: - Plan Complication

struct WatchPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPlanSnapshot
    let appearance: WatchComplicationUserSettings
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
                    WidgetPlanItem(name: "Pull-ups",    icon: "figure.strengthtraining.traditional", isCompleted: false),
                ],
                isRestDay: false
            ),
            appearance: .default
        )
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchPlanEntry) -> Void) {
        completion(WatchPlanEntry(
            date: Date(),
            snapshot: readTodayPlanSnapshot(),
            appearance: readWatchComplicationSettings()
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlanEntry>) -> Void) {
        let snapshot = readTodayPlanSnapshot()
        let appearance = readWatchComplicationSettings()
        let now = Date()
        let cal = Calendar.current

        var entries: [WatchPlanEntry] = []
        for hour in 0..<12 {
            if let d = cal.date(byAdding: .hour, value: hour, to: now) {
                entries.append(WatchPlanEntry(date: d, snapshot: snapshot, appearance: appearance))
            }
        }

        // Force a rollover at midnight by appending an entry stamped at the
        // start of the next day with whatever multi-day snapshot covers it.
        if let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            let tomorrow = readMultiDaySnapshots().first { cal.isDate($0.date, inSameDayAs: nextMidnight) }
                ?? WidgetPlanSnapshot(planName: snapshot.planName, date: nextMidnight, items: [], isRestDay: true)
            entries.append(WatchPlanEntry(date: nextMidnight, snapshot: tomorrow, appearance: appearance))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PlanComplicationView: View {
    var entry: WatchPlanEntry
    @Environment(\.widgetFamily) var family

    private var completedCount: Int { entry.snapshot.items.filter { $0.isCompleted }.count }
    private var totalCount: Int     { entry.snapshot.items.count }
    private var fraction: Double {
        if totalCount > 0 { return Double(completedCount) / Double(totalCount) }
        return entry.snapshot.isRestDay ? 1.0 : 0.0
    }
    private var appearance: ComplicationAppearance { entry.appearance.plan }
    private var accentColor: Color { complicationColor(appearance.colorPreset, fraction: fraction) }

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

    private var circularView: some View {
        ZStack {
            if appearance.style == .fill {
                ComplicationFillShape(fraction: fraction, color: accentColor, shape: appearance.shape)
            } else {
                Gauge(value: fraction) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(accentColor)
            }

            if entry.snapshot.isRestDay {
                VStack(spacing: 0) {
                    Image(systemName: "zzz").font(.system(size: 12, weight: .bold))
                    Text("Rest").font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(appearance.style == .fill ? .white : .green)
                .shadow(color: appearance.style == .fill ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
            } else if totalCount == 0 {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(appearance.style == .fill ? .white : .secondary)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: fraction >= 1.0 ? "checkmark" : "calendar.badge.checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
                .foregroundColor(appearance.style == .fill ? .white : (fraction >= 1.0 ? .green : .primary))
                .shadow(color: appearance.style == .fill ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
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
        StaticConfiguration(kind: kind, provider: WatchPlanProvider()) { entry in
            PlanComplicationView(entry: entry)
        }
        .configurationDisplayName("Today's Plan")
        .description("Shows your training plan completion ring.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Steps / Distance Complications

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
    let appearance: ComplicationAppearance
    let mode: StepsDisplayMode
}

struct WatchStepsProvider: TimelineProvider {
    let mode: StepsDisplayMode

    private let store       = HKHealthStore()
    private let stepsKey    = "watch_cached_steps"
    private let distanceKey = "watch_cached_distance_km"
    private let cacheDateKey = "watch_cached_steps_date"

    /// Returns cached steps/distance only if the cache was written today.
    /// Prevents the complication from briefly showing yesterday's totals when
    /// `getSnapshot` is called before `getTimeline` has refreshed HK data.
    private func freshCachedSteps() -> (steps: Double, km: Double) {
        let d = sharedDefaults
        guard let stored = d.object(forKey: cacheDateKey) as? Date,
              Calendar.current.isDate(stored, inSameDayAs: Date()) else {
            return (0, 0)
        }
        return (d.double(forKey: stepsKey), d.double(forKey: distanceKey))
    }

    private func appearance(for settings: WatchComplicationUserSettings) -> ComplicationAppearance {
        switch mode {
        case .stepsOnly:    return settings.stepsOnly
        case .distanceOnly: return settings.distanceOnly
        case .both:         return settings.stepsAndDistance
        }
    }

    func placeholder(in context: Context) -> WatchStepsEntry {
        WatchStepsEntry(
            date: Date(), steps: 7342, distanceKm: 5.8,
            settings: .default,
            appearance: appearance(for: .default),
            mode: mode
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStepsEntry) -> Void) {
        let userSettings = readWatchComplicationSettings()
        let cached = freshCachedSteps()
        completion(WatchStepsEntry(
            date: Date(),
            steps: cached.steps,
            distanceKm: cached.km,
            settings: readWatchStepsSettings(),
            appearance: appearance(for: userSettings),
            mode: mode
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStepsEntry>) -> Void) {
        let settings     = readWatchStepsSettings()
        let userSettings = readWatchComplicationSettings()
        let app          = appearance(for: userSettings)
        Task {
            let steps = await querySum(type: HKQuantityType(.stepCount),               unit: .count())
            let km    = await querySum(type: HKQuantityType(.distanceWalkingRunning),  unit: .meter()) / 1000.0
            let d = sharedDefaults
            d.set(steps, forKey: stepsKey)
            d.set(km,    forKey: distanceKey)
            // Stamp the cache so a snapshot request after midnight doesn't
            // surface yesterday's totals before the next timeline refresh.
            d.set(Calendar.current.startOfDay(for: Date()), forKey: cacheDateKey)

            let now  = Date()
            let cal  = Calendar.current

            var entries: [WatchStepsEntry] = [
                WatchStepsEntry(
                    date: now, steps: steps, distanceKm: km,
                    settings: settings, appearance: app, mode: mode
                )
            ]
            // Midnight rollover: zero the displayed totals so the ring resets
            // even if no other reload fires overnight.
            if let nextMidnight = cal.nextDate(
                after: now,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) {
                entries.append(WatchStepsEntry(
                    date: nextMidnight, steps: 0, distanceKm: 0,
                    settings: settings, appearance: app, mode: mode
                ))
            }

            let next = cal.date(byAdding: .minute, value: 15, to: now) ?? now
            completion(Timeline(entries: entries, policy: .after(next)))
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

    private var settings: WatchStepsSettings   { entry.settings }
    private var mode: StepsDisplayMode         { entry.mode }
    private var appearance: ComplicationAppearance { entry.appearance }
    private var displayDist: Double {
        settings.distanceUnit == .km ? entry.distanceKm : entry.distanceKm / 1.60934
    }
    private var stepsFrac: Double { min(entry.steps / max(settings.stepsGoal, 1), 1.0) }
    private var distFrac:  Double { min(displayDist / max(settings.distanceGoal, 0.001), 1.0) }
    private var ringFrac:  Double { mode == .distanceOnly ? distFrac : stepsFrac }
    private var accentColor: Color { complicationColor(appearance.colorPreset, fraction: ringFrac) }

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
        ZStack {
            if appearance.style == .fill {
                ComplicationFillShape(fraction: ringFrac, color: accentColor, shape: appearance.shape)
            } else {
                Gauge(value: ringFrac) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(accentColor)
            }
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
            .foregroundColor(appearance.style == .fill ? .white : (ringFrac >= 1.0 ? .green : .primary))
            .shadow(color: appearance.style == .fill ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
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
                Gauge(value: stepsFrac) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(accentColor)
                Text("Goal: \(fmt(settings.stepsGoal)) steps").font(.system(size: 10)).foregroundColor(.secondary)

            case .distanceOnly:
                HStack(spacing: 4) {
                    Image(systemName: "location.fill").font(.system(size: 11, weight: .semibold)).foregroundColor(accentColor)
                    Text("Distance").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(String(format: "%.2f", displayDist) + " " + settings.distanceUnit.rawValue)
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundColor(distFrac >= 1.0 ? .green : .primary)
                }
                Gauge(value: distFrac) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(accentColor)
                Text("Goal: \(String(format: "%.1f", settings.distanceGoal)) \(settings.distanceUnit.rawValue)").font(.system(size: 10)).foregroundColor(.secondary)

            case .both:
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk").font(.system(size: 10, weight: .semibold)).foregroundColor(accentColor)
                    Text(fmt(entry.steps)).font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundColor(stepsFrac >= 1.0 ? .green : .primary)
                    Spacer()
                    Text("/ \(fmt(settings.stepsGoal))").font(.system(size: 10)).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "location.fill").font(.system(size: 10, weight: .semibold)).foregroundColor(accentColor)
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
    let appearance: ComplicationAppearance
}

struct WatchWaterProvider: TimelineProvider {
    private let store = HKHealthStore()

    func placeholder(in context: Context) -> WatchWaterEntry {
        WatchWaterEntry(date: Date(), todayOz: 40, goalOz: 64, unit: "oz", appearance: .defaultWater)
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchWaterEntry) -> Void) {
        completion(WatchWaterEntry(
            date: Date(),
            todayOz: readWaterTodayOz(),
            goalOz: readWaterGoalOz(),
            unit: readWaterUnit(),
            appearance: readWatchComplicationSettings().water
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWaterEntry>) -> Void) {
        let appearance = readWatchComplicationSettings().water
        Task {
            let oz = await queryWaterOz()
            let now = Date()
            let cal = Calendar.current

            var entries: [WatchWaterEntry] = [
                WatchWaterEntry(date: now, todayOz: oz, goalOz: readWaterGoalOz(), unit: readWaterUnit(), appearance: appearance)
            ]
            // Midnight rollover: zero the displayed total so the complication
            // resets correctly even if no app/widget reload happens overnight.
            if let nextMidnight = cal.nextDate(
                after: now,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) {
                entries.append(WatchWaterEntry(
                    date: nextMidnight, todayOz: 0,
                    goalOz: readWaterGoalOz(), unit: readWaterUnit(),
                    appearance: appearance
                ))
            }
            let next = cal.date(byAdding: .minute, value: 15, to: now) ?? now
            completion(Timeline(entries: entries, policy: .after(next)))
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

    private var appearance: ComplicationAppearance { entry.appearance }
    private var fillFraction: Double { min(entry.todayOz / max(entry.goalOz, 1), 1.0) }
    private var accentColor: Color { complicationColor(appearance.colorPreset, fraction: fillFraction) }

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
            if appearance.style == .fill {
                ComplicationFillShape(fraction: fillFraction, color: accentColor, shape: appearance.shape)
            } else {
                Gauge(value: fillFraction) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(accentColor)
            }
            VStack(spacing: 0) {
                Image(systemName: "drop.fill").font(.system(size: 10, weight: .semibold))
                Text(shortLabel).font(.system(size: 10, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundColor(appearance.style == .fill ? .white : accentColor)
            .shadow(color: appearance.style == .fill ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
        }
        .containerBackground(.background, for: .widget)
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Gauge(value: fillFraction) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(accentColor)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill").font(.system(size: 11, weight: .semibold))
                    Text("Water").font(.system(size: 11, weight: .bold))
                }.foregroundColor(accentColor)
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
