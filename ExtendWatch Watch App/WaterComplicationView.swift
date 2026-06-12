////
////  WaterComplicationView.swift
////  ExtendWatch
////
////  Watch complication showing today's water intake as a circular ring.
////  Tapping it opens the Water tab in the Watch app.
////

import WidgetKit
import SwiftUI

// MARK: - Complication View

struct WaterComplicationView: View {
    var entry: WatchWaterEntry

    private var waterColor: Color { Color(red: 0.2, green: 0.55, blue: 1.0) }
    private var fillFraction: Double { min(entry.todayOz / max(entry.goalOz, 1), 1.0) }

    var body: some View {
        ZStack {
            Gauge(value: fillFraction) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(fillFraction >= 1.0 ? .green : waterColor)

            VStack(spacing: 0) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(shortLabel)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(fillFraction >= 1.0 ? .green : waterColor)
        }
        .containerBackground(.background, for: .widget)
    }

    private var shortLabel: String {
        if entry.unit == "mL" {
            let ml = entry.todayOz * 29.5735
            if ml >= 1000 { return String(format: "%.1fL", ml / 1000) }
            return String(format: "%.0f", ml)
        }
        if entry.todayOz >= 10 { return String(format: "%.0f", entry.todayOz) }
        return String(format: "%.1f", entry.todayOz)
    }
}

// MARK: - Complication Widget Declaration

struct WaterComplication: Widget {
    let kind = "ExtendWatch.Water"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWaterProvider()) { entry in
            WaterComplicationView(entry: entry)
        }
        .configurationDisplayName("Water")
        .description("Shows today's water intake as a ring. Tap to open Extend.")
        .supportedFamilies([.accessoryCircular])
    }
}
