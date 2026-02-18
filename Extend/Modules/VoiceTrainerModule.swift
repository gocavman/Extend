////
////  VoiceTrainerModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/15/26.
////

import SwiftUI
import Observation
import AVFoundation

/// Voice Trainer module - speak text lines with customizable timing and rounds
public struct VoiceTrainerModule: AppModule {
    public let id: UUID = ModuleIDs.voiceTrainer
    public let displayName: String = "Trainer"
    public let iconName: String = "speaker.wave.2"
    public let description: String = "Read text aloud with customizable rounds and timing"

    public var order: Int = 0
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        let view = VoiceTrainerModuleView(module: self)
        return AnyView(view)
    }
}

// MARK: - Voice Trainer View

private struct VoiceTrainerModuleView: View {
    let module: VoiceTrainerModule
    
    @Environment(VoiceTrainerState.self) var state
    @Environment(WorkoutLogState.self) var logState
    @Environment(DashboardState.self) var dashboardState
    
    @State private var showSaveDialog = false
    @State private var configName = ""
    @State private var showFavorites = false
    @State private var selectedFavoriteId: UUID?
    @State private var isLoadingConfig = false
    @State private var voiceManager: VoiceManager?
    @State private var updateTimer: Timer?
    @State private var text = ""
    @State private var roundLength: Int = 30
    @State private var restLength: Int = 60
    @State private var delayBetweenLines: Int = 5
    @State private var numberOfRounds: Int = 1
    @State private var randomOrder = false
    @State private var cooldownPeriod: Int = 0
    @State private var showPlaybackScreen = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice Trainer")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if state.isPlaying || state.isPaused {
                            Text("Round \(state.currentRound) of \(numberOfRounds)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if !state.savedConfigurations.isEmpty {
                            Button(action: { showFavorites = true }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Button(action: { showSaveDialog = true }) {
                            Image(systemName: "heart")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                        }
                    }
                }
                
                // Saved configurations tags (no preferences icon in tags)
                if !state.savedConfigurations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.savedConfigurations) { config in
                                Button(action: {
                                    // Load configuration and set selected without triggering onChange
                                    selectedFavoriteId = config.id
                                    text = config.text
                                    numberOfRounds = config.numberOfRounds
                                    roundLength = config.roundLength
                                    restLength = config.restLength
                                    delayBetweenLines = config.delayBetweenLines
                                    randomOrder = config.randomOrder
                                    cooldownPeriod = config.cooldownPeriod
                                    updateTotalTime()
                                }) {
                                    Text(config.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedFavoriteId == config.id ? .white : .black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedFavoriteId == config.id ? Color.black : Color(red: 0.88, green: 0.88, blue: 0.88))
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Text Area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text to Read")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $text)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                .cornerRadius(8)
                                .disabled(state.isPlaying || state.isPaused)
                                .opacity(text.isEmpty ? 0.25 : 1.0)
                            
                            if text.isEmpty {
                                Text("Enter text to read aloud, one item per line...")
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.75))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    
                    // MARK: - Configuration Options
                    VStack(spacing: 12) {
                        // Number of Rounds
                        HStack {
                            Text("Number of Rounds")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            HStack(spacing: 12) {
                                Button(action: {
                                    if numberOfRounds > 1 {
                                        numberOfRounds -= 1
                                        updateTotalTime()
                                    }
                                }) {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                .disabled(numberOfRounds <= 1)
                                
                                Text("\(numberOfRounds)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 30)
                                
                                Button(action: {
                                    if numberOfRounds < 100 {
                                        numberOfRounds += 1
                                        updateTotalTime()
                                    }
                                }) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                .disabled(numberOfRounds >= 100)
                            }
                        }
                        
                        // Round Length
                        HStack {
                            Text("Round Length")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Picker("Round Length", selection: $roundLength) {
                                Text("30 sec").tag(30)
                                Text("1 min").tag(60)
                                Text("1.5 min").tag(90)
                                Text("2 min").tag(120)
                                Text("2.5 min").tag(150)
                                Text("3 min").tag(180)
                                Text("3.5 min").tag(210)
                                Text("4 min").tag(240)
                                Text("4.5 min").tag(270)
                                Text("5 min").tag(300)
                                Text("6 min").tag(360)
                                Text("7 min").tag(420)
                                Text("8 min").tag(480)
                                Text("9 min").tag(540)
                                Text("10 min").tag(600)
                                Text("15 min").tag(900)
                                Text("20 min").tag(1200)
                            }
                            .pickerStyle(.menu)
                            .disabled(state.isPlaying || state.isPaused)
                            .onChange(of: roundLength) { _, _ in
                                updateTotalTime()
                            }
                        }
                        
                        // Rest Length
                        HStack {
                            Text("Rest Length")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Picker("Rest Length", selection: $restLength) {
                                Text("None").tag(0)
                                Text("10 sec").tag(10)
                                Text("15 sec").tag(15)
                                Text("30 sec").tag(30)
                                Text("45 sec").tag(45)
                                Text("1 min").tag(60)
                                Text("1.5 min").tag(90)
                                Text("2 min").tag(120)
                                Text("2.5 min").tag(150)
                                Text("3 min").tag(180)
                                Text("3.5 min").tag(210)
                                Text("4.5 min").tag(270)
                                Text("5 min").tag(300)
                            }
                            .pickerStyle(.menu)
                            .disabled(state.isPlaying || state.isPaused)
                        }
                        
                        // Delay Between Lines
                        HStack {
                            Text("Delay Between Lines")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Picker("Delay Between Lines", selection: $delayBetweenLines) {
                                Text("0 sec").tag(0)
                                Text("1 sec").tag(1)
                                Text("2 sec").tag(2)
                                Text("3 sec").tag(3)
                                Text("4 sec").tag(4)
                                Text("5 sec").tag(5)
                                Text("6 sec").tag(6)
                                Text("7 sec").tag(7)
                                Text("8 sec").tag(8)
                                Text("9 sec").tag(9)
                                Text("10 sec").tag(10)
                            }
                            .pickerStyle(.menu)
                            .disabled(state.isPlaying || state.isPaused)
                            .onChange(of: delayBetweenLines) { _, _ in
                                updateTotalTime()
                            }
                        }
                        
                        // Cooldown Period
                        HStack {
                            Text("Cooldown Period")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Picker("Cooldown Period", selection: $cooldownPeriod) {
                                Text("None").tag(0)
                                Text("1 min").tag(1)
                                Text("2 min").tag(2)
                                Text("3 min").tag(3)
                                Text("4 min").tag(4)
                                Text("5 min").tag(5)
                                Text("10 min").tag(10)
                                Text("15 min").tag(15)
                                Text("20 min").tag(20)
                            }
                            .pickerStyle(.menu)
                            .disabled(state.isPlaying || state.isPaused)
                            .onChange(of: cooldownPeriod) { _, _ in
                                updateTotalTime()
                            }
                        }
                        
                        // Random Order Toggle
                        Toggle(isOn: $randomOrder) {
                            Text("Random Order")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .disabled(state.isPlaying || state.isPaused)
                    }
                    .padding(12)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .cornerRadius(8)
                }
                .padding(16)
            }
            
            Spacer()
            
            // MARK: - Playback Controls
            VStack(spacing: 12) {
                // Duration Display
                if state.isPlaying || state.isPaused {
                    VStack(spacing: 4) {
                        Text(formatTime(state.elapsedTime))
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text(String(format: "%@ / %@", formatTime(state.elapsedTime), formatTime(state.totalTime)))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Control Buttons
                HStack(spacing: 12) {
                    // Start Button with Total Time
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if state.isPlaying {
                            pausePlayback()
                        } else if state.isPaused {
                            resumePlayback()
                        } else {
                            startPlayback()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: state.isPlaying ? "pause.fill" : (state.isPaused ? "play.fill" : "play.fill"))
                                .font(.system(size: 16, weight: .semibold))
                            Text(state.isPlaying ? "Pause" : (state.isPaused ? "Resume" : "Start"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("(\(formatTime(state.totalTime)))")
                                .font(.subheadline)
                                .opacity(0.7)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(red: 0.88, green: 0.88, blue: 0.88))
                        .cornerRadius(8)
                    }
                    .disabled(text.isEmpty)
                }
            }
            .padding(16)
        }
        .onAppear {
            voiceManager = VoiceManager()
            updateTotalTime()
        }
        .onChange(of: text) { _, _ in
            selectedFavoriteId = nil
        }
        .onChange(of: roundLength) { _, _ in
            selectedFavoriteId = nil
        }
        .onChange(of: restLength) { _, _ in
            selectedFavoriteId = nil
        }
        .onChange(of: delayBetweenLines) { _, _ in
            selectedFavoriteId = nil
        }
        .onChange(of: numberOfRounds) { _, _ in
            selectedFavoriteId = nil
        }
        .onChange(of: randomOrder) { _, _ in
            selectedFavoriteId = nil
        }
        .onChange(of: cooldownPeriod) { _, _ in
            selectedFavoriteId = nil
        }
        .sheet(isPresented: $showSaveDialog) {
            SaveConfigurationSheet(
                name: $configName,
                onSave: {
                    let config = VoiceTrainerConfig(
                        id: UUID(),
                        name: configName,
                        text: text,
                        roundLength: roundLength,
                        restLength: restLength,
                        delayBetweenLines: delayBetweenLines,
                        numberOfRounds: numberOfRounds,
                        randomOrder: randomOrder,
                        cooldownPeriod: cooldownPeriod
                    )
                    state.saveConfiguration(name: configName, config: config)
                    configName = ""
                    showSaveDialog = false
                },
                onCancel: {
                    configName = ""
                    showSaveDialog = false
                }
            )
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesSheet(state: state)
        }
        .fullScreenCover(isPresented: $showPlaybackScreen) {
            PlaybackScreen(
                state: state,
                numberOfRounds: numberOfRounds,
                onPause: {
                    pausePlayback()
                },
                onResume: {
                    resumePlayback()
                },
                onStop: {
                    resetPlayback()
                    showPlaybackScreen = false
                },
                onComplete: {
                    completeSession()
                    showPlaybackScreen = false
                },
                onStartPlayback: {
                    startUpdateTimer()
                },
                formatTime: formatTime
            )
        }
    }
    
    private func startPlayback() {
        state.isPlaying = false  // Don't set to true yet - will be set when first line starts
        state.isPaused = false
        state.elapsedTime = 0
        state.currentRound = 1
        state.currentLineIndex = 0
        state.currentLineText = ""
        state.lineHistory = []
        state.linesSpoken = 0
        
        // Don't start timer yet - it will start after countdown finishes
        let playbackConfig = VoicePlaybackConfig(
            text: text,
            roundLength: roundLength,
            restLength: restLength,
            delayBetweenLines: delayBetweenLines,
            numberOfRounds: numberOfRounds,
            randomOrder: randomOrder,
            cooldownPeriod: cooldownPeriod
        )
        voiceManager?.startPlayback(config: playbackConfig, state: state)
        
        // Show fullscreen playback view
        showPlaybackScreen = true
    }
    
    private func pausePlayback() {
        state.isPlaying = false
        state.isPaused = true
        // Keep timer alive; it will no-op while paused
        
        // Stop the synthesizer completely
        voiceManager?.pausePlayback()
    }
    
    private func resumePlayback() {
        state.isPlaying = true
        state.isPaused = false
        if updateTimer == nil {
            startUpdateTimer()
        }
        voiceManager?.resumePlayback()
    }
    
    private func resetPlayback() {
        state.reset()
        updateTimer?.invalidate()
        voiceManager?.stop()
    }
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [state, voiceManager, numberOfRounds, restLength, cooldownPeriod] timer in
            // Pause all timers when paused
            if state.isPaused {
                return
            }

            // Only run timers after initial countdown has finished
            if state.isPlaying {
                // Only increment elapsed time if NOT in initial countdown
                if !state.isInInitialCountdown {
                    state.elapsedTime += 1
                }

                // Rest countdown
                if state.restCountdown > 0 {
                    state.restCountdown = max(0, state.restCountdown - 1)
                    voiceManager?.handleRestCountdownTick()
                } else if state.roundTimeRemaining > 0 && !state.isInInitialCountdown {
                    // Round timer only runs when not resting AND not in initial countdown
                    state.roundTimeRemaining -= 1

                    // Check if round just expired
                    if state.roundTimeRemaining == 0 {
                        if restLength > 0 && state.currentRound < numberOfRounds {
                            // Start rest countdown immediately to keep timers in sync
                            voiceManager?.startRestCountdownIfNeeded(duration: restLength, warningAt: state.restEndWarning)
                        } else if cooldownPeriod > 0 && state.currentRound == numberOfRounds {
                            // Start cooldown countdown immediately to keep timers in sync
                            voiceManager?.startCooldownCountdownIfNeeded(duration: cooldownPeriod * 60)
                        }
                        print("⏱️ Round time just expired! currentRound: \(state.currentRound) / \(numberOfRounds)")
                        // Stop speaking and complete round via VoiceManager
                        voiceManager?.forceRoundComplete()
                    }
                }
            }
            
            // Check stop condition AFTER all updates so final second is counted
            if !state.isPlaying && !state.isPaused {
                timer.invalidate()
                return
            }
        }
    }
    
    private func completeSession() {
        // Use the actual lines that were spoken in the order they were spoken
        let linesSpoken = state.lineHistory + (state.currentLineText.isEmpty ? [] : [state.currentLineText])
        let linesText = linesSpoken.joined(separator: "\n")
        let notes = """
Voice Trainer Session

Lines Read (in order):
\(linesText)

Total Lines Read: \(state.linesSpoken)
"""
        
        let workoutLog = WorkoutLog(
            id: UUID(),
            workoutName: "Trainer Session",
            completedAt: Date(),
            exercises: [],
            notes: notes,
            duration: TimeInterval(state.elapsedTime)
        )
        
        logState.addLog(workoutLog)
        resetPlayback()
        
        // Navigate to log screen
        ModuleState.shared.selectedModuleID = ModuleIDs.progress
    }
    
    private func updateTotalTime() {
        // Total time for all lines across all rounds (round length includes reading time)
        let totalRoundsTime = roundLength * numberOfRounds
        
        // Rest periods only happen BETWEEN rounds, not after the last round
        let restPeriodsCount = max(0, numberOfRounds - 1)
        let totalRestTime = restPeriodsCount * restLength
        
        // Add cooldown period (in minutes, convert to seconds)
        let cooldownSeconds = cooldownPeriod * 60
        
        state.totalTime = totalRoundsTime + totalRestTime + cooldownSeconds
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func formatRestLength(_ seconds: Int) -> String {
        if seconds == 0 { return "None" }
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return "\(minutes)m"
    }
}

// MARK: - Voice Playback Configuration

private struct VoicePlaybackConfig {
    let text: String
    let roundLength: Int
    let restLength: Int
    let delayBetweenLines: Int
    let numberOfRounds: Int
    let randomOrder: Bool
    let cooldownPeriod: Int
}

// MARK: - Voice Manager

private class VoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    private var synthesizer: AVSpeechSynthesizer
    private var scheduledWorkItems: [DispatchWorkItem] = []
    private var stopRequested = false
    private var pauseRequested = false
    private var isCompletingRound = false  // Flag to prevent re-entrant calls
    private var currentState: VoiceTrainerState?
    private var countdownQueue: [String] = []
    private var linesQueue: [(line: String, delay: TimeInterval)] = []
    private var currentConfig: VoicePlaybackConfig?
    private var allLines: [String] = []
    private var currentRoundNumber = 1
    private var isResting = false
    private var isCoolingDown = false
    private var restWarningAt: Int = 0
    private var restWarningSpoken = false
    private var isAnnouncingEndOfRound = false
    private var lastRestCountdownSpoken: Int = -1

    override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
    }
    
    func startPlayback(config: VoicePlaybackConfig, state: VoiceTrainerState) {
        stopRequested = false
        pauseRequested = false
        isCompletingRound = false  // Reset flag for new session
        isResting = false
        isCoolingDown = false
        currentState = state
        currentConfig = config
        currentRoundNumber = 0  // Start at 0 so first call to startRound(1) is detected as new round
        
        allLines = config.text.split(separator: "\n")
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Populate next lines to show during countdown
        if !allLines.isEmpty {
            if allLines.count >= 5 {
                state.nextLines = Array(allLines.prefix(5))
            } else {
                let remainingNeeded = 5 - allLines.count
                let repeated = Array(allLines.prefix(remainingNeeded))
                state.nextLines = allLines + repeated
            }
        }
        
        // Start with countdown if configured
        if state.workoutStartWarning > 0 {
            // Set isPlaying to true so pause button shows during countdown
            // Set isInInitialCountdown to true so elapsed time doesn't increment during countdown
            DispatchQueue.main.async {
                state.isPlaying = true
                state.isInInitialCountdown = true
            }
            countdownQueue = (1...state.workoutStartWarning).reversed().map { "\($0)" }
            speakNextCountdown()
        } else {
            // No countdown, start lines immediately
            startRound(roundNumber: 1)
        }
    }
    
    func pausePlayback() {
        print("⏸️ Pause called")
        pauseRequested = true
        // Don't cancel scheduled work items - let them check pauseRequested flag
        // This allows rest countdown and other timers to resume properly
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    func resumePlayback() {
        print("▶️ Resume called")
        pauseRequested = false
        // Continue speaking the current line if it was interrupted
        synthesizer.continueSpeaking()
        // If synthesizer doesn't have anything to resume, check what to speak next
        if !synthesizer.isSpeaking {
            if !countdownQueue.isEmpty {
                print("🎤 Synthesizer not speaking, resuming countdown")
                speakNextCountdown()
            } else if !linesQueue.isEmpty {
                print("🎤 Synthesizer not speaking, calling speakNextLine immediately")
                speakNextLine()
            }
        }
    }
    
    func stop() {
        stopRequested = true
        pauseRequested = false
        scheduledWorkItems.forEach { $0.cancel() }
        scheduledWorkItems.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        countdownQueue.removeAll()
        linesQueue.removeAll()
    }
    
    func forceRoundComplete() {
        // Called when round timer expires - stop current speech and complete round
        print("🛑 forceRoundComplete called - stopping all speech and scheduled work")

        // Prevent re-entrant calls
        guard !isCompletingRound else {
            print("⚠️ Already completing round, ignoring duplicate call")
            return
        }

        isCompletingRound = true
        isAnnouncingEndOfRound = true

        print("   currentRoundNumber: \(currentRoundNumber)")
        print("   stopRequested: \(stopRequested), pauseRequested: \(pauseRequested)")

        // Stop synthesizer immediately
        synthesizer.stopSpeaking(at: .immediate)

        // Cancel all pending scheduled work to prevent overlaps
        print("   Canceling \(scheduledWorkItems.count) scheduled work items")
        scheduledWorkItems.forEach { $0.cancel() }
        scheduledWorkItems.removeAll()

        // Clear all queues
        linesQueue.removeAll()
        countdownQueue.removeAll()

        // If a rest is coming, start its countdown immediately to keep timers in sync
        if let config = currentConfig,
           let state = currentState,
           currentRoundNumber < config.numberOfRounds,
           config.restLength > 0 {
            isResting = true
            restWarningAt = state.restEndWarning
            restWarningSpoken = false
            lastRestCountdownSpoken = -1
            state.restCountdown = config.restLength
            state.nextItemCountdown = 0
            state.currentLineText = ""
        }

        // Create and track the work item for handleRoundComplete
        let completeWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                print("❌ self is nil in forceRoundComplete delayed call")
                return
            }
            guard !self.stopRequested && !self.pauseRequested else {
                print("❌ Stop/pause requested in forceRoundComplete delayed call")
                self.isCompletingRound = false
                self.isAnnouncingEndOfRound = false
                return
            }
            print("🏁 Announcing end of round \(self.currentRoundNumber) after cleanup delay")

            // Announce "End of round X"
            let announcement = "End of round \(self.currentRoundNumber)"
            let utterance = AVSpeechUtterance(string: announcement)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            self.synthesizer.speak(utterance)

            // Wait for announcement to finish, then handle round complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                print("🏁 Starting handleRoundComplete after announcement")
                print("   currentConfig: \(self.currentConfig != nil)")
                print("   currentState: \(self.currentState != nil)")
                self.handleRoundComplete()
                self.isCompletingRound = false  // Reset flag after completion
                self.isAnnouncingEndOfRound = false
            }
        }

        // Add to tracked items so it won't get canceled
        scheduledWorkItems.append(completeWorkItem)

        // Wait a brief moment to ensure everything is stopped before starting rest
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: completeWorkItem)
    }

    func startRestCountdownIfNeeded(duration: Int, warningAt: Int) {
        guard let state = currentState else { return }
        guard duration > 0 else { return }
        if isResting || state.restCountdown > 0 {
            return
        }
        isResting = true
        restWarningAt = warningAt
        restWarningSpoken = false
        lastRestCountdownSpoken = -1
        state.restCountdown = duration
        state.nextItemCountdown = 0
        state.currentLineText = ""
    }

    func startCooldownCountdownIfNeeded(duration: Int) {
        guard let state = currentState else { return }
        guard duration > 0 else { return }
        if isCoolingDown || state.restCountdown > 0 {
            return
        }
        isCoolingDown = true
        state.restCountdown = duration
        state.nextItemCountdown = 0
        state.currentLineText = ""
        state.nextLines = []
    }

    private func startRound(roundNumber: Int) {
        print("🏁 startRound called for round \(roundNumber)")
        guard let config = currentConfig,
              let state = currentState,
              roundNumber <= config.numberOfRounds,
              !stopRequested && !pauseRequested else {
            print("❌ startRound guard failed")
            return
        }
        
        // Check if this is a new round (before updating currentRoundNumber)
        let isNewRound = currentRoundNumber != roundNumber
        
        // Only initialize round countdown timer for NEW rounds, not when looping list within same round
        if isNewRound {
            print("🆕 Starting NEW round \(roundNumber), setting roundTimeRemaining to \(config.roundLength)s")
            state.roundTimeRemaining = config.roundLength
        } else {
            print("🔄 Continuing same round \(roundNumber), roundTimeRemaining: \(state.roundTimeRemaining)s")
        }
        
        currentRoundNumber = roundNumber
        state.currentRound = roundNumber
        
        // Generate lines for this round
        let roundLines: [String]
        if config.randomOrder {
            roundLines = (0..<allLines.count).map { _ in allLines.randomElement() ?? "" }.filter { !$0.isEmpty }
        } else {
            roundLines = allLines
        }
        
        print("📝 Generated \(roundLines.count) lines for round \(roundNumber)")
        
        // Queue up lines with delays
        linesQueue = roundLines.enumerated().map { (index, line) in
            (line: line, delay: TimeInterval(index * config.delayBetweenLines))
        }
        
        print("📋 LinesQueue now has \(linesQueue.count) items")
        
        // Clear initial countdown flag when starting first round (actual workout begins)
        if roundNumber == 1 && state.isInInitialCountdown {
            print("⏱️ Clearing isInInitialCountdown flag - workout starting")
            DispatchQueue.main.async {
                state.isInInitialCountdown = false
            }
        }
        
        // Set isPlaying to true when lines start (for any round)
        if !state.isPlaying {
            print("⏱️ Setting isPlaying to true for round \(roundNumber)")
            DispatchQueue.main.async {
                state.isPlaying = true
            }
        }
        
        // Start speaking first line
        print("🎤 Calling speakNextLine")
        speakNextLine()
    }
    
    private func speakNextLine() {
        print("🎯 speakNextLine called, queue has \(linesQueue.count) items")
        guard let state = currentState,
              let config = currentConfig,
              !stopRequested && !pauseRequested else {
            print("❌ speakNextLine guard failed")
            return
        }
        
        // Check if round time has expired before speaking
        if state.roundTimeRemaining <= 0 && currentRoundNumber > 0 {
            print("⏱️ Round time expired, handling round completion instead of speaking")
            handleRoundComplete()
            return
        }
        
        if linesQueue.isEmpty {
            print("📋 Queue empty, checking if should refill or complete round")
            // If round time is still remaining, refill the queue and continue
            if state.roundTimeRemaining > 0 {
                print("⏱️ Round time remaining (\(state.roundTimeRemaining)s), refilling queue")
                // Regenerate lines for continuation of same round
                let roundLines: [String]
                if config.randomOrder {
                    roundLines = (0..<allLines.count).map { _ in allLines.randomElement() ?? "" }.filter { !$0.isEmpty }
                } else {
                    roundLines = allLines
                }
                
                // Queue up lines
                linesQueue = roundLines.enumerated().map { (index, line) in
                    (line: line, delay: TimeInterval(index * config.delayBetweenLines))
                }
                
                print("📋 Refilled queue with \(linesQueue.count) items, continuing round \(state.currentRound)")
                // Now fall through to speak the first item from the refilled queue
            } else {
                print("✅ Round time complete, delegate will handle round completion")
                // Round time expired - delegate will call handleRoundComplete() after delay
                return
            }
        }
        
        // If we get here, queue should have items (either already had them, or we just refilled)
        if linesQueue.isEmpty {
            print("⚠️ Queue still empty after refill check")
            return
        }
        
        let (line, _) = linesQueue.removeFirst()
        print("🗣️ Speaking line: '\(line)'")
        
        // Update state
        state.linesSpoken += 1
        if !state.currentLineText.isEmpty {
            state.lineHistory.insert(state.currentLineText, at: 0)  // Insert at beginning (bottom of display)
        }
        state.currentLineText = line
        state.nextItemCountdown = 0
        state.startingInCountdown = 0  // Clear starting countdown when lines begin
        
        // Update next lines preview (next 5 items)
        // If queue has items, show those. If fewer than 5, supplement with next iteration
        if !linesQueue.isEmpty {
            var previewLines = linesQueue.prefix(5).map { $0.line }

            if previewLines.count < 5 && state.roundTimeRemaining > 0 {
                let remainingNeeded = 5 - previewLines.count
                let nextIterationLines: [String]
                if config.randomOrder {
                    nextIterationLines = (0..<remainingNeeded).map { _ in allLines.randomElement() ?? "" }.filter { !$0.isEmpty }
                } else {
                    var repeated: [String] = []
                    var index = 0
                    while repeated.count < remainingNeeded && !allLines.isEmpty {
                        repeated.append(allLines[index % allLines.count])
                        index += 1
                    }
                    nextIterationLines = repeated
                }
                previewLines.append(contentsOf: nextIterationLines)
            }

            state.nextLines = previewLines
        } else if state.roundTimeRemaining > 0 {
            // Queue empty but round continues: show next iteration preview
            let nextIterationLines: [String]
            if config.randomOrder {
                nextIterationLines = (0..<min(5, allLines.count)).map { _ in allLines.randomElement() ?? "" }.filter { !$0.isEmpty }
            } else {
                var repeated: [String] = []
                var index = 0
                while repeated.count < 5 && !allLines.isEmpty {
                    repeated.append(allLines[index % allLines.count])
                    index += 1
                }
                nextIterationLines = repeated
            }
            state.nextLines = nextIterationLines
        } else if currentRoundNumber < config.numberOfRounds {
            // Last item of current round - show preview of next round (which starts after rest or delay)
            let nextRoundLines: [String]
            if config.randomOrder {
                nextRoundLines = (0..<min(5, allLines.count)).map { _ in allLines.randomElement() ?? "" }.filter { !$0.isEmpty }
            } else {
                nextRoundLines = allLines
            }
            state.nextLines = Array(nextRoundLines.prefix(5))
        } else {
            // Last round, last item - no upcoming items
            state.nextLines = []
        }
        
        let utterance = AVSpeechUtterance(string: line)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        
        // Schedule next item countdown if delay is configured
        // Show countdown even if queue is empty (will refill after delay)
        if config.delayBetweenLines > 1 {
            scheduleNextItemCountdown(delay: config.delayBetweenLines)
        }
        
        synthesizer.speak(utterance)
    }
    
    private func scheduleNextItemCountdown(delay: Int) {
        guard let state = currentState else { return }
        
        for second in 1..<delay {
            let workItem = DispatchWorkItem { [weak self, weak state] in
                guard let self = self, let state = state,
                      !self.stopRequested && !self.pauseRequested else { return }
                state.nextItemCountdown = delay - second
            }
            scheduledWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(second), execute: workItem)
        }
    }
    
    private func handleRoundComplete() {
        print("🏁 handleRoundComplete called")
        guard let config = currentConfig,
              let state = currentState,
              !stopRequested && !pauseRequested else {
            print("❌ handleRoundComplete guard failed:")
            print("   config: \(currentConfig != nil)")
            print("   state: \(currentState != nil)")
            print("   stopRequested: \(stopRequested)")
            print("   pauseRequested: \(pauseRequested)")
            return
        }

        // Cancel any delayed line-queue work before starting rest/next round
        scheduledWorkItems.forEach { $0.cancel() }
        scheduledWorkItems.removeAll()

        print("   currentRoundNumber: \(currentRoundNumber) / \(config.numberOfRounds)")
        print("   restLength: \(config.restLength)")

        if currentRoundNumber < config.numberOfRounds {
            if config.restLength > 0 {
                // Rest may already be running if it was started early in forceRoundComplete
                if isResting && state.restCountdown > 0 {
                    return
                }
                print("🛌 Scheduling rest period for \(config.restLength) seconds")
                beginRest(duration: config.restLength, warningAt: state.restEndWarning)
            } else {
                print("🏁 No rest, starting next round immediately (delegate already waited delay)")
                startRound(roundNumber: currentRoundNumber + 1)
            }
        } else {
            // All rounds complete - schedule cooldown if configured
            if config.cooldownPeriod > 0 {
                // If cooldown already started, don't reset it
                if isCoolingDown && state.restCountdown > 0 {
                    return
                }
                // Start cooldown period
                let cooldownSeconds = config.cooldownPeriod * 60
                print("❄️ Cool down period starting for \(cooldownSeconds) seconds")
                isCoolingDown = true
                state.restCountdown = cooldownSeconds  // Initialize cooldown display
                state.currentLineText = ""  // Clear current line during cooldown
                state.nextLines = []
                // Timer will handle countdown and completion when restCountdown hits 0
            } else {
                // No cooldown - just finish immediately
                print("✅ All rounds complete")
                state.isPlaying = false
                state.isPaused = false
            }
        }
    }
    
    private func beginRest(duration: Int, warningAt: Int) {
        guard let state = currentState else { return }
        isResting = true
        restWarningAt = warningAt
        restWarningSpoken = false
        lastRestCountdownSpoken = -1
        state.restCountdown = duration
        state.nextItemCountdown = 0
        state.currentLineText = ""  // Clear current line during rest
    }

    func handleRestCountdownTick() {
        guard let state = currentState else { return }
        
        // Handle both rest and cooldown
        if !isResting && !isCoolingDown { return }

        let remaining = state.restCountdown
        
        // Set nextItemCountdown to show "Next in" during final seconds of rest (not cooldown)
        if isResting && remaining > 0 {
            state.nextItemCountdown = remaining
        }
        
        // Only speak countdown during rest (not cooldown)
        if isResting && remaining > 0 && remaining <= restWarningAt && remaining != lastRestCountdownSpoken {
            lastRestCountdownSpoken = remaining
            // Speak the remaining seconds in real time
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
            let utterance = AVSpeechUtterance(string: "\(remaining)")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            synthesizer.speak(utterance)
        }

        if remaining == 0 {
            if isResting {
                // Rest complete - dispatch everything asynchronously to prevent blocking the timer
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let state = self.currentState else { return }
                    self.isResting = false
                    state.nextItemCountdown = 0  // Clear when rest ends
                    if self.synthesizer.isSpeaking {
                        self.synthesizer.stopSpeaking(at: .immediate)
                    }
                    self.startRound(roundNumber: self.currentRoundNumber + 1)
                }
            } else if isCoolingDown {
                // Cooldown complete - end session
                isCoolingDown = false
                state.isPlaying = false
                state.isPaused = false
                print("✅ Cooldown complete, session ended")
            }
        }
    }

    private func scheduleRestCountdown(duration: Int, warningAt: Int) {
        guard let state = currentState else { return }
        print("🛌 Rest period starting for \(duration) seconds")
        state.restCountdown = duration
        isResting = true
        restWarningAt = warningAt
        restWarningSpoken = false
        lastRestCountdownSpoken = -1
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🎤 Delegate: didFinish utterance: '\(utterance.speechString)'")
        // Use delegate callback for reliable timing instead of scheduled work items
        guard !stopRequested && !pauseRequested else {
            print("❌ Delegate: stop or pause requested")
            return
        }

        if isAnnouncingEndOfRound {
            print("🔇 End-of-round announcement finished; ignoring queue handling")
            return
        }

        print("📊 Countdown queue: \(countdownQueue.count), Lines queue: \(linesQueue.count)")
        print("📊 isPlaying: \(currentState?.isPlaying ?? false)")
        print("📊 currentConfig exists: \(currentConfig != nil)")

        if !countdownQueue.isEmpty {
            print("⏰ Continuing countdown, scheduling next number in 1 second (total 1s between numbers)")
            // Continue countdown after 1 second from NOW (not from when it started speaking)
            let workItem = DispatchWorkItem { [weak self] in
                self?.speakNextCountdown()
            }
            scheduledWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        } else if let config = currentConfig, linesQueue.isEmpty, currentRoundNumber > 0 {
            // Last line of the queue just finished (we're in a round, not just finishing countdown)
            if isCompletingRound || isResting {
                print("⏭️ Skipping queue-empty handling during round completion/rest")
                return
            }
            let finishTime = Date()
            print("🔄 Queue empty after line finished at \(finishTime), waiting \(config.delayBetweenLines) seconds")
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, !self.stopRequested && !self.pauseRequested else { return }
                if self.isCompletingRound || self.isResting {
                    print("⏭️ Skipping delayed queue-empty handling during round completion/rest")
                    return
                }

                let resumeTime = Date()
                print("⏰ Delay complete at \(resumeTime), elapsed: \(resumeTime.timeIntervalSince(finishTime))s")

                // Check if queue was already refilled by another call (prevent duplicates)
                if !self.linesQueue.isEmpty {
                    print("⚠️ Queue already refilled, skipping duplicate call")
                    return
                }

                // Check if we should refill queue or complete round
                if let state = self.currentState, state.roundTimeRemaining > 0 {
                    print("⏱️ Round time remaining (\(state.roundTimeRemaining)s), refilling queue and continuing")
                    self.speakNextLine() // This will refill the queue and speak next line
                } else {
                    print("✅ Round time complete (or expired), forcing round completion")
                    self.forceRoundComplete()
                }
            }
            scheduledWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(config.delayBetweenLines), execute: workItem)
        } else if countdownQueue.isEmpty && linesQueue.isEmpty && currentRoundNumber == 0 {
            // Just finished countdown (both queues empty and no rounds started yet)
            print("🎯 Delegate detected countdown finished, waiting 1 second before starting lines")
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, !self.stopRequested && !self.pauseRequested else { return }
                self.startRound(roundNumber: 1)
            }
            scheduledWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        } else if let config = currentConfig, !linesQueue.isEmpty {
            print("📝 Continuing to next line after \(config.delayBetweenLines) seconds")
            // Just finished a line, wait delay then speak next line
            let workItem = DispatchWorkItem { [weak self] in
                self?.speakNextLine()
            }
            scheduledWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(config.delayBetweenLines), execute: workItem)
        } else {
            print("⚠️ Delegate: No action taken")
            print("   - countdownQueue.isEmpty: \(countdownQueue.isEmpty)")
            print("   - linesQueue.isEmpty: \(linesQueue.isEmpty)")
            print("   - isPlaying: \(currentState?.isPlaying ?? false)")
        }
    }
    
    // MARK: - Countdown
    private func speakNextCountdown() {
        guard !stopRequested && !pauseRequested else { return }

        if countdownQueue.isEmpty {
            // Countdown finished, delegate will handle the 1 second delay
            print("🎯 Countdown complete, delegate will handle the delay")
            return
        }

        let number = countdownQueue.removeFirst()
        let countdownIndex = countdownQueue.count + 1

        // Set the UI countdown display
        if let state = currentState {
            state.startingInCountdown = countdownIndex
        }

        print("🔢 Speaking countdown: \(number)")
        let utterance = AVSpeechUtterance(string: number)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }
}

// MARK: - Save Configuration Sheet

private struct SaveConfigurationSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Configuration Name") {
                    TextField("Enter name", text: $name)
                }
            }
            .navigationTitle("Save Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(name.isEmpty)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Favorites Sheet

private struct FavoritesSheet: View {
    @Environment(\.dismiss) var dismiss
    let state: VoiceTrainerState
    
    @State private var selectedConfigId: UUID?
    @State private var showRenameDialog = false
    @State private var configToDeleteId: UUID?
    @State private var renameText = ""
    
    var body: some View {
        NavigationStack {
            List {
                if state.savedConfigurations.isEmpty {
                    Text("No saved configurations")
                        .foregroundColor(.gray)
                } else {
                    ForEach(state.savedConfigurations, id: \.id) { config in
                        VoiceTrainerConfigRow(
                            config: config,
                            formatRoundLength: formatRoundLength,
                            formatRestLength: formatRestLength,
                            onRename: {
                                renameText = config.name
                                selectedConfigId = config.id
                                showRenameDialog = true
                            },
                            onDelete: {
                                configToDeleteId = config.id
                            }
                        )
                    }
                    .onMove { indices, newOffset in
                        state.savedConfigurations.move(fromOffsets: indices, toOffset: newOffset)
                        state.saveConfigurations()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Saved Configurations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showRenameDialog) {
            RenameConfigurationSheet(
                name: $renameText,
                onSave: {
                    if let configId = selectedConfigId,
                       let config = state.savedConfigurations.first(where: { $0.id == configId }) {
                        state.updateConfiguration(config, name: renameText)
                        showRenameDialog = false
                        selectedConfigId = nil
                    }
                },
                onCancel: {
                    showRenameDialog = false
                    selectedConfigId = nil
                    renameText = ""
                }
            )
        }
        .alert("Delete Configuration", isPresented: Binding(
            get: { configToDeleteId != nil },
            set: { if !$0 { configToDeleteId = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let configId = configToDeleteId {
                    if let config = state.savedConfigurations.first(where: { $0.id == configId }) {
                        state.deleteConfiguration(config)
                    }
                    configToDeleteId = nil
                }
            }
            Button("Cancel", role: .cancel) {
                configToDeleteId = nil
            }
        } message: {
            if let configId = configToDeleteId,
               let config = state.savedConfigurations.first(where: { $0.id == configId }) {
                Text("Are you sure you want to delete '\(config.name)'? This cannot be undone.")
            }
        }
    }
    
    private func formatRoundLength(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return "\(minutes)m"
    }
    
    private func formatRestLength(_ seconds: Int) -> String {
        if seconds == 0 { return "None" }
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return "\(minutes)m"
    }
}

// MARK: - Voice Trainer Config Row View

private struct VoiceTrainerConfigRow: View {
    let config: VoiceTrainerConfig
    let formatRoundLength: (Int) -> String
    let formatRestLength: (Int) -> String
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(config.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Text("Lines: \(config.text.split(separator: "\n").count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Configuration details
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rounds: \(config.numberOfRounds) • Length: \(formatRoundLength(config.roundLength))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Rest: \(formatRestLength(config.restLength)) • Delay: \(config.delayBetweenLines)s • Cooldown: \(config.cooldownPeriod)m")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Random: \(config.randomOrder ? "On" : "Off")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 8) {
                Button(action: {
                    onRename()
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Rename Configuration Sheet

private struct RenameConfigurationSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Configuration Name") {
                    TextField("Enter name", text: $name)
                }
            }
            .navigationTitle("Rename Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(name.isEmpty)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Playback Screen

private struct PlaybackScreen: View {
    let state: VoiceTrainerState
    let numberOfRounds: Int
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onComplete: () -> Void
    let onStartPlayback: () -> Void
    let formatTime: (Int) -> String
    
    @State private var timerStarted = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with controls
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onStop()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Round \(state.currentRound)/\(numberOfRounds)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if state.isPlaying {
                            onPause()
                        } else {
                            onResume()
                        }
                    }) {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Main content area
                VStack(spacing: 0) {
                    Spacer()

                    // Previous lines (most recent at bottom, closest to current line)
                    // Fixed height container to prevent current line box from moving
                    VStack(alignment: .center, spacing: 4) {
                        Spacer(minLength: 0)
                        if !state.lineHistory.isEmpty {
                            // Reverse the array so most recent (index 0) appears at bottom
                            ForEach(Array(state.lineHistory.prefix(5).enumerated().reversed()), id: \.offset) { index, line in
                                // Most recent is index 0 (should be largest and closest to current)
                                // Size gradually decreases: 0=18pt, 1=16pt, 2=14pt, 3=12pt, 4=10pt
                                let fontSize: CGFloat = 18 - CGFloat(index * 2)
                                // Opacity gradually decreases: 0=0.9, 1=0.75, 2=0.6, 3=0.45, 4=0.3
                                let opacity: Double = 0.9 - (Double(index) * 0.15)
                                
                                Text(line)
                                    .font(.system(size: fontSize))
                                    .foregroundColor(.gray)
                                    .opacity(opacity)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(height: 120, alignment: .bottom)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 0)

                    // Current line in contained box (max 3 lines height)
                    VStack(alignment: .center, spacing: 8) {
                        if !state.isPlaying && !state.isPaused && state.elapsedTime > 0 {
                            // Show Done! when workout is complete
                            Text("Done!")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(16)
                        } else if state.restCountdown > 0 {
                            // Show Rest or Cool down label with pulsing animation
                            if state.currentRound < numberOfRounds {
                                Text("Rest")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .multilineTextAlignment(.center)
                                    .padding(16)
                                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                                    .onAppear {
                                        pulseAnimation = true
                                    }
                            } else {
                                Text("Cool down")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .multilineTextAlignment(.center)
                                    .padding(16)
                                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                                    .onAppear {
                                        pulseAnimation = true
                                    }
                            }
                        } else if !state.currentLineText.isEmpty {
                            Text(state.currentLineText)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(16)
                                .transition(.scale.combined(with: .opacity))
                                .id(state.currentLineText)
                                .onAppear {
                                    pulseAnimation = false
                                }
                        } else {
                            Text("Get Ready...")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .onAppear {
                                    pulseAnimation = false
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 140)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)

                    // Next items preview - fixed height container
                    VStack(alignment: .center, spacing: 4) {
                        if !state.nextLines.isEmpty {
                            ForEach(Array(state.nextLines.enumerated()), id: \.offset) { index, line in
                                let fontSize: CGFloat = 16 - CGFloat(index * 2)
                                let opacity = 0.8 - (Double(index) * 0.15)
                                Text(line)
                                    .font(.system(size: max(fontSize, 8)))
                                    .foregroundColor(.gray)
                                    .opacity(opacity)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 0)

                    // Starting/Next in label (moved below upcoming lines)
                    VStack(spacing: 2) {
                        if state.startingInCountdown > 0 {
                            Text("Starting in: \(state.startingInCountdown)s")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.green)
                        } else if state.nextItemCountdown > 0 && state.currentRound < numberOfRounds {
                            Text("Next in: \(state.nextItemCountdown)s")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                    }
                    .frame(height: 24)
                    .padding(.top, 4)

                    Spacer()
                }

                // Timer section (bottom, fixed position)
                VStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(formatTime(state.elapsedTime))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        Text("Time Elapsed")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            let remainingTime = max(0, state.totalTime - state.elapsedTime)
                            Text(formatTime(remainingTime))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            Text("Time Remaining")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            if state.restCountdown > 0 {
                                Text(formatTime(state.restCountdown))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                                    .monospacedDigit()
                                Text("Rest Time")
                                    .font(.caption2)
                                    .foregroundColor(.cyan)
                            } else {
                                Text(formatTime(state.roundTimeRemaining))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                                Text("Round Time")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 12)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onComplete()
                }) {
                    Text("Complete Session")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onChange(of: state.isPlaying) { oldValue, newValue in
            if newValue && !oldValue && !timerStarted {
                timerStarted = true
                onStartPlayback()
            }
        }
    }
}

#Preview {
    VoiceTrainerModuleView(module: VoiceTrainerModule())
        .environment(VoiceTrainerState())
        .environment(WorkoutLogState.shared)
        .environment(DashboardState.shared)
}
