////
////  WatchWaterView.swift
////  ExtendWatch
////
////  Full-screen water tracking view in the Watch app.
////  Ring at top, % + oz labels inside, quick-add buttons, Custom uses Digital Crown.
////

import SwiftUI
import WidgetKit

struct WatchWaterView: View {

    @State private var todayOz: Double = 0
    @State private var goalOz: Double = 64
    @State private var unit: String = "oz"
    @State private var isLoading = true
    @State private var refreshTimer: Timer? = nil
    @State private var showCustomEntry = false
    @State private var customOzDouble: Double = 12

    private let appGroupID = "group.com.cavanmannenbach.extend"
    private var waterColor: Color { Color(red: 0.2, green: 0.55, blue: 1.0) }
    private var fillFraction: Double { min(todayOz / max(goalOz, 1), 1.0) }
    private var percentText: String { "\(Int(fillFraction * 100))%" }

    var body: some View {
        VStack(spacing: 8) {
            // Fill ring
            ZStack {
                Circle()
                    .stroke(waterColor.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fillFraction)
                    .stroke(
                        fillFraction >= 1.0 ? Color.green : waterColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: fillFraction)

                if isLoading {
                    ProgressView().scaleEffect(0.6)
                } else {
                    VStack(spacing: 1) {
                        Text(percentText)
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundColor(fillFraction >= 1.0 ? .green : waterColor)
                        Text("\(displayAmount(todayOz)) \(unit)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(width: 86, height: 86)

            if !isLoading {
                // +4 / +6 / +8 quick-add row
                HStack(spacing: 6) {
                    quickAddButton(oz: 4)
                    quickAddButton(oz: 6)
                    quickAddButton(oz: 8)
                }

                // Custom amount via Digital Crown
                Button {
                    customOzDouble = 12
                    showCustomEntry = true
                } label: {
                    Text("Custom")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(waterColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .onAppear { loadData(); startTimer() }
        .onDisappear { stopTimer() }
        .onReceive(NotificationCenter.default.publisher(for: .watchWaterDataUpdated)) { _ in
            loadData()
        }
        .sheet(isPresented: $showCustomEntry) {
            customEntrySheet
        }
    }

    // MARK: - Quick-add button

    private func quickAddButton(oz: Double) -> some View {
        Button {
            addWater(oz: oz)
        } label: {
            Text("+\(Int(oz))")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(waterColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom entry sheet (tap +/- or use Digital Crown)

    private var customEntrySheet: some View {
        VStack(spacing: 10) {
            Text("Add Water")
                .font(.headline)

            HStack(spacing: 14) {
                Button {
                    if customOzDouble > 1 { customOzDouble -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(waterColor)
                }
                .buttonStyle(.plain)

                Text("\(Int(customOzDouble.rounded()))")
                    .font(.system(size: 32, weight: .bold).monospacedDigit())
                    .foregroundColor(waterColor)
                    .frame(minWidth: 52)
                    .focusable()
                    .digitalCrownRotation(
                        $customOzDouble,
                        from: 1,
                        through: 100,
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )

                Button {
                    if customOzDouble < 100 { customOzDouble += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(waterColor)
                }
                .buttonStyle(.plain)
            }

            Text("oz")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Add \(Int(customOzDouble.rounded())) oz") {
                addWater(oz: customOzDouble.rounded())
                showCustomEntry = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(waterColor, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }

    // MARK: - Data management

    private func addWater(oz: Double) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        todayOz += oz
        defaults.set(todayOz, forKey: "water_today_oz")
        appendPendingLog(oz: oz, defaults: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWatch.Water")
        WatchConnectivityBridge.shared.sendWaterLog(oz: oz, date: Date())
    }

    private func appendPendingLog(oz: Double, defaults: UserDefaults) {
        struct PendingLog: Codable { let oz: Double; let date: Date }
        let key = "water_pending_logs"
        var pending: [PendingLog] = []
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PendingLog].self, from: data) {
            pending = decoded
        }
        pending.append(PendingLog(oz: oz, date: Date()))
        if let encoded = try? JSONEncoder().encode(pending) {
            defaults.set(encoded, forKey: key)
        }
    }

    private func loadData() {
        isLoading = true
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        goalOz = readWaterGoalOz()
        unit   = readWaterUnit()
        Task { @MainActor in
            let hkOz = await WatchHealthKit.shared.todayWaterOz()
            todayOz = hkOz > 0 ? hkOz : (defaults.double(forKey: "water_today_oz"))
            isLoading = false
        }
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            loadData()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Display helpers

    private func displayAmount(_ oz: Double) -> String {
        if unit == "mL" {
            let ml = oz * 29.5735
            return String(format: "%.0f", ml)
        }
        return oz >= 10 ? String(format: "%.0f", oz) : String(format: "%.1f", oz)
    }
}
