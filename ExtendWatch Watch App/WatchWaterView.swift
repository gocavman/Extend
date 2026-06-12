////
////  WatchWaterView.swift
////  ExtendWatch
////
////  Full-screen water tracking view in the Watch app.
////  Shows fill ring, today's total, goal, and quick-add buttons.
////  Writes to App Group UserDefaults so the iOS app picks up widget-logged water.
////

import SwiftUI

struct WatchWaterView: View {

    @State private var todayOz: Double = 0
    @State private var goalOz: Double = 64
    @State private var unit: String = "oz"
    @State private var isLoading = true
    @State private var refreshTimer: Timer? = nil
    @State private var showCustomEntry = false
    @State private var customText: String = ""

    private let appGroupID = "group.com.cavanmannenbach.extend"
    private var waterColor: Color { Color(red: 0.2, green: 0.55, blue: 1.0) }
    private var fillFraction: Double { min(todayOz / max(goalOz, 1), 1.0) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
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
                        VStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(displayAmount(todayOz))
                                .font(.system(size: 16, weight: .bold).monospacedDigit())
                            Text(unit)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(fillFraction >= 1.0 ? .green : waterColor)
                    }
                }
                .frame(width: 110, height: 110)

                if !isLoading {
                    Text("Goal: \(displayAmount(goalOz)) \(unit)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Divider()

                    // Quick-add buttons
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            quickAddButton(oz: 4)
                            quickAddButton(oz: 8)
                        }
                        HStack(spacing: 8) {
                            quickAddButton(oz: 12)
                            quickAddButton(oz: 16)
                        }
                        Button {
                            customText = ""
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
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Water")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData(); startTimer() }
        .onDisappear { stopTimer() }
        .sheet(isPresented: $showCustomEntry) {
            customEntrySheet
        }
    }

    // MARK: - Quick-add button

    private func quickAddButton(oz: Double) -> some View {
        Button {
            addWater(oz: oz)
        } label: {
            Text("+\(Int(oz)) oz")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(waterColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom entry sheet

    private var customEntrySheet: some View {
        VStack(spacing: 12) {
            Text("Add Water")
                .font(.headline)

            // Preset custom amounts for Watch (no free-form keyboard on watchOS)
            ForEach([20.0, 24.0, 32.0], id: \.self) { oz in
                Button {
                    addWater(oz: oz)
                    showCustomEntry = false
                } label: {
                    Text("+\(Int(oz)) oz")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(waterColor)
                }
                .buttonStyle(.plain)
            }

            Button("Cancel") {
                showCustomEntry = false
            }
            .foregroundColor(.secondary)
            .font(.system(size: 12))
        }
        .padding()
    }

    // MARK: - Data management

    private func addWater(oz: Double) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        todayOz += oz
        defaults.set(todayOz, forKey: "water_today_oz")
        // Write a pending log for the iOS app to pick up
        appendPendingLog(oz: oz, defaults: defaults)
        // Reload water complication timeline
        WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWatch.Water")
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
            // Prefer HealthKit data; fall back to locally cached value
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

// Needed in Watch target (WidgetCenter is available in watchOS 7+)
import WidgetKit
