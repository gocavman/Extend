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
    @State private var customOzDouble: Double = 3

    private let appGroupID = "group.com.cavanmannenbach.extend"
    private var waterColor: Color { Color(red: 0.2, green: 0.55, blue: 1.0) }
    private var fillFraction: Double { min(todayOz / max(goalOz, 1), 1.0) }
    private var percentText: String { "\(Int(fillFraction * 100))%" }

    private let dropSize: CGFloat = 100

    var body: some View {
        VStack(spacing: 8) {
            // Droplet fill
            ZStack {
                // Background (empty portion)
                Image(systemName: "drop.fill")
                    .font(.system(size: dropSize))
                    .foregroundColor(waterColor.opacity(0.12))

                // Rising water fill masked to drop shape
                GeometryReader { geo in
                    let fillH = geo.size.height * CGFloat(fillFraction)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    fillFraction >= 1.0 ? Color.green.opacity(0.7) : waterColor.opacity(0.7),
                                    fillFraction >= 1.0 ? Color.green : waterColor
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(0, fillH))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .mask {
                    Image(systemName: "drop.fill")
                        .font(.system(size: dropSize))
                        .foregroundColor(.white)
                }
                .frame(width: dropSize, height: dropSize * 1.25)
                .animation(.easeInOut(duration: 0.6), value: fillFraction)

                if isLoading {
                    ProgressView().scaleEffect(0.6)
                } else {
                    VStack(spacing: 1) {
                        Text(percentText)
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                        Text("\(displayAmount(todayOz)) \(unit)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                    .offset(y: 8)
                }
            }
            .frame(width: dropSize, height: dropSize * 1.25)

            if !isLoading {
                // +4 / +6 / +8 quick-add row
                HStack(spacing: 6) {
                    quickAddButton(oz: 4)
                    quickAddButton(oz: 6)
                    quickAddButton(oz: 8)
                }

                // +12 / +16 / Custom quick-add row
                HStack(spacing: 6) {
                    quickAddButton(oz: 12)
                    quickAddButton(oz: 16)

                    Button {
                        let saved = UserDefaults(suiteName: appGroupID)?.double(forKey: "water_custom_last_oz") ?? 0
                        customOzDouble = saved > 0 ? saved : 3
                        showCustomEntry = true
                    } label: {
                        Text("Custom")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(waterColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(waterColor)
                    }
                    .buttonStyle(.plain)
                }
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

            Button {
                let oz = customOzDouble.rounded()
                UserDefaults(suiteName: appGroupID)?.set(oz, forKey: "water_custom_last_oz")
                addWater(oz: oz)
                showCustomEntry = false
            } label: {
                Text("Add")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(waterColor, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
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
