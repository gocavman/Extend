////
////  VoiceTrainerState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/15/26.
////

import Foundation
import Observation

@Observable
final class VoiceTrainerState {
    // Configuration
    var text: String = ""
    var roundLength: Int = 30  // seconds, 30-7200
    var restLength: Int = 60   // seconds (0, 30, 60, 90, 120, 150, 180, 240, 300)
    var delayBetweenLines: Int = 5  // seconds, 0-10
    var numberOfRounds: Int = 1  // 1-100
    var randomOrder: Bool = false
    
    // Countdown warnings
    var workoutStartWarning: Int = 10  // seconds countdown before workout starts
    var restEndWarning: Int = 10  // seconds countdown before rest ends
    
    // Playback state
    var isPlaying: Bool = false
    var isPaused: Bool = false
    var isInInitialCountdown: Bool = false  // true during initial countdown before workout starts
    var currentRound: Int = 1
    var currentLineIndex: Int = 0
    var currentLineText: String = ""
    var lineHistory: [String] = []
    var nextLines: [String] = []  // next 2 lines coming up
    var elapsedTime: Int = 0  // seconds
    var totalTime: Int = 0    // seconds
    var roundTimeRemaining: Int = 0  // seconds remaining in current round
    var nextItemCountdown: Int = 0  // countdown to next item
    var restCountdown: Int = 0  // countdown during rest period
    var startingInCountdown: Int = 0  // countdown before lines start reading
    var linesSpoken: Int = 0  // count of lines actually spoken during session
    
    // Favorites
    var savedConfigurations: [VoiceTrainerConfig] = []
    
    init() {
        loadSettings()
        loadSavedConfigurations()
        createDefaultConfigurationsIfNeeded()
    }
    
    // MARK: - Default Configurations
    
    private func createDefaultConfigurationsIfNeeded() {
        // Check if defaults have ever been created (stored in UserDefaults)
        let defaultsCreatedKey = "VoiceTrainerDefaultsCreated"
        let defaultsAlreadyCreated = UserDefaults.standard.bool(forKey: defaultsCreatedKey)
        
        // Only create defaults on first launch
        if !defaultsAlreadyCreated {
            createDefaultConfigurations()
            UserDefaults.standard.set(true, forKey: defaultsCreatedKey)
        }
    }
    
    private func createDefaultConfigurations() {
        let heavyBagText = """
1
2
3
4
Jab
3 Hooks
4 Hooks
5 Hooks
2 and a 3
3 and a 4
10 Right Straights
2 and a Right Straight
Double Left Hook
Double Right Hook
3 and a 2
4 and a 3
2 and a 4
3 and 2 Left Hooks
2 Fours
3 Uppercuts
2 and a Left Uppercut Right Straight
Right Straight Left Hook Right Straight
Left and Right Straights
Left and Right Uppercuts
1 and a 2
1 and a 3
1 and a 4
2 and a 1
3 and a 1
4 and a 1
5
6
4 and a 2
2 Twos
2 Threes
2 Jabs
3 Jabs
2 Jabs and a Right Straight Left Hook
"""
        
        let heavyBagConfig = VoiceTrainerConfig(
            id: UUID(),
            name: "Heavy Bag Workout",
            text: heavyBagText,
            roundLength: 300,  // 5 minutes
            restLength: 60,    // 1 minute
            delayBetweenLines: 5,
            numberOfRounds: 5,
            randomOrder: true,  // Enabled
            cooldownPeriod: 0  // No cooldown by default
        )
        
        savedConfigurations.append(heavyBagConfig)
        saveToDefaults()
    }
    
    // MARK: - Computed Properties
    
    var lines: [String] {
        text.split(separator: "\n").map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    var sortedLines: [String] {
        randomOrder ? lines.shuffled() : lines
    }
    
    // MARK: - Configuration Management
    
    func saveConfiguration(name: String, config: VoiceTrainerConfig) {
        var configToSave = config
        configToSave.name = name
        
        if let existingIndex = savedConfigurations.firstIndex(where: { $0.id == config.id }) {
            savedConfigurations[existingIndex] = configToSave
        } else {
            savedConfigurations.append(configToSave)
        }
        
        saveToDefaults()
    }
    
    func loadConfiguration(_ config: VoiceTrainerConfig) {
        text = config.text
        roundLength = config.roundLength
        restLength = config.restLength
        delayBetweenLines = config.delayBetweenLines
        numberOfRounds = config.numberOfRounds
        randomOrder = config.randomOrder
    }
    
    func deleteConfiguration(_ config: VoiceTrainerConfig) {
        savedConfigurations.removeAll { $0.id == config.id }
        saveToDefaults()
    }
    
    func updateConfiguration(_ config: VoiceTrainerConfig, name: String) {
        if let index = savedConfigurations.firstIndex(where: { $0.id == config.id }) {
            var updated = config
            updated.name = name
            savedConfigurations[index] = updated
            saveToDefaults()
        }
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        workoutStartWarning = UserDefaults.standard.integer(forKey: "VoiceTrainerWorkoutStartWarning")
        if workoutStartWarning == 0 { workoutStartWarning = 10 } // Default to 10
        
        restEndWarning = UserDefaults.standard.integer(forKey: "VoiceTrainerRestEndWarning")
        if restEndWarning == 0 { restEndWarning = 10 } // Default to 10
    }
    
    func saveSettings() {
        UserDefaults.standard.set(workoutStartWarning, forKey: "VoiceTrainerWorkoutStartWarning")
        UserDefaults.standard.set(restEndWarning, forKey: "VoiceTrainerRestEndWarning")
    }
    
    private func saveToDefaults() {
        if let encoded = try? JSONEncoder().encode(savedConfigurations) {
            UserDefaults.standard.set(encoded, forKey: "VoiceTrainerConfigs")
        }
    }
    
    public func saveConfigurations() {
        saveToDefaults()
    }
    
    private func loadSavedConfigurations() {
        if let data = UserDefaults.standard.data(forKey: "VoiceTrainerConfigs"),
           let decoded = try? JSONDecoder().decode([VoiceTrainerConfig].self, from: data) {
            savedConfigurations = decoded
        }
    }
    
    // MARK: - Playback Control
    
    func reset() {
        isPlaying = false
        isPaused = false
        isInInitialCountdown = false
        currentRound = 1
        currentLineIndex = 0
        currentLineText = ""
        lineHistory = []
        nextLines = []
        elapsedTime = 0
        nextItemCountdown = 0
        restCountdown = 0
        startingInCountdown = 0
        linesSpoken = 0
    }
    
    func calculateTotalTime() {
        let linesCount = lines.count
        let linesDuration = linesCount > 0 ? (linesCount * delayBetweenLines) : 0
        let roundDuration = roundLength + (restLength * (numberOfRounds - 1))
        totalTime = roundDuration + (linesDuration * numberOfRounds)
    }
}

// MARK: - Data Models

struct VoiceTrainerConfig: Identifiable, Codable {
    var id: UUID
    var name: String
    var text: String
    var roundLength: Int
    var restLength: Int
    var delayBetweenLines: Int
    var numberOfRounds: Int
    var randomOrder: Bool
    var cooldownPeriod: Int  // minutes after all rounds complete (0-60)
    
    // Custom decoding to provide default value for cooldownPeriod (for legacy configs)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        text = try container.decode(String.self, forKey: .text)
        roundLength = try container.decode(Int.self, forKey: .roundLength)
        restLength = try container.decode(Int.self, forKey: .restLength)
        delayBetweenLines = try container.decode(Int.self, forKey: .delayBetweenLines)
        numberOfRounds = try container.decode(Int.self, forKey: .numberOfRounds)
        randomOrder = try container.decode(Bool.self, forKey: .randomOrder)
        // Default to 0 if cooldownPeriod doesn't exist (legacy configs)
        cooldownPeriod = try container.decodeIfPresent(Int.self, forKey: .cooldownPeriod) ?? 0
    }
    
    // Standard initializer for creating new configs
    init(id: UUID, name: String, text: String, roundLength: Int, restLength: Int, delayBetweenLines: Int, numberOfRounds: Int, randomOrder: Bool, cooldownPeriod: Int) {
        self.id = id
        self.name = name
        self.text = text
        self.roundLength = roundLength
        self.restLength = restLength
        self.delayBetweenLines = delayBetweenLines
        self.numberOfRounds = numberOfRounds
        self.randomOrder = randomOrder
        self.cooldownPeriod = cooldownPeriod
    }
}
