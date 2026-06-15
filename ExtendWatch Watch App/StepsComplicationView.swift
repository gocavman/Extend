////
////  StepsComplicationView.swift
////  ExtendWatch
////
////  Three separate complications — Steps, Distance, Steps & Distance —
////  so the user picks which to add directly on the Watch face.
////

import WidgetKit
import SwiftUI

// MARK: - Module-level color helper (used by all complication views in this target)

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

// MARK: - Rising shape fill view (shared by all circular complications)

struct ComplicationFillShape: View {
    let fraction: Double
    let color: Color
    let shape: String

    var body: some View {
        ZStack {
            // Dim background outline of the shape
            Image(systemName: shape)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(color.opacity(0.15))

            // Rising fill clipped to the shape
            GeometryReader { geo in
                let fillH = geo.size.height * CGFloat(min(fraction, 1.0))
                Rectangle()
                    .fill(color.opacity(0.9))
                    .frame(height: max(0, fillH))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .mask(alignment: .center) {
                Image(systemName: shape)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

// MARK: - Shared format helpers

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
        let settings   = entry.settings
        let appearance = entry.appearance.stepsOnly
        let frac       = min(entry.steps / max(settings.stepsGoal, 1), 1.0)
        let label      = formattedSteps(entry.steps)
        let color      = complicationColor(appearance.colorPreset, fraction: frac)

        ZStack {
            if appearance.style == .fill {
                ComplicationFillShape(fraction: frac, color: color, shape: appearance.shape)
            } else {
                Gauge(value: frac) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(color)
            }

            VStack(spacing: 0) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(appearance.style == .fill ? .white : color)
            .shadow(
                color: appearance.style == .fill ? .black.opacity(0.4) : .clear,
                radius: 1, x: 0, y: 1
            )
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "extendwatch://steps")!)
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
        let settings   = entry.settings
        let appearance = entry.appearance.distanceOnly
        let dist       = displayDistance(entry.distanceKm, unit: settings.distanceUnit)
        let frac       = min(dist / max(settings.distanceGoal, 0.001), 1.0)
        let label      = formattedDistance(dist)
        let color      = complicationColor(appearance.colorPreset, fraction: frac)

        ZStack {
            if appearance.style == .fill {
                ComplicationFillShape(fraction: frac, color: color, shape: appearance.shape)
            } else {
                Gauge(value: frac) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(color)
            }

            VStack(spacing: 0) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(settings.distanceUnit.rawValue)
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundColor(appearance.style == .fill ? .white.opacity(0.75) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(appearance.style == .fill ? .white : color)
            .shadow(
                color: appearance.style == .fill ? .black.opacity(0.4) : .clear,
                radius: 1, x: 0, y: 1
            )
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "extendwatch://steps")!)
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
        let settings   = entry.settings
        let appearance = entry.appearance.stepsAndDistance
        // Ring/fill tracks steps; secondary line shows distance
        let frac       = min(entry.steps / max(settings.stepsGoal, 1), 1.0)
        let stepsLabel = formattedSteps(entry.steps)
        let dist       = displayDistance(entry.distanceKm, unit: settings.distanceUnit)
        let distLine   = "\(formattedDistance(dist)) \(settings.distanceUnit.rawValue)"
        let color      = complicationColor(appearance.colorPreset, fraction: frac)

        ZStack {
            if appearance.style == .fill {
                ComplicationFillShape(fraction: frac, color: color, shape: appearance.shape)
            } else {
                Gauge(value: frac) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(color)
            }

            VStack(spacing: 0) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 9, weight: .semibold))
                Text(stepsLabel)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(distLine)
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundColor(appearance.style == .fill ? .white.opacity(0.75) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(appearance.style == .fill ? .white : color)
            .shadow(
                color: appearance.style == .fill ? .black.opacity(0.4) : .clear,
                radius: 1, x: 0, y: 1
            )
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "extendwatch://steps")!)
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

// MARK: - Shape preview (open canvas to browse fill shapes without a device)

private let previewShapes: [(String, ComplicationColorPreset, Double)] = [
    ("circle.fill",                          .orange, 0.73),
    ("hexagon.fill",                         .orange, 0.60),
    ("octagon.fill",                         .cyan,   0.45),
    ("shield.fill",                          .purple, 0.80),
    ("seal.fill",                            .red,    0.55),
    ("pentagon.fill",                        .blue,   0.40),
    ("triangle.fill",                        .mint,   0.65),
    ("diamond.fill",                         .pink,   0.30),
    ("arrowshape.up.fill",                   .orange, 0.70),
    ("location.north.fill",                  .cyan,   0.50),
    ("oval.fill",                            .indigo, 0.85),
    ("oval.portrait.fill",                   .blue,   0.75),
    ("square.fill",                          .green,  1.00),
    ("rectangle.fill",                       .orange, 0.62),
    ("rectangle.portrait.fill",              .purple, 0.48),
    ("capsule.fill",                         .red,    0.35),
    ("peacesign",                            .mint,   0.90),
    ("sun.max.fill",                         .yellow, 0.68),
    ("button.roundedtop.horizontal.fill",    .cyan,   0.55),
    ("button.roundedbottom.horizontal.fill", .indigo, 0.42),
    ("button.angledtop.vertical.left.fill",  .orange, 0.77),
    ("button.angledtop.vertical.right.fill", .pink,   0.58),
]

#Preview("Fill Shapes") {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    ScrollView {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(previewShapes, id: \.0) { shape, preset, frac in
                let color = complicationColor(preset, fraction: frac)
                ZStack {
                    ComplicationFillShape(fraction: frac, color: color, shape: shape)
                    Text(shape.components(separatedBy: ".").first ?? shape)
                        .font(.system(size: 5))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .offset(y: 14)
                }
                .frame(width: 52, height: 52)
                .background(Color.black.opacity(0.85), in: Circle())
            }
        }
        .padding()
    }
    .background(.black)
    .preferredColorScheme(.dark)
}
