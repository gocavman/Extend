////
////  WaterComplicationView.swift
////  ExtendWatch
////
////  Watch complication showing today's water intake as a circular ring or fill shape.
////  Tapping it opens the Water tab in the Watch app.
////

import WidgetKit
import SwiftUI

// MARK: - Complication View

struct WaterComplicationView: View {
    var entry: WatchWaterEntry
    @Environment(\.widgetFamily) var family

    private var appearance: ComplicationAppearance { entry.appearance.water }
    private var fillFraction: Double { min(entry.todayOz / max(entry.goalOz, 1), 1.0) }
    private var accentColor: Color { complicationColor(appearance.colorPreset, fraction: fillFraction) }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rectangularView
            default:
                circularView
            }
        }
        .widgetURL(URL(string: "extendwatch://water")!)
    }

    // MARK: Circular

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
                Image(systemName: "drop.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(shortLabel)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(appearance.style == .fill ? .white : accentColor)
            .shadow(
                color: appearance.style == .fill ? .black.opacity(0.4) : .clear,
                radius: 1, x: 0, y: 1
            )
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: Rectangular (always uses gauge style)

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Gauge(value: fillFraction) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(accentColor)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Water")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(accentColor)
                Text("\(shortLabel) \(entry.unit) today")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.secondary)
                Text("\(Int(fillFraction * 100))% of goal")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundColor(fillFraction >= 1.0 ? .green : .primary)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: Helpers

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
        .description("Shows today's water intake. Tap to open Extend.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
