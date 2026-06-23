////
////  WatchStepsView.swift
////  ExtendWatch
////
////  Full-screen live steps/distance view inside the Watch app.
////  Shows one large nested ring: orange outer ring for steps, cyan inner ring
////  for distance. Text in the middle reports both values.
////  Queries HealthKit on appear and on a 30-second timer for live updates.
////

import SwiftUI
import WidgetKit

private let appGroupID = "group.com.cavanmannenbach.extend"
private var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

struct WatchStepsView: View {

    @Environment(\.scenePhase) private var scenePhase
    @State private var steps: Double = 0
    @State private var distanceKm: Double = 0
    @State private var settings: WatchStepsSettings = readWatchStepsSettings()
    @State private var isLoading = true
    @State private var refreshTimer: Timer? = nil

    private let outerRingSize: CGFloat = 150
    private let outerRingWidth: CGFloat = 10
    private let innerRingSize: CGFloat = 112
    private let innerRingWidth: CGFloat = 9

    var body: some View {
        VStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .padding(.top, 24)
            } else {
                nestedRings

                HStack(spacing: 6) {
                    Text("/ \(stepsLabel(settings.stepsGoal))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text("/ \(String(format: "%.1f", settings.distanceGoal)) \(settings.distanceUnit.rawValue)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
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

    // MARK: - Nested rings

    private var stepsTint: Color { stepsFraction >= 1.0 ? .green : .orange }
    private var distanceTint: Color { distanceFraction >= 1.0 ? .green : .cyan }

    private var nestedRings: some View {
        ZStack {
            // Outer (steps) ring
            Circle()
                .stroke(Color.orange.opacity(0.2), lineWidth: outerRingWidth)
                .frame(width: outerRingSize, height: outerRingSize)
            Circle()
                .trim(from: 0, to: stepsFraction)
                .stroke(stepsTint, style: StrokeStyle(lineWidth: outerRingWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: outerRingSize, height: outerRingSize)
                .animation(.easeOut(duration: 0.4), value: stepsFraction)

            // Inner (distance) ring
            Circle()
                .stroke(Color.cyan.opacity(0.2), lineWidth: innerRingWidth)
                .frame(width: innerRingSize, height: innerRingSize)
            Circle()
                .trim(from: 0, to: distanceFraction)
                .stroke(distanceTint, style: StrokeStyle(lineWidth: innerRingWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: innerRingSize, height: innerRingSize)
                .animation(.easeOut(duration: 0.4), value: distanceFraction)

            // Centered readout — steps on top, distance below
            VStack(spacing: 2) {
                Text(stepsLabel(steps))
                    .font(.system(size: 26, weight: .bold).monospacedDigit())
                    .foregroundColor(stepsTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(String(format: "%.2f", displayDistance)) \(settings.distanceUnit.rawValue)")
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundColor(distanceTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: innerRingSize - 14)
        }
        .frame(width: outerRingSize, height: outerRingSize)
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
        // Truncate (not round) when collapsing into the "k" form so 9,961
        // doesn't display as "10.0k" when the user hasn't actually hit the
        // 10k milestone yet. Matches the watch complication's behavior.
        if v >= 1000 { return String(format: "%.1fk", floor(v / 100) / 10) }
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
            // The complication's own timeline only reloads every 10 minutes, so
            // it can show a value the user already sees as out-of-date in this
            // view. Push the freshest values into the shared cache and kick the
            // complications to redraw so the watch face stays in sync.
            pushFreshValuesToComplications(steps: steps, distanceKm: distanceKm)
        }
    }

    private func pushFreshValuesToComplications(steps: Double, distanceKm: Double) {
        let d = sharedDefaults
        let prevSteps = d.double(forKey: "cached_steps")
        let prevKm    = d.double(forKey: "cached_distance_km")
        d.set(steps, forKey: "cached_steps")
        d.set(distanceKm, forKey: "cached_distance_km")
        d.set(Calendar.current.startOfDay(for: Date()), forKey: "steps_cache_date")
        // Only nudge the widget pipeline when something actually changed —
        // avoids burning the watch's tight widget-reload budget on no-ops.
        if abs(steps - prevSteps) >= 1 || abs(distanceKm - prevKm) >= 0.005 {
            WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWatch.StepsRing")
            WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWatch.DistanceRing")
            WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWatch.StepsAndDistance")
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
