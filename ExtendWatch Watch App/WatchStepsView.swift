////
////  WatchStepsView.swift
////  ExtendWatch
////
////  Full-screen live steps/distance view inside the Watch app.
////  Shows two rings side by side: orange for steps, cyan for distance.
////  Queries HealthKit on appear and on a 30-second timer for live updates.
////

import SwiftUI

struct WatchStepsView: View {

    @Environment(\.scenePhase) private var scenePhase
    @State private var steps: Double = 0
    @State private var distanceKm: Double = 0
    @State private var settings: WatchStepsSettings = readWatchStepsSettings()
    @State private var isLoading = true
    @State private var refreshTimer: Timer? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 24)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        // Steps ring (orange)
                        ringColumn(
                            fraction: stepsFraction,
                            color: .orange,
                            icon: "figure.walk",
                            valueText: stepsLabel(steps),
                            unitText: "steps",
                            goalText: "/ \(stepsLabel(settings.stepsGoal))"
                        )

                        // Distance ring (cyan)
                        ringColumn(
                            fraction: distanceFraction,
                            color: .cyan,
                            icon: "location.fill",
                            valueText: String(format: "%.2f", displayDistance),
                            unitText: settings.distanceUnit.rawValue,
                            goalText: "/ \(String(format: "%.1f", settings.distanceGoal)) \(settings.distanceUnit.rawValue)"
                        )
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData(); startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: scenePhase) { _, phase in
            // .onAppear doesn't fire when the watch app returns from background,
            // so HK values would otherwise stay frozen at last-foreground state
            // (a yesterday-vs-today rollover problem).
            if phase == .active { loadData() }
        }
    }

    // MARK: - Ring column

    private func ringColumn(
        fraction: Double,
        color: Color,
        icon: String,
        valueText: String,
        unitText: String,
        goalText: String
    ) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        fraction >= 1.0 ? Color.green : color,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: fraction)

                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(valueText)
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                    Text(unitText)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(fraction >= 1.0 ? .green : color)
            }
            .frame(width: 72, height: 72)

            Text(goalText)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Derived values

    private var displayDistance: Double {
        settings.distanceUnit == .km ? distanceKm : distanceKm / 1.60934
    }

    private var stepsFraction: Double {
        min(steps / max(settings.stepsGoal, 1), 1.0)
    }

    private var distanceFraction: Double {
        min(displayDistance / max(settings.distanceGoal, 0.001), 1.0)
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
