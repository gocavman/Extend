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
                // Steps ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: stepsFraction)
                        .stroke(
                            stepsFraction >= 1.0 ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: stepsFraction)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 14, weight: .semibold))
                            Text(stepsLabel(steps))
                                .font(.system(size: 16, weight: .bold).monospacedDigit())
                            Text("steps")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(stepsFraction >= 1.0 ? .green : .primary)
                    }
                }
                .frame(width: 110, height: 110)

                if !isLoading {
                    Text("Goal: \(stepsLabel(settings.stepsGoal)) steps")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Divider()

                    // Distance row
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", displayDistance) + " " + settings.distanceUnit.rawValue)
                            .font(.system(size: 12).monospacedDigit())
                        Spacer()
                        Text("of \(String(format: "%.1f", settings.distanceGoal)) \(settings.distanceUnit.rawValue)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
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

    private var displayDistance: Double {
        settings.distanceUnit == .km ? distanceKm : distanceKm / 1.60934
    }

    private var stepsFraction: Double {
        min(steps / max(settings.stepsGoal, 1), 1.0)
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
