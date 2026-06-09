////
////  ExtendWidget.swift
////  ExtendWidget
////
////  Today's Plan widget — shows the active training plan's items for today.
////  Supports small, medium, and large sizes.
////

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TodaysPlanProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodaysPlanEntry {
        TodaysPlanEntry(
            date: Date(),
            snapshot: WidgetPlanSnapshot(
                planName: "My Plan",
                date: Date(),
                items: [
                    WidgetPlanItem(name: "Morning Run", icon: "dumbbell.fill"),
                    WidgetPlanItem(name: "Pull-ups", icon: "figure.strengthtraining.traditional"),
                    WidgetPlanItem(name: "Breathing", icon: "waveform"),
                ],
                isRestDay: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysPlanEntry) -> Void) {
        completion(TodaysPlanEntry(date: Date(), snapshot: readWidgetSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysPlanEntry>) -> Void) {
        let snapshot = readWidgetSnapshot()
        let now = Date()
        // Generate one entry per hour for the next 12 hours so the widget
        // stays current even if the app isn't open. The main app also calls
        // WidgetCenter.shared.reloadAllTimelines() immediately whenever plan
        // data changes, so edits show up right away regardless of this schedule.
        var entries: [TodaysPlanEntry] = []
        for hour in 0..<12 {
            if let date = Calendar.current.date(byAdding: .hour, value: hour, to: now) {
                entries.append(TodaysPlanEntry(date: date, snapshot: snapshot))
            }
        }
        // After 12 hours, ask WidgetKit to reload (picks up any day rollover)
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Entry

struct TodaysPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPlanSnapshot
}

// MARK: - Widget View

struct TodaysPlanWidgetView: View {
    var entry: TodaysPlanEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        case .systemLarge:  largeView
        default:            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 13, weight: .semibold))
                Text("Today's Plan")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(.primary)

            if let name = entry.snapshot.planName {
                Text(name)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if entry.snapshot.isRestDay {
                Text("Rest day")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.snapshot.items.prefix(3), id: \.name) { item in
                    itemRow(item, iconSize: 10)
                }
                let overflow = entry.snapshot.items.count - 3
                if overflow > 0 {
                    Text("+\(overflow) more")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Today's Plan")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.primary)

                if let name = entry.snapshot.planName {
                    Text(name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(entry.date, style: .date)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 110, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                if entry.snapshot.isRestDay {
                    Spacer()
                    Text("Rest day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ForEach(entry.snapshot.items.prefix(4), id: \.name) { item in
                        itemRow(item, iconSize: 11)
                    }
                    let overflow = entry.snapshot.items.count - 4
                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    // MARK: Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("Today's Plan")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(entry.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)

            if let name = entry.snapshot.planName {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if entry.snapshot.isRestDay {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "moon.zzz")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Rest day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.snapshot.items, id: \.name) { item in
                    itemRow(item, iconSize: 13)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    // MARK: Shared row

    private func itemRow(_ item: WidgetPlanItem, iconSize: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: iconSize))
                .foregroundColor(.secondary)
                .frame(width: iconSize + 4)
            Text(item.name)
                .font(.system(size: iconSize + 1))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if item.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Widget Declaration (no @main — ExtendWidgetBundle is the entry point)

struct ExtendWidget: Widget {
    let kind: String = "ExtendWidget.TodaysPlan"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysPlanProvider()) { entry in
            TodaysPlanWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Plan")
        .description("See your active training plan items for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
