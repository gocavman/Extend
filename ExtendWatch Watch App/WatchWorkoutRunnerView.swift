////
////  WatchWorkoutRunnerView.swift
////  ExtendWatch
////
////  Set-by-set runner shown during a blueprint-driven workout. Two render
////  modes:
////  • Exercise mode — walks the user through a single exercise's predefined
////    sets. Reps + weight are picked via wheel pickers (Crown drives them
////    naturally). "Log Set" records the set and advances; timed sets show
////    a countdown that auto-logs when it hits 0; explicit rests get an
////    auto-rest countdown before the next set.
////  • Complex mode — shows every exercise in the complex on a single
////    screen with a shared per-round countdown. The user can tap any
////    exercise to adjust its reps/weight in a sheet. When the timer
////    expires (or "Next Round" is tapped), one set per exercise is
////    logged using the current values and the round counter advances.
////
////  Verbal countdown (3-2-1-Go between complex rounds + 5-second tail
////  on timed sets) is opt-in via WatchSettingsView.
////

import SwiftUI
import WatchKit
import AVFoundation

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
    /// Active auto-rest after a logged set.
    @State private var restEndDate: Date? = nil
    @State private var restDurationSeconds: Int = 0
    @State private var restPausedRemaining: Int? = nil
    /// Active complex round countdown. nil = paused / not started.
    @State private var complexEndDate: Date? = nil
    @State private var complexPausedRemaining: Int? = nil
    /// Last second we spoke during a countdown — prevents re-speaking the same
    /// second when the TimelineView fires more than once for the same value.
    @State private var lastSpokenSecond: Int = -1
    /// Identifier (complex exercise UUID) of the exercise the user is
    /// editing — drives the per-exercise picker sheet.
    @State private var editingComplexExerciseID: String? = nil

    /// True when the user has completed at least the planned sets for the
    /// current exercise — UI swaps "Log Set" for "Next Exercise".
    private var isExerciseFinished: Bool {
        manager.loggedSetCount() >= manager.plannedSetCount()
    }

    private var isCurrentSetTimed: Bool {
        (manager.nextPredefinedSet()?.timedSeconds ?? 0) > 0
    }

    private var isResting: Bool {
        restEndDate != nil || restPausedRemaining != nil
    }

    /// Shared speech engine — held on the view so ARC doesn't release it
    /// mid-utterance. Cheap to keep around even if speech is disabled.
    @State private var speech = SpeechBox()

    @AppStorage("watch_speech_enabled") private var speechEnabled: Bool = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 4) {
                header(now: context.date)

                if let item = manager.currentItem() {
                    switch item {
                    case .exercise(let ex):
                        exerciseBody(ex, now: context.date)
                    case .complex(let cx):
                        complexBody(cx, now: context.date)
                    }
                } else {
                    completedBody
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            syncFromPredefined()
            // Warm the audio engine immediately so the first audible speech
            // (round announcement or countdown tail) doesn't queue behind a
            // still-spinning pipeline and burst-play.
            if speechEnabled { speech.prime() }
        }
        .sheet(item: editingComplexBinding()) { editing in
            ComplexValueEditor(
                exercise: editing,
                initialReps: manager.complexValues[editing.id]?.reps ?? editing.predefinedSets.first?.reps ?? 0,
                initialWeight: manager.complexValues[editing.id]?.weight ?? editing.predefinedSets.first?.weight ?? 0,
                hasWeight: (editing.predefinedSets.first?.weight ?? 0) > 0,
                onSave: { newReps, newWeight in
                    manager.setComplexValue(forExerciseID: editing.id,
                                            reps: newReps, weight: newWeight)
                    editingComplexExerciseID = nil
                }
            )
        }
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

    // MARK: - Single-exercise body

    private func exerciseBody(_ ex: WatchBlueprintExercise, now: Date) -> some View {
        let planned = manager.plannedSetCount()
        let logged = manager.loggedSetCount()
        let setNumber = min(logged + 1, max(planned, 1))
        let predefined = manager.nextPredefinedSet()
        let hasWeight = (predefined?.weight ?? 0) > 0

        return VStack(spacing: 4) {
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

    // MARK: - Rep set UI (wheel pickers)

    private func repSetBody(hasWeight: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                wheelPicker(
                    label: "Reps",
                    selection: Binding(get: { reps }, set: { reps = $0 }),
                    values: Array(stride(from: 0, through: 50, by: 1))
                )
                if hasWeight {
                    wheelPicker(
                        label: "Weight",
                        selection: Binding(get: { Int(weight) }, set: { weight = Double($0) }),
                        values: Array(stride(from: 0, through: 500, by: 5))
                    )
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
        if isRunning, remaining <= 0 {
            DispatchQueue.main.async { handleTimedSetCompletion() }
        } else if isRunning {
            // Speak the 5-second tail.
            maybeSpeakTail(remaining)
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

    // MARK: - Complex body

    private func complexBody(_ cx: WatchBlueprintComplex, now: Date) -> some View {
        let totalSeconds = cx.intervalSeconds
        let isRunning = complexEndDate != nil
        let isPaused = complexPausedRemaining != nil
        let remaining: Int = {
            if let paused = complexPausedRemaining { return paused }
            guard let endDate = complexEndDate else { return totalSeconds }
            return max(0, Int(ceil(endDate.timeIntervalSince(now))))
        }()
        if isRunning, remaining <= 0 {
            DispatchQueue.main.async { handleComplexRoundExpiry() }
        } else if isRunning {
            maybeSpeakTail(remaining)
        }
        let textColor: Color = isPaused ? .orange : (isRunning && remaining <= 10 ? .red : .primary)
        return ScrollView {
            VStack(spacing: 6) {
                // Round + countdown header
                VStack(spacing: 0) {
                    Text("Round \(manager.complexRound) of \(cx.rounds)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(formatSeconds(remaining))
                        .font(.system(size: 30, weight: .bold).monospacedDigit())
                        .foregroundColor(textColor)
                }

                // Per-exercise rows
                VStack(spacing: 3) {
                    ForEach(cx.exercises, id: \.id) { ex in
                        complexRow(for: ex)
                    }
                }

                // Controls
                if !isRunning && !isPaused {
                    Button(action: startComplexRound) {
                        Text("Start Round")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else if isPaused {
                    Button(action: resumeComplexRound) {
                        Label("Resume", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button(action: pauseComplexRound) {
                        Label("Pause", systemImage: "pause.fill")
                            .font(.system(size: 12, weight: .semibold))
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
                    Button(action: completeComplexRoundManually) {
                        Text(manager.complexRound >= cx.rounds ? "Finish Complex" : "Next Round")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.blue)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func complexRow(for ex: WatchBlueprintExercise) -> some View {
        let current = manager.complexValues[ex.id]
            ?? WatchLoggedSet(reps: ex.predefinedSets.first?.reps ?? 0,
                              weight: ex.predefinedSets.first?.weight ?? 0)
        let hasWeight = (ex.predefinedSets.first?.weight ?? 0) > 0
        return Button { editingComplexExerciseID = ex.id } label: {
            HStack(spacing: 4) {
                Text(ex.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if hasWeight {
                    Text("\(current.reps)× \(formattedWeight(current.weight))")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                } else {
                    Text("\(current.reps) reps")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func editingComplexBinding() -> Binding<WatchBlueprintExercise?> {
        Binding(
            get: {
                guard let id = editingComplexExerciseID,
                      let cx = manager.currentComplex() else { return nil }
                return cx.exercises.first { $0.id == id }
            },
            set: { editingComplexExerciseID = $0?.id }
        )
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

    // MARK: - Shared control row

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

    // MARK: - Wheel picker

    private func wheelPicker(label: String,
                             selection: Binding<Int>,
                             values: [Int]) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Picker("", selection: selection) {
                ForEach(values, id: \.self) { v in
                    Text("\(v)")
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions (single exercise)

    private func syncFromPredefined() {
        let predefined = manager.nextPredefinedSet()
        reps = predefined?.reps ?? 0
        weight = predefined?.weight ?? 0
        timerEndDate = nil
        timerPausedRemaining = nil
        timerDurationSeconds = predefined?.timedSeconds ?? 0
        restEndDate = nil
        restPausedRemaining = nil
        restDurationSeconds = 0
        lastSpokenSecond = -1
    }

    private func logSet() {
        let justLoggedRest = manager.nextPredefinedSet()?.restSecondsAfter ?? 0
        manager.logSet(reps: reps, weight: weight)
        if justLoggedRest > 0 {
            startRest(seconds: justLoggedRest)
        } else {
            prepareNextStep()
        }
    }

    private func advanceExercise() {
        manager.advanceToNextItem()
        syncFromPredefined()
        // Newly-entered complex: nothing to seed locally — manager handles
        // its own complex value seeding.
    }

    private func startTimedSet() {
        let seconds = manager.nextPredefinedSet()?.timedSeconds ?? 0
        guard seconds > 0 else { return }
        timerDurationSeconds = seconds
        timerEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        timerPausedRemaining = nil
        lastSpokenSecond = -1
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

    private func skipTimedSet() { handleTimedSetCompletion() }

    private func handleTimedSetCompletion() {
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

    private func prepareNextStep() {
        if manager.isWorkoutComplete() { return }
        if manager.loggedSetCount() >= manager.plannedSetCount(),
           manager.currentExercise() != nil {
            manager.advanceToNextItem()
        }
        let next = manager.nextPredefinedSet()
        reps = next?.reps ?? 0
        weight = next?.weight ?? 0
        timerDurationSeconds = next?.timedSeconds ?? 0
        if (next?.timedSeconds ?? 0) > 0 {
            startTimedSet()
        }
    }

    // MARK: - Complex actions

    private func startComplexRound() {
        guard let cx = manager.currentComplex() else { return }
        complexEndDate = Date().addingTimeInterval(TimeInterval(cx.intervalSeconds))
        complexPausedRemaining = nil
        lastSpokenSecond = -1
        WKInterfaceDevice.current().play(.start)
        // Interrupt any tail-end countdown speech from the previous round
        // so the new round's announcement plays immediately.
        speech.speakNow("Round \(manager.complexRound). Go.")
    }

    private func pauseComplexRound() {
        guard let endDate = complexEndDate else { return }
        complexPausedRemaining = max(0, Int(ceil(endDate.timeIntervalSince(Date()))))
        complexEndDate = nil
        WKInterfaceDevice.current().play(.stop)
    }

    private func resumeComplexRound() {
        guard let remaining = complexPausedRemaining, remaining > 0 else { return }
        complexEndDate = Date().addingTimeInterval(TimeInterval(remaining))
        complexPausedRemaining = nil
        WKInterfaceDevice.current().play(.start)
    }

    private func handleComplexRoundExpiry() {
        // TimelineView fires catch-up ticks when the watch screen wakes from
        // Always-On / sleep — each tick whose `remaining <= 0` queues another
        // async expiry. Guarding only on "endDate != nil" lets every one of
        // those asyncs fire (because startComplexRound resets endDate to a
        // fresh future value), so the runner skips ahead by several rounds
        // back-to-back. Bail unless the deadline genuinely lapsed.
        guard let endDate = complexEndDate, endDate <= Date() else { return }
        completeComplexRoundManually()
    }

    private func completeComplexRoundManually() {
        complexEndDate = nil
        complexPausedRemaining = nil
        let wasLast = manager.complexRound >= (manager.currentComplex()?.rounds ?? 1)
        let finishedAll = manager.completeComplexRound()
        WKInterfaceDevice.current().play(.notification)
        if finishedAll {
            // Past the complex — sync state for whatever the next item is.
            syncFromPredefined()
        } else if !wasLast {
            // Auto-roll the next round. Don't speak the round number here —
            // startComplexRound speaks it once, so an extra utterance at this
            // point doubles up the announcement.
            startComplexRound()
        }
    }

    // MARK: - Speech

    private func speak(_ text: String) {
        guard speechEnabled else { return }
        speech.speak(text)
    }

    /// Speaks single-second numbers during the last 5 seconds of any
    /// countdown (timed set or complex round), once per second. Uses
    /// `speakNow` so each new number replaces the previous one in flight —
    /// keeps the synth queue at depth 1 so a brief audio-engine hiccup
    /// can't cause a burst.
    private func maybeSpeakTail(_ remaining: Int) {
        guard speechEnabled else { return }
        guard remaining > 0, remaining <= 5 else { return }
        guard remaining != lastSpokenSecond else { return }
        lastSpokenSecond = remaining
        speech.speakNow("\(remaining)")
    }

    // MARK: - Util

    private func formatSeconds(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        if m > 0 { return String(format: "%d:%02d", m, sec) }
        return "\(sec)s"
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(w))"
            : String(format: "%.1f", w)
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

// MARK: - Complex value editor sheet

/// Modal sheet that lets the user adjust one complex exercise's reps + weight
/// via wheel pickers. Save commits back into the session manager.
private struct ComplexValueEditor: View {
    let exercise: WatchBlueprintExercise
    let initialReps: Int
    let initialWeight: Double
    let hasWeight: Bool
    let onSave: (Int, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int = 0
    @State private var weight: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            Text(exercise.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                VStack(spacing: 0) {
                    Text("Reps").font(.system(size: 9)).foregroundColor(.secondary)
                    Picker("", selection: $reps) {
                        ForEach(0...50, id: \.self) { v in
                            Text("\(v)").font(.system(size: 16, weight: .semibold).monospacedDigit()).tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 70)
                }
                if hasWeight {
                    VStack(spacing: 0) {
                        Text("Weight").font(.system(size: 9)).foregroundColor(.secondary)
                        Picker("", selection: $weight) {
                            ForEach(Array(stride(from: 0, through: 500, by: 5)), id: \.self) { v in
                                Text("\(v)").font(.system(size: 16, weight: .semibold).monospacedDigit()).tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 70)
                    }
                }
            }
            Button {
                onSave(reps, Double(weight))
                dismiss()
            } label: {
                Text("Save")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 6)
        .onAppear {
            reps = initialReps
            weight = Int(initialWeight)
        }
    }
}

// MARK: - Speech box

/// Tiny wrapper around AVSpeechSynthesizer so the view can hold a single
/// instance through state and ARC keeps it alive between utterances.
///
/// `prime()` plays an inaudible warmup utterance so the audio engine is
/// running by the time the first audible speech is requested — without it,
/// rapid back-to-back countdown numbers queue up while the engine spins
/// up and then fire in a burst. `speakNow` interrupts any in-flight or
/// queued utterance so per-second countdowns always reflect the latest
/// number instead of stacking.
@MainActor
private final class SpeechBox {
    private let synth = AVSpeechSynthesizer()
    private var hasPrimed = false

    func prime() {
        guard !hasPrimed else { return }
        hasPrimed = true
        let warmup = AVSpeechUtterance(string: "ready")
        warmup.volume = 0
        warmup.rate = AVSpeechUtteranceMaximumSpeechRate
        synth.speak(warmup)
    }

    func speak(_ text: String) {
        prime()
        let u = AVSpeechUtterance(string: text)
        u.rate = 0.5
        u.pitchMultiplier = 1.05
        synth.speak(u)
    }

    func speakNow(_ text: String) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speak(text)
    }
}
