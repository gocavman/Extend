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
    
    func updateConfiguration(_ config: VoiceTrainerConfig) {
        if let index = savedConfigurations.firstIndex(where: { $0.id == config.id }) {
            savedConfigurations[index] = config
            saveToDefaults()
        }
    }
    
    func cloneConfiguration(_ config: VoiceTrainerConfig) {
        var cloned = config
        cloned.id = UUID()
        cloned.name = "\(config.name) Copy"
        cloned.isFavorite = false
        savedConfigurations.append(cloned)
        saveToDefaults()
    }
    
    func toggleFavorite(id: UUID) {
        if let index = savedConfigurations.firstIndex(where: { $0.id == id }) {
            savedConfigurations[index].isFavorite.toggle()
            saveToDefaults()
        }
    }
    
    var favoriteConfigs: [VoiceTrainerConfig] {
        savedConfigurations.filter { $0.isFavorite }
    }
    
    func resetConfigurations() {
        savedConfigurations = []
        saveToDefaults()
    }
    
    // MARK: - Persistence
    

    
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

struct VoiceTrainerConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var text: String
    var roundLength: Int
    var restLength: Int
    var delayBetweenLines: Int
    var numberOfRounds: Int
    var randomOrder: Bool
    var cooldownPeriod: Int  // minutes after all rounds complete (0-60)
    var workoutStartWarning: Int  // seconds countdown before workout starts (0-30)
    var restEndWarning: Int       // seconds countdown before rest ends (0-30)
    var isFavorite: Bool
    
    // Custom decoding to provide default values for new fields (backward compatibility)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        text = try container.decode(String.self, forKey: .text)
        roundLength = try container.decode(Int.self, forKey: .roundLength)
        restLength = try container.decode(Int.self, forKey: .restLength)
        delayBetweenLines = try container.decode(Int.self, forKey: .delayBetweenLines)
        numberOfRounds = try container.decode(Int.self, forKey: .numberOfRounds)
        randomOrder = try container.decode(Bool.self, forKey: .randomOrder)
        cooldownPeriod = try container.decodeIfPresent(Int.self, forKey: .cooldownPeriod) ?? 0
        workoutStartWarning = try container.decodeIfPresent(Int.self, forKey: .workoutStartWarning) ?? 10
        restEndWarning = try container.decodeIfPresent(Int.self, forKey: .restEndWarning) ?? 10
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
    
    // Standard initializer for creating new configs
    init(id: UUID = UUID(), name: String, notes: String = "", text: String, roundLength: Int, restLength: Int, delayBetweenLines: Int, numberOfRounds: Int, randomOrder: Bool, cooldownPeriod: Int, workoutStartWarning: Int = 10, restEndWarning: Int = 10, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.notes = notes
        self.text = text
        self.roundLength = roundLength
        self.restLength = restLength
        self.delayBetweenLines = delayBetweenLines
        self.numberOfRounds = numberOfRounds
        self.randomOrder = randomOrder
        self.cooldownPeriod = cooldownPeriod
        self.workoutStartWarning = workoutStartWarning
        self.restEndWarning = restEndWarning
        self.isFavorite = isFavorite
    }
    
    var parameterSummary: String {
        var parts: [String] = []
        parts.append("Rounds: \(numberOfRounds)")
        let roundMins = roundLength / 60
        let roundSecs = roundLength % 60
        if roundMins > 0 && roundSecs > 0 {
            parts.append("Round: \(roundMins)m\(roundSecs)s")
        } else if roundMins > 0 {
            parts.append("Round: \(roundMins)m")
        } else {
            parts.append("Round: \(roundSecs)s")
        }
        if restLength > 0 {
            let restMins = restLength / 60
            let restSecs = restLength % 60
            if restMins > 0 && restSecs > 0 {
                parts.append("Rest: \(restMins)m\(restSecs)s")
            } else if restMins > 0 {
                parts.append("Rest: \(restMins)m")
            } else {
                parts.append("Rest: \(restSecs)s")
            }
        }
        if cooldownPeriod > 0 { parts.append("Cooldown: \(cooldownPeriod)m") }
        if randomOrder { parts.append("Random") }
        return parts.joined(separator: " · ")
    }
}
