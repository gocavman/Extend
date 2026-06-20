////
////  WatchWorkoutRunnerView.swift
////  ExtendWatch
////
////  Set-by-set runner shown during a blueprint-driven workout. Walks the
////  user through each exercise of the loaded WatchWorkoutBlueprint:
////  • Rep sets — Crown adjusts reps (and weight when the predefined target
////    has weight). "Log Set" records the set and advances.
////  • Timed sets — countdown timer with Start; auto-logs (reps: 0, weight:
////    predefined) when the timer reaches 0 and fires a notification haptic.
////  • Loops show a "Round N of M" subtitle (iPhone pre-expands rounds).
////  • After the last set of an exercise, "Next" advances to the next entry.
////  • "Stop" ends the session at any time and forwards the partial log to
////    the iPhone via WatchConnectivityBridge.sendCompletedLog.
////

import SwiftUI
import WatchKit

struct WatchWorkoutRunnerView: View {

    @Bindable var manager: WatchWorkoutSessionManager
    @State private var reps: Int = 0
    @State private var weight: Double = 0
    @State private var isFinishing: Bool = false
    /// Countdown anchor + duration for the active timed work set. `timerEndDate`
    /// drives the visible countdown via TimelineView; nil = not currently
    /// counting (either never started or paused).
    @State private var timerEndDate: Date? = nil
    @State private var timerDurationSeconds: Int = 0
    /// Seconds remaining when work paused, restored on resume. nil = not paused.
    @State private var timerPausedRemaining: Int? = nil
    /// Active auto-rest after a logged set. Chained from Tabata/Interval loops
    /// and explicit RestItems. Same Pause/Skip/Resume affordances as the work
    /// timer; when it expires we auto-advance to the next set/exercise (and
    /// auto-start the next work timer if it's timed too).
    @State private var restEndDate: Date? = nil
    @State private var restDurationSeconds: Int = 0
    @State private var restPausedRemaining: Int? = nil

    /// True when the user has completed at least the planned sets for the
    /// current exercise — UI swaps "Log Set" for "Next Exercise".
    private var isExerciseFinished: Bool {
        manager.loggedSetCount() >= manager.plannedSetCount()
    }

    /// True when the next set on the current exercise is timed.
    private var isCurrentSetTimed: Bool {
        (manager.nextPredefinedSet()?.timedSeconds ?? 0) > 0
    }

    /// True while a rest countdown is on the screen (running or paused).
    private var isResting: Bool {
        restEndDate != nil || restPausedRemaining != nil
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 4) {
                header(now: context.date)

                if let ex = manager.currentExercise() {
                    exerciseBody(ex, now: context.date)
                } else {
                    completedBody
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { syncFromPredefined() }
    }

    // MARK: - Header

    private func header(now: Date) -> some View {
        let start = manager.startDate ?? Date()
        let s = Int(now.timeIntervalSince(start))
        let m = (s % 3600) / 60
        let sec = s % 60
        return HStack(spacing: 6) {
            Text(String(format: "%02d:%02d", m, sec))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(.secondary)
            Spacer()
            if manager.heartRate > 0 {
                Label("\(Int(manager.heartRate))", systemImage: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
                    .labelStyle(.titleAndIcon)
            }
            if manager.activeEnergyKcal > 0 {
                Label("\(Int(manager.activeEnergyKcal))", systemImage: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Active exercise body

    private func exerciseBody(_ ex: WatchBlueprintExercise, now: Date) -> some View {
        let planned = manager.plannedSetCount()
        let logged = manager.loggedSetCount()
        let setNumber = min(logged + 1, max(planned, 1))
        let predefined = manager.nextPredefinedSet()
        let hasWeight = (predefined?.weight ?? 0) > 0

        return VStack(spacing: 4) {
            // Title block — exercise name + set count + optional Round N of M
            VStack(spacing: 0) {
                Text(ex.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 4) {
                    Text("Set \(setNumber) of \(max(planned, 1))")
                    if let r = ex.loopRound, let total = ex.loopTotalRounds {
                        Text("•")
                        Text("Round \(r) of \(total)")
                    } else if let r = ex.complexRound, let total = ex.complexTotalRounds {
                        Text("•")
                        Text("Round \(r) of \(total) (Complex)")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            if isResting {
                restBody(now: now)
            } else if isCurrentSetTimed {
                timedSetBody(now: now, predefined: predefined)
            } else {
                repSetBody(hasWeight: hasWeight)
            }
        }
    }

    // MARK: - Rest body

    private func restBody(now: Date) -> some View {
        let isRunning = restEndDate != nil
        let isPaused = restPausedRemaining != nil
        let remaining: Int = {
            if let paused = restPausedRemaining { return paused }
            guard let endDate = restEndDate else { return 0 }
            return max(0, Int(ceil(endDate.timeIntervalSince(now))))
        }()
        if isRunning, remaining <= 0 {
            DispatchQueue.main.async { handleRestCompletion() }
        }
        return VStack(spacing: 6) {
            Text("REST")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.blue)
            Text(formatSeconds(remaining))
                .font(.system(size: 32, weight: .bold).monospacedDigit())
                .foregroundColor(isPaused ? .orange : .primary)
            if isPaused {
                Button(action: resumeRest) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button(action: pauseRest) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            HStack(spacing: 6) {
                Button(role: .destructive, action: finish) {
                    if isFinishing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "stop.fill")
                    }
                }
                .tint(.red)
                .disabled(isFinishing)
                Button(action: skipRest) {
                    Text("Skip")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(.blue)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Rep set UI

    private func repSetBody(hasWeight: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                stepper(
                    label: "Reps",
                    value: reps,
                    formatted: "\(reps)",
                    range: 0...50,
                    step: 1
                ) { newValue in
                    reps = max(0, min(50, newValue))
                }
                if hasWeight {
                    stepper(
                        label: "Weight",
                        value: Int(weight),
                        formatted: weight.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(weight))"
                            : String(format: "%.1f", weight),
                        range: 0...500,
                        step: 5
                    ) { newValue in
                        weight = Double(max(0, min(500, newValue)))
                    }
                }
            }
            controlRow(primaryLabel: "Log Set", primaryTint: .green, onPrimary: logSet)
        }
    }

    // MARK: - Timed set UI

    private func timedSetBody(now: Date, predefined: WatchPredefinedSet?) -> some View {
        let totalSeconds = predefined?.timedSeconds ?? 0
        let isRunning = timerEndDate != nil
        let isPaused = timerPausedRemaining != nil
        let remaining: Int = {
            if let paused = timerPausedRemaining { return paused }
            guard let endDate = timerEndDate else { return totalSeconds }
            return max(0, Int(ceil(endDate.timeIntervalSince(now))))
        }()
        // Auto-log + haptic when the countdown reaches 0.
        if isRunning, remaining <= 0 {
            DispatchQueue.main.async { handleTimedSetCompletion() }
        }
        return VStack(spacing: 6) {
            Text(formatSeconds(remaining))
                .font(.system(size: 32, weight: .bold).monospacedDigit())
                .foregroundColor(isPaused ? .orange : (isRunning ? .primary : .secondary))
            if !isRunning && !isPaused {
                Button(action: startTimedSet) {
                    Text("Start \(totalSeconds)s")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else if isPaused {
                Button(action: resumeTimedSet) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button(action: pauseTimedSet) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            controlRow(
                primaryLabel: "Skip",
                primaryTint: .blue,
                onPrimary: skipTimedSet,
                showPrimary: isRunning || isPaused
            )
        }
    }

    private var completedBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)
            Text("Workout complete")
                .font(.system(size: 13, weight: .semibold))
            Button(role: .destructive, action: finish) {
                if isFinishing {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Finish")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .disabled(isFinishing)
        }
        .padding(.top, 4)
    }

    // MARK: - Shared control row (stop + Log/Next)

    @ViewBuilder
    private func controlRow(primaryLabel: String,
                            primaryTint: Color,
                            onPrimary: @escaping () -> Void,
                            showPrimary: Bool = true) -> some View {
        HStack(spacing: 6) {
            Button(role: .destructive, action: finish) {
                if isFinishing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "stop.fill")
                }
            }
            .tint(.red)
            .disabled(isFinishing)

            if isExerciseFinished {
                Button(action: advanceExercise) {
                    Text("Next")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(.blue)
            } else if showPrimary {
                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(primaryTint)
            }
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Crown-controlled stepper

    private func stepper(label: String,
                         value: Int,
                         formatted: String,
                         range: ClosedRange<Int>,
                         step: Int,
                         onChange: @escaping (Int) -> Void) -> some View {
        let binding = Binding<Double>(
            get: { Double(value) },
            set: { onChange(Int($0.rounded())) }
        )
        return VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(formatted)
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundColor(.primary)
                .focusable()
                .digitalCrownRotation(
                    binding,
                    from: Double(range.lowerBound),
                    through: Double(range.upperBound),
                    by: Double(step),
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func syncFromPredefined() {
        let predefined = manager.nextPredefinedSet()
        reps = predefined?.reps ?? 0
        weight = predefined?.weight ?? 0
        // Cancel any in-flight timer/rest so a new set's countdown isn't
        // carrying a stale end date or paused-remaining value.
        timerEndDate = nil
        timerPausedRemaining = nil
        timerDurationSeconds = predefined?.timedSeconds ?? 0
        restEndDate = nil
        restPausedRemaining = nil
        restDurationSeconds = 0
    }

    private func logSet() {
        // Snapshot the just-logged set's rest BEFORE logSet — manager advances
        // its index so nextPredefinedSet() will then return the FOLLOWING set.
        let justLoggedRest = manager.nextPredefinedSet()?.restSecondsAfter ?? 0
        manager.logSet(reps: reps, weight: weight)
        if justLoggedRest > 0 {
            startRest(seconds: justLoggedRest)
        } else {
            prepareNextStep()
        }
    }

    private func advanceExercise() {
        manager.advanceToNextExercise()
        syncFromPredefined()
    }

    private func startTimedSet() {
        let seconds = manager.nextPredefinedSet()?.timedSeconds ?? 0
        guard seconds > 0 else { return }
        timerDurationSeconds = seconds
        timerEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        timerPausedRemaining = nil
        WKInterfaceDevice.current().play(.start)
    }

    private func pauseTimedSet() {
        guard let endDate = timerEndDate else { return }
        let remaining = max(0, Int(ceil(endDate.timeIntervalSince(Date()))))
        timerPausedRemaining = remaining
        timerEndDate = nil
        WKInterfaceDevice.current().play(.stop)
    }

    private func resumeTimedSet() {
        guard let remaining = timerPausedRemaining, remaining > 0 else { return }
        timerEndDate = Date().addingTimeInterval(TimeInterval(remaining))
        timerPausedRemaining = nil
        WKInterfaceDevice.current().play(.start)
    }

    private func skipTimedSet() {
        // Treat skip as completion (counts the set so the user can move on).
        handleTimedSetCompletion()
    }

    private func handleTimedSetCompletion() {
        // Skip can fire from either running or paused state — accept both.
        guard timerEndDate != nil || timerPausedRemaining != nil else { return }
        timerEndDate = nil
        timerPausedRemaining = nil
        let predefined = manager.nextPredefinedSet()
        let pWeight = predefined?.weight ?? 0
        let restAfter = predefined?.restSecondsAfter ?? 0
        manager.logSet(reps: 0, weight: pWeight)
        WKInterfaceDevice.current().play(.notification)
        if restAfter > 0 {
            startRest(seconds: restAfter)
        } else {
            prepareNextStep()
        }
    }

    // MARK: - Rest control + chain

    private func startRest(seconds: Int) {
        restDurationSeconds = seconds
        restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        restPausedRemaining = nil
        WKInterfaceDevice.current().play(.directionUp)
    }

    private func pauseRest() {
        guard let endDate = restEndDate else { return }
        restPausedRemaining = max(0, Int(ceil(endDate.timeIntervalSince(Date()))))
        restEndDate = nil
        WKInterfaceDevice.current().play(.stop)
    }

    private func resumeRest() {
        guard let remaining = restPausedRemaining, remaining > 0 else { return }
        restEndDate = Date().addingTimeInterval(TimeInterval(remaining))
        restPausedRemaining = nil
        WKInterfaceDevice.current().play(.start)
    }

    private func skipRest() {
        guard restEndDate != nil || restPausedRemaining != nil else { return }
        restEndDate = nil
        restPausedRemaining = nil
        prepareNextStep()
    }

    private func handleRestCompletion() {
        guard restEndDate != nil else { return }
        restEndDate = nil
        restPausedRemaining = nil
        WKInterfaceDevice.current().play(.notification)
        prepareNextStep()
    }

    /// Called after a logged set + any rest. If the current exercise is done,
    /// advance to the next one. Then sync the stepper / countdown values from
    /// the new "next set" — and auto-start it when it's a timed work set
    /// (Tabata-style chain).
    private func prepareNextStep() {
        if manager.isWorkoutComplete() { return }
        if manager.loggedSetCount() >= manager.plannedSetCount() {
            manager.advanceToNextExercise()
        }
        let next = manager.nextPredefinedSet()
        reps = next?.reps ?? 0
        weight = next?.weight ?? 0
        timerDurationSeconds = next?.timedSeconds ?? 0
        if (next?.timedSeconds ?? 0) > 0 {
            startTimedSet()
        }
    }

    private func formatSeconds(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        if m > 0 { return String(format: "%d:%02d", m, sec) }
        return "\(sec)s"
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        let logName = manager.pendingLogName
        let activityTypeRaw = manager.activityTypeRaw
        let start = manager.startDate ?? Date()
        let exercises = manager.loggedExercisesForReport()
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
                exercises: exercises
            )
            await MainActor.run { isFinishing = false }
        }
    }
}
