////
////  StepsComplicationView.swift
////  ExtendWatch
////
////  Three separate complications — Steps, Distance, Steps & Distance —
////  so the user picks which to add directly on the Watch face.
////

import WidgetKit
import SwiftUI

// MARK: - Shared helpers

private func formattedSteps(_ v: Double) -> String {
    if v >= 1000 { return String(format: "%.1fk", v / 1000) }
    return String(Int(v))
}

private func formattedDistance(_ v: Double) -> String {
    String(format: "%.1f", v)
}

private func displayDistance(_ km: Double, unit: WatchDistanceUnit) -> Double {
    unit == .km ? km : km / 1.60934
}

// MARK: - Steps-only complication

struct StepsOnlyComplicationView: View {
    var entry: WatchStepsEntry

    var body: some View {
        let settings = entry.settings
        let frac = min(entry.steps / max(settings.stepsGoal, 1), 1.0)
        let label = formattedSteps(entry.steps)
        let color: Color = frac >= 1.0 ? .green : .orange

        ZStack {
            Gauge(value: frac) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(color)

            VStack(spacing: 0) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(color)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct StepsOnlyComplication: Widget {
    let kind = "ExtendWatch.StepsOnly"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider()) { entry in
            StepsOnlyComplicationView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Shows today's step count as a ring.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Distance-only complication

struct DistanceOnlyComplicationView: View {
    var entry: WatchStepsEntry

    var body: some View {
        let settings = entry.settings
        let dist = displayDistance(entry.distanceKm, unit: settings.distanceUnit)
        let frac = min(dist / max(settings.distanceGoal, 0.001), 1.0)
        let label = formattedDistance(dist)
        let color: Color = frac >= 1.0 ? .green : .orange

        ZStack {
            Gauge(value: frac) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(color)

            VStack(spacing: 0) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(settings.distanceUnit.rawValue)
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(color)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct DistanceOnlyComplication: Widget {
    let kind = "ExtendWatch.DistanceOnly"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider()) { entry in
            DistanceOnlyComplicationView(entry: entry)
        }
        .configurationDisplayName("Distance")
        .description("Shows today's walking/running distance as a ring.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Steps & Distance complication

struct StepsAndDistanceComplicationView: View {
    var entry: WatchStepsEntry

    var body: some View {
        let settings = entry.settings
        // Ring tracks steps; secondary line shows distance
        let frac = min(entry.steps / max(settings.stepsGoal, 1), 1.0)
        let stepsLabel = formattedSteps(entry.steps)
        let dist = displayDistance(entry.distanceKm, unit: settings.distanceUnit)
        let distLine = "\(formattedDistance(dist)) \(settings.distanceUnit.rawValue)"
        let color: Color = frac >= 1.0 ? .green : .orange

        ZStack {
            Gauge(value: frac) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(color)

            VStack(spacing: 0) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 9, weight: .semibold))
                Text(stepsLabel)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(distLine)
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(color)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct StepsAndDistanceComplication: Widget {
    let kind = "ExtendWatch.StepsAndDistance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider()) { entry in
            StepsAndDistanceComplicationView(entry: entry)
        }
        .configurationDisplayName("Steps & Distance")
        .description("Shows today's steps as a ring with distance below.")
        .supportedFamilies([.accessoryCircular])
    }
}
