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
    // Newer iPhone snapshots include these — older ones don't, so default
    // them on decode to keep complications working through the upgrade.
    let hkActivityTypeRaw: UInt?
    let logName: String?
    let kind: String?
    let sourceID: String?

    private enum CodingKeys: String, CodingKey {
        case name, icon, isCompleted, hkActivityTypeRaw, logName, kind, sourceID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        isCompleted = (try? c.decodeIfPresent(Bool.self, forKey: .isCompleted)) ?? false
        hkActivityTypeRaw = try? c.decodeIfPresent(UInt.self, forKey: .hkActivityTypeRaw)
        logName = try? c.decodeIfPresent(String.self, forKey: .logName)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        sourceID = try? c.decodeIfPresent(String.self, forKey: .sourceID)
    }

    // Convenience init for the in-extension placeholder timeline entries.
    init(name: String, icon: String, isCompleted: Bool) {
        self.name = name
        self.icon = icon
        self.isCompleted = isCompleted
        self.hkActivityTypeRaw = nil
        self.logName = nil
        self.kind = nil
        self.sourceID = nil
    }
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
    var libraryShape: String = ""

    var stepsColor: String = ""
    var distanceColor: String = ""
    var stepsAndDistanceColor: String = ""
    var waterColor: String = ""
    var planColor: String = ""
    var libraryColor: String = ""

    var stepsTextColor: String = ""
    var distanceTextColor: String = ""
    var stepsAndDistanceTextColor: String = ""
    var waterTextColor: String = ""
    var planTextColor: String = ""
    var libraryTextColor: String = ""

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
    /// Stored as the ".fill" SF symbol name; we display its outline variant for the
    /// visible border so the center stays empty enough to read text drawn on top.
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
        case "heart.fill":    return 0.82
        case "star.fill":     return 0.78
        case "diamond.fill":  return 0.92
        case "seal.fill":     return 0.92
        default:              return 1.0
        }
    }

    /// "heart.fill" → "heart". Used for the visible outline so text drawn on top
    /// is legible inside the empty middle.
    private var outlineSymbol: String {
        shape.hasSuffix(".fill") ? String(shape.dropLast(5)) : shape
    }

    var body: some View {
        ZStack {
            // Background: dim outline always visible (the unfilled portion).
            Image(systemName: outlineSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.primary.opacity(0.3))

            // Foreground: bright outline + soft interior fill, masked to the
            // current fill height so the silhouette brightens from the bottom
            // up as the value approaches the goal.
            GeometryReader { geo in
                ZStack {
                    Image(systemName: shape)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.primary.opacity(0.28))
                    Image(systemName: outlineSymbol)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.primary)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: max(0, geo.size.height * CGFloat(min(fraction, 1.0))))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
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
    let textColor: String
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
            color: "",
            textColor: ""
        )
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchPlanEntry) -> Void) {
        let settings = readWatchComplicationShapeSettings()
        completion(WatchPlanEntry(
            date: Date(),
            snapshot: readTodayPlanSnapshot(),
            shape: settings.planShape,
            color: settings.planColor,
            textColor: settings.planTextColor
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlanEntry>) -> Void) {
        let todaySnapshot = readTodayPlanSnapshot()
        let multiday = readMultiDaySnapshots()
        let settings = readWatchComplicationShapeSettings()
        let shape = settings.planShape
        let color = settings.planColor
        let textColor = settings.planTextColor
        let now = Date()
        let cal = Calendar.current

        // Resolve the right snapshot for any given calendar day so entries
        // that cross midnight automatically swap to the new day's plan.
        func snapshot(for date: Date) -> WidgetPlanSnapshot {
            if let match = multiday.first(where: { cal.isDate($0.date, inSameDayAs: date) }) {
                return match
            }
            if cal.isDate(date, inSameDayAs: Date()) { return todaySnapshot }
            return WidgetPlanSnapshot(planName: todaySnapshot.planName, date: date, items: [], isRestDay: true)
        }

        var entries: [WatchPlanEntry] = []
        // Hourly entries across the next 24 hours — each picks its own day's snapshot.
        for hour in 0..<24 {
            if let d = cal.date(byAdding: .hour, value: hour, to: now) {
                entries.append(WatchPlanEntry(date: d, snapshot: snapshot(for: d), shape: shape, color: color, textColor: textColor))
            }
        }
        // Explicit midnight entry guarantees the rollover lands exactly at 00:00.
        if let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            entries.append(WatchPlanEntry(date: nextMidnight, snapshot: snapshot(for: nextMidnight), shape: shape, color: color, textColor: textColor))
            entries.sort { $0.date < $1.date }
        }

        // Reload aggressively so the watch picks up iPhone-side plan changes
        // (e.g. logging a workout) quickly, even if an explicit push gets
        // dropped or deferred by the complication budget.
        let refreshAt = cal.date(byAdding: .minute, value: 30, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshAt)))
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
    private var shapeTint: Color? { complicationColor(entry.color) }
    private var textTint: Color? { complicationColor(entry.textColor) ?? shapeTint }
    /// Show a checkmark under the label on rest days and once every planned
    /// activity for the day is logged. Both states represent "done for the
    /// day" and should read identically at a glance.
    private var showCheckmark: Bool {
        entry.snapshot.isRestDay || (totalCount > 0 && completedCount >= totalCount)
    }

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
                    .applyTint(shapeTint)
            } else {
                Gauge(value: fraction) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .applyTint(shapeTint)
            }

            VStack(spacing: 0) {
                // Shrink the label a touch when the checkmark is shown so the
                // stacked pair doesn't crowd the gauge ring.
                Text(entry.snapshot.isRestDay ? "Rest" : "\(completedCount)/\(totalCount)")
                    .font(.system(size: showCheckmark ? 15 : 17, weight: .bold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .applyTint(textTint)
                if showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .applyTint(textTint)
                }
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = entry.snapshot.planName {
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if entry.snapshot.isRestDay {
                Text("Rest Day").font(.title3.weight(.semibold)).applyTint(textTint)
            } else if totalCount > 0 {
                Text("\(completedCount) of \(totalCount) done")
                    .font(.title3.weight(.semibold))
                    .applyTint(textTint)
            } else {
                Text("No activities").font(.title3).foregroundStyle(.secondary)
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

// MARK: - Library Complication

/// Total number of activities (workouts + exercises + timers + voice
/// trainers) the user has logged today. iPhone writes this on every plan /
/// log refresh; the date stamp lets the widget zero out a stale value if
/// yesterday's count survives into the next day without a refresh.
private func readTodayLogCount() -> Int {
    let date = sharedDefaults.object(forKey: "today_log_count_date") as? Date
    guard let date, Calendar.current.isDate(date, inSameDayAs: Date()) else { return 0 }
    return sharedDefaults.integer(forKey: "today_log_count")
}

struct WatchLibraryEntry: TimelineEntry {
    let date: Date
    let doneToday: Int
    let shape: String
    let color: String
    let textColor: String
}

struct WatchLibraryProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchLibraryEntry {
        WatchLibraryEntry(date: Date(), doneToday: 3, shape: "", color: "", textColor: "")
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchLibraryEntry) -> Void) {
        let settings = readWatchComplicationShapeSettings()
        completion(WatchLibraryEntry(
            date: Date(),
            doneToday: readTodayLogCount(),
            shape: settings.libraryShape,
            color: settings.libraryColor,
            textColor: settings.libraryTextColor
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchLibraryEntry>) -> Void) {
        let now = Date()
        let cal = Calendar.current
        let settings = readWatchComplicationShapeSettings()
        let shape = settings.libraryShape
        let color = settings.libraryColor
        let textColor = settings.libraryTextColor
        var entries: [WatchLibraryEntry] = [
            WatchLibraryEntry(date: now, doneToday: readTodayLogCount(), shape: shape, color: color, textColor: textColor)
        ]
        // Snap the count back to zero exactly at midnight so the wrist
        // doesn't show yesterday's total in the morning before iPhone
        // pushes a fresh refresh.
        if let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            entries.append(WatchLibraryEntry(date: nextMidnight, doneToday: 0, shape: shape, color: color, textColor: textColor))
        }
        let refreshAt = cal.date(byAdding: .minute, value: 30, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshAt)))
    }
}

struct LibraryComplicationView: View {
    var entry: WatchLibraryEntry
    @Environment(\.widgetFamily) var family

    private var shapeTint: Color? { complicationColor(entry.color) }
    private var textTint: Color? { complicationColor(entry.textColor) ?? shapeTint }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangularView.containerBackground(.background, for: .widget)
            default: circularView.containerBackground(.background, for: .widget)
            }
        }
        .widgetURL(URL(string: "extendwatch://library")!)
    }

    private var circularView: some View {
        ZStack {
            // Library has no natural progress metric, so the optional shape
            // renders fully filled — purely decorative, matches the visual
            // language of the other circular complications without inventing
            // a fake daily target.
            if !entry.shape.isEmpty {
                ComplicationFillShape(fraction: 1.0, shape: entry.shape)
                    .applyTint(shapeTint)
            }
            VStack(spacing: 0) {
                Text("Extend")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .applyTint(textTint)
                Text("\(entry.doneToday) done")
                    .font(.system(size: 11).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .applyTint(textTint)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Extend")
                .font(.system(size: 15, weight: .bold))
                .applyTint(textTint)
            Text("\(entry.doneToday) done today")
                .font(.caption2)
                .applyTint(textTint)
        }
    }
}

struct LibraryComplication: Widget {
    let kind = "ExtendWatch.Library"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchLibraryProvider()) { entry in
            LibraryComplicationView(entry: entry)
        }
        .configurationDisplayName("Extend")
        .description("Shortcut to the Extend library with today's activity count")
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
    let textColor: String
}

struct WatchWaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchWaterEntry {
        WatchWaterEntry(date: Date(), todayOz: 48, goalOz: 64, unit: "oz", shape: "", color: "", textColor: "")
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchWaterEntry) -> Void) {
        let settings = readWatchComplicationShapeSettings()
        completion(WatchWaterEntry(
            date: Date(),
            todayOz: readWaterTodayOz(),
            goalOz: readWaterGoalOz(),
            unit: readWaterUnit(),
            shape: settings.waterShape,
            color: settings.waterColor,
            textColor: settings.waterTextColor
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWaterEntry>) -> Void) {
        let now = Date()
        let cal = Calendar.current
        let settings = readWatchComplicationShapeSettings()
        let shape = settings.waterShape
        let color = settings.waterColor
        let textColor = settings.waterTextColor

        var entries: [WatchWaterEntry] = []
        for hour in 0..<6 {
            if let d = cal.date(byAdding: .hour, value: hour, to: now) {
                entries.append(WatchWaterEntry(
                    date: d,
                    todayOz: readWaterTodayOz(),
                    goalOz: readWaterGoalOz(),
                    unit: readWaterUnit(),
                    shape: shape,
                    color: color,
                    textColor: textColor
                ))
            }
        }

        if let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            entries.append(WatchWaterEntry(date: nextMidnight, todayOz: 0, goalOz: readWaterGoalOz(), unit: readWaterUnit(), shape: shape, color: color, textColor: textColor))
        }

        // Reload at least every 30 minutes so the watch isn't stuck on a stale value
        // when iPhone-pushed updates fail to deliver.
        let refreshAt = cal.date(byAdding: .minute, value: 30, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshAt)))
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
        return entry.todayOz >= 10 ? String(format: "%.0f", entry.todayOz) : String(format: "%.0f", entry.todayOz)
    }
    private var shapeTint: Color? { complicationColor(entry.color) }
    private var textTint: Color? { complicationColor(entry.textColor) ?? shapeTint }

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
                    .applyTint(shapeTint)
            } else {
                Gauge(value: fraction) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .applyTint(shapeTint)
            }

            VStack(spacing: 0) {
                Text(displayValue)
                    .font(.system(size: 19, weight: .bold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .applyTint(textTint)
                Text(entry.unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    // Nudge the unit label up against the bottom of the value
                    // — the bold 19pt digits leave a noticeable leading gap
                    // below their baseline, which made the pair look bottom-
                    // weighted inside the circular dial.
                    .padding(.top, -4)
            }
            // Slight downward nudge to keep the value+unit pair visually
            // centered inside the gauge ring (the bold digits read high).
            .offset(y: 1)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Water")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text("\(displayValue) \(entry.unit)")
                .font(.title2.weight(.semibold).monospacedDigit())
                .applyTint(textTint)
            Text("of \(Int(entry.goalOz)) \(entry.unit)")
                .font(.caption)
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
    let textColor: String
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
            settings: .default, shape: "", color: "", textColor: "", mode: mode
        )
    }

    private func styles(for shapes: WatchComplicationShapeSettings) -> (shape: String, color: String, textColor: String) {
        switch mode {
        case .stepsOnly:    return (shapes.stepsShape,            shapes.stepsColor,            shapes.stepsTextColor)
        case .distanceOnly: return (shapes.distanceShape,         shapes.distanceColor,         shapes.distanceTextColor)
        case .both:         return (shapes.stepsAndDistanceShape, shapes.stepsAndDistanceColor, shapes.stepsAndDistanceTextColor)
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStepsEntry) -> Void) {
        let cached = freshCachedSteps()
        let s = styles(for: readWatchComplicationShapeSettings())
        completion(WatchStepsEntry(
            date: Date(),
            steps: cached.steps,
            distanceKm: cached.km,
            settings: readWatchStepsSettings(),
            shape: s.shape,
            color: s.color,
            textColor: s.textColor,
            mode: mode
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStepsEntry>) -> Void) {
        let settings = readWatchStepsSettings()
        let s = styles(for: readWatchComplicationShapeSettings())

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
                    settings: settings, shape: s.shape, color: s.color, textColor: s.textColor, mode: mode
                )
            ]

            if let nextMidnight = cal.nextDate(
                after: now,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) {
                entries.append(WatchStepsEntry(
                    date: nextMidnight, steps: 0, distanceKm: 0,
                    settings: settings, shape: s.shape, color: s.color, textColor: s.textColor, mode: mode
                ))
            }

            // Reload every 10 minutes so live HK values and midnight rollover stay current.
            let next = cal.date(byAdding: .minute, value: 10, to: now) ?? now
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
    private var shapeTint: Color? { complicationColor(entry.color) }
    private var textTint: Color? { complicationColor(entry.textColor) ?? shapeTint }

    // Truncate (don't round) to one decimal so a value like 4.88 displays
    // as "4.8" rather than "4.9" — otherwise the complication can briefly
    // imply the goal was hit a step or two before it actually was.
    private func fmt(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "%.1fk", floor(v / 100) / 10)
        }
        return String(Int(v))
    }
    private func fmtDist(_ v: Double) -> String {
        String(format: "%.1f", floor(v * 10) / 10)
    }

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
                    .applyTint(shapeTint)
            } else {
                Gauge(value: ringFrac) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .applyTint(shapeTint)
            }

            VStack(spacing: 0) {
                switch mode {
                case .stepsOnly:
                    Text(fmt(entry.steps))
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .applyTint(textTint)
                case .distanceOnly:
                    Text(fmtDist(displayDist))
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .applyTint(textTint)
                    Text(settings.distanceUnit.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                case .both:
                    // 13pt + 10pt (down from 14/11) leaves enough margin
                    // that a 5-digit step value or 3-digit distance won't
                    // butt up against the circular complication's edge ring.
                    // The distance now uses the same tint as the step count
                    // so the pair reads as one value, not value + label.
                    Text(fmt(entry.steps))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .applyTint(textTint)
                    Text("\(fmtDist(displayDist))\(settings.distanceUnit.rawValue)")
                        .font(.system(size: 10).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .applyTint(textTint)
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
                    Text("Steps").font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text(fmt(entry.steps))
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .applyTint(textTint)
                }
                Gauge(value: stepsFrac) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .applyTint(shapeTint)
                Text("Goal: \(fmt(settings.stepsGoal)) steps")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

            case .distanceOnly:
                HStack(spacing: 4) {
                    Text("Distance").font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text("\(fmtDist(displayDist)) \(settings.distanceUnit.rawValue)")
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .applyTint(textTint)
                }
                Gauge(value: distFrac) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .applyTint(shapeTint)
                Text("Goal: \(fmtDist(settings.distanceGoal)) \(settings.distanceUnit.rawValue)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

            case .both:
                HStack(spacing: 4) {
                    Text(fmt(entry.steps))
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .applyTint(textTint)
                    Spacer()
                    Text("/ \(fmt(settings.stepsGoal))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Text("\(fmtDist(displayDist)) \(settings.distanceUnit.rawValue)")
                        .font(.system(size: 15).monospacedDigit())
                        .applyTint(textTint)
                    Spacer()
                    Text("/ \(fmtDist(settings.distanceGoal))")
                        .font(.system(size: 12))
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
