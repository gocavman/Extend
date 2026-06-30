////
////  WatchTimerRunnerView.swift
////  ExtendWatch
////
////  Wrist-side runner for a TimerConfig. Mirrors the iPhone's ActiveTimerView
////  at the level of detail the watch needs:
////
////  • Builds the same phase list (warmup → type-specific work/rest/round
////    progression → cooldown) as iPhone TimerModule's `buildPhaseList()`.
////  • Honors Count Up vs Count Down for Standard and AMRAP.
////  • Auto-advances count-down phases when their duration elapses, with a
////    final-3-second haptic warning and a phase-end notification haptic.
////  • Adds an AMRAP rounds-completed +/- stepper that ships back to the
////    iPhone log as notes.
////  • Pause/Resume freezes elapsed time; Skip moves between phases.
////  • Finish ends the live HKWorkoutSession and posts a typed timer log
////    (rounds completed, phase summary) back to the iPhone.
////

import SwiftUI
import WatchKit

struct WatchTimerRunnerView: View {

    @Bindable var manager: WatchWorkoutSessionManager
    let config: WatchTimerConfig

    @State private var phases: [Phase] = []
    @State private var phaseIndex: Int = 0
    /// Reference Date for the running phase. For count-down phases the runner
    /// computes `remaining = max(0, duration - (now - phaseStart))`; for
    /// count-up phases it computes `elapsed = now - phaseStart`.
    @State private var phaseStart: Date? = nil
    /// When non-nil the phase is paused and this holds the elapsed-so-far
    /// (in whole seconds) for the current phase.
    @State private var pausedElapsed: Int? = nil
    @State private var amrapRounds: Int = 0
    /// Tracks the last second at which the runner played the final-3-second
    /// warning haptic so it fires once per integer tick (3, 2, 1).
    @State private var lastWarningSecond: Int = -1
    @State private var hasAnnouncedPhase: Bool = false
    @State private var isFinishing: Bool = false
    @State private var showingCancelConfirm: Bool = false
    @State private var showingEarlyFinishConfirm: Bool = false
    @State private var isCompleted: Bool = false

    struct Phase: Equatable {
        let label: String
        /// 0 means the phase counts up indefinitely (Standard count-up only).
        let duration: Int
        var isCountUp: Bool { duration == 0 }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            content(now: context.date)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if phases.isEmpty {
                phases = WatchTimerRunnerView.buildPhases(for: config)
                phaseIndex = 0
                phaseStart = Date()
                pausedElapsed = nil
                lastWarningSecond = -1
                hasAnnouncedPhase = false
                isCompleted = false
                WKInterfaceDevice.current().play(.start)
            }
        }
        .alert("Discard Timer?", isPresented: $showingCancelConfirm) {
            Button("Keep Going", role: .cancel) { }
            Button("Discard", role: .destructive) { cancelSession() }
        } message: {
            Text("The session will be cancelled and no log will be saved.")
        }
        .alert("Finish Early?", isPresented: $showingEarlyFinishConfirm) {
            Button("Keep Going", role: .cancel) { }
            Button("Finish", role: .destructive) { finish() }
        } message: {
            Text("The timer hasn't finished. Save what you've done so far?")
        }
    }

    // MARK: - Body content

    @ViewBuilder
    private func content(now: Date) -> some View {
        if isCompleted {
            completedBody
        } else {
            runningBody(now: now)
        }
    }

    private func runningBody(now: Date) -> some View {
        let elapsed = elapsedSeconds(now: now)
        let phase = currentPhase
        let isPaused = pausedElapsed != nil
        // Side-effect: integer-second transitions that drive haptics + advance.
        let displaySeconds: Int = {
            guard let phase else { return 0 }
            if phase.isCountUp { return elapsed }
            return max(0, phase.duration - elapsed)
        }()
        return VStack(spacing: 4) {
            header()
            phaseLabel()
            timerNumber(seconds: displaySeconds, phase: phase, isPaused: isPaused)
            if config.type == "AMRAP" { amrapRow() }
            controls(isPaused: isPaused)
        }
        .onChange(of: elapsed) { _, newValue in
            handleTick(elapsed: newValue)
        }
    }

    private func header() -> some View {
        HStack(spacing: 6) {
            Text(config.name.isEmpty ? config.type : config.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if manager.heartRate > 0 {
                Label("\(Int(manager.heartRate))", systemImage: "heart.fill")
                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                    .foregroundColor(.red)
                    .labelStyle(.titleAndIcon)
            }
        }
        // The fullScreenCover host puts a system X dismiss button in the
        // top-left corner; without this inset the runner's title sits
        // directly under it.
        .padding(.leading, 32)
        .padding(.top, 2)
    }

    private func phaseLabel() -> some View {
        Text(currentPhase?.label ?? "Done")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(phaseLabelColor)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
    }

    private var phaseLabelColor: Color {
        guard let label = currentPhase?.label.lowercased() else { return .secondary }
        if label.contains("rest") { return .blue }
        if label.contains("warmup") { return .orange }
        if label.contains("cooldown") { return .green }
        return .secondary
    }

    private func timerNumber(seconds: Int, phase: Phase?, isPaused: Bool) -> some View {
        let color: Color = {
            if isPaused { return .orange }
            guard let phase, !phase.isCountUp, phase.duration > 0 else { return .primary }
            return seconds <= 3 ? .red : .primary
        }()
        return Text(formatTime(seconds))
            .font(.system(size: 36, weight: .bold).monospacedDigit())
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func amrapRow() -> some View {
        HStack(spacing: 10) {
            Button {
                if amrapRounds > 0 {
                    amrapRounds -= 1
                    WKInterfaceDevice.current().play(.click)
                }
            } label: {
                Image(systemName: "minus.circle.fill").font(.system(size: 22))
            }
            .buttonStyle(.plain)
            .disabled(amrapRounds == 0)

            VStack(spacing: 0) {
                Text("\(amrapRounds)")
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                Text("rounds")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 44)

            Button {
                amrapRounds += 1
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 22))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func controls(isPaused: Bool) -> some View {
        HStack(spacing: 4) {
            Button(action: previousPhase) {
                Image(systemName: "backward.end.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.gray)
            .disabled(phaseIndex == 0)

            if isPaused {
                Button(action: resume) {
                    Image(systemName: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
            } else {
                Button(action: pause) {
                    Image(systemName: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.orange)
            }

            Button(action: nextPhase) {
                Image(systemName: "forward.end.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.gray)
            .disabled(phaseIndex >= phases.count - 1)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .font(.system(size: 14, weight: .semibold))

        HStack(spacing: 4) {
            Button(role: .destructive) {
                showingCancelConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .tint(.red)

            Button {
                if phaseIndex < phases.count - 1 {
                    showingEarlyFinishConfirm = true
                } else {
                    finish()
                }
            } label: {
                if isFinishing {
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: "checkmark")
                        .frame(maxWidth: .infinity)
                }
            }
            .tint(.green)
            .disabled(isFinishing)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .font(.system(size: 14, weight: .semibold))
    }

    private var completedBody: some View {
        VStack(spacing: 6) {
            header()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundColor(.green)
            Text("Timer complete")
                .font(.system(size: 13, weight: .semibold))
            if config.type == "AMRAP" {
                Text("\(amrapRounds) rounds")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Button(role: .destructive, action: finish) {
                if isFinishing {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Finish")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isFinishing)
        }
    }

    // MARK: - State helpers

    private var currentPhase: Phase? {
        guard phaseIndex >= 0, phaseIndex < phases.count else { return nil }
        return phases[phaseIndex]
    }

    private func elapsedSeconds(now: Date) -> Int {
        if let paused = pausedElapsed { return paused }
        guard let start = phaseStart else { return 0 }
        return max(0, Int(now.timeIntervalSince(start)))
    }

    private func handleTick(elapsed: Int) {
        guard let phase = currentPhase, pausedElapsed == nil else { return }
        // Play the round/phase start haptic once per phase. Skipped via the
        // chevron buttons resets `hasAnnouncedPhase`.
        if !hasAnnouncedPhase {
            hasAnnouncedPhase = true
            // Don't double-play the opening .start that fires in onAppear.
            if elapsed > 0 || phaseIndex > 0 {
                WKInterfaceDevice.current().play(.start)
            }
        }
        // Final 3-second warning for count-down phases.
        if !phase.isCountUp, phase.duration > 0 {
            let remaining = phase.duration - elapsed
            if remaining > 0, remaining <= 3, remaining != lastWarningSecond {
                lastWarningSecond = remaining
                WKInterfaceDevice.current().play(.directionUp)
            }
            if remaining <= 0 {
                advancePhaseAuto()
            }
        }
    }

    // MARK: - Phase control

    private func pause() {
        guard pausedElapsed == nil else { return }
        let elapsed = elapsedSeconds(now: Date())
        pausedElapsed = elapsed
        phaseStart = nil
        WKInterfaceDevice.current().play(.stop)
    }

    private func resume() {
        guard let elapsed = pausedElapsed else { return }
        phaseStart = Date().addingTimeInterval(-TimeInterval(elapsed))
        pausedElapsed = nil
        lastWarningSecond = -1
        WKInterfaceDevice.current().play(.start)
    }

    private func nextPhase() {
        WKInterfaceDevice.current().play(.click)
        if phaseIndex < phases.count - 1 {
            phaseIndex += 1
            resetPhaseClock()
        }
    }

    private func previousPhase() {
        WKInterfaceDevice.current().play(.click)
        if phaseIndex > 0 {
            phaseIndex -= 1
            resetPhaseClock()
        }
    }

    private func advancePhaseAuto() {
        if phaseIndex < phases.count - 1 {
            phaseIndex += 1
            resetPhaseClock()
            WKInterfaceDevice.current().play(.notification)
        } else {
            // Last phase done.
            pausedElapsed = nil
            phaseStart = nil
            isCompleted = true
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func resetPhaseClock() {
        phaseStart = Date()
        pausedElapsed = nil
        lastWarningSecond = -1
        hasAnnouncedPhase = false
    }

    // MARK: - Finish / cancel

    private func cancelSession() {
        Task {
            await manager.cancel()
        }
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        let logName = manager.pendingLogName
        let activityTypeRaw = manager.activityTypeRaw
        let start = manager.startDate ?? Date()
        let notes = buildNotes()
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
                notes: notes,
                logType: "timer",
                activeCalories: activeCalories > 0 ? activeCalories : nil
            )
            await MainActor.run { isFinishing = false }
        }
    }

    private func buildNotes() -> String {
        var lines: [String] = []
        lines.append("Type: \(config.type)")
        if !config.name.isEmpty { lines.append("Name: \(config.name)") }
        lines.append("Duration: \(formatHuman(config.duration))")
        if config.type != "Standard" && config.type != "AMRAP" {
            lines.append("Rounds: \(config.rounds)")
        }
        if config.type == "Interval" || config.type == "Tabata" || config.type == "EMOM" {
            lines.append("Rest: \(formatHuman(config.restDuration))")
        }
        if config.warmupDuration > 0 {
            lines.append("Warmup: \(formatHuman(config.warmupDuration))")
        }
        if config.cooldownDuration > 0 {
            lines.append("Cooldown: \(formatHuman(config.cooldownDuration))")
        }
        if config.type == "Ladder" {
            lines.append("Ladder Step: \(config.ladderStep)s | Peak: \(config.ladderPeakRounds) rounds")
        }
        if config.type == "AMRAP" {
            lines.append("Rounds Completed: \(amrapRounds)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting

    private func formatTime(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private func formatHuman(_ s: Int) -> String {
        if s >= 60 {
            let m = s / 60
            let sec = s % 60
            return sec == 0 ? "\(m)m" : "\(m)m \(sec)s"
        }
        return "\(s)s"
    }

    // MARK: - Phase building (mirrors iPhone TimerModule.buildPhaseList)

    static func buildPhases(for config: WatchTimerConfig) -> [Phase] {
        var list: [Phase] = []

        if config.warmupDuration > 0 {
            list.append(Phase(label: "Warmup", duration: config.warmupDuration))
        }

        switch config.type {
        case "Standard":
            let isUp = config.direction == "Count Up"
            list.append(Phase(label: "Go", duration: isUp ? 0 : config.duration))

        case "Interval":
            let rounds = max(1, config.rounds)
            for r in 1...rounds {
                list.append(Phase(label: "Interval \(r) of \(rounds) — Work", duration: config.duration))
                if config.restDuration > 0 && r < rounds {
                    list.append(Phase(label: "Interval \(r) of \(rounds) — Rest", duration: config.restDuration))
                }
            }

        case "Tabata":
            let rounds = max(1, config.rounds)
            for r in 1...rounds {
                list.append(Phase(label: "Tabata \(r) of \(rounds) — Work", duration: config.duration))
                if r < rounds {
                    list.append(Phase(label: "Tabata \(r) of \(rounds) — Rest", duration: config.restDuration))
                }
            }

        case "EMOM":
            let rounds = max(1, config.rounds)
            for r in 1...rounds {
                list.append(Phase(label: "Minute \(r) of \(rounds)", duration: 60))
            }

        case "AMRAP":
            let isUp = config.direction == "Count Up"
            list.append(Phase(label: "AMRAP — Go!", duration: isUp ? 0 : config.duration))

        case "Ladder":
            let peak = max(1, config.ladderPeakRounds)
            var steps: [Int] = []
            for i in 1...peak { steps.append(i * config.ladderStep) }
            if peak > 1 {
                for i in stride(from: peak - 1, through: 1, by: -1) {
                    steps.append(i * config.ladderStep)
                }
            }
            let total = steps.count
            for (idx, dur) in steps.enumerated() {
                list.append(Phase(label: "Ladder \(idx + 1) of \(total) — \(dur)s", duration: dur))
                if config.restDuration > 0 && idx < total - 1 {
                    list.append(Phase(label: "Rest", duration: config.restDuration))
                }
            }

        default:
            // Unknown type from a newer iPhone build — fall back to a simple
            // count-down so the user still sees something useful.
            list.append(Phase(label: "Go", duration: max(0, config.duration)))
        }

        if config.cooldownDuration > 0 {
            list.append(Phase(label: "Cooldown", duration: config.cooldownDuration))
        }

        return list
    }
}
