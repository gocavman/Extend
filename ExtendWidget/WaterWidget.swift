////
////  WaterWidget.swift
////  ExtendWidget
////
////  iOS Water intake widget.
////  - Small: fill ring + today's oz + quick-add 4oz / 8oz buttons (iOS 17 AppIntent)
////  - Medium: fill ring + today's oz + quick-add buttons + 7-day bar graph
////

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - AppIntents for interactive buttons

@available(iOS 17.0, *)
struct AddWater4ozIntent: AppIntent {
    static var title: LocalizedStringResource = "Add 4 oz Water"
    static var description = IntentDescription("Logs 4 oz of water.")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend")
        let current = defaults?.double(forKey: "water_today_oz") ?? 0
        defaults?.set(current + 4, forKey: "water_today_oz")
        // Append a pending log entry for main app to pick up
        appendPendingWaterLog(oz: 4, defaults: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWidget.Water")
        return .result()
    }
}

@available(iOS 17.0, *)
struct AddWater6ozIntent: AppIntent {
    static var title: LocalizedStringResource = "Add 6 oz Water"
    static var description = IntentDescription("Logs 6 oz of water.")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend")
        let current = defaults?.double(forKey: "water_today_oz") ?? 0
        defaults?.set(current + 6, forKey: "water_today_oz")
        appendPendingWaterLog(oz: 6, defaults: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWidget.Water")
        return .result()
    }
}

@available(iOS 17.0, *)
struct AddWater8ozIntent: AppIntent {
    static var title: LocalizedStringResource = "Add 8 oz Water"
    static var description = IntentDescription("Logs 8 oz of water.")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend")
        let current = defaults?.double(forKey: "water_today_oz") ?? 0
        defaults?.set(current + 8, forKey: "water_today_oz")
        appendPendingWaterLog(oz: 8, defaults: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWidget.Water")
        return .result()
    }
}

/// Writes a pending water log entry to the App Group so the main app can import it on next launch.
private func appendPendingWaterLog(oz: Double, defaults: UserDefaults?) {
    guard let defaults else { return }
    let key = "water_pending_logs"
    struct PendingLog: Codable {
        let oz: Double
        let date: Date
    }
    var pending: [PendingLog] = []
    if let data = defaults.data(forKey: key),
       let decoded = try? JSONDecoder().decode([PendingLog].self, from: data) {
        pending = decoded
    }
    pending.append(PendingLog(oz: oz, date: Date()))
    if let encoded = try? JSONEncoder().encode(pending) {
        defaults.set(encoded, forKey: key)
    }
}

// MARK: - Timeline Provider

struct WaterEntry: TimelineEntry {
    let date: Date
    let todayOz: Double
    let goalOz: Double
    let unit: String
    /// Last 7 days (oldest first). Each entry is (dayOffset: Int, oz: Double).
    let weekTotals: [(offset: Int, oz: Double)]
}

struct WaterWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(
            date: Date(),
            todayOz: 48,
            goalOz: 64,
            unit: "oz",
            weekTotals: sampleWeekTotals()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        let now = Date()
        let cal = Calendar.current
        let entry = makeEntry()

        // Insert a midnight entry that zeroes today's total so the widget rolls
        // over correctly even if the app isn't opened before midnight.
        var entries: [WaterEntry] = [entry]
        if let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            entries.append(WaterEntry(
                date: nextMidnight,
                todayOz: 0,
                goalOz: entry.goalOz,
                unit: entry.unit,
                weekTotals: entry.weekTotals
            ))
        }

        let nextUpdate = cal.date(byAdding: .hour, value: 1, to: now) ?? now
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry() -> WaterEntry {
        WaterEntry(
            date: Date(),
            todayOz: readWaterTodayOz(),
            goalOz: readWaterGoalOz(),
            unit: readWaterUnit(),
            weekTotals: readWeekTotals()
        )
    }

    private func readWeekTotals() -> [(offset: Int, oz: Double)] {
        let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend")
        // Read daily totals stored as [[String: Any]] under "water_week_totals"
        // Fallback: return zeros if not yet written.
        guard let data = defaults?.data(forKey: "water_week_totals"),
              let arr = try? JSONDecoder().decode([[String: Double]].self, from: data)
        else {
            return (0..<7).map { (offset: $0, oz: 0) }
        }
        return arr.enumerated().map { (offset: $0.offset, oz: $0.element["oz"] ?? 0) }
    }

    private func sampleWeekTotals() -> [(offset: Int, oz: Double)] {
        zip(0..<7, [30.0, 48, 64, 52, 44, 60, 48]).map { (offset: $0, oz: $1) }
    }
}

// MARK: - Widget Views

struct WaterWidgetView: View {
    var entry: WaterEntry
    @Environment(\.widgetFamily) var family

    private var waterColor: Color { Color(red: 0.2, green: 0.55, blue: 1.0) }
    private var fillFraction: Double { min(entry.todayOz / max(entry.goalOz, 1), 1.0) }

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(waterColor)
                Text("Water")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
            }

            // Fill ring + amount
            ZStack {
                Circle()
                    .stroke(waterColor.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fillFraction)
                    .stroke(waterColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(percentText)
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundColor(waterColor)
                    Text("\(displayAmount(entry.todayOz)) \(entry.unit)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 70, height: 70)

            // Quick-add buttons
            if #available(iOS 17.0, *) {
                HStack(spacing: 4) {
                    Button(intent: AddWater4ozIntent()) {
                        Text("+4oz")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    Button(intent: AddWater6ozIntent()) {
                        Text("+6oz")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    Button(intent: AddWater8ozIntent()) {
                        Text("+8oz")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(percentText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerBackground(.background, for: .widget)
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 14) {
            // Left: ring + amount + buttons
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(waterColor)
                    Text("Water")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }

                ZStack {
                    Circle()
                        .stroke(waterColor.opacity(0.2), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: fillFraction)
                        .stroke(waterColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(percentText)
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundColor(waterColor)
                        Text("\(displayAmount(entry.todayOz)) \(entry.unit)")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 64, height: 64)

                if #available(iOS 17.0, *) {
                    HStack(spacing: 4) {
                        Button(intent: AddWater4ozIntent()) {
                            Text("+4oz")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        Button(intent: AddWater6ozIntent()) {
                            Text("+6oz")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        Button(intent: AddWater8ozIntent()) {
                            Text("+8oz")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(percentText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 110)

            // Right: 7-day bar chart
            VStack(alignment: .leading, spacing: 4) {
                Text("7-Day Trend")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                WeekBarChart(totals: entry.weekTotals, goalOz: entry.goalOz, color: waterColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    // MARK: Helpers

    private var percentText: String {
        "\(Int((fillFraction * 100).rounded()))%"
    }

    private func displayAmount(_ oz: Double) -> String {
        if entry.unit == "mL" {
            return String(format: "%.0f", oz * 29.5735)
        }
        if oz >= 10 {
            return String(format: "%.0f", oz)
        }
        return String(format: "%.1f", oz)
    }
}

// MARK: - 7-day bar chart (widget-local)

struct WeekBarChart: View {
    let totals: [(offset: Int, oz: Double)]
    let goalOz: Double
    let color: Color

    private var cal: Calendar { .current }

    var body: some View {
        GeometryReader { geo in
            let maxOz = max(totals.map(\.oz).max() ?? 1, goalOz)
            let barW = (geo.size.width - CGFloat(totals.count - 1) * 3) / CGFloat(totals.count)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(totals, id: \.offset) { item in
                    let frac = CGFloat(item.oz / max(maxOz, 1))
                    let metGoal = item.oz >= goalOz
                    // Reserve ~18pt for the value label above + 10pt for the day label below
                    let barH = max(frac * (geo.size.height - 28), 2)
                    let isToday = item.offset == totals.count - 1

                    VStack(spacing: 1) {
                        Spacer(minLength: 0)
                        Text(item.oz >= 1 ? String(format: "%.0f", item.oz) : "")
                            .font(.system(size: 6, weight: .semibold).monospacedDigit())
                            .foregroundColor(isToday ? color : .primary.opacity(0.65))
                            .frame(width: barW)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(metGoal ? color : color.opacity(0.35))
                            .frame(width: barW, height: barH)
                            .overlay(
                                isToday
                                    ? RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1)
                                    : nil
                            )
                        Text(dayLabel(item.offset))
                            .font(.system(size: 7, weight: .medium).monospacedDigit())
                            .foregroundColor(isToday ? color : .primary.opacity(0.65))
                            .frame(width: barW)
                    }
                }
            }
        }
    }

    private func dayLabel(_ offset: Int) -> String {
        // offset 0 = 6 days ago, offset 6 = today
        let daysAgo = (totals.count - 1) - offset
        guard let d = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "E"
        return String(fmt.string(from: d).prefix(1))
    }
}

// MARK: - Widget Declaration

struct WaterWidget: Widget {
    let kind: String = "ExtendWidget.Water"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterWidgetProvider()) { entry in
            WaterWidgetView(entry: entry)
        }
        .configurationDisplayName("Water Intake")
        .description("Track your daily water intake and quickly log water from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
