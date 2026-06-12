////
////  WatchStepsView.swift
////  ExtendWatch
////
////  Full-screen live steps/distance view inside the Watch app.
////  Queries HealthKit on appear and on a 30-second timer for live updates.
////

import SwiftUI

struct WatchStepsView: View {

    @State private var steps: Double = 0
    @State private var distanceKm: Double = 0
    @State private var settings: WatchStepsSettings = readWatchStepsSettings()
    @State private var isLoading = true
    @State private var refreshTimer: Timer? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Large ring gauge
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: primaryFraction)
                        .stroke(
                            primaryFraction >= 1.0 ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: primaryFraction)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: primaryIcon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(primaryValueLabel)
                                .font(.system(size: 16, weight: .bold).monospacedDigit())
                            Text(primaryUnitLabel)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(primaryFraction >= 1.0 ? .green : .primary)
                    }
                }
                .frame(width: 110, height: 110)

                // Goal line
                if !isLoading {
                    Text("Goal: \(goalLabel)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    // Secondary metric (shown in .both mode)
                    if settings.mode == .both {
                        Divider()
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(secondaryDistanceLabel)
                                .font(.system(size: 12).monospacedDigit())
                            Spacer()
                            Text("of \(String(format: "%.1f", settings.distanceGoal)) \(settings.distanceUnit.rawValue)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData(); startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Derived values

    private var displayDistanceKm: Double { distanceKm }
    private var displayDistanceMiles: Double { distanceKm / 1.60934 }
    private var displayDistance: Double {
        settings.distanceUnit == .km ? displayDistanceKm : displayDistanceMiles
    }

    private var primaryFraction: Double {
        switch settings.mode {
        case .stepsOnly:
            return min(steps / max(settings.stepsGoal, 1), 1.0)
        case .distanceOnly:
            return min(displayDistance / max(settings.distanceGoal, 0.001), 1.0)
        case .both:
            return min(steps / max(settings.stepsGoal, 1), 1.0)
        }
    }

    private var primaryIcon: String {
        switch settings.mode {
        case .distanceOnly: return "location.fill"
        default:            return "figure.walk"
        }
    }

    private var primaryValueLabel: String {
        switch settings.mode {
        case .stepsOnly: return stepsLabel(steps)
        case .distanceOnly: return String(format: "%.2f", displayDistance)
        case .both: return stepsLabel(steps)
        }
    }

    private var primaryUnitLabel: String {
        switch settings.mode {
        case .stepsOnly: return "steps"
        case .distanceOnly: return settings.distanceUnit.rawValue
        case .both: return "steps"
        }
    }

    private var goalLabel: String {
        switch settings.mode {
        case .stepsOnly: return stepsLabel(settings.stepsGoal) + " steps"
        case .distanceOnly: return String(format: "%.1f", settings.distanceGoal) + " " + settings.distanceUnit.rawValue
        case .both: return stepsLabel(settings.stepsGoal) + " steps"
        }
    }

    private var secondaryDistanceLabel: String {
        String(format: "%.2f", displayDistance) + " " + settings.distanceUnit.rawValue
    }

    private func stepsLabel(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(Int(v))
    }

    // MARK: - Data loading

    private func loadData() {
        isLoading = true
        Task { @MainActor in
            steps       = await WatchHealthKit.shared.todaySteps()
            distanceKm  = await WatchHealthKit.shared.todayDistanceKm()
            settings    = readWatchStepsSettings()
            isLoading   = false
        }
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            loadData()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
