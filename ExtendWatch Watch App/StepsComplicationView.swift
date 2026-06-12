////
////  StepsComplicationView.swift
////  ExtendWatch
////
////  Complication view for the Steps/Distance Ring.
////  Supports .accessoryCircular only.
////

import WidgetKit
import SwiftUI

struct StepsComplicationView: View {
    var entry: WatchStepsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        circularView
            .containerBackground(.background, for: .widget)
    }

    // MARK: - Derived values

    private var settings: WatchStepsSettings { entry.settings }

    /// Primary ring fraction (0…1) and label string.
    private var primary: (fraction: Double, label: String, unit: String) {
        switch settings.mode {
        case .stepsOnly:
            let frac = min(entry.steps / max(settings.stepsGoal, 1), 1.0)
            return (frac, formattedSteps(entry.steps), "steps")
        case .distanceOnly:
            let dist = displayDistance(entry.distanceKm)
            let frac = min(dist / max(settings.distanceGoal, 0.001), 1.0)
            return (frac, formattedDistance(dist), settings.distanceUnit.rawValue)
        case .both:
            // Ring tracks steps; secondary line shows distance
            let frac = min(entry.steps / max(settings.stepsGoal, 1), 1.0)
            return (frac, formattedSteps(entry.steps), "steps")
        }
    }

    private var secondaryDistanceLine: String? {
        guard settings.mode == .both else { return nil }
        let dist = displayDistance(entry.distanceKm)
        return "\(formattedDistance(dist)) \(settings.distanceUnit.rawValue)"
    }

    private func displayDistance(_ km: Double) -> Double {
        settings.distanceUnit == .km ? km : km / 1.60934
    }

    private func formattedSteps(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(Int(v))
    }

    private func formattedDistance(_ v: Double) -> String {
        String(format: "%.1f", v)
    }

    // MARK: - Circular view

    private var circularView: some View {
        let p = primary
        return ZStack {
            Gauge(value: p.fraction) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(p.fraction >= 1.0 ? .green : .orange)

            VStack(spacing: 0) {
                if settings.mode == .stepsOnly {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10, weight: .semibold))
                } else if settings.mode == .distanceOnly {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .semibold))
                } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 9, weight: .semibold))
                }

                Text(p.label)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let sec = secondaryDistanceLine {
                    Text(sec)
                        .font(.system(size: 8).monospacedDigit())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundColor(p.fraction >= 1.0 ? .green : .primary)
        }
    }
}

// MARK: - Widget Declaration

struct StepsComplication: Widget {
    let kind = "ExtendWatch.StepsRing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStepsProvider()) { entry in
            StepsComplicationView(entry: entry)
        }
        .configurationDisplayName("Steps & Distance")
        .description("Shows today's steps or distance as a ring.")
        .supportedFamilies([.accessoryCircular])
    }
}
