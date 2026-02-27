////
////  Game1Module.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/16/26.
////
// Stick figure running and jumping game

import SwiftUI

// MARK: - Stick Figure Animation Manager

struct StickFigureAnimationConfig: Codable {
    let animationName: String
    let frameNumbers: [Int]
    let baseFrameInterval: TimeInterval
    
    // Load frames from Bundle (animations.json)
    func loadFrames() -> [StickFigure2D] {
        let allFrames = AnimationStorage.shared.loadFrames()
        
        // Filter frames by animation name and frame numbers
        return frameNumbers.compactMap { frameNum in
            if let frame = allFrames.first(where: { $0.name == animationName && $0.frameNumber == frameNum }) {
                return frame.pose.toStickFigure2D()
            }
            return nil
        }
    }
    
    // Load objects associated with frames
    func loadObjects() -> [[AnimationObject]] {
        let allFrames = AnimationStorage.shared.loadFrames()
        
        // Get objects for each frame number in order
        return frameNumbers.map { frameNum in
            if let frame = allFrames.first(where: { $0.name == animationName && $0.frameNumber == frameNum }) {
                return frame.objects
            }
            return []
        }
    }
}

// MARK: - Flip Mode for Actions

enum FlipMode: String, Codable {
    case none           // No flipping
    case random         // Random flip each time
    case alternating    // Alternate flip each time
}

// MARK: - Action Configuration

struct ActionFloatingTextConfig: Codable {
    let timing: TimeInterval?
    let text: [String]?
    let random: Bool?
    let loop: Bool?
    let color: String?
}

struct FloatingTextTracker {
    var lastTriggerTime: Double = 0
    var textIndex: Int = 0
    var nextTriggerTime: Double = 0
    var hasCompleted: Bool = false  // Track if we've cycled through all text
}

// MARK: - Points Per Interval Configuration

struct PointsPerIntervalConfig: Codable {
    let interval: TimeInterval  // Time interval in seconds
    let points: Int             // Points to award per interval
}

struct ActionConfig: Codable {
    let id: String
    let displayName: String
    let unlockLevel: Int
    let pointsPerCompletion: Int
    let pointsPerInterval: PointsPerIntervalConfig?  // Optional: award points periodically (e.g., Run)
    let variableTiming: [Int: TimeInterval]? // Optional custom timing per frame
    let flipMode: FlipMode
    let supportsSpeedBoost: Bool
    let allowMovement: Bool // Whether character can move left/right during this action
    let countdown: Bool? // Optional: show countdown timer during animation
    let stickFigureAnimation: StickFigureAnimationConfig?
    let floatingText: ActionFloatingTextConfig?

    // Helper to get available actions for a level (legacy - uses unlockLevel)
    static func actionsForLevel(_ level: Int) -> [ActionConfig] {
        return ACTION_CONFIGS.filter { $0.unlockLevel <= level }
    }

    // Helper to check if an action is available for a specific level (uses LEVEL_CONFIGS)
    static func isActionAvailableForLevel(_ actionId: String, level: Int) -> Bool {
        if let levelConfig = LEVEL_CONFIGS.first(where: { $0.id == level }) {
            return levelConfig.isActionAvailable(actionId)
        }
        return false
    }

    // Helper to get available actions for a level using LEVEL_CONFIGS
    static func availableActionsForLevel(_ level: Int) -> [ActionConfig] {
        if let levelConfig = LEVEL_CONFIGS.first(where: { $0.id == level }) {
            return ACTION_CONFIGS.filter { levelConfig.isActionAvailable($0.id) }
        }
        return []
    }

    // Helper to get level-based action IDs
    static func levelBasedActionIDs(forLevel level: Int) -> Set<String> {
        return Set(ACTION_CONFIGS.filter { $0.unlockLevel <= level }.map { $0.id })
    }
}

// MARK: - Level Configuration

struct LevelCatchableConfig: Codable {
    let chance: Double  // Probability of spawning (0.0 to 1.0)
}

struct LevelConfig: Codable {
    let id: Int
    let name: String
    let displayName: String
    let pointsToComplete: Int
    let availableActions: [String]  // Action IDs available in this level
    let catchables: [String: LevelCatchableConfig]  // Catchable types and their config
    let mapX: Double
    let mapY: Double
    let width: Double
    let height: Double
    let difficulty: Double
    let description: String
    // Helper to check if an action is available in this level
    func isActionAvailable(_ actionId: String) -> Bool {
        return availableActions.contains(actionId)
    }
}

// MARK: - Door Structure

struct Door {
    let id: String
    let position: DoorPosition // left, right, top, bottom
    let collisionSide: CollisionSide // which side triggers collision
    let destinationRoomId: String
    let x: CGFloat // Normalized position (0-1)
    let y: CGFloat // Normalized position (0-1)
    let width: CGFloat // Width as fraction of screen
    let height: CGFloat // Height as fraction of screen
    
    enum DoorPosition {
        case left
        case right
        case top
        case bottom
    }
    
    enum CollisionSide {
        case left  // Collide when hitting from right (running right)
        case right // Collide when hitting from left (running left)
    }
}

// MARK: - Action Configuration Loading

/// Loads action configurations from actions_config.json
func loadActionConfigs() -> [ActionConfig] {
    // Try to load from bundle
    if let url = Bundle.main.url(forResource: "actions_config", withExtension: "json"),
       let data = try? Data(contentsOf: url) {
        let decoder = JSONDecoder()
        if let configs = try? decoder.decode([ActionConfig].self, from: data) {
            print("✅ Successfully loaded \(configs.count) action configurations from JSON")
            return configs
        } else {
            print("⚠️ Failed to decode actions_config.json")
        }
    } else {
        print("⚠️ Could not find actions_config.json in bundle")
    }
    
    // Fallback to empty array - should not happen if JSON is properly included
    print("❌ No action configurations available - game will not work properly")
    return []
}

/// Loads level configurations from levels.json
func loadLevels() -> [LevelConfig] {
    // Try to load from bundle
    if let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
       let data = try? Data(contentsOf: url) {
        let decoder = JSONDecoder()
        do {
            let levels = try decoder.decode([LevelConfig].self, from: data)
            print("✅ Successfully loaded \(levels.count) level configurations from JSON")
            return levels
        } catch {
            print("⚠️ Failed to decode levels.json: \(error)")
        }
    } else {
        print("⚠️ Could not find levels.json in bundle")
    }
    
    // Fallback to empty array
    print("❌ No level configurations available - game will not work properly")
    return []
}

// MARK: - Action Configurations

let ACTION_CONFIGS: [ActionConfig] = loadActionConfigs()

// MARK: - Level Configurations

let LEVEL_CONFIGS: [LevelConfig] = loadLevels()

public struct Game1Module: AppModule {
    public let id: UUID = ModuleIDs.game1
    public let displayName: String = "Game 1"
    public let iconName: String = "gamecontroller.fill"
    public let description: String = "Stick figure running game"

    public var order: Int = 0
    public var isVisible: Bool = true
    public var hidesNavBars: Bool { true }

    public var moduleView: AnyView {
        let view = ZStack {
            // Full opaque background to cover everything
            Color(red: 0.95, green: 0.95, blue: 0.98)
                .ignoresSafeArea()
            Game1ModuleView(module: self)
        }
        return AnyView(view)
    }
}

// MARK: - Floating Text

struct FloatingTextItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var text: String
    var color: Color
    var fontSize: CGFloat = 12
    var age: Double = 0
    let lifespan: Double = 2.0
    var isMeditation: Bool = false // Flag for meditation text
}

// MARK: - Catchable Configuration

struct CatchableConfig: Codable {
    let id: String
    let name: String
    let assetName: String?
    let iconName: String?
    let unlockLevel: Int
    let direction: String  // "falls" or "vertical"
    let spins: Bool
    let spinSpeed: Double
    let collisionAnimation: String?  // Optional action animation ID
    let baseSpawnChance: Double
    let baseVerticalSpeed: Double
    let baseVerticalSpeedMax: Double
    let color: String?  // Hex color for SF symbols
    let points: Int
}

/// Loads catchable configurations from catchables.json
func loadCatchables() -> [CatchableConfig] {
    if let url = Bundle.main.url(forResource: "catchables", withExtension: "json"),
       let data = try? Data(contentsOf: url) {
        let decoder = JSONDecoder()
        if let configs = try? decoder.decode([CatchableConfig].self, from: data) {
            print("✅ Successfully loaded \(configs.count) catchable configurations from JSON")
            return configs
        } else {
            print("⚠️ Failed to decode catchables.json")
        }
    } else {
        print("⚠️ Could not find catchables.json in bundle")
    }
    return []
}

// MARK: - Catchable Configurations

let CATCHABLE_CONFIGS: [CatchableConfig] = loadCatchables()

// MARK: - Falling Item

struct FallingItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let itemType: String  // "leaf", "heart", "brain", "sun"
    var x: CGFloat
    var y: CGFloat
    var rotation: Double = 0
    var horizontalVelocity: CGFloat = 0
    var verticalSpeed: CGFloat = 0.003
    
    static func == (lhs: FallingItem, rhs: FallingItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Falling Shaker

struct FallingShaker: Identifiable, Equatable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double = 0
    var verticalSpeed: CGFloat = 0.005
    
    static func == (lhs: FallingShaker, rhs: FallingShaker) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Firework Particle

struct FireworkParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var age: Double = 0
    let lifespan: Double = 1.0
    let color: Color
}

// MARK: - Game State

// MARK: - Stick Figure Game State

@Observable
class StickFigureGameState {
    // Core stats
    var currentLevel: Int = 1
    var currentPoints: Int = 0
    var score: Int = 0
    var highScore: Int = 0
    var timeElapsed: Double = 0
    var allTimeElapsed: Double = 0
    
    // Time tracking - unified system
    private var gameSessionStartTime: Double = 0  // When current app session started
    private var lastSavedTime: Double = 0  // Last time we saved stats
    var catchablesCaught: [String: Int] = [:]  // Dynamic tracking for all catchables by ID
    var totalCoinsCollected: Int = 0
    var actionTimes: [String: Double] = [:]
    var sessionActions: [String] = []
    
    // MARK: - Computed Properties for Backwards Compatibility
    var totalLeavesCaught: Int {
        get { catchablesCaught["leaf"] ?? 0 }
        set { catchablesCaught["leaf"] = newValue }
    }
    var totalHeartsCaught: Int {
        get { catchablesCaught["heart"] ?? 0 }
        set { catchablesCaught["heart"] = newValue }
    }
    var totalBrainsCaught: Int {
        get { catchablesCaught["brain"] ?? 0 }
        set { catchablesCaught["brain"] = newValue }
    }
    var totalSunsCaught: Int {
        get { catchablesCaught["sun"] ?? 0 }
        set { catchablesCaught["sun"] = newValue }
    }
    var totalShakersCaught: Int {
        get { catchablesCaught["shaker"] ?? 0 }
        set { catchablesCaught["shaker"] = newValue }
    }

    // Movement + animation
    var figurePosition: CGFloat = 0
    var isMovingLeft: Bool = false
    var isMovingRight: Bool = false
    var facingRight: Bool = true
    var animationFrame: Int = 0
    var animationTimer: Timer?
    var movementTimer: Timer?
    var lastMovementUpdateTime: Double = 0  // Track when movement was last updated to detect stuck movement

    // Actions
    var selectedAction: String = "Rest"
    var currentAction: String = ""
    var actionStartTime: Double = 0
    var currentPerformingAction: String?
    var actionFrame: Int = 0  // DEPRECATED: Use currentFrameIndex instead
    var currentFrameIndex: Int = 0  // Current frame index in action animation
    var actionFlip: Bool = false
    var lastActionFlip: [String: Bool] = [:]
    var actionTimer: Timer?
    var currentStickFigure: StickFigure2D?  // For rendering custom stick figure animations
    
    // Stick figure animation frames
    var standFrame: StickFigure2D?  // Stand frame
    var moveFrames: [StickFigure2D] = []  // Move frames 1-4
    var shakerFrames: [StickFigure2D] = []  // Shaker frames 1-2
    var shakerFrameObjects: [[AnimationObject]] = []  // Objects for Shaker frames 1-2
    var actionStickFigureFrames: [StickFigure2D] = []  // Current action's stick figure frames
    var actionStickFigureObjects: [[AnimationObject]] = []  // Objects for current action's frames

    // Idle / wave
    var isWaving: Bool = false
    var shouldFlipWave: Bool = false
    var waveFrame: Int = 1
    var waveTimer: Timer?
    var idleTimer: Timer?

    // Floating text + effects
    var floatingTexts: [FloatingTextItem] = []
    var floatingTextTimer: Timer?
    var elapsedTimeTimer: Timer?
    var fireworkParticles: [FireworkParticle] = []
    var actionFloatingTextActionId: String? = nil
    var actionFloatingTextLastTime: Double = 0
    var actionFloatingTextIndex: Int = 0

    // Falling items
    var fallingItems: [FallingItem] = []
    var fallingShakers: [FallingShaker] = []

    // Shaker action
    var isPerformingShaker: Bool = false
    var shakerFrame: Int = 1
    var shakerFlip: Bool = false
    var shakerAnimationTimer: Timer?

    // Meditation tracking
    var meditationTotalDuration: Double = 0
    var meditationTimeRemaining: Double = 0
    var meditationCountdownTimer: Timer?

    // Generic countdown tracking for config-driven countdowns
    var actionCountdownTotalDuration: Double = 0
    var actionCountdownTimeRemaining: Double = 0
    var actionCountdownTimer: Timer?

    // Rest animation tracking
    var restTotalDuration: Double = 0
    var restTimeRemaining: Double = 0
    var restCountdownTimer: Timer?
    var restZzzTimer: Timer?
    var restZzzLastTime: Double = 0

    // Yoga animation tracking
    var yogaTotalDuration: Double = 0
    var yogaTimeRemaining: Double = 0
    var yogaCountdownTimer: Timer?

    // Pullup counting
    var pullupCount: Int = 0
    var pullupCountdownTimer: Timer?
    var lastActionFrame: Int = 0  // Track previous frame for pullup detection
    var lastPullupCounterTime: Double = 0  // Track when last pullup counter was shown
    
    // Generic floating text tracking for actions
    var floatingTextTrackers: [String: FloatingTextTracker] = [:]  // Per-action tracking
    
    // Action completion tracking for floating text
    var lastCompletedAction: String?
    var lastCompletedActionTime: Double = 0
    
    // Periodic points tracking for continuous actions (e.g., Run)
    var periodicPointsLastAwardedTime: Double = 0  // Track when last periodic points were awarded
    
    // Doors
    var doors: [Door] = []

    // Speed boost
    var speedBoostEndTime: Date? = nil
    var speedBoostTimeRemaining: Double {
        guard let endTime = speedBoostEndTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }
    var boostTimerUpdateTrigger = UUID() // Trigger for UI refresh
    var boostTimerRefreshTimer: Timer?
    var boostTimerTick: Int = 0 // Counter for boost timer updates

    // Map return
    var shouldReturnToMap: Bool = false

    private let statsKey = "game1_stats"
    private let highScoreKey = "game1_high_score"
    private let mapPositionKey = "game1_map_position"

    init() {
        loadStats()
        if selectedAction.isEmpty {
            selectedAction = "Rest"
        }
        
        // Initialize time tracking
        gameSessionStartTime = Date().timeIntervalSince1970
        lastSavedTime = gameSessionStartTime
        
        // Start unified time tracking timer
        startUnifiedTimeTimer()
        initializeRoom("level_1")
        startMovementTimer()
        startFloatingTextTimer()
        resetIdleTimer()
    }

    func pointsNeeded(forLevel level: Int) -> Int {
        return max(10, level * 20)
    }

    func recordActionTime(action: String, duration: Double) {
        actionTimes[action, default: 0] += duration
        // Note: timeElapsed and allTimeElapsed are now tracked continuously in the game loop
        // Do not double-count by adding duration here
        if ActionConfig.levelBasedActionIDs(forLevel: currentLevel).contains(action) {
            sessionActions.append(action)
        }
    }

    func addPoints(_ points: Int, action: String) {
        if ActionConfig.levelBasedActionIDs(forLevel: currentLevel).contains(action) {
            if !sessionActions.contains(action) {
                sessionActions.append(action)
            }
        }

        var awarded = points
        let comboCount = getValidComboCount()
        if comboCount > 1 {
            let maxCombo = getMaxComboForLevel(currentLevel)
            let bonusPercent = min(comboCount, maxCombo)
            awarded += Int(Double(points) * (Double(bonusPercent) / 100.0))
        }

        currentPoints += awarded
        score += awarded
        if score > highScore {
            highScore = score
            saveHighScore()
        }
        
        // Track completed action for floating text display in GamePlayArea
        lastCompletedAction = action
        lastCompletedActionTime = Date().timeIntervalSince1970

        let needed = pointsNeeded(forLevel: currentLevel)
        if currentPoints >= needed {
            addFloatingText("Level Complete!", x: 0.5, y: 0.2, color: .purple, fontSize: 18)
            spawnFireworks()
            currentPoints = 0
            sessionActions.removeAll()
            shouldReturnToMap = true
        }
    }

    func getValidComboCount() -> Int {
        let validIDs = ActionConfig.levelBasedActionIDs(forLevel: currentLevel)
        return Set(sessionActions).intersection(validIDs).count
    }

    func getMaxComboForLevel(_ level: Int) -> Int {
        let availableActions = ACTION_CONFIGS.filter { $0.unlockLevel <= level }
        return max(1, availableActions.count)
    }

    func formatTimeDuration(_ milliseconds: Double) -> String {
        let totalSeconds = Int(milliseconds / 1000.0)
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let totalHours = totalMinutes / 60
        let hours = totalHours % 24
        let days = totalHours / 24
        let months = days / 30
        
        if months > 0 {
            let remainingDays = days % 30
            return String(format: "%dmo %dd %02d:%02d:%02d", months, remainingDays, hours, minutes, seconds)
        } else if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        } else if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    func saveStats() {
        let payload: [String: Any] = [
            "currentLevel": currentLevel,
            "currentPoints": currentPoints,
            "score": score,
            "allTimeElapsed": allTimeElapsed,
            "catchablesCaught": catchablesCaught,
            "totalCoinsCollected": totalCoinsCollected,
            "selectedAction": selectedAction,
            "actionTimes": actionTimes
        ]
        UserDefaults.standard.set(payload, forKey: statsKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Unified Time Tracking
    
    private func startUnifiedTimeTimer() {
        // Use a 0.1 second timer to continuously track elapsed time
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Update allTimeElapsed to reflect continuous time
            self.allTimeElapsed += 0.1
            self.timeElapsed += 0.1
            
            // Auto-save every 10 seconds (100 * 0.1 second intervals)
            if Int(self.allTimeElapsed * 10) % 100 == 0 {
                self.saveStats()
            }
        }
    }

    private func loadStats() {
        guard let payload = UserDefaults.standard.dictionary(forKey: statsKey) else { return }
        currentLevel = payload["currentLevel"] as? Int ?? currentLevel
        currentPoints = payload["currentPoints"] as? Int ?? currentPoints
        score = payload["score"] as? Int ?? score
        allTimeElapsed = payload["allTimeElapsed"] as? Double ?? allTimeElapsed
        if let storedCatchables = payload["catchablesCaught"] as? [String: Int] {
            catchablesCaught = storedCatchables
        }
        totalCoinsCollected = payload["totalCoinsCollected"] as? Int ?? totalCoinsCollected
        selectedAction = payload["selectedAction"] as? String ?? selectedAction
        if let storedTimes = payload["actionTimes"] as? [String: Double] {
            actionTimes = storedTimes
        }
        
        // Force "Rest" as the only action available in level 1
        if currentLevel == 1 {
            selectedAction = "Rest"
        }
        
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }
    
    func loadStickFigureFrames() {
        // Load from file-based storage
        let allFrames = AnimationStorage.shared.loadFrames()
        
        print("DEBUG: Found \(allFrames.count) total saved frames")
        allFrames.forEach { frame in
            print("DEBUG: Frame - Name: '\(frame.name)', Number: \(frame.frameNumber)")
        }
        
        // Load Stand frame (frameNumber 0 - as originally saved)
        if let standFrameData = allFrames.first(where: { $0.name == "Stand" && $0.frameNumber == 0 }) {
            standFrame = standFrameData.pose.toStickFigure2D()
            print("DEBUG: ✓ Loaded Stand frame (frameNumber 0)")
        } else {
            print("DEBUG: ✗ Stand frame 0 not found")
        }
        
        // Load Move frames 1-4
        moveFrames = (1...4).compactMap { frameNum in
            if let frame = allFrames.first(where: { $0.name == "Move" && $0.frameNumber == frameNum }) {
                print("DEBUG: ✓ Loaded Move frame \(frameNum)")
                return frame.pose.toStickFigure2D()
            } else {
                print("DEBUG: ✗ Move frame \(frameNum) not found")
                return nil
            }
        }
        print("DEBUG: Loaded \(moveFrames.count) Move frames total")
        
        // Load Shaker frames 1-2
        shakerFrames = []
        shakerFrameObjects = []
        for frameNum in 1...2 {
            if let frame = allFrames.first(where: { $0.name == "Shaker" && $0.frameNumber == frameNum }) {
                print("DEBUG: ✓ Loaded Shaker frame \(frameNum) with \(frame.objects.count) objects")
                shakerFrames.append(frame.pose.toStickFigure2D())
                shakerFrameObjects.append(frame.objects)
            } else {
                print("DEBUG: ✗ Shaker frame \(frameNum) not found")
            }
        }
        print("DEBUG: Loaded \(shakerFrames.count) Shaker frames total")
    }

    func saveHighScore() {
        UserDefaults.standard.set(highScore, forKey: highScoreKey)
    }

    func saveMapPosition(_ mapState: GameMapState) {
        let payload: [String: Any] = [
            "x": Double(mapState.characterX),
            "y": Double(mapState.characterY)
        ]
        UserDefaults.standard.set(payload, forKey: mapPositionKey)
    }

    func loadMapPosition(_ mapState: GameMapState) {
        guard let payload = UserDefaults.standard.dictionary(forKey: mapPositionKey) else { return }
        if let x = payload["x"] as? Double, let y = payload["y"] as? Double {
            mapState.characterX = CGFloat(x)
            mapState.characterY = CGFloat(y)
            mapState.targetX = CGFloat(x)
            mapState.targetY = CGFloat(y)
        }
    }

    func initializeRoom(_ roomId: String) {
        if roomId == "map" {
            doors = []
            return
        }

        doors = [
            Door(
                id: "door_to_map",
                position: .bottom,
                collisionSide: .left,
                destinationRoomId: "map",
                x: 0.85,
                y: 0.2,
                width: 0.12,
                height: 0.18
            )
        ]
    }
    
    // MARK: - Helper: Convert Hex Color to SwiftUI Color
    
    func getColorFromHex(_ hexString: String) -> Color {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return .gray }
        
        let rgbValue = UInt32(hex, radix: 16) ?? 0
        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }

    func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
        isWaving = false
        waveTimer?.invalidate()
        waveTimer = nil

        idleTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.startWaveAnimation()
        }
    }

    private func startWaveAnimation() {
        isWaving = true
        shouldFlipWave = Bool.random()
        waveFrame = 1
        waveTimer?.invalidate()
        var ticks = 0
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            ticks += 1
            self.waveFrame = self.waveFrame == 1 ? 2 : 1
            if ticks >= 10 {
                timer.invalidate()
                self.isWaving = false
                self.waveFrame = 1
                // Restart the idle timer so the wave can play again
                self.resetIdleTimer()
            }
        }
    }

    private func startMovementTimer() {
        movementTimer?.invalidate()
        movementTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            var delta: CGFloat = 0
            if self.isMovingLeft {
                delta = -0.011
            } else if self.isMovingRight {
                delta = 0.011
            }
            
            // Check for stuck movement - if movement has been on for more than 5 seconds without updates, force stop it
            let now = Date().timeIntervalSince1970
            if (self.isMovingLeft || self.isMovingRight) {
                if self.lastMovementUpdateTime == 0 {
                    self.lastMovementUpdateTime = now
                } else if now - self.lastMovementUpdateTime > 5.0 {
                    // Movement is stuck, force stop it
                    self.isMovingLeft = false
                    self.isMovingRight = false
                    if self.currentAction == "move" {
                        let duration = now * 1000 - self.actionStartTime
                        self.recordActionTime(action: "move", duration: duration)
                        self.currentAction = ""
                    }
                    self.stopAnimation(gameState: self)
                    delta = 0
                }
            } else {
                self.lastMovementUpdateTime = 0  // Reset when not moving
            }
            
            if delta != 0 {
                self.lastMovementUpdateTime = now  // Update timestamp whenever we're actively moving
            }
            
            if self.speedBoostTimeRemaining > 0 {
                delta *= 1.5
            }
            if delta != 0 {
                // Allow wrapping - character appears on opposite side when going off-screen
                self.figurePosition = self.figurePosition + delta
                // Wrap around: if position goes beyond -1 or 1, wrap to opposite side
                if self.figurePosition > 1 {
                    self.figurePosition -= 2
                } else if self.figurePosition < -1 {
                    self.figurePosition += 2
                }
            }
        }
    }

    func addFloatingText(_ text: String, x: CGFloat, y: CGFloat, color: Color, fontSize: CGFloat = 12, isMeditation: Bool = false) {
        let item = FloatingTextItem(x: x, y: y, text: text, color: color, fontSize: fontSize, isMeditation: isMeditation)
        floatingTexts.append(item)
    }

    private func startFloatingTextTimer() {
        floatingTextTimer?.invalidate()
        floatingTextTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for i in self.floatingTexts.indices.reversed() {
                self.floatingTexts[i].age += 0.05
                // Meditation text moves slower
                let moveSpeed = self.floatingTexts[i].isMeditation ? 0.003 : 0.01
                self.floatingTexts[i].y -= moveSpeed
                if self.floatingTexts[i].age >= self.floatingTexts[i].lifespan {
                    self.floatingTexts.remove(at: i)
                }
            }
            for i in self.fireworkParticles.indices.reversed() {
                self.fireworkParticles[i].age += 0.05
                self.fireworkParticles[i].x += self.fireworkParticles[i].velocityX * 0.05
                self.fireworkParticles[i].y += self.fireworkParticles[i].velocityY * 0.05
                if self.fireworkParticles[i].age >= self.fireworkParticles[i].lifespan {
                    self.fireworkParticles.remove(at: i)
                }
            }
        }
    }

    private func spawnFireworks() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
        let baseX: CGFloat = 0.5
        let baseY: CGFloat = 0.3
        for i in 0..<20 {
            let angle = Double(i) * (2 * Double.pi / 20)
            let speed: CGFloat = 0.3
            fireworkParticles.append(
                FireworkParticle(
                    x: baseX,
                    y: baseY,
                    velocityX: CGFloat(cos(angle)) * speed,
                    velocityY: CGFloat(sin(angle)) * speed,
                    color: colors[i % colors.count]
                )
            )
        }
    }

    func checkFallingItemCollisions(figureX: CGFloat, figureY: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat) {
        // Spawn falling items based on current level
        let unlockedItems = CATCHABLE_CONFIGS.filter { $0.unlockLevel <= currentLevel }
        let maxItems = max(4, unlockedItems.count * 2)
        
        if fallingItems.count < maxItems && Double.random(in: 0...1) < 0.002 {
            if let itemConfig = unlockedItems.randomElement() {
                let item = FallingItem(
                    itemType: itemConfig.id,
                    x: CGFloat.random(in: 0.05...0.95),
                    y: 0.0,
                    rotation: Double.random(in: 0...360),
                    horizontalVelocity: CGFloat.random(in: -0.002...0.002),
                    verticalSpeed: CGFloat.random(in: itemConfig.baseVerticalSpeed...itemConfig.baseVerticalSpeedMax)
                )
                fallingItems.append(item)
            }
        }
        
        for i in fallingItems.indices.reversed() {
            fallingItems[i].y += fallingItems[i].verticalSpeed
            fallingItems[i].x += fallingItems[i].horizontalVelocity
            
            // Get config to access spinSpeed
            if let config = CATCHABLE_CONFIGS.first(where: { $0.id == fallingItems[i].itemType }), config.spins {
                fallingItems[i].rotation += config.spinSpeed
            }
            
            let itemScreenX = fallingItems[i].x * screenWidth
            let itemScreenY = fallingItems[i].y * screenHeight
            let dx = itemScreenX - figureX
            let characterCollisionY = figureY + 60
            let dy = itemScreenY - characterCollisionY
            
            if sqrt(dx * dx + dy * dy) < 60 {
                // Found the config for this item
                if let config = CATCHABLE_CONFIGS.first(where: { $0.id == fallingItems[i].itemType }) {
                    // Update stats dynamically
                    catchablesCaught[config.id, default: 0] += 1
                    
                    // Trigger collision animation if configured
                    if let animationId = config.collisionAnimation {
                        if let actionConfig = ACTION_CONFIGS.first(where: { $0.id == animationId }) {
                            startAction(actionConfig, gameState: self)
                        }
                    }
                    
                    addPoints(config.points, action: fallingItems[i].itemType)
                    
                    // Get color from hex string in config
                    let pointColor = getColorFromHex(config.color ?? "#808080")
                    addFloatingText("+\(config.points)", x: fallingItems[i].x, y: fallingItems[i].y, color: pointColor)
                }
                fallingItems.remove(at: i)
                continue
            }
            
            if fallingItems[i].y > 1.1 || fallingItems[i].x < -0.2 || fallingItems[i].x > 1.2 {
                fallingItems.remove(at: i)
            }
        }
    }

    func checkShakerCollisions(figureX: CGFloat, figureY: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat) {
        // Use config-driven spawn chance for Shaker
        if let shakerConfig = CATCHABLE_CONFIGS.first(where: { $0.id == "shaker" }) {
            // Allow up to 1 Shaker on screen (same as before, but now respects low spawn chance)
            if fallingShakers.count < 1 && Double.random(in: 0...1) < shakerConfig.baseSpawnChance {
                let shaker = FallingShaker(
                    x: CGFloat.random(in: 0.1...0.9),
                    y: 0.0,
                    rotation: Double.random(in: 0...360),
                    verticalSpeed: shakerConfig.baseVerticalSpeed
                )
                fallingShakers.append(shaker)
            }
        }

        for i in fallingShakers.indices.reversed() {
            fallingShakers[i].y += fallingShakers[i].verticalSpeed
            fallingShakers[i].rotation += 6

            let shakerScreenX = fallingShakers[i].x * screenWidth
            let shakerScreenY = fallingShakers[i].y * screenHeight
            let dx = shakerScreenX - figureX
            // Collision detection at the bottom/feet of character (60 pixels below top of collision box)
            let characterCollisionY = figureY + 60
            let dy = shakerScreenY - characterCollisionY
            if sqrt(dx * dx + dy * dy) < 60 {
                totalShakersCaught += 1
                addPoints(5, action: "shaker")
                addFloatingText("Boost!", x: fallingShakers[i].x, y: fallingShakers[i].y, color: .orange)
                fallingShakers.remove(at: i)

                speedBoostEndTime = Date().addingTimeInterval(6)
                // Start boost timer refresh for UI updates
                boostTimerRefreshTimer?.invalidate()
                boostTimerRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                    guard let self = self else { return }
                    if self.speedBoostTimeRemaining <= 0 {
                        timer.invalidate()
                        self.boostTimerRefreshTimer = nil
                    }
                    // Increment tick to trigger view updates
                    self.boostTimerTick += 1
                }
                triggerShakerAnimation()
                continue
            }

            if fallingShakers[i].y > 1.1 {
                fallingShakers.remove(at: i)
            }
        }
    }

    private func triggerShakerAnimation() {
        shakerAnimationTimer?.invalidate()
        isPerformingShaker = true
        shakerFlip = Bool.random()
        shakerFrame = 1
        
        // Animation: show frame 1 briefly, then frame 2 for 1 second
        var animationStage = 0
        
        shakerAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            animationStage += 1
            
            if animationStage == 1 {
                // Show frame 1 for 0.1 seconds
                self.shakerFrame = 1
            } else if animationStage == 2 {
                // Show frame 2 starting at 0.2 seconds
                self.shakerFrame = 2
            } else if animationStage >= 12 {
                // After 1.2 seconds total (frame 2 for 1 second), complete animation
                timer.invalidate()
                self.shakerAnimationTimer = nil
                self.isPerformingShaker = false
                self.shakerFrame = 1
                // Trigger fireworks when shaker animation completes
                self.spawnFireworks()
            }
        }
    }

    func checkDoorCollision(figureX: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat, isMovingRight: Bool, isMovingLeft: Bool, animatedDoorY: CGFloat) -> Door? {
        for door in doors {
            let doorScreenX = door.x * screenWidth
            let doorWidth = door.width * screenWidth
            let doorHeight = door.height * screenHeight
            let doorScreenY = animatedDoorY

            let withinX = abs(figureX - doorScreenX) < (doorWidth * 0.5)
            let doorNearGround = doorScreenY >= (screenHeight - doorHeight - 60)
            let doorVisible = doorScreenY >= 0 && doorScreenY <= screenHeight // Door must be on screen
            let movingIntoDoor = (door.collisionSide == .left && isMovingRight) || (door.collisionSide == .right && isMovingLeft)

            if withinX && doorNearGround && doorVisible && movingIntoDoor {
                return door
            }
        }
        return nil
    }

    // MARK: - Animation Helper Functions

    func startAnimation(gameState: StickFigureGameState) {
        gameState.animationTimer?.invalidate()
        var frameCount = 0
        gameState.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.13, repeats: true) { _ in
            frameCount += 1
            gameState.animationFrame = ((frameCount - 1) % 4) + 1
        }
    }
    
    func stopAnimation(gameState: StickFigureGameState) {
        gameState.animationTimer?.invalidate()
        gameState.animationTimer = nil
        gameState.animationFrame = 0
    }
    
    func startMovingLeft(gameState: StickFigureGameState, geometry: GeometryProxy) {
        // Check if movement is allowed for current action
        if let currentAction = gameState.currentPerformingAction,
           let config = ACTION_CONFIGS.first(where: { $0.id == currentAction }),
           !config.allowMovement {
            return
        }
        
        gameState.resetIdleTimer()
        
        // If "Run" is selected and no action is currently performing, start Run action
        if gameState.selectedAction == "Run" && gameState.currentPerformingAction == nil {
            if let runConfig = ACTION_CONFIGS.first(where: { $0.id == "run" }) {
                startAction(runConfig, gameState: gameState)
            }
            // Initialize periodic points tracker
            gameState.periodicPointsLastAwardedTime = 0
        }
        
        if gameState.currentAction != "move" {
            gameState.currentAction = "move"
            gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
        }
        gameState.isMovingLeft = true
        gameState.isMovingRight = false
        gameState.facingRight = false
        if gameState.animationFrame == 0 {
            startAnimation(gameState: gameState)
        }
    }
    
    func stopMovingLeft(gameState: StickFigureGameState) {
        gameState.isMovingLeft = false
        if !gameState.isMovingRight {
            if gameState.currentAction == "move" {
                let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                gameState.recordActionTime(action: "move", duration: duration)
                gameState.currentAction = ""
            }
            // Clear Run action when movement stops
            if gameState.currentPerformingAction == "run" {
                gameState.currentPerformingAction = nil
                gameState.periodicPointsLastAwardedTime = 0
            }
            stopAnimation(gameState: gameState)
        }
    }
    
    func startMovingRight(gameState: StickFigureGameState, geometry: GeometryProxy) {
        // Check if movement is allowed for current action
        if let currentAction = gameState.currentPerformingAction,
           let config = ACTION_CONFIGS.first(where: { $0.id == currentAction }),
           !config.allowMovement {
            return
        }
        
        gameState.resetIdleTimer()
        
        // If "Run" is selected and no action is currently performing, start Run action
        if gameState.selectedAction == "Run" && gameState.currentPerformingAction == nil {
            if let runConfig = ACTION_CONFIGS.first(where: { $0.id == "run" }) {
                startAction(runConfig, gameState: gameState)
            }
            // Initialize periodic points tracker
            gameState.periodicPointsLastAwardedTime = 0
        }
        
        if gameState.currentAction != "move" {
            gameState.currentAction = "move"
            gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
        }
        gameState.isMovingRight = true
        gameState.isMovingLeft = false
        gameState.facingRight = true
        if gameState.animationFrame == 0 {
            startAnimation(gameState: gameState)
        }
    }
    
    func stopMovingRight(gameState: StickFigureGameState) {
        gameState.isMovingRight = false
        if !gameState.isMovingLeft {
            if gameState.currentAction == "move" {
                let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                gameState.recordActionTime(action: "move", duration: duration)
                gameState.currentAction = ""
            }
            // Clear Run action when movement stops
            if gameState.currentPerformingAction == "run" {
                gameState.currentPerformingAction = nil
                gameState.periodicPointsLastAwardedTime = 0
            }
            stopAnimation(gameState: gameState)
        }
    }
    
    // MARK: - Helper: Calculate Animation Duration
    
    /// Calculates the total duration of an action animation based on its frame count and timing
    private func calculateAnimationDuration(config: ActionConfig) -> Double {
        guard let sfConfig = config.stickFigureAnimation else { return 0 }
        let frameCount = Double(sfConfig.frameNumbers.count)
        let baseInterval = sfConfig.baseFrameInterval
        return frameCount * baseInterval
    }
    
    func startAction(_ config: ActionConfig, gameState: StickFigureGameState) {
        // Stop other animations
        gameState.animationTimer?.invalidate()
        gameState.actionTimer?.invalidate()
        
        // Set up action state
        gameState.currentPerformingAction = config.id
        gameState.currentFrameIndex = 0
        
        // Load stick figure frames if this action has a stick figure animation
        if let sfConfig = config.stickFigureAnimation {
            gameState.actionStickFigureFrames = sfConfig.loadFrames()
            gameState.actionStickFigureObjects = sfConfig.loadObjects()
            // Set the first frame as current
            if let firstFrame = gameState.actionStickFigureFrames.first {
                gameState.currentStickFigure = firstFrame
            }
        } else {
            gameState.actionStickFigureFrames = []
            gameState.actionStickFigureObjects = []
            gameState.currentStickFigure = nil
        }
        
        // Handle flip based on flipMode
        switch config.flipMode {
        case .none:
            gameState.actionFlip = false
        case .random:
            gameState.actionFlip = Bool.random()
        case .alternating:
            // Toggle the flip state for this action
            let currentFlip = gameState.lastActionFlip[config.id] ?? false
            gameState.lastActionFlip[config.id] = !currentFlip
            gameState.actionFlip = !currentFlip
        }
        
        let actionStartTime = Date().timeIntervalSince1970 * 1000
        
        // Start config-driven countdown timer if enabled
        if config.countdown == true {
            let duration = calculateAnimationDuration(config: config)
            gameState.actionCountdownTotalDuration = duration
            gameState.actionCountdownTimeRemaining = duration
            gameState.actionCountdownTimer?.invalidate()
            gameState.actionCountdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak gameState] _ in
                guard let gameState = gameState else { return }
                gameState.actionCountdownTimeRemaining = max(0, gameState.actionCountdownTimeRemaining - 0.1)
                if gameState.actionCountdownTimeRemaining <= 0 {
                    gameState.actionCountdownTimer?.invalidate()
                    gameState.actionCountdownTimer = nil
                }
            }
        }
        
        // Handle variable timing (like pushups)
        if let variableTiming = config.variableTiming {
            startActionWithVariableTiming(config, gameState: gameState, variableTiming: variableTiming, startTime: actionStartTime)
        } else {
            startActionWithUniformTiming(config, gameState: gameState, startTime: actionStartTime)
        }
    }
    
    private func startActionWithUniformTiming(_ config: ActionConfig, gameState: StickFigureGameState, startTime: Double) {
        var frameIndex = 0
        let speedMultiplier = (config.supportsSpeedBoost && gameState.speedBoostTimeRemaining > 0) ? 0.5 : 1.0
        let baseInterval = config.stickFigureAnimation?.baseFrameInterval ?? 0.15
        let interval = baseInterval * speedMultiplier
        
        gameState.actionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if frameIndex < gameState.actionStickFigureFrames.count {
                // Update stick figure frame
                if frameIndex < gameState.actionStickFigureFrames.count {
                    gameState.currentStickFigure = gameState.actionStickFigureFrames[frameIndex]
                }
                
                gameState.lastActionFrame = frameIndex
                gameState.currentFrameIndex = frameIndex
                
                frameIndex += 1
            } else {
                gameState.actionTimer?.invalidate()
                gameState.actionTimer = nil
                let currentAction = gameState.currentPerformingAction
                gameState.currentPerformingAction = nil
                gameState.currentFrameIndex = 0
                gameState.actionFlip = false
                gameState.currentStickFigure = nil
                
                // Clean up floating text tracker for this action
                if let action = currentAction {
                    gameState.floatingTextTrackers.removeValue(forKey: action)
                }
                
                let duration = Date().timeIntervalSince1970 * 1000 - startTime
                gameState.recordActionTime(action: config.id, duration: duration)
                
                if gameState.currentLevel >= config.unlockLevel {
                    gameState.addPoints(config.pointsPerCompletion, action: config.id)
                }
            }
        }
    }
    
    private func startActionWithVariableTiming(_ config: ActionConfig, gameState: StickFigureGameState, variableTiming: [Int: TimeInterval], startTime: Double) {
        var frameIndex = 0
        let speedMultiplier = (config.supportsSpeedBoost && gameState.speedBoostTimeRemaining > 0) ? 0.5 : 1.0
        
        // Initialize config-driven floating text state
        var floatingTextIndex = 0
        var nextFloatingTextTime = config.floatingText?.timing ?? 0
        var elapsedTime = 0.0
        
        func scheduleNextFrame() {
            guard frameIndex < gameState.actionStickFigureFrames.count else {
                gameState.actionTimer?.invalidate()
                gameState.actionTimer = nil
                let currentAction = gameState.currentPerformingAction
                gameState.currentPerformingAction = nil
                gameState.currentFrameIndex = 0
                gameState.actionFlip = false
                gameState.currentStickFigure = nil
                
                // Clean up floating text tracker for this action
                if let action = currentAction {
                    gameState.floatingTextTrackers.removeValue(forKey: action)
                }
                
                let duration = Date().timeIntervalSince1970 * 1000 - startTime
                gameState.recordActionTime(action: config.id, duration: duration)
                
                if gameState.currentLevel >= config.unlockLevel {
                    gameState.addPoints(config.pointsPerCompletion, action: config.id)
                }
                return
            }
            
            // Update stick figure frame
            if frameIndex < gameState.actionStickFigureFrames.count {
                gameState.currentStickFigure = gameState.actionStickFigureFrames[frameIndex]
            }
            
            gameState.lastActionFrame = frameIndex
            
            // Handle config-driven floating text
            if let floatingTextConfig = config.floatingText, let texts = floatingTextConfig.text, !texts.isEmpty {
                if elapsedTime >= nextFloatingTextTime {
                    let text: String
                    if floatingTextConfig.random ?? false {
                        // Random selection
                        text = texts.randomElement() ?? texts[0]
                    } else {
                        // Sequential selection
                        text = texts[floatingTextIndex % texts.count]
                        floatingTextIndex += 1
                    }
                    gameState.addFloatingText(text, x: 0.5, y: 0.65, color: .blue, fontSize: 20, isMeditation: true)
                    nextFloatingTextTime += floatingTextConfig.timing ?? 5.0
                }
            }
            
            gameState.lastActionFrame = frameIndex
            gameState.currentFrameIndex = frameIndex
            frameIndex += 1
            
            // Use the base frame interval for timing from stick figure animation config
            let baseInterval = config.stickFigureAnimation?.baseFrameInterval ?? 0.15
            let interval = baseInterval * speedMultiplier
            elapsedTime += interval
            
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                scheduleNextFrame()
            }
        }
        
        scheduleNextFrame()
    }
}

// MARK: - Game State

// MARK: - Level Box for Map

struct LevelBox: Identifiable {
    let id = UUID()
    let levelNumber: Int
    let x: CGFloat // Center X position on map
    let y: CGFloat // Center Y position on map
    let width: CGFloat
    let height: CGFloat
    
    var isCompleted: Bool = false
    var isAvailable: Bool = true
}

// MARK: - Tree Structure

struct MapTree: Identifiable {
    let id = UUID()
    let x: CGFloat // Position on map
    let y: CGFloat // Position on map
    let size: CGFloat // Size multiplier (0.8 to 1.5)
}

// MARK: - Coin Structure

struct MapCoin {
    var x: CGFloat // Position on map
    var y: CGFloat // Position on map
    var isVisible: Bool = true
    var lastCollectedTime: Date? = nil
}

// MARK: - Game Map State

@Observable
class GameMapState {
    var characterX: CGFloat = 0
    var characterY: CGFloat = 0
    var targetX: CGFloat = 0
    var targetY: CGFloat = 0
    var isMoving: Bool = false
    var isTouchActive: Bool = false
    var animationFrame: Int = 1
    var characterRotation: Double = 0
    var mapOffsetX: CGFloat = 0
    var mapOffsetY: CGFloat = 0
    var levelBoxes: [LevelBox] = []
    var trees: [MapTree] = []
    var coin: MapCoin? = nil
    var mapFloatingTexts: [FloatingTextItem] = []
    var selectedLevelNumber: Int? = nil
    var animationTimer: Timer? = nil
    var movementTimer: Timer? = nil
    var floatingTextTimer: Timer? = nil
    var doorAnimationTimer: Timer? = nil
    var doorY: CGFloat = -200 // Starting position (above screen)
    var isDoorAnimating: Bool = false
    
    let mapWidth: CGFloat = 2000
    let mapHeight: CGFloat = 2000
    let characterSpeed: CGFloat = 200 // pixels per second
    
    init() {
        // Set initial character position to center of map
        characterX = mapWidth / 2
        characterY = mapHeight / 2
        targetX = mapWidth / 2
        targetY = mapHeight / 2
        initializeLevelBoxes()
        generateCoin()
    }
    
    func initializeLevelBoxes(currentLevel: Int = 1) {
        // Create level boxes from LEVEL_CONFIGS data
        var boxes: [LevelBox] = []
        
        for levelConfig in LEVEL_CONFIGS {
            // Level is completed if player has passed it
            let isCompleted = levelConfig.id < currentLevel
            // Level is available if it's completed, currently playing, or next unlocked level
            let isAvailable = levelConfig.id <= currentLevel
            
            boxes.append(LevelBox(
                levelNumber: levelConfig.id,
                x: levelConfig.mapX,
                y: levelConfig.mapY,
                width: levelConfig.width,
                height: levelConfig.height,
                isCompleted: isCompleted,
                isAvailable: isAvailable
            ))
        }
        
        levelBoxes = boxes.sorted { $0.levelNumber < $1.levelNumber }
        // Don't reset character position here - let the view control it
        
        // Generate trees after level boxes are created
        generateTrees()
    }
    
    func generateTrees() {
        var newTrees: [MapTree] = []
        let treeCount = 250 // Number of trees to generate
        let minDistanceFromLevelBox: CGFloat = 100 // Minimum distance from level boxes
        let minDistanceFromPath: CGFloat = 60 // Minimum distance from paths between levels
        let edgeMargin: CGFloat = 100 // Keep trees away from edges
        
        // Generate random trees
        for _ in 0..<treeCount {
            var attempts = 0
            let maxAttempts = 50
            
            while attempts < maxAttempts {
                // Random position on map
                let x = CGFloat.random(in: edgeMargin...(mapWidth - edgeMargin))
                let y = CGFloat.random(in: edgeMargin...(mapHeight - edgeMargin))
                
                // Check if too close to any level box
                var tooClose = false
                for box in levelBoxes {
                    let dx = x - box.x
                    let dy = y - box.y
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance < minDistanceFromLevelBox {
                        tooClose = true
                        break
                    }
                }
                
                // Check if too close to paths between consecutive levels
                if !tooClose {
                    for i in 0..<(levelBoxes.count - 1) {
                        let box1 = levelBoxes[i]
                        let box2 = levelBoxes[i + 1]
                        
                        // Calculate distance from point to line segment
                        let distanceToPath = distanceFromPointToLineSegment(
                            px: x, py: y,
                            x1: box1.x, y1: box1.y,
                            x2: box2.x, y2: box2.y
                        )
                        
                        if distanceToPath < minDistanceFromPath {
                            tooClose = true
                            break
                        }
                    }
                }
                
                if !tooClose {
                    // Random size variation
                    let size = CGFloat.random(in: 0.8...1.5)
                    newTrees.append(MapTree(x: x, y: y, size: size))
                    break
                }
                
                attempts += 1
            }
        }
        
        trees = newTrees
    }
    
    // Helper function to calculate distance from a point to a line segment
    func distanceFromPointToLineSegment(px: CGFloat, py: CGFloat, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        
        if dx == 0 && dy == 0 {
            // Line segment is a point
            let dpx = px - x1
            let dpy = py - y1
            return sqrt(dpx * dpx + dpy * dpy)
        }
        
        // Calculate projection factor
        let t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)))
        
        // Find closest point on line segment
        let closestX = x1 + t * dx
        let closestY = y1 + t * dy
        
        // Return distance to closest point
        let dpx = px - closestX
        let dpy = py - closestY
        return sqrt(dpx * dpx + dpy * dpy)
    }
    
    func generateCoin() {
        let minDistanceFromSpawn: CGFloat = 500
        let spawnX = mapWidth / 2
        let spawnY = mapHeight / 2
        let edgeMargin: CGFloat = 100
        
        var attempts = 0
        let maxAttempts = 100
        
        // Load last collected time from UserDefaults
        let timestamp = UserDefaults.standard.double(forKey: "game1_coin_last_collected_time")
        var lastCollectedTime: Date? = nil
        if timestamp > 0 {
            lastCollectedTime = Date(timeIntervalSince1970: timestamp)
        }
        
        // Check if 12 hours have passed since last collection
        var shouldBeVisible = true
        if let lastCollected = lastCollectedTime {
            let twelveHoursInSeconds: TimeInterval = 12 * 60 * 60
            let timeSinceCollection = Date().timeIntervalSince(lastCollected)
            shouldBeVisible = timeSinceCollection >= twelveHoursInSeconds
        }
        
        while attempts < maxAttempts {
            // Random position on map
            let x = CGFloat.random(in: edgeMargin...(mapWidth - edgeMargin))
            let y = CGFloat.random(in: edgeMargin...(mapHeight - edgeMargin))
            
            // Check distance from spawn point
            let dx = x - spawnX
            let dy = y - spawnY
            let distanceFromSpawn = sqrt(dx * dx + dy * dy)
            
            if distanceFromSpawn >= minDistanceFromSpawn {
                coin = MapCoin(x: x, y: y, isVisible: shouldBeVisible, lastCollectedTime: lastCollectedTime)
                break
            }
            
            attempts += 1
        }
        
        // Fallback if no valid position found
        if coin == nil {
            coin = MapCoin(x: 200, y: 200, isVisible: shouldBeVisible, lastCollectedTime: lastCollectedTime)
        }
    }
    
    func checkCoinCollision() -> Bool {
        guard let coin = coin, coin.isVisible else { return false }
        
        let dx = characterX - coin.x
        let dy = characterY - coin.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Collision radius
        return distance < 40
    }
    
    func collectCoin() {
        coin?.isVisible = false
        coin?.lastCollectedTime = Date()
        
        // Save the collection time
        saveCoinLastCollectedTime()
        
        // Add floating text at character position with darker color for readability
        addMapFloatingText("Yessssss!", x: characterX, y: characterY + 30, color: .black, fontSize: 20)
        
        // Regenerate coin only after 12 hours
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Check if 12 hours have passed
            if let lastCollected = self.coin?.lastCollectedTime {
                let twelveHoursInSeconds: TimeInterval = 12 * 60 * 60
                let timeSinceCollection = Date().timeIntervalSince(lastCollected)
                
                if timeSinceCollection >= twelveHoursInSeconds {
                    // 12 hours passed, generate new coin
                    self.generateCoin()
                }
                // If less than 12 hours, coin stays invisible
            } else {
                // No last collected time, generate coin
                self.generateCoin()
            }
        }
    }
    
    func saveCoinLastCollectedTime() {
        if let lastCollectedTime = coin?.lastCollectedTime {
            UserDefaults.standard.set(lastCollectedTime.timeIntervalSince1970, forKey: "game1_coin_last_collected_time")
        }
    }
    
    func loadCoinLastCollectedTime() {
        let timestamp = UserDefaults.standard.double(forKey: "game1_coin_last_collected_time")
        if timestamp > 0 {
            coin?.lastCollectedTime = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    func getCoinTimeRemaining() -> TimeInterval? {
        guard let lastCollected = coin?.lastCollectedTime else { return nil }
        let twelveHoursInSeconds: TimeInterval = 12 * 60 * 60
        let timeSinceCollection = Date().timeIntervalSince(lastCollected)
        let remaining = twelveHoursInSeconds - timeSinceCollection
        return remaining > 0 ? remaining : nil
    }
    
    func addMapFloatingText(_ text: String, x: CGFloat, y: CGFloat, color: Color, fontSize: CGFloat = 12) {
        let floatingText = FloatingTextItem(x: x, y: y, text: text, color: color, fontSize: fontSize)
        mapFloatingTexts.append(floatingText)
    }
    
    func updateMapFloatingTexts(deltaTime: Double) {
        for i in mapFloatingTexts.indices.reversed() {
            mapFloatingTexts[i].age += deltaTime
            mapFloatingTexts[i].y -= 20 * deltaTime // Move upward
            
            if mapFloatingTexts[i].age >= mapFloatingTexts[i].lifespan {
                mapFloatingTexts.remove(at: i)
            }
        }
    }
    
    func startDoorSliding() {
        isDoorAnimating = true
        doorY = -200 // Reset to top of screen
        doorAnimationTimer?.invalidate()
        
        doorAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.doorY += 8 // Slide down at constant speed
            
            // Loop back to top when door goes off bottom of screen
            if self.doorY > 900 {
                self.doorY = -200
            }
        }
    }
    
    func stopDoorSliding() {
        isDoorAnimating = false
        doorAnimationTimer?.invalidate()
        doorAnimationTimer = nil
        doorY = -200 // Reset position
    }
    
    func moveCharacterTowards(_ targetX: CGFloat, _ targetY: CGFloat, deltaTime: CGFloat) {
        let dx = targetX - characterX
        let dy = targetY - characterY
        let distance = sqrt(dx * dx + dy * dy)
        
        // Stop when close to target AND touch is released
        if distance < 20 && !isTouchActive {
            isMoving = false
            return
        }
        
        // Don't move if already at target
        if distance < 1 {
            isMoving = false
            return
        }
        
        isMoving = true
        let moveDistance = characterSpeed * deltaTime
        
        // Don't overshoot the target
        let actualMoveDistance = min(moveDistance, distance)
        let moveX = (dx / distance) * actualMoveDistance
        let moveY = (dy / distance) * actualMoveDistance
        
        characterX += moveX
        characterY += moveY
        
        // Update rotation to face direction
        characterRotation = atan2(dy, dx) * 180 / .pi
    }
    
    func updateMapOffset(screenWidth: CGFloat, screenHeight: CGFloat) {
        // Keep character centered - pan map so character stays in middle of screen
        mapOffsetX = characterX - (screenWidth / 2)
        mapOffsetY = characterY - (screenHeight / 2)
        
        // Note: We don't clamp here anymore since character is always centered on screen
        // The level boxes will just pan off-screen naturally at edges
    }
    
    func checkLevelBoxCollision() -> Int? {
        for box in levelBoxes {
            let dx = characterX - box.x
            let dy = characterY - box.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < box.width / 2 {
                return box.levelNumber
            }
        }
        return nil
    }
}

// MARK: - Stat Row Component

private struct StatRow: View {
    let label: String
    let value: String
    var isUnlocked: Bool = true
    var isCurrentLevel: Bool = false
    var unlocksAt: Int? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .foregroundColor(isUnlocked ? .black : Color.gray.opacity(0.4))
                if let unlockLevel = unlocksAt, !isUnlocked {
                    Text("Unlocks at Level \(unlockLevel)")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            Spacer()
            Text(value)
                .fontWeight(isCurrentLevel ? .semibold : .regular)
                .foregroundColor(isUnlocked ? .black : Color.gray.opacity(0.4))
        }
    }
}

// MARK: - Stats List Content Helper

private struct StatsListContent: View {
    @Bindable var gameState: StickFigureGameState
    var showLevelPicker: Binding<Bool>
    var onResetData: () -> Void
    
    var body: some View {
        List {
            StatRow(label: "Level", value: "\(gameState.currentLevel)")
            StatRow(label: "Current Points", value: "\(gameState.currentPoints)/\(gameState.pointsNeeded(forLevel: gameState.currentLevel))")
            StatRow(label: "Time Elapsed", value: gameState.formatTimeDuration(gameState.timeElapsed * 1000))
            StatRow(label: "All Time Elapsed", value: gameState.formatTimeDuration(gameState.allTimeElapsed * 1000))
            Divider()
            Text("Catchables (Always Available)")
                .font(.headline)
                .foregroundColor(.primary)
            StatRow(label: "Leaves", value: "\(gameState.totalLeavesCaught) caught", isUnlocked: true)
            StatRow(label: "Hearts", value: "\(gameState.totalHeartsCaught) caught", isUnlocked: gameState.currentLevel >= 4, unlocksAt: 4)
            StatRow(label: "Brains", value: "\(gameState.totalBrainsCaught) caught", isUnlocked: gameState.currentLevel >= 7, unlocksAt: 7)
            StatRow(label: "Suns", value: "\(gameState.totalSunsCaught) caught", isUnlocked: gameState.currentLevel >= 10, unlocksAt: 10)
            StatRow(label: "Shakers", value: "\(gameState.totalShakersCaught) caught", isUnlocked: true)
            StatRow(label: "Coins", value: "\(gameState.totalCoinsCollected) collected", isUnlocked: true)
            Divider()
            Text("Actions & Points")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Dynamically generate action rows from config
            ForEach(ACTION_CONFIGS, id: \.id) { config in
                let timeValue = gameState.actionTimes[config.id] ?? 0
                let isCurrentLevel = config.unlockLevel == 1
                StatRow(
                    label: "Lvl \(config.unlockLevel): \(config.displayName)",
                    value: gameState.formatTimeDuration(timeValue),
                    isUnlocked: gameState.currentLevel >= config.unlockLevel,
                    isCurrentLevel: isCurrentLevel
                )
            }
            
            Divider()
            Text("Combo Boost")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Mix different level-based actions (Rest, Run, Jump, Yoga, Bicep Curls, Kettlebell Swings, Push Ups, Pull Ups, Meditation) in one session for a bonus! 2 actions = +2%, 3 actions = +3%, etc. Max combo = your current level. Leaves & shakers give points but don't count toward combo.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 2)
            Divider()
            Text("Developer Debug")
                .font(.subheadline)
                .foregroundColor(.red)
            
            HStack {
                Text("Set Level:")
                    .foregroundColor(.gray)
                Spacer()
                Button(action: { showLevelPicker.wrappedValue = true }) {
                    HStack(spacing: 6) {
                        Text("Level \(gameState.currentLevel)")
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: onResetData) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Reset All Game Data")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(8)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Stats Overlay View (Unified for all screens)

struct StatsOverlayView: View {
    var gameState: StickFigureGameState
    var mapState: GameMapState
    var showStats: Binding<Bool>
    var showLevelPicker: Binding<Bool>
    var showProgrammableDemo: Binding<Bool>
    
    var body: some View {
        if showStats.wrappedValue {
            VStack(spacing: 0) {
                HStack {
                    Text("Statistics")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()
                    
                    Button(action: { showStats.wrappedValue = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(Color.white)

                StatsListContent(
                    gameState: gameState,
                    showLevelPicker: showLevelPicker,
                    onResetData: {
                        // Reset all game data
                        gameState.currentLevel = 1
                        gameState.currentPoints = 0
                        gameState.selectedAction = "Rest"
                        gameState.sessionActions.removeAll()
                        gameState.actionTimes.removeAll()
                        gameState.catchablesCaught.removeAll()
                        gameState.totalCoinsCollected = 0
                        gameState.allTimeElapsed = 0
                        gameState.timeElapsed = 0
                        gameState.score = 0
                        gameState.highScore = 0
                        gameState.saveStats()
                        gameState.saveHighScore()
                        
                        // Clear coin last collected time
                        UserDefaults.standard.removeObject(forKey: "game1_coin_last_collected_time")
                        
                        // Reinitialize map level boxes after reset
                        mapState.initializeLevelBoxes(currentLevel: 1)
                        
                        // Regenerate coin (will be visible since no collection time)
                        mapState.generateCoin()
                        
                        // Position character next to level 1
                        if mapState.levelBoxes.count > 0 {
                            let level1Box = mapState.levelBoxes[0]
                            let offset: CGFloat = 100
                            mapState.characterX = level1Box.x - offset
                            mapState.characterY = level1Box.y
                            mapState.targetX = level1Box.x - offset
                            mapState.targetY = level1Box.y
                        }
                    }
                )

                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 12)
            .padding(.top, 50)
            .transition(.move(edge: .bottom))
            .onAppear {
                print("📊 STATS OVERLAY APPEARED - Timer status: \(gameState.elapsedTimeTimer != nil)")
            }
        }
    }
}

// MARK: - Game 1 Module View

private struct Game1ModuleView: View {
    let module: Game1Module
    @State private var gameState = StickFigureGameState()
    @State private var mapState = GameMapState()
    @State private var showGameMap = true
    @State private var hasInitializedMap = false
    @State private var isTouchActive = false
    @State private var lastTouchLocation: CGPoint = .zero
    @State private var lastProcessedTouchLocation: CGPoint = .zero
    @State private var targetSetForCurrentPress = false
    @State private var showStats = false
    @State private var showActionPicker = false
    @State private var showLevelPicker = false
    @State private var showDoor = false
    @State private var boostTimerUpdateTrigger = UUID() // Trigger for boost timer refresh
    @State private var showProgrammableDemo = false // NEW: Toggle for stick figure editor
    @Environment(ModuleState.self) var moduleState
    @Environment(\.scenePhase) var scenePhase

    @ViewBuilder
    var body: some View {
        Group {
            if showProgrammableDemo {
                ZStack {
                    Color.white.ignoresSafeArea()
                    
                    StickFigure2DEditorView(onDismiss: {
                        showProgrammableDemo = false
                    })
                }
            } else if showGameMap {
                mapScreen
            } else {
                gameplayScreen
            }
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            // Save game state when app goes to background or is about to terminate
            if newValue == .background || newValue == .inactive {
                print("🎮 App going to background/inactive - Saving game state")
                gameState.saveStats()
            }
        }
    }
    
    private var mapScreen: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar - Fixed at top
                HStack {
                        Button(action: {
                            // Save map position before exiting
                            gameState.saveMapPosition(mapState)
                            // Save stats immediately on exit
                            gameState.saveStats()
                            moduleState.selectModule(ModuleIDs.dashboard)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text("Exit")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("Level \(gameState.currentLevel)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            GeometryReader { geometry in
                                let pointsNeeded = gameState.pointsNeeded(forLevel: gameState.currentLevel)
                                let progress = min(CGFloat(gameState.currentPoints) / CGFloat(pointsNeeded), 1.0)
                                
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: geometry.size.width * progress, height: 8)
                                }
                            }
                            .frame(width: 120, height: 8)
                            
                            Text("\(gameState.currentPoints)/\(gameState.pointsNeeded(forLevel: gameState.currentLevel))")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                        
                        Spacer()
                        
                        Button(action: {
                            showStats.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                Text("Stats")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            showProgrammableDemo = true
                        }) {
                            Image(systemName: "figure.stand")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                        }
                    }
                    .padding(12)
                    .padding(.top, 50)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.98))
                    .zIndex(1000)
                    
                    // Map area
                    GeometryReader { geometry in
                        ZStack {
                            Rectangle()
                                .fill(Color(red: 0.85, green: 0.95, blue: 0.85))
                            
                            // Draw connection lines between levels
                            connectionLinesView(mapState: mapState)
                            
                            // Draw trees
                            ForEach(mapState.trees) { tree in
                                let screenX = tree.x - mapState.mapOffsetX
                                let screenY = tree.y - mapState.mapOffsetY
                                
                                Text("🌲")
                                    .font(.system(size: 30 * tree.size))
                                    .position(x: screenX, y: screenY)
                            }
                            
                            // Draw coin
                            if let coin = mapState.coin, coin.isVisible {
                                let coinScreenX = coin.x - mapState.mapOffsetX
                                let coinScreenY = coin.y - mapState.mapOffsetY
                                
                                Text("🪙")
                                    .font(.system(size: 40))
                                    .position(x: coinScreenX, y: coinScreenY)
                                    .shadow(color: .yellow.opacity(0.6), radius: 10)
                            }
                            
                            // Level boxes - manually create boxes without ForEach
                            ZStack {
                                // Level 1
                                let box1 = mapState.levelBoxes.count > 0 ? mapState.levelBoxes[0] : nil
                                if let box = box1 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 2
                                let box2 = mapState.levelBoxes.count > 1 ? mapState.levelBoxes[1] : nil
                                if let box = box2 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 3
                                let box3 = mapState.levelBoxes.count > 2 ? mapState.levelBoxes[2] : nil
                                if let box = box3 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 4
                                let box4 = mapState.levelBoxes.count > 3 ? mapState.levelBoxes[3] : nil
                                if let box = box4 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 5
                                let box5 = mapState.levelBoxes.count > 4 ? mapState.levelBoxes[4] : nil
                                if let box = box5 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 6
                                let box6 = mapState.levelBoxes.count > 5 ? mapState.levelBoxes[5] : nil
                                if let box = box6 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 7
                                let box7 = mapState.levelBoxes.count > 6 ? mapState.levelBoxes[6] : nil
                                if let box = box7 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 8
                                let box8 = mapState.levelBoxes.count > 7 ? mapState.levelBoxes[7] : nil
                                if let box = box8 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 9
                                let box9 = mapState.levelBoxes.count > 8 ? mapState.levelBoxes[8] : nil
                                if let box = box9 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                                
                                // Level 10
                                let box10 = mapState.levelBoxes.count > 9 ? mapState.levelBoxes[9] : nil
                                if let box = box10 {
                                    let screenX = box.x - mapState.mapOffsetX
                                    let screenY = box.y - mapState.mapOffsetY
                                    VStack {
                                        Text("Level \(box.levelNumber)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(box.isAvailable && !box.isCompleted ? .black : .white)
                                    }
                                    .frame(width: box.width, height: box.height)
                                    .background(box.isCompleted ? Color.green : (box.isAvailable ? Color.white : Color.gray))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(box.isAvailable && !box.isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .position(x: screenX, y: screenY)
                                }
                            }
                            
                            // Character - always render at center of screen for smooth experience
                            VStack {
                                Spacer()
                                Image("topview\(mapState.animationFrame)")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .rotationEffect(.degrees(mapState.characterRotation + 90))
                                Spacer()
                            }
                            .frame(width: 50, height: 50)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            
                            // Floating text on map
                            ForEach(mapState.mapFloatingTexts) { floatingText in
                                let screenX = floatingText.x - mapState.mapOffsetX
                                let screenY = floatingText.y - mapState.mapOffsetY
                                
                                Text(floatingText.text)
                                    .font(.system(size: floatingText.fontSize, weight: .bold))
                                    .foregroundColor(floatingText.color)
                                    .opacity(1.0 - (floatingText.age / floatingText.lifespan))
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                                    .position(x: screenX, y: screenY)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    mapState.isTouchActive = true
                                    
                                    // Only process if map is initialized
                                    if !hasInitializedMap {
                                        return
                                    }
                                    
                                    // Update target only if finger has moved significantly from last processed location
                                    let touchDx = value.location.x - lastProcessedTouchLocation.x
                                    let touchDy = value.location.y - lastProcessedTouchLocation.y
                                    let touchDist = sqrt(touchDx * touchDx + touchDy * touchDy)
                                    
                                    if touchDist > 30 || lastProcessedTouchLocation == .zero {
                                        lastProcessedTouchLocation = value.location
                                        
                                        // Convert to world coordinates
                                        let tapWorldX = value.location.x + mapState.mapOffsetX
                                        let tapWorldY = value.location.y + mapState.mapOffsetY
                                        
                                        mapState.targetX = tapWorldX
                                        mapState.targetY = tapWorldY
                                        mapState.isMoving = true
                                    }
                                }
                                .onEnded { _ in
                                    mapState.isTouchActive = false
                                    lastTouchLocation = .zero
                                    lastProcessedTouchLocation = .zero
                                    targetSetForCurrentPress = false
                                }
                        )
                        .onAppear {
                            // Reinitialize level boxes based on current progress
                            mapState.initializeLevelBoxes(currentLevel: gameState.currentLevel)
                            
                            // Only set character position on first load, not when returning from level
                            if !hasInitializedMap {
                                // Try to load saved position
                                gameState.loadMapPosition(mapState)
                                
                                // If no saved position (loadMapPosition will check), set default
                                if mapState.characterX == mapState.mapWidth / 2 && mapState.characterY == mapState.mapHeight / 2 {
                                    // Center character NEXT TO the current/highest unlocked level (not on top of it)
                                    if gameState.currentLevel <= mapState.levelBoxes.count {
                                        let targetBox = mapState.levelBoxes[gameState.currentLevel - 1]
                                        // Position character to the left of the level box with offset
                                        let offset: CGFloat = 100 // Distance from level box
                                        mapState.characterX = targetBox.x - offset
                                        mapState.characterY = targetBox.y
                                        mapState.targetX = targetBox.x - offset
                                        mapState.targetY = targetBox.y
                                    } else {
                                        // Fallback: center on map
                                        mapState.characterX = mapState.mapWidth / 2
                                        mapState.characterY = mapState.mapHeight / 2
                                        mapState.targetX = mapState.mapWidth / 2
                                        mapState.targetY = mapState.mapHeight / 2
                                    }
                                }
                                hasInitializedMap = true
                            }
                            
                            mapState.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                                mapState.moveCharacterTowards(mapState.targetX, mapState.targetY, deltaTime: 0.08)
                                mapState.updateMapOffset(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                                mapState.updateMapFloatingTexts(deltaTime: 0.08)
                                
                                if mapState.isMoving {
                                    mapState.animationFrame = mapState.animationFrame == 2 ? 3 : 2
                                } else {
                                    mapState.animationFrame = 1
                                }
                                
                                if let levelNumber = mapState.checkLevelBoxCollision() {
                                    let levelBox = mapState.levelBoxes[levelNumber - 1]
                                    // Only allow entry if available AND not completed
                                    if levelBox.isAvailable && !levelBox.isCompleted {
                                        gameState.currentLevel = levelNumber
                                        gameState.initializeRoom("level_\(levelNumber)")
                                        gameState.figurePosition = 0
                                        showDoor = false // Hide door by default when entering room
                                        showGameMap = false // Switch to gameplay view
                                        mapState.animationTimer?.invalidate()
                                        mapState.animationTimer = nil
                                        // Don't clear elapsedTimeTimer here - let gameplayScreen handle it
                                    }
                                }
                                
                                // Check coin collision
                                if mapState.checkCoinCollision() {
                                    gameState.currentPoints += 100
                                    gameState.totalCoinsCollected += 1
                                    mapState.collectCoin()
                                    
                                    // Check if level up occurred on map
                                    let pointsNeeded = gameState.pointsNeeded(forLevel: gameState.currentLevel)
                                    if gameState.currentPoints >= pointsNeeded {
                                        // Level up on map
                                        let nextLevel = gameState.currentLevel + 1
                                        
                                        // Show level up message
                                        if let newAction = ACTION_CONFIGS.first(where: { $0.unlockLevel == nextLevel }) {
                                            let message = "Level \(nextLevel)!\n\(newAction.displayName) Unlocked!"
                                            mapState.addMapFloatingText(message, x: mapState.characterX, y: mapState.characterY - 50, color: .purple, fontSize: 24)
                                            gameState.selectedAction = newAction.displayName
                                        } else {
                                            mapState.addMapFloatingText("Level \(nextLevel)!", x: mapState.characterX, y: mapState.characterY - 50, color: .purple, fontSize: 24)
                                        }
                                        
                                        // Reset points and increment level
                                        gameState.currentPoints = 0
                                        gameState.currentLevel = nextLevel
                                        
                                        // Update map level boxes for new level
                                        if gameState.currentLevel - 1 > 0 && gameState.currentLevel - 1 <= mapState.levelBoxes.count {
                                            var updatedBoxes = mapState.levelBoxes
                                            updatedBoxes[gameState.currentLevel - 2].isCompleted = true
                                            
                                            if gameState.currentLevel - 1 < updatedBoxes.count {
                                                updatedBoxes[gameState.currentLevel - 1].isAvailable = true
                                            }
                                            
                                            mapState.levelBoxes = updatedBoxes
                                        }
                                        
                                        gameState.saveStats()
                                    }
                                }
                            }
                            
                            // Timer is managed by mapScreen.onAppear and gameplayScreen.onAppear
                        }
                        .onDisappear {
                            print("❌ TIMER CLEARED at mapScreen GeometryReader disappear")
                            mapState.animationTimer?.invalidate()
                            mapState.animationTimer = nil
                            // Don't clear elapsedTimeTimer here - each screen manages its own timer
                        }
                }
            }
            
            // ...existing code...
            // Unified stats overlay
            StatsOverlayView(
                gameState: gameState,
                mapState: mapState,
                showStats: $showStats,
                showLevelPicker: $showLevelPicker,
                showProgrammableDemo: $showProgrammableDemo
            )
            .zIndex(100)
            
            if showLevelPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showLevelPicker = false
                    }
                    .zIndex(200)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("Select Level")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: { showLevelPicker = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        
                        VStack(spacing: 0) {
                            let maxLevel = ACTION_CONFIGS.map { $0.unlockLevel }.max() ?? 7
                            ForEach(1...maxLevel, id: \.self) { level in
                                if level > 1 {
                                    Divider()
                                }
                                ActionPickerButton(title: "Level \(level)", isSelected: gameState.currentLevel == level) {
                                    gameState.currentLevel = level
                                    gameState.currentPoints = 0
                                    gameState.saveStats()
                                    // Reinitialize map level boxes after level change
                                    mapState.initializeLevelBoxes(currentLevel: level)
                                    showLevelPicker = false
                                }
                            }
                        }
                        .background(Color.white)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                }
                .transition(.move(edge: .bottom))
                .zIndex(201)
            }
        }
        .onAppear {
            // Unified timer is now managed in gameState init and runs continuously
            print("🗺️  MAP SCREEN APPEARED - Unified timer is running")
        }
        .onDisappear {
            print("❌ MAP SCREEN DISAPPEARED")
            // Save stats when map screen disappears
            gameState.saveStats()
        }
    }
    
    private var gameplayScreen: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        gameState.animationTimer?.invalidate()
                        gameState.floatingTextTimer?.invalidate()
                        // DO NOT invalidate elapsedTimeTimer - it's the unified continuous timer
                        gameState.idleTimer?.invalidate()
                        gameState.waveTimer?.invalidate()
                        gameState.actionTimer?.invalidate()
                        gameState.shakerAnimationTimer?.invalidate()
                        gameState.sessionActions.removeAll() // Reset combo for next session
                        gameState.timeElapsed = 0 // Reset session time elapsed
                        gameState.fireworkParticles.removeAll() // Clear any lingering fireworks
                        gameState.saveStats()
                        
                        // Save the current level to map position for restoration
                        if gameState.currentLevel <= mapState.levelBoxes.count {
                            let currentLevelBox = mapState.levelBoxes[gameState.currentLevel - 1]
                            // Position character below the level they were working on
                            mapState.characterX = currentLevelBox.x
                            mapState.characterY = currentLevelBox.y + 150
                            gameState.saveMapPosition(mapState)
                        }
                        
                        moduleState.selectModule(ModuleIDs.dashboard)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Exit")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                    }

                    Spacer()
                    
                    // Level and Progress Bar
                    VStack(spacing: 4) {
                        Text("Level \(gameState.currentLevel)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        GeometryReader { geometry in
                            let pointsNeeded = gameState.pointsNeeded(forLevel: gameState.currentLevel)
                            let progress = min(CGFloat(gameState.currentPoints) / CGFloat(pointsNeeded), 1.0)
                            
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * progress, height: 8)
                            }
                        }
                        .frame(width: 120, height: 8)
                        
                        Text("\(gameState.currentPoints)/\(gameState.pointsNeeded(forLevel: gameState.currentLevel))")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Combo Boost Bar - Fixed height container
                        ZStack {
                            if gameState.getValidComboCount() > 1 {
                                let maxCombo = gameState.getMaxComboForLevel(gameState.currentLevel)
                                let comboCount = min(gameState.getValidComboCount(), maxCombo)
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)
                                    Text("Bonus: \(comboCount)%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.yellow)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.8))
                                .cornerRadius(4)
                                .padding(.top, 4)
                            }
                        }
                        .frame(height: 26)
                        .padding(.top, 0)
                        
                        // Speed Boost Timer - Fixed height container
                        ZStack {
                            if gameState.speedBoostEndTime != nil && gameState.speedBoostTimeRemaining > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)
                                    Text(String(format: "Boost: %.1fs", gameState.speedBoostTimeRemaining))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.yellow)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.8))
                                .cornerRadius(4)
                                .padding(.top, 4)
                                .id(gameState.boostTimerTick) // Force refresh when tick changes
                            }
                        }
                        .frame(height: 26)
                        .padding(.top, 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)

                    Spacer()

                    Button(action: {
                        showStats.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                            Text("Stats")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                    }
                }
                .padding(12)
                .padding(.top, 60)

                GamePlayArea(
                    gameState: gameState,
                    mapState: mapState,
                    showGameMap: $showGameMap,
                    showDoor: $showDoor,
                    startMovingLeftAction: { gs, geo in gs.startMovingLeft(gameState: gs, geometry: geo) },
                    stopMovingLeftAction: { gs in gs.stopMovingLeft(gameState: gs) },
                    startMovingRightAction: { gs, geo in gs.startMovingRight(gameState: gs, geometry: geo) },
                    stopMovingRightAction: { gs in gs.stopMovingRight(gameState: gs) },
                    startActionAction: { config, gs in gs.startAction(config, gameState: gs) }
                )
                .frame(height: 500)
                
                // Movement buttons with action selector in center
                VStack(spacing: 4) {
                    HStack(spacing: 12) {
                        // Left button - only available in level 2+
                        if gameState.currentLevel >= 2 {
                            Button(action: {}) {
                                Image(systemName: "arrowshape.left.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray)
                                    .cornerRadius(6)
                            }
                            .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                                
                                if isPressing {
                                    gameState.resetIdleTimer()
                                    if gameState.currentAction != "move" {
                                        gameState.currentAction = "move"
                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                    }
                                    gameState.isMovingLeft = true
                                    gameState.isMovingRight = false
                                    gameState.facingRight = false
                                    if gameState.animationFrame == 0 {
                                        gameState.startAnimation(gameState: gameState)
                                    }
                                } else {
                                    gameState.isMovingLeft = false
                                    if !gameState.isMovingRight {
                                        if gameState.currentAction == "move" {
                                            let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                                            gameState.recordActionTime(action: "move", duration: duration)
                                            gameState.currentAction = ""
                                        }
                                        gameState.stopAnimation(gameState: gameState)
                                    }
                                }
                            }, perform: {})
                        } else {
                            // Spacer in level 1 where left button would be
                            Spacer()
                                .frame(width: 40, height: 40)
                        }
                        
                        // Action button in center
                        VStack(spacing: 4) {
                            Text("Action")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showActionPicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Text(gameState.selectedAction)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right button - only available in level 2+
                        if gameState.currentLevel >= 2 {
                            Button(action: {}) {
                                Image(systemName: "arrowshape.right.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray)
                                    .cornerRadius(6)
                            }
                            .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                                
                                if isPressing {
                                    gameState.resetIdleTimer()
                                    if gameState.currentAction != "move" {
                                        gameState.currentAction = "move"
                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                    }
                                    gameState.isMovingRight = true
                                    gameState.isMovingLeft = false
                                    gameState.facingRight = true
                                    if gameState.animationFrame == 0 {
                                        gameState.startAnimation(gameState: gameState)
                                    }
                                } else {
                                    gameState.isMovingRight = false
                                    if !gameState.isMovingLeft {
                                        if gameState.currentAction == "move" {
                                            let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                                            gameState.recordActionTime(action: "move", duration: duration)
                                            gameState.currentAction = ""
                                        }
                                        gameState.stopAnimation(gameState: gameState)
                                    }
                                }
                            }, perform: {})
                        } else {
                            // Spacer in level 1 where right button would be
                            Spacer()
                                .frame(width: 40, height: 40)
                        }
                    }
                    .padding(.horizontal, 12)
                    
                    Spacer()
                        .frame(height: 12)
                    
                    Button(action: {
                        mapState.startDoorSliding()
                        showDoor = true
                    }) {
                        Text("Exit Room")
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(6)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 12)
                .background(Color(red: 0.95, green: 0.95, blue: 0.98))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            if showActionPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showActionPicker = false
                    }
                    .zIndex(200)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("Select Action")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: { showActionPicker = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        
                        VStack(spacing: 0) {
                            // Dynamically generate action buttons from config
                            ForEach(Array(ACTION_CONFIGS.enumerated()), id: \.element.id) { index, config in
                                if index > 0 {
                                    Divider()
                                }
                                
                                if gameState.currentLevel >= config.unlockLevel {
                                    ActionPickerButton(
                                        title: config.displayName,
                                        isSelected: gameState.selectedAction == config.displayName
                                    ) {
                                        gameState.selectedAction = config.displayName
                                        gameState.resetIdleTimer()
                                        showActionPicker = false
                                    }
                                }
                            }
                        }
                        .background(Color.white)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                }
                .transition(.move(edge: .bottom))
                .zIndex(201)
            }

            if showLevelPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showLevelPicker = false
                    }
                    .zIndex(200)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("Select Level")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: { showLevelPicker = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        
                        VStack(spacing: 0) {
                            let maxLevel = ACTION_CONFIGS.map { $0.unlockLevel }.max() ?? 7
                            ForEach(1...maxLevel, id: \.self) { level in
                                if level > 1 {
                                    Divider()
                                }
                                ActionPickerButton(title: "Level \(level)", isSelected: gameState.currentLevel == level) {
                                    gameState.currentLevel = level
                                    gameState.currentPoints = 0
                                    gameState.saveStats()
                                    // Reinitialize map level boxes after level change
                                    mapState.initializeLevelBoxes(currentLevel: level)
                                    showLevelPicker = false
                                }
                            }
                        }
                        .background(Color.white)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                }
                .transition(.move(edge: .bottom))
                .zIndex(202)
            }

            // Unified stats overlay
            StatsOverlayView(
                gameState: gameState,
                mapState: mapState,
                showStats: $showStats,
                showLevelPicker: $showLevelPicker,
                showProgrammableDemo: $showProgrammableDemo
            )
            .zIndex(100)
        }
        .onAppear {
            // Unified timer is now managed in gameState init and runs continuously
            print("🎮 GAMEPLAY SCREEN APPEARED - Unified timer is running")
        }
        .onDisappear {
            print("🎮 GAMEPLAY SCREEN DISAPPEARED")
            // Save stats when gameplay screen disappears
            gameState.saveStats()
        }
        .onChange(of: gameState.shouldReturnToMap) { oldValue, newValue in
            if newValue {
                // Delay to show the "Level Complete" message before returning
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Increment level now that we're returning
                    gameState.currentLevel += 1
                    
                    // Auto-select the highest-level action available for the new level
                    let availableActions = ACTION_CONFIGS.filter { $0.unlockLevel <= gameState.currentLevel }
                    if let highestAction = availableActions.max(by: { $0.unlockLevel < $1.unlockLevel }) {
                        gameState.selectedAction = highestAction.displayName
                    }
                    
                    // Update map level boxes for new level
                    mapState.initializeLevelBoxes(currentLevel: gameState.currentLevel)
                    
                    // Position character below the level they just completed
                    let completedLevel = gameState.currentLevel - 1
                    if completedLevel > 0 && completedLevel <= mapState.levelBoxes.count {
                        let levelBox = mapState.levelBoxes[completedLevel - 1]
                        mapState.characterX = levelBox.x
                        mapState.characterY = levelBox.y + 150
                        mapState.targetX = levelBox.x
                        mapState.targetY = levelBox.y + 150
                    }
                    
                    showGameMap = true
                    gameState.shouldReturnToMap = false
                }
            }
        }
    }
    
    func connectionLinesView(mapState: GameMapState) -> some View {
        ZStack {
            let levelBoxes = mapState.levelBoxes.sorted { $0.levelNumber < $1.levelNumber }
            
            ForEach(0..<levelBoxes.count - 1, id: \.self) { index in
                let from = levelBoxes[index]
                let to = levelBoxes[index + 1]
                
                drawConnectionLine(from: from, to: to, mapState: mapState)
            }
        }
    }
    
    func drawConnectionLine(from: LevelBox, to: LevelBox, mapState: GameMapState) -> some View {
        let fromScreenX = from.x - mapState.mapOffsetX
        let fromScreenY = from.y - mapState.mapOffsetY
        let toScreenX = to.x - mapState.mapOffsetX
        let toScreenY = to.y - mapState.mapOffsetY
        
        return Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: fromScreenX, y: fromScreenY))
            path.addLine(to: CGPoint(x: toScreenX, y: toScreenY))
            
            let stroke = StrokeStyle(lineWidth: 2, dash: [5, 5])
            context.stroke(path, with: .color(.blue.opacity(0.5)), style: stroke)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Action Picker Button

private struct ActionPickerButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game Play Area

private struct GamePlayArea: View {
    @Bindable var gameState: StickFigureGameState
    var mapState: GameMapState
    @Binding var showGameMap: Bool
    @Binding var showDoor: Bool
    @State private var collisionTimer: Timer?

    var startMovingLeftAction: (StickFigureGameState, GeometryProxy) -> Void
    var stopMovingLeftAction: (StickFigureGameState) -> Void
    var startMovingRightAction: (StickFigureGameState, GeometryProxy) -> Void
    var stopMovingRightAction: (StickFigureGameState) -> Void
    var startActionAction: (ActionConfig, StickFigureGameState) -> Void

    private func getStandImage() -> String {
        if gameState.selectedAction == "Bicep Curls" {
            return "curls1"
        } else {
            return "guy_stand"
        }
    }

    @ViewBuilder
    private func renderShakerObject(_ object: AnimationObject, baseToGameScaleX: CGFloat, baseToGameScaleY: CGFloat) -> some View {
        if let uiImage = UIImage(named: object.imageName) {
            // Objects are stored in base canvas coordinates (600x720)
            // Convert to game canvas coordinates for rendering
            let gamePosX = object.position.x * baseToGameScaleX
            let gamePosY = object.position.y * baseToGameScaleY

            // Calculate scaled object dimensions
            let objWidth = 50 * object.scale * baseToGameScaleX
            let objHeight = 50 * object.scale * baseToGameScaleY

            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: objWidth, height: objHeight)
                .rotationEffect(.degrees(object.rotation))
                .position(x: gamePosX, y: gamePosY)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let figureX = ((gameState.figurePosition + 1.0) / 2.0) * geometry.size.width
            let baseY = geometry.size.height - 80
            let figureY = baseY
            let textStartY = max(0.05, (baseY - 120) / geometry.size.height)
            let normX = figureX / geometry.size.width
            
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                            if gameState.currentLevel >= 2 {
                                if isPressing {
                                    startMovingLeftAction(gameState, geometry)
                                } else {
                                    stopMovingLeftAction(gameState)
                                }
                            }
                        }, perform: {})

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                            if gameState.currentLevel >= 2 {
                                if isPressing {
                                    startMovingRightAction(gameState, geometry)
                                } else {
                                    stopMovingRightAction(gameState)
                                }
                            }
                        }, perform: {})
                }

                VStack {
                    Spacer()

                    // Generic action rendering
                    if let actionId = gameState.currentPerformingAction,
                       let _ = ACTION_CONFIGS.first(where: { $0.id == actionId }) {
                        // Use stick figure if available
                        if let stickFigure = gameState.currentStickFigure {
                            let gameCanvasSize = CGSize(width: 150, height: 225)
                            
                            // Get current frame index
                            let frameIndex = gameState.currentFrameIndex
                            let frameObjects = frameIndex >= 0 && frameIndex < gameState.actionStickFigureObjects.count ? gameState.actionStickFigureObjects[frameIndex] : []
                                
                            ZStack {
                                StickFigure2DView(figure: stickFigure, canvasSize: gameCanvasSize)
                                
                                // Render objects
                                Group {
                                    if frameObjects.count > 0 {
                                        let object = frameObjects[0]
                                        if object.imageName == "line" {
                                            // Render line object
                                            let baseCanvasSize = CGSize(width: 600, height: 720)
                                            let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
                                            let canvasCenter = CGPoint(x: gameCanvasSize.width / 2, y: gameCanvasSize.height / 2)
                                            let canvasScale = gameCanvasSize.width / baseCanvasSize.width
                                            
                                            let dx = object.position.x - baseCenter.x
                                            let dy = object.position.y - baseCenter.y
                                            let gamePosX = canvasCenter.x + dx * canvasScale * stickFigure.scale
                                            let gamePosY = canvasCenter.y + dy * canvasScale * stickFigure.scale
                                            
                                            let objWidth = 50 * object.scale * canvasScale * stickFigure.scale
                                            
                                            Line()
                                                .stroke(Color.black, lineWidth: (2 + (object.scale * 3)) * canvasScale * stickFigure.scale)
                                                .frame(width: objWidth, height: max(1, (2 + (object.scale * 3)) * canvasScale * stickFigure.scale))
                                                .rotationEffect(.degrees(object.rotation))
                                                .position(x: gamePosX, y: gamePosY)
                                        } else if let uiImage = UIImage(named: object.imageName) {
                                            // Render image object
                                            let baseCanvasSize = CGSize(width: 600, height: 720)
                                            let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
                                            let canvasCenter = CGPoint(x: gameCanvasSize.width / 2, y: gameCanvasSize.height / 2)
                                            let canvasScale = gameCanvasSize.width / baseCanvasSize.width
                                            
                                            let dx = object.position.x - baseCenter.x
                                            let dy = object.position.y - baseCenter.y
                                            let gamePosX = canvasCenter.x + dx * canvasScale * stickFigure.scale
                                            let gamePosY = canvasCenter.y + dy * canvasScale * stickFigure.scale
                                            
                                            let objWidth = 50 * object.scale * canvasScale * stickFigure.scale
                                            
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: objWidth, height: objWidth)
                                                .rotationEffect(.degrees(object.rotation))
                                                .position(x: gamePosX, y: gamePosY)
                                        }
                                    }
                                }
                            }
                            .frame(width: gameCanvasSize.width, height: gameCanvasSize.height)
                            .scaleEffect(x: gameState.actionFlip ? -1 : 1, y: 1)
                            .position(x: figureX, y: figureY)
                            .onTapGesture {
                                // Ignore extra taps during animation
                            }
                        } else {
                            // No frame found - show placeholder
                            Text("?")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 150)
                                .position(x: figureX, y: figureY)
                                .onTapGesture {
                                    // Ignore extra taps during animation
                                }
                        }
                    } else if gameState.isPerformingShaker {
                        // Shaker animation - show frame 1 or 2
                        let frameIndex = gameState.shakerFrame - 1  // Convert 1-based to 0-based
                        if frameIndex >= 0 && frameIndex < gameState.shakerFrames.count {
                            // Canvas dimensions:
                            // - Objects are stored in base canvas coordinates (600x720)
                            // - Game renders in 150x225
                            let gameCanvasSize = CGSize(width: 150, height: 225)
                            
                            // Get the objects for this frame
                            let frameObjects = frameIndex < gameState.shakerFrameObjects.count ? gameState.shakerFrameObjects[frameIndex] : []
                            let shakerFigure = gameState.shakerFrames[frameIndex]
                            let shouldFlip = gameState.shakerFlip
                            
                            ZStack {
                                // Render the stick figure
                                StickFigure2DView(figure: shakerFigure, canvasSize: gameCanvasSize)
                                
                                // Render each object manually (without ForEach to avoid closure issues)
                                Group {
                                    if frameObjects.count > 0 {
                                        let object = frameObjects[0]
                                        
                                        // Apply the same coordinate transformation as the stick figure
                                        let baseCanvasSize = CGSize(width: 600, height: 720)
                                        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
                                        let canvasCenter = CGPoint(x: gameCanvasSize.width / 2, y: gameCanvasSize.height / 2)
                                        let canvasScale = gameCanvasSize.width / baseCanvasSize.width
                                        
                                        // Transform object position: same formula as stick figure
                                        let dx = object.position.x - baseCenter.x
                                        let dy = object.position.y - baseCenter.y
                                        let gamePosX = canvasCenter.x + dx * canvasScale * shakerFigure.scale
                                        let gamePosY = canvasCenter.y + dy * canvasScale * shakerFigure.scale
                                        
                                        // Scale object size by the same factors
                                        let objWidth = 50 * object.scale * canvasScale * shakerFigure.scale
                                        let objHeight = 50 * object.scale * canvasScale * shakerFigure.scale
                                        
                                        if object.imageName == "line" {
                                            // Render line object
                                            Line()
                                                .stroke(Color.black, lineWidth: (2 + (object.scale * 3)) * canvasScale * shakerFigure.scale)
                                                .frame(width: objWidth, height: max(1, (2 + (object.scale * 3)) * canvasScale * shakerFigure.scale))
                                                .rotationEffect(.degrees(object.rotation))
                                                .position(x: gamePosX, y: gamePosY)
                                        } else if let uiImage = UIImage(named: object.imageName) {
                                            // Render image object
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: objWidth, height: objHeight)
                                                .rotationEffect(.degrees(object.rotation))
                                                .position(x: gamePosX, y: gamePosY)
                                        }
                                    }
                                    if frameObjects.count > 1 {
                                        let object = frameObjects[1]
                                        
                                        // Apply the same coordinate transformation as the stick figure
                                        let baseCanvasSize = CGSize(width: 600, height: 720)
                                        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
                                        let canvasCenter = CGPoint(x: gameCanvasSize.width / 2, y: gameCanvasSize.height / 2)
                                        let canvasScale = gameCanvasSize.width / baseCanvasSize.width
                                        
                                        // Transform object position: same formula as stick figure
                                        let dx = object.position.x - baseCenter.x
                                        let dy = object.position.y - baseCenter.y
                                        let gamePosX = canvasCenter.x + dx * canvasScale * shakerFigure.scale
                                        let gamePosY = canvasCenter.y + dy * canvasScale * shakerFigure.scale
                                        
                                        // Scale object size by the same factors
                                        let objWidth = 50 * object.scale * canvasScale * shakerFigure.scale
                                        let objHeight = 50 * object.scale * canvasScale * shakerFigure.scale
                                        
                                        if object.imageName == "line" {
                                            // Render line object
                                            Line()
                                                .stroke(Color.black, lineWidth: (2 + (object.scale * 3)) * canvasScale * shakerFigure.scale)
                                                .frame(width: objWidth, height: max(1, (2 + (object.scale * 3)) * canvasScale * shakerFigure.scale))
                                                .rotationEffect(.degrees(object.rotation))
                                                .position(x: gamePosX, y: gamePosY)
                                        } else if let uiImage = UIImage(named: object.imageName) {
                                            // Render image object
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: objWidth, height: objHeight)
                                                .rotationEffect(.degrees(object.rotation))
                                                .position(x: gamePosX, y: gamePosY)
                                        }
                                    }
                                }
                            }
                            .frame(width: gameCanvasSize.width, height: gameCanvasSize.height)
                            .scaleEffect(x: shouldFlip ? -1 : 1, y: 1)
                            .position(x: figureX, y: figureY)
                            .onTapGesture {
                                // Ignore extra taps during animation
                            }
                        } else {
                            // No Shaker frame - show placeholder
                            Text("?")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 150)
                                .position(x: figureX, y: figureY)
                                .onTapGesture {
                                    // Ignore extra taps during animation
                                }
                        }
                    } else if gameState.isWaving {
                        // Wave animation - load from animations.json
                        if gameState.waveFrame >= 1 && gameState.waveFrame <= 2 {
                            let allFrames = AnimationStorage.shared.loadFrames()
                            if let waveFrameData = allFrames.first(where: { $0.name == "Wave" && $0.frameNumber == gameState.waveFrame }) {
                                let waveFigure = waveFrameData.pose.toStickFigure2D()
                                StickFigure2DView(figure: waveFigure, canvasSize: CGSize(width: 150, height: 225))
                                    .frame(width: 150, height: 225)
                                    .scaleEffect(x: gameState.shouldFlipWave ? -1 : 1, y: 1)
                                    .position(x: figureX, y: figureY)
                            } else {
                                // Fallback if frames not found
                                Text("?")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                    .frame(width: 100, height: 150)
                                    .position(x: figureX, y: figureY)
                            }
                        } else {
                            Text("?")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 150)
                                .position(x: figureX, y: figureY)
                        }
                    } else {
                        // Standing or Moving - use stick figure frames
                        if gameState.animationFrame == 0 {
                            // Standing - use Stand frame
                            if let standFrame = gameState.standFrame {
                                StickFigure2DView(figure: standFrame, canvasSize: CGSize(width: 150, height: 225))
                                    .frame(width: 150, height: 225)
                                    .scaleEffect(x: gameState.facingRight ? 1 : -1, y: 1)
                                    .position(x: figureX, y: figureY)
                                    .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                                        if isPressing {
                                            // Gesture started - check where user tapped
                                            // We'll use a state variable to track if this was a valid movement tap
                                            // For now, we just need to start movement if they tapped left/right
                                            // But we need the tap location, which we can't get from onLongPressGesture alone
                                            // So we'll need to combine with another gesture
                                        } else {
                                            // User released - stop movement
                                            gameState.isMovingLeft = false
                                            gameState.isMovingRight = false
                                            if gameState.currentAction == "move" {
                                                let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                                                gameState.recordActionTime(action: "move", duration: duration)
                                                gameState.currentAction = ""
                                            }
                                            gameState.stopAnimation(gameState: gameState)
                                        }
                                    }, perform: {})
                                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            // 10px center area (5px on each side) triggers action via gesture end
                                            if distanceFromCenter > 5 {
                                                if tapX < figureX && gameState.currentLevel >= 2 {
                                                    // Tapped left - trigger left movement
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingLeft = true
                                                    gameState.isMovingRight = false
                                                    gameState.facingRight = false
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                } else if tapX >= figureX && gameState.currentLevel >= 2 {
                                                    // Tapped right - trigger right movement
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingRight = true
                                                    gameState.isMovingLeft = false
                                                    gameState.facingRight = true
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            // Check if tap was in center 10px area
                                            if distanceFromCenter <= 5 && gameState.isMovingLeft == false && gameState.isMovingRight == false {
                                                // Tapped center - trigger action
                                                if gameState.selectedAction == "Jump" {
                                                    if let config = ACTION_CONFIGS.first(where: { $0.id == "jump" }) {
                                                        startActionAction(config, gameState)
                                                    }
                                                } else if let config = ACTION_CONFIGS.first(where: { $0.displayName == gameState.selectedAction }) {
                                                    if gameState.currentPerformingAction == nil {
                                                        startActionAction(config, gameState)
                                                    }
                                                }
                                            }
                                        }
                                    )
                            } else {
                                // No Stand frame - show placeholder
                                Text("?")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                    .frame(width: 100, height: 150)
                                    .position(x: figureX, y: figureY)
                                    .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                                        if !isPressing {
                                            // User released - stop movement
                                            gameState.isMovingLeft = false
                                            gameState.isMovingRight = false
                                            if gameState.currentAction == "move" {
                                                let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                                                gameState.recordActionTime(action: "move", duration: duration)
                                                gameState.currentAction = ""
                                            }
                                            gameState.stopAnimation(gameState: gameState)
                                        }
                                    }, perform: {})
                                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            if distanceFromCenter > 5 {
                                                if tapX < figureX && gameState.currentLevel >= 2 {
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingLeft = true
                                                    gameState.isMovingRight = false
                                                    gameState.facingRight = false
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                } else if tapX >= figureX && gameState.currentLevel >= 2 {
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingRight = true
                                                    gameState.isMovingLeft = false
                                                    gameState.facingRight = true
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            if distanceFromCenter <= 5 && gameState.isMovingLeft == false && gameState.isMovingRight == false {
                                                if gameState.selectedAction == "Jump" {
                                                    if let config = ACTION_CONFIGS.first(where: { $0.id == "jump" }) {
                                                        startActionAction(config, gameState)
                                                    }
                                                } else if let config = ACTION_CONFIGS.first(where: { $0.displayName == gameState.selectedAction }) {
                                                    if gameState.currentPerformingAction == nil {
                                                        startActionAction(config, gameState)
                                                    }
                                                }
                                            }
                                        }
                                    )
                            }
                        } else {
                            // Moving - use Move frames
                            let moveIndex = gameState.animationFrame - 1
                            if moveIndex >= 0 && moveIndex < gameState.moveFrames.count {
                                StickFigure2DView(figure: gameState.moveFrames[moveIndex], canvasSize: CGSize(width: 150, height: 225))
                                    .frame(width: 150, height: 225)
                                    .scaleEffect(x: gameState.facingRight ? 1 : -1, y: 1)
                                    .position(x: figureX, y: figureY)
                                    .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                                        if !isPressing {
                                            // User released - stop movement
                                            gameState.isMovingLeft = false
                                            gameState.isMovingRight = false
                                            if gameState.currentAction == "move" {
                                                let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                                                gameState.recordActionTime(action: "move", duration: duration)
                                                gameState.currentAction = ""
                                            }
                                            gameState.stopAnimation(gameState: gameState)
                                        }
                                    }, perform: {})
                                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            if distanceFromCenter > 5 {
                                                if tapX < figureX && gameState.currentLevel >= 2 {
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingLeft = true
                                                    gameState.isMovingRight = false
                                                    gameState.facingRight = false
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                } else if tapX >= figureX && gameState.currentLevel >= 2 {
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingRight = true
                                                    gameState.isMovingLeft = false
                                                    gameState.facingRight = true
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            if distanceFromCenter <= 5 && gameState.isMovingLeft == false && gameState.isMovingRight == false {
                                                if gameState.selectedAction == "Jump" {
                                                    if let config = ACTION_CONFIGS.first(where: { $0.id == "jump" }) {
                                                        startActionAction(config, gameState)
                                                    }
                                                } else if let config = ACTION_CONFIGS.first(where: { $0.displayName == gameState.selectedAction }) {
                                                    if gameState.currentPerformingAction == nil {
                                                        startActionAction(config, gameState)
                                                    }
                                                }
                                            }
                                        }
                                    )
                            } else {
                                // No Move frame - show placeholder
                                Text("?")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                    .frame(width: 100, height: 150)
                                    .position(x: figureX, y: figureY)
                                    .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                                        if !isPressing {
                                            // User released - stop movement
                                            gameState.isMovingLeft = false
                                            gameState.isMovingRight = false
                                            if gameState.currentAction == "move" {
                                                let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                                                gameState.recordActionTime(action: "move", duration: duration)
                                                gameState.currentAction = ""
                                            }
                                            gameState.stopAnimation(gameState: gameState)
                                        }
                                    }, perform: {})
                                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            if distanceFromCenter > 5 {
                                                if tapX < figureX && gameState.currentLevel >= 2 {
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingLeft = true
                                                    gameState.isMovingRight = false
                                                    gameState.facingRight = false
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                } else if tapX >= figureX && gameState.currentLevel >= 2 {
                                                    gameState.resetIdleTimer()
                                                    if gameState.currentAction != "move" {
                                                        gameState.currentAction = "move"
                                                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                                                    }
                                                    gameState.isMovingRight = true
                                                    gameState.isMovingLeft = false
                                                    gameState.facingRight = true
                                                    gameState.lastMovementUpdateTime = Date().timeIntervalSince1970
                                                    if gameState.animationFrame == 0 {
                                                        gameState.startAnimation(gameState: gameState)
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            let tapX = value.location.x
                                            let distanceFromCenter = abs(tapX - figureX)
                                            
                                            if distanceFromCenter <= 5 && gameState.isMovingLeft == false && gameState.isMovingRight == false {
                                                if gameState.selectedAction == "Jump" {
                                                    if let config = ACTION_CONFIGS.first(where: { $0.id == "jump" }) {
                                                        startActionAction(config, gameState)
                                                    }
                                                } else if let config = ACTION_CONFIGS.first(where: { $0.displayName == gameState.selectedAction }) {
                                                    if gameState.currentPerformingAction == nil {
                                                        startActionAction(config, gameState)
                                                    }
                                                }
                                            }
                                        }
                                    )
                            }
                        }
                    }
                }

                ForEach(gameState.floatingTexts) { floatingText in
                    Text(floatingText.text)
                        .font(.system(size: floatingText.fontSize))
                        .fontWeight(.semibold)
                        .foregroundColor(floatingText.color)
                        .opacity(1.0 - (floatingText.age / floatingText.lifespan))
                        .lineLimit(1)
                        .position(x: max(40, min(geometry.size.width - 40, floatingText.x * geometry.size.width)), y: floatingText.y * geometry.size.height)
                }

                ForEach(gameState.fallingItems) { item in
                    if let config = CATCHABLE_CONFIGS.first(where: { $0.id == item.itemType }) {
                        // Render icon (SF Symbol) if configured
                        if let iconName = config.iconName {
                            Image(systemName: iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .foregroundColor(gameState.getColorFromHex(config.color ?? "#808080"))
                                .rotationEffect(.degrees(item.rotation))
                                .position(x: item.x * geometry.size.width, y: item.y * geometry.size.height)
                        }
                        // Render image asset if configured
                        else if let assetName = config.assetName, let uiImage = UIImage(named: assetName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .rotationEffect(.degrees(item.rotation))
                                .position(x: item.x * geometry.size.width, y: item.y * geometry.size.height)
                        }
                    }
                }

                ForEach(gameState.fallingShakers) { shaker in
                    Image("Shaker")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(shaker.rotation))
                        .position(x: shaker.x * geometry.size.width, y: shaker.y * geometry.size.height)
                }
                
                // Config-driven countdown timer (replaces hardcoded rest/yoga)
                if gameState.actionCountdownTimeRemaining > 0 {
                    Text(String(format: "%.1f", gameState.actionCountdownTimeRemaining))
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))  // Dark gray
                        .position(x: max(50, min(geometry.size.width - 50, figureX)), y: figureY - 120)  // Position higher above stick figure
                }
                
                // Pullup counter is now displayed as floating text in the collision timer

                ForEach(gameState.fireworkParticles) { particle in

                    Circle()
                        .fill(particle.color)
                        .frame(width: 4, height: 4)
                        .opacity(1.0 - (particle.age / particle.lifespan))
                        .position(x: particle.x * geometry.size.width, y: particle.y * geometry.size.height)
                }
                
                // Render doors
                if showDoor {
                    ForEach(gameState.doors, id: \.id) { door in
                        let doorScreenX = door.x * geometry.size.width
                        let doorWidth = door.width * geometry.size.width
                        let doorHeight = door.height * geometry.size.height
                        // Use animated doorY from mapState - slides down continuously from top
                        let doorScreenY = mapState.doorY
                    
                    ZStack {
                        Rectangle()
                            .fill(Color(red: 0.6, green: 0.4, blue: 0.2)) // Brown color
                            .frame(width: doorWidth, height: doorHeight)
                        
                        Rectangle()
                            .stroke(Color(red: 0.4, green: 0.2, blue: 0.0), lineWidth: 2) // Darker brown border
                            .frame(width: doorWidth, height: doorHeight)
                        
                        Text("🚪")
                            .font(.system(size: 20))
                    }
                    .position(x: doorScreenX, y: doorScreenY)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .onAppear {
                // Load stick figure frames from 2D editor
                gameState.loadStickFigureFrames()
                
                collisionTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak gameState] _ in
                    guard let gameState = gameState else { return }
                    
                    let currentFigureX = ((gameState.figurePosition + 1.0) / 2.0) * geometry.size.width
                    let currentBaseY = geometry.size.height - 120
                    let currentFigureY = currentBaseY
                    gameState.checkFallingItemCollisions(figureX: currentFigureX, figureY: currentFigureY, screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                    gameState.checkShakerCollisions(figureX: currentFigureX, figureY: currentFigureY, screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                    
                    // Spawn config-driven floating text for current action
                    if let currentAction = gameState.currentPerformingAction,
                       let config = ACTION_CONFIGS.first(where: { $0.id == currentAction }) {
                        
                        let normX = currentFigureX / geometry.size.width
                        let normY = currentFigureY / geometry.size.height
                        
                        // Generic config-driven floating text for all actions
                        if let floatingTextConfig = config.floatingText,
                           let texts = floatingTextConfig.text,
                           !texts.isEmpty {
                            
                            // Initialize tracker if needed
                            if gameState.floatingTextTrackers[currentAction] == nil {
                                gameState.floatingTextTrackers[currentAction] = FloatingTextTracker(
                                    lastTriggerTime: Date().timeIntervalSince1970,
                                    textIndex: 0,
                                    nextTriggerTime: floatingTextConfig.timing ?? 0.1,
                                    hasCompleted: false
                                )
                            }
                            
                            var tracker = gameState.floatingTextTrackers[currentAction]!
                            let currentTime = Date().timeIntervalSince1970
                            
                            // Check if we should display text
                            let shouldLoop = floatingTextConfig.loop ?? true  // Default to looping
                            let hasCompletedAndShouldNotLoop = tracker.hasCompleted && !shouldLoop
                            
                            if !hasCompletedAndShouldNotLoop && currentTime - tracker.lastTriggerTime >= tracker.nextTriggerTime {
                                let text: String
                                if floatingTextConfig.random ?? false {
                                    // Random selection
                                    text = texts.randomElement() ?? texts[0]
                                } else {
                                    // Sequential selection
                                    text = texts[tracker.textIndex % texts.count]
                                    tracker.textIndex += 1
                                    
                                    // Mark as completed if we've gone through all text
                                    if tracker.textIndex >= texts.count {
                                        tracker.hasCompleted = true
                                    }
                                }
                                
                                // Determine color
                                let colorString = floatingTextConfig.color ?? "gray"
                                let textColor: Color = {
                                    switch colorString.lowercased() {
                                    case "red": return .red
                                    case "blue": return .blue
                                    case "green": return .green
                                    case "yellow": return .yellow
                                    case "orange": return .orange
                                    case "purple": return .purple
                                    case "pink": return .pink
                                    case "white": return .white
                                    default: return .gray
                                    }
                                }()
                                
                                // Add random horizontal offset for certain actions like rest
                                let xOffset = (currentAction == "rest") ? CGFloat.random(in: -0.03...0.03) : 0
                                gameState.addFloatingText(text, x: normX + xOffset, y: normY, color: textColor, fontSize: 20)
                                
                                tracker.lastTriggerTime = currentTime
                                gameState.floatingTextTrackers[currentAction] = tracker
                            }
                        }
                        
                        // Handle periodic points for continuous actions (e.g., Run)
                        if let pointsPerInterval = config.pointsPerInterval {
                            let currentTime = Date().timeIntervalSince1970
                            
                            // For Run action, only award points if character is actually moving left or right
                            let isMoving = (currentAction == "run") && (gameState.isMovingLeft || gameState.isMovingRight)
                            
                            if isMoving {
                                // If this is the first time tracking, initialize
                                if gameState.periodicPointsLastAwardedTime == 0 {
                                    gameState.periodicPointsLastAwardedTime = currentTime
                                    print("DEBUG: Started tracking Run periodic points. Interval: \(pointsPerInterval.interval)s, Points per interval: \(pointsPerInterval.points)")
                                }
                                
                                // Check if enough time has passed
                                let timeSinceLastAward = currentTime - gameState.periodicPointsLastAwardedTime
                                if timeSinceLastAward >= pointsPerInterval.interval {
                                    print("DEBUG: Awarding \(pointsPerInterval.points) points for Run (time elapsed: \(timeSinceLastAward)s)")
                                    gameState.addPoints(pointsPerInterval.points, action: currentAction)
                                    gameState.periodicPointsLastAwardedTime = currentTime
                                }
                            } else {
                                // Not moving - reset the timer
                                gameState.periodicPointsLastAwardedTime = 0
                            }
                        }
                    } else {
                        // No longer performing an action - reset periodic points tracker
                        gameState.periodicPointsLastAwardedTime = 0
                    }
                    
                    // Check door collision only if door is visible
                    if showDoor {
                        if let door = gameState.checkDoorCollision(figureX: currentFigureX, screenWidth: geometry.size.width, screenHeight: geometry.size.height, isMovingRight: gameState.isMovingRight, isMovingLeft: gameState.isMovingLeft, animatedDoorY: mapState.doorY) {
                            // Check if returning to map
                            if door.destinationRoomId == "map" {
                                // Mark current level as completed and unlock next level
                                if gameState.currentLevel <= mapState.levelBoxes.count {
                                    // Create a copy of the array to trigger SwiftUI update
                                    var updatedBoxes = mapState.levelBoxes
                                    updatedBoxes[gameState.currentLevel - 1].isCompleted = true
                                    
                                    // Unlock next level
                                    if gameState.currentLevel < updatedBoxes.count {
                                        updatedBoxes[gameState.currentLevel].isAvailable = true
                                    }
                                    
                                    // Reassign to trigger update
                                    mapState.levelBoxes = updatedBoxes
                                }
                                
                                // Position character below the level they just exited
                                // currentLevel is still the level we're exiting (not incremented yet)
                                let exitedLevelNumber = gameState.currentLevel
                                if exitedLevelNumber > 0 && exitedLevelNumber <= mapState.levelBoxes.count {
                                    let levelBox = mapState.levelBoxes[exitedLevelNumber - 1]
                                    // Position below the level box (outside of it)
                                    mapState.characterX = levelBox.x
                                    mapState.characterY = levelBox.y + 150
                                    mapState.targetX = levelBox.x
                                    mapState.targetY = levelBox.y + 150
                                }
                                // Save stats when exiting level via door
                                gameState.saveStats()
                                showGameMap = true
                            } else {
                                // Enter the door - move to center of new room
                                gameState.initializeRoom(door.destinationRoomId)
                                gameState.figurePosition = 0 // Center
                                stopMovingLeftAction(gameState)
                                stopMovingRightAction(gameState)
                                showDoor = false // Hide door when entering new room
                            }
                        }
                    }
                }
            }
            .onDisappear {
                print("🎮 GAMEPLAY AREA DISAPPEARED")
                collisionTimer?.invalidate()
                collisionTimer = nil
                // Don't invalidate elapsedTimeTimer here - let gameplayScreen handle it
                mapState.stopDoorSliding()
            }
            .onChange(of: showDoor) { oldValue, newValue in
                if !newValue {
                    mapState.stopDoorSliding()
                }
            }
            .onChange(of: gameState.isWaving) { _, isWaving in
                guard isWaving else { return }
                if Bool.random() {
                    let greeting = Bool.random() ? "*hi*" : "*hey*"
                    gameState.addFloatingText(greeting, x: normX, y: textStartY, color: .blue)
                }
            }
        } // End of GeometryReader
    } // End of body
}


