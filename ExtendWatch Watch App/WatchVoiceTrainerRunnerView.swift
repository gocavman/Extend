////
////  WatchVoiceTrainerRunnerView.swift
////  ExtendWatch
////
////  Wrist-side runner for a voice trainer. Mirrors the iPhone's
////  VoiceManager at the level of detail the watch needs:
////
////  • Optional pre-workout countdown (1…workoutStartWarning).
////  • Per round: speak each line, wait `delayBetweenLines` between them,
////    auto-end the round when `roundLength` seconds elapse.
////  • Optional rest between rounds with a `restEndWarning`-second
////    spoken countdown.
////  • Random ordering when configured.
////
////  Speech uses `AVSpeechSynthesizer` over an audio session set to
////  `.playback` so output goes to the watch speaker / paired audio
////  routes — same pattern the iPhone uses.
////

import SwiftUI
import WatchKit
import AVFoundation

struct WatchVoiceTrainerRunnerView: View {

    @Bindable var manager: WatchWorkoutSessionManager
    let config: WatchVoiceTrainerConfig

    @State private var phase: Phase = .preparing
    @State private var round: Int = 1
    @State private var roundEndDate: Date? = nil
    @State private var pausedRemaining: Int? = nil
    @State private var currentLine: String = ""
    @State private var lastSpokenCountdown: Int = -1
    @State private var isFinishing: Bool = false
    /// Engine held on the view so ARC doesn't release the synthesizer mid-
    /// utterance and so its delegate stays alive across line transitions.
    @State private var engine = VoicePlaybackEngine()

    private enum Phase: Equatable {
        case preparing      // waiting for audio engine warmup to complete
        case preStart       // pre-workout countdown running
        case roundActive    // a round is in flight
        case resting        // rest between rounds
        case completed      // all rounds done
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                header(now: context.date)
                content(now: context.date)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { startSessionIfNeeded() }
        .onDisappear { engine.shutdown() }
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
        }
        .padding(.top, 2)
    }

    // MARK: - Body content

    @ViewBuilder
    private func content(now: Date) -> some View {
        let isPaused = pausedRemaining != nil
        let remaining: Int = {
            if let paused = pausedRemaining { return paused }
            guard let endDate = roundEndDate else { return 0 }
            return max(0, Int(ceil(endDate.timeIntervalSince(now))))
        }()
        switch phase {
        case .preparing:
            preparingBody
        case .preStart:
            preStartBody(remaining: remaining, isPaused: isPaused)
        case .roundActive:
            roundActiveBody(remaining: remaining, isPaused: isPaused)
        case .resting:
            restingBody(remaining: remaining, isPaused: isPaused)
        case .completed:
            completedBody
        }
    }

    private var preparingBody: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Preparing…")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func preStartBody(remaining: Int, isPaused: Bool) -> some View {
        VStack(spacing: 6) {
            Text("Starting in")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text("\(remaining)")
                .font(.system(size: 38, weight: .bold).monospacedDigit())
                .foregroundColor(isPaused ? .orange : .primary)
            controls(isPaused: isPaused)
        }
        .onChange(of: remaining) { _, newValue in
            // Speak the countdown each second.
            if phase == .preStart, newValue > 0, newValue != lastSpokenCountdown, !isPaused {
                lastSpokenCountdown = newValue
                engine.speakNow("\(newValue)")
            }
            if phase == .preStart, newValue <= 0 {
                beginRound(1)
            }
        }
    }

    private func roundActiveBody(remaining: Int, isPaused: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("Round \(round) of \(config.numberOfRounds)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatSeconds(remaining))
                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                    .foregroundColor(remaining <= 5 ? .red : .primary)
            }

            ScrollView {
                Text(currentLine.isEmpty ? "—" : currentLine)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }

            controls(isPaused: isPaused)
        }
        .onChange(of: remaining) { _, newValue in
            if phase == .roundActive, !isPaused, newValue <= 0 {
                endRound()
            }
        }
    }

    private func restingBody(remaining: Int, isPaused: Bool) -> some View {
        VStack(spacing: 6) {
            Text("Rest")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.blue)
            Text(formatSeconds(remaining))
                .font(.system(size: 32, weight: .bold).monospacedDigit())
                .foregroundColor(isPaused ? .orange : .primary)
            Text("Round \(round + 1) of \(config.numberOfRounds) coming up")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            controls(isPaused: isPaused)
        }
        .onChange(of: remaining) { _, newValue in
            guard phase == .resting, !isPaused else { return }
            if newValue > 0,
               newValue <= config.restEndWarning,
               newValue != lastSpokenCountdown {
                lastSpokenCountdown = newValue
                engine.speakNow("\(newValue)")
            }
            if newValue <= 0 {
                beginRound(round + 1)
            }
        }
    }

    private var completedBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)
            Text("Trainer complete")
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

    @ViewBuilder
    private func controls(isPaused: Bool) -> some View {
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

            if isPaused {
                Button(action: resume) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
            } else {
                Button(action: pause) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(.orange)
            }
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Session lifecycle

    private func startSessionIfNeeded() {
        guard roundEndDate == nil && pausedRemaining == nil else { return }
        round = 1
        phase = .preparing
        // Kick the audio engine and wait for the silent warmup utterance to
        // finish before starting the countdown — otherwise the first few
        // seconds get queued behind a still-spinning audio pipeline and play
        // back in a burst once it catches up (the visible symptom was a
        // 10-second countdown that didn't speak until ~8 and then said
        // "8 7 6" all at once before settling into a normal cadence).
        engine.prepareForPlayback {
            Task { @MainActor in
                guard phase == .preparing else { return }
                if config.workoutStartWarning > 0 {
                    phase = .preStart
                    roundEndDate = Date().addingTimeInterval(TimeInterval(config.workoutStartWarning))
                    // Speak the initial value here — `.onChange(of:)` only
                    // fires on subsequent changes, so without this the first
                    // number heard would be one less than the configured
                    // warning (e.g. "9" instead of "10").
                    lastSpokenCountdown = config.workoutStartWarning
                    engine.speakNow("\(config.workoutStartWarning)")
                } else {
                    beginRound(1)
                }
            }
        }
    }

    private func beginRound(_ n: Int) {
        round = n
        phase = .roundActive
        roundEndDate = Date().addingTimeInterval(TimeInterval(config.roundLength))
        pausedRemaining = nil
        lastSpokenCountdown = -1
        WKInterfaceDevice.current().play(.start)
        engine.beginRound(
            lines: config.lines,
            delayBetweenLines: config.delayBetweenLines,
            randomOrder: config.randomOrder,
            roundLength: config.roundLength,
            announceRound: "Round \(n).",
            onLineChange: { line in currentLine = line }
        )
    }

    private func endRound() {
        roundEndDate = nil
        engine.endRound()
        WKInterfaceDevice.current().play(.notification)
        if round >= config.numberOfRounds {
            phase = .completed
            engine.speakNow("End of workout.")
        } else if config.restLength > 0 {
            phase = .resting
            roundEndDate = Date().addingTimeInterval(TimeInterval(config.restLength))
            lastSpokenCountdown = -1
            engine.speakNow("Rest.")
        } else {
            beginRound(round + 1)
        }
    }

    private func pause() {
        guard let endDate = roundEndDate else { return }
        pausedRemaining = max(0, Int(ceil(endDate.timeIntervalSince(Date()))))
        roundEndDate = nil
        engine.pause()
        WKInterfaceDevice.current().play(.stop)
    }

    private func resume() {
        guard let remaining = pausedRemaining, remaining > 0 else { return }
        roundEndDate = Date().addingTimeInterval(TimeInterval(remaining))
        pausedRemaining = nil
        engine.resume()
        WKInterfaceDevice.current().play(.start)
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        engine.shutdown()
        let logName = manager.pendingLogName
        let activityTypeRaw = manager.activityTypeRaw
        let start = manager.startDate ?? Date()
        Task {
            let uuid = await manager.end()
            let endDate = Date()
            let duration = endDate.timeIntervalSince(start)
            WatchConnectivityBridge.shared.sendCompletedLog(
                name: logName,
                completedAt: endDate,
                duration: duration,
                hkActivityTypeRaw: activityTypeRaw,
                hkWorkoutUUID: uuid
            )
            await MainActor.run { isFinishing = false }
        }
    }

    private func formatSeconds(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        if m > 0 { return String(format: "%d:%02d", m, sec) }
        return "\(sec)s"
    }
}

// MARK: - Playback engine

/// Owns the synthesizer + audio session for one trainer session. Lines are
/// queued each round; when one finishes speaking, a delegate callback waits
/// `delayBetweenLines` seconds (pause-aware) and speaks the next, looping
/// off the end of the list until the round ends from the outside.
@MainActor
private final class VoicePlaybackEngine: NSObject {
    private let synth = AVSpeechSynthesizer()
    private var lines: [String] = []
    private var lineIndex: Int = 0
    private var delayBetweenLines: Int = 0
    private var randomOrder: Bool = false
    private var roundActive: Bool = false
    private var pendingNextLineWork: DispatchWorkItem? = nil
    private var isPaused: Bool = false
    /// True between the round-start announcement and the first real line.
    /// The delegate uses this to schedule the first line immediately after
    /// the announcement instead of waiting `delayBetweenLines` (that delay
    /// is for the gap *between* lines, not announcement→first-line).
    private var firstLinePending: Bool = false
    private var onLineChange: ((String) -> Void)? = nil
    private var hasPrimed: Bool = false
    private var isPrimed: Bool = false
    /// Identity-compared in the delegate to know when the silent warmup
    /// utterance has actually finished playing (vs. round/line utterances).
    private var warmupUtterance: AVSpeechUtterance?
    private var onPrimed: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Configures the audio session and runs an inaudible warmup utterance.
    /// `completion` fires once the warmup is actually done playing — that's
    /// the earliest point at which subsequent `speak(...)` calls can be
    /// trusted to start on time instead of queueing behind a still-spinning
    /// audio pipeline. A 2.5-second timeout falls through anyway so a
    /// missing delegate callback (e.g. simulator quirks) can't hang the UI.
    func prepareForPlayback(completion: @escaping () -> Void) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // Non-fatal — speech still attempts to play with whatever the
            // system default routes to.
        }
        if isPrimed {
            completion()
            return
        }
        onPrimed = completion
        if !hasPrimed {
            hasPrimed = true
            let warmup = AVSpeechUtterance(string: "ready")
            warmup.volume = 0
            warmup.rate = AVSpeechUtteranceMaximumSpeechRate
            warmupUtterance = warmup
            synth.speak(warmup)
        }
        // Safety timeout in case didFinish never fires.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2500)) { [weak self] in
            guard let self else { return }
            guard !self.isPrimed else { return }
            self.isPrimed = true
            self.warmupUtterance = nil
            let cb = self.onPrimed
            self.onPrimed = nil
            cb?()
        }
    }

    func beginRound(lines: [String],
                    delayBetweenLines: Int,
                    randomOrder: Bool,
                    roundLength: Int,
                    announceRound: String,
                    onLineChange: @escaping (String) -> Void) {
        cancelPending()
        self.lines = lines
        self.lineIndex = 0
        self.delayBetweenLines = delayBetweenLines
        self.randomOrder = randomOrder
        self.roundActive = true
        self.isPaused = false
        self.onLineChange = onLineChange
        self.firstLinePending = true
        // Interrupt any in-flight speech (typically the last countdown
        // number still in the queue) so the round announcement plays
        // immediately rather than waiting for the queue to drain. The
        // delegate's didFinish will pick up after the announcement and
        // schedule the first real line — scheduling one here too caused
        // double-queueing where the first line played mid-announcement.
        speakNow(announceRound)
    }

    func endRound() {
        roundActive = false
        cancelPending()
        synth.stopSpeaking(at: .immediate)
    }

    func pause() {
        isPaused = true
        cancelPending()
        if synth.isSpeaking { synth.pauseSpeaking(at: .immediate) }
    }

    func resume() {
        isPaused = false
        if synth.isPaused {
            synth.continueSpeaking()
        } else if roundActive {
            scheduleNextLine(after: 0)
        }
    }

    func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.pitchMultiplier = 1.0
        synth.speak(u)
    }

    /// Stop whatever's currently playing (or queued) before speaking. Use
    /// for per-second countdowns and state-transition announcements where
    /// each new utterance should immediately replace any older one — keeps
    /// the synth queue at depth 1 so it can't catch up in a burst.
    func speakNow(_ text: String) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speak(text)
    }

    func shutdown() {
        cancelPending()
        roundActive = false
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func cancelPending() {
        pendingNextLineWork?.cancel()
        pendingNextLineWork = nil
    }

    private func nextLine() -> String? {
        guard !lines.isEmpty else { return nil }
        if randomOrder {
            return lines.randomElement()
        }
        let line = lines[lineIndex % lines.count]
        lineIndex += 1
        return line
    }

    private func scheduleNextLine(after seconds: Int) {
        guard roundActive, !isPaused else { return }
        cancelPending()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.roundActive, !self.isPaused else { return }
            guard let line = self.nextLine() else { return }
            self.onLineChange?(line)
            self.speak(line)
        }
        pendingNextLineWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: work)
    }
}

extension VoicePlaybackEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        // The utterance itself isn't Sendable, so pull out the volume on
        // this thread — only the silent warmup is at volume 0, which lets
        // the main-actor side distinguish it from real round/line speech.
        let isWarmup = utterance.volume == 0
        Task { @MainActor [weak self] in
            guard let self else { return }
            if isWarmup {
                self.warmupUtterance = nil
                if !self.isPrimed {
                    self.isPrimed = true
                    let cb = self.onPrimed
                    self.onPrimed = nil
                    cb?()
                }
                return
            }
            guard self.roundActive, !self.isPaused else { return }
            // The first line after the round announcement plays with no
            // delay; subsequent lines wait `delayBetweenLines` seconds.
            let delay: Int
            if self.firstLinePending {
                self.firstLinePending = false
                delay = 0
            } else {
                delay = max(0, self.delayBetweenLines)
            }
            self.scheduleNextLine(after: delay)
        }
    }
}
