////
////  WatchActiveWorkoutView.swift
////  ExtendWatch
////
////  Full-screen overlay shown while an HKWorkoutSession is collecting live
////  heart rate / calories on the watch. Two flavours:
////  • iPhone-driven session — read-only, the iPhone ends it.
////  • Watch-initiated session — shows a Finish button that ends the session
////    and forwards the resulting log back to the iPhone for storage.
////

import SwiftUI

struct WatchActiveWorkoutView: View {

    @Bindable var manager: WatchWorkoutSessionManager
    @State private var isFinishing: Bool = false

    var body: some View {
        // Multi-exercise blueprints get the set-by-set runner; voice trainers
        // get the round-based playback runner; timers get the phase-driven
        // runner; everything else falls back to the duration-only view.
        if manager.blueprint != nil {
            WatchWorkoutRunnerView(manager: manager)
        } else if let voice = manager.voiceConfig {
            WatchVoiceTrainerRunnerView(manager: manager, config: voice)
        } else if let timer = manager.timerConfig {
            WatchTimerRunnerView(manager: manager, config: timer)
        } else {
            simpleView
        }
    }

    private func elapsedLabel(at now: Date) -> String {
        guard let start = manager.startDate else { return "00:00" }
        let s = Int(now.timeIntervalSince(start))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private var simpleView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                Text(manager.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)

                Text(elapsedLabel(at: context.date))
                    .font(.system(size: 28, weight: .bold).monospacedDigit())
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    metric(
                        icon: "heart.fill",
                        color: .red,
                        value: manager.heartRate > 0 ? String(Int(manager.heartRate)) : "—",
                        unit: "BPM"
                    )
                    metric(
                        icon: "flame.fill",
                        color: .orange,
                        value: manager.activeEnergyKcal > 0 ? String(Int(manager.activeEnergyKcal)) : "—",
                        unit: "kcal"
                    )
                }

                Spacer(minLength: 0)

                if manager.isLocallyStarted {
                    Button(action: finish) {
                        if isFinishing {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Finish")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isFinishing)
                } else {
                    Text("Controlled from iPhone")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        // Capture log fields BEFORE end() — the manager clears its state on end.
        let logName = manager.pendingLogName
        let activityTypeRaw = manager.activityTypeRaw
        let start = manager.startDate ?? Date()
        let activeCalories = manager.activeEnergyKcal
        Task {
            let uuid = await manager.end()
            let endDate = Date()
            let duration = endDate.timeIntervalSince(start)
            WatchConnectivityBridge.shared.sendCompletedLog(
                name: logName,
                completedAt: endDate,
                duration: duration,
                hkActivityTypeRaw: activityTypeRaw,
                hkWorkoutUUID: uuid,
                activeCalories: activeCalories > 0 ? activeCalories : nil
            )
            await MainActor.run { isFinishing = false }
        }
    }

    private func metric(icon: String, color: Color, value: String, unit: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WatchActiveWorkoutView(manager: WatchWorkoutSessionManager.shared)
}
