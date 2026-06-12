////
////  PlanComplicationView.swift
////  ExtendWatch
////
////  Views for the Plan Ring complication families:
////    • .accessoryCircular  — gauge ring showing % complete
////    • .accessoryRectangular — item list (first 3 items)
////

import WidgetKit
import SwiftUI

// MARK: - Plan Complication View

struct PlanComplicationView: View {
    var entry: WatchPlanEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    // MARK: Circular — gauge ring

    private var completedCount: Int {
        entry.snapshot.items.filter { $0.isCompleted }.count
    }

    private var totalCount: Int {
        entry.snapshot.items.count
    }

    private var fraction: Double {
        guard totalCount > 0 else { return entry.snapshot.isRestDay ? 1.0 : 0.0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var circularView: some View {
        ZStack {
            // Background gauge ring
            Gauge(value: fraction) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(entry.snapshot.isRestDay ? .green : .blue)

            if entry.snapshot.isRestDay {
                VStack(spacing: 0) {
                    Image(systemName: "zzz")
                        .font(.system(size: 12, weight: .bold))
                    Text("Rest")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.green)
            } else if totalCount == 0 {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: fraction >= 1.0 ? "checkmark" : "calendar.badge.checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
                .foregroundColor(fraction >= 1.0 ? .green : .primary)
            }
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: Rectangular — item list

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 11, weight: .semibold))
                Text(entry.snapshot.planName ?? "Today's Plan")
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                Spacer()
                if !entry.snapshot.isRestDay && totalCount > 0 {
                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)

            if entry.snapshot.isRestDay {
                HStack(spacing: 4) {
                    Image(systemName: "zzz")
                        .font(.system(size: 10))
                    Text("Rest day")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            } else {
                ForEach(entry.snapshot.items.prefix(3), id: \.name) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                        Text(item.name)
                            .font(.system(size: 10))
                            .lineLimit(1)
                        Spacer()
                        if item.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget Declaration

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
