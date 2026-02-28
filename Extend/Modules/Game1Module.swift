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
    
    // Debug flags
    var showDebugGestureAreas: Bool = false {
        didSet {
            UserDefaults.standard.set(showDebugGestureAreas, forKey: "game1_showDebugGestureAreas")
        }
    }
    
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
        
        // Load debug flag
        showDebugGestureAreas = UserDefaults.standard.bool(forKey: "game1_showDebugGestureAreas")
        
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
        if let levelConfig = LEVEL_CONFIGS.first(where: { $0.id == level }) {
            return levelConfig.pointsToComplete
        }
        return max(10, level * 20) // Fallback to formula if level not found
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
            print("DEBUG: Found Stand frame data, converting to StickFigure2D...")
            standFrame = standFrameData.pose.toStickFigure2D()
            print("DEBUG: ✓ Loaded Stand frame (frameNumber 0)")
            print("DEBUG: Stand frame head color: \(standFrame?.headColor ?? .clear)")
            print("DEBUG: Stand frame torso color: \(standFrame?.torsoColor ?? .clear)")
            print("DEBUG: Stand frame fusiform: upper=\(standFrame?.fusiformUpperTorso ?? 0), lower=\(standFrame?.fusiformLowerTorso ?? 0)")
            print("DEBUG: Stand frame fusiform arms: upper=\(standFrame?.fusiformUpperArms ?? 0), lower=\(standFrame?.fusiformLowerArms ?? 0)")
            print("DEBUG: Stand frame fusiform legs: upper=\(standFrame?.fusiformUpperLegs ?? 0), lower=\(standFrame?.fusiformLowerLegs ?? 0)")
        } else {
            print("DEBUG: ✗ Stand frame 0 not found - available Stand frames:")
            allFrames.filter { $0.name == "Stand" }.forEach { frame in
                print("DEBUG:   - Frame \(frame.frameNumber)")
            }
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
        
        // Load the stick figure frames for this room
        loadStickFigureFrames()
        print("🎮 initializeRoom: Loaded stick figure frames - standFrame = \(standFrame != nil ? "SET" : "NIL")")
    }
    
    func forceReloadFrames() {
        print("🎮 forceReloadFrames: Reloading all animation frames...")
        loadStickFigureFrames()
        print("🎮 forceReloadFrames: standFrame = \(standFrame != nil ? "SET" : "NIL")")
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
        // Set first frame immediately
        gameState.animationFrame = 1
        var frameCount = 1
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
        
        // Set direction FIRST before starting any animations
        gameState.isMovingLeft = true
        gameState.isMovingRight = false
        gameState.facingRight = false
        
        if gameState.currentAction != "move" {
            gameState.currentAction = "move"
            gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
        }
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
        
        // Set direction FIRST before starting any animations
        gameState.isMovingRight = true
        gameState.isMovingLeft = false
        gameState.facingRight = true
        
        if gameState.currentAction != "move" {
            gameState.currentAction = "move"
            gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
        }
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
                Text("Show Gesture Areas:")
                    .foregroundColor(.gray)
                Spacer()
                Toggle("", isOn: $gameState.showDebugGestureAreas)
            }
            
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
    @State private var showProgrammableDemo = false
    @State private var showGame = true  // Control whether to show the game view
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
            } else if showGame {
                // Use SpriteKit for the game
                SpriteKitGameView(gameState: gameState, mapState: mapState, onDismiss: {
                    print("🎮 Game dismissed - navigating back to dashboard")
                    // Select dashboard module to show it
                    moduleState.selectModule(ModuleIDs.dashboard)
                })
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            // Reset showGame to true when this module appears
            print("🎮 Game1Module appeared - ensuring showGame is true")
            showGame = true
        }
        .onChange(of: showProgrammableDemo) { oldValue, newValue in
            if oldValue == true && newValue == false {
                // Exiting editor, reload frames
                print("🎮 Exiting editor - Forcing frame reload")
                gameState.forceReloadFrames()
            }
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .background || newValue == .inactive {
                print("🎮 App going to background/inactive - Saving game state")
                gameState.saveStats()
            }
        }
    }
}
