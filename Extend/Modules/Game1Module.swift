////
////  Game1Module.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/16/26.
////
// Stick figure running and jumping game

import SwiftUI

// MARK: - Action Configuration

struct ActionConfig {
    let id: String
    let displayName: String
    let unlockLevel: Int
    let pointsPerCompletion: Int
    let animationFrames: [Int]
    let baseFrameInterval: TimeInterval
    let variableTiming: [Int: TimeInterval]? // Optional custom timing per frame
    let supportsFlip: Bool
    let supportsSpeedBoost: Bool
    let imagePrefix: String // Prefix for image names (e.g., "guy_curls" or "pushup")
    
    // Helper to get available actions for a level
    static func actionsForLevel(_ level: Int) -> [ActionConfig] {
        return ACTION_CONFIGS.filter { $0.unlockLevel <= level }
    }
    
    // Helper to get level-based action IDs
    static func levelBasedActionIDs(forLevel level: Int) -> Set<String> {
        return Set(ACTION_CONFIGS.filter { $0.unlockLevel <= level }.map { $0.id })
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

// MARK: - Action Configurations

let ACTION_CONFIGS: [ActionConfig] = [
    // Level 1: Run - special case, handled separately (continuous points)
    ActionConfig(
        id: "run",
        displayName: "Run",
        unlockLevel: 1,
        pointsPerCompletion: 1,
        animationFrames: [],
        baseFrameInterval: 0,
        variableTiming: nil,
        supportsFlip: false,
        supportsSpeedBoost: true,
        imagePrefix: "guy_move"
    ),
    
    // Level 2: Jump
    ActionConfig(
        id: "jump",
        displayName: "Jump",
        unlockLevel: 2,
        pointsPerCompletion: 2,
        animationFrames: [1, 2, 3],
        baseFrameInterval: 0.1,
        variableTiming: nil,
        supportsFlip: false,
        supportsSpeedBoost: true,
        imagePrefix: "guy_jump"
    ),
    
    // Level 3: Curls
    ActionConfig(
        id: "curls",
        displayName: "Bicep Curls",
        unlockLevel: 3,
        pointsPerCompletion: 3,
        animationFrames: [2, 1, 2, 1, 3, 1],
        baseFrameInterval: 0.2,
        variableTiming: nil,
        supportsFlip: true,
        supportsSpeedBoost: true,
        imagePrefix: "guy_curls"
    ),
    
    // Level 4: Kettlebell
    ActionConfig(
        id: "kettlebell",
        displayName: "Kettlebell swings",
        unlockLevel: 4,
        pointsPerCompletion: 4,
        animationFrames: [1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 7, 8, 7, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1],
        baseFrameInterval: 0.15,
        variableTiming: nil,
        supportsFlip: true,
        supportsSpeedBoost: true,
        imagePrefix: "kb"
    ),
    
    // Level 5: Pull ups
    ActionConfig(
        id: "pullup",
        displayName: "Pull ups",
        unlockLevel: 5,
        pointsPerCompletion: 5,
        animationFrames: [1, 2, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 2, 1],
        baseFrameInterval: 0.2,
        variableTiming: nil,
        supportsFlip: false,
        supportsSpeedBoost: true,
        imagePrefix: "pullup"
    ),
    
    // Level 6: Push ups (with variable timing)
    ActionConfig(
        id: "pushup",
        displayName: "Push ups",
        unlockLevel: 6,
        pointsPerCompletion: 6,
        animationFrames: [1, 2, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 2, 1],
        baseFrameInterval: 0.2,
        variableTiming: [1: 0.1, 2: 0.1], // Frames 1 and 2 are faster
        supportsFlip: true,
        supportsSpeedBoost: true,
        imagePrefix: "pushup"
    ),
    
    // Level 7: Jumping jacks
    ActionConfig(
        id: "jumpingjack",
        displayName: "Jumping jacks",
        unlockLevel: 7,
        pointsPerCompletion: 7,
        animationFrames: [3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 1],
        baseFrameInterval: 0.15,
        variableTiming: nil,
        supportsFlip: false,
        supportsSpeedBoost: true,
        imagePrefix: "jumpingjack"
    )
]

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
}

// MARK: - Falling Leaf

struct FallingLeaf: Identifiable, Equatable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double = 0
    var horizontalVelocity: CGFloat = 0
    var verticalSpeed: CGFloat = 0.003
    
    static func == (lhs: FallingLeaf, rhs: FallingLeaf) -> Bool {
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
    var selectedLevelNumber: Int? = nil
    var animationTimer: Timer? = nil
    var movementTimer: Timer? = nil
    
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
    }
    
    func initializeLevelBoxes(currentLevel: Int = 1) {
        // Create 100 level boxes in 5-column grid (20 rows)
        // Layout: 1-5, 10-6, 11-15, 20-16, etc. (zigzag pattern)
        var boxes: [LevelBox] = []
        let boxSize: CGFloat = 60
        let spacing: CGFloat = 180
        let columnCount = 5
        let startX: CGFloat = 200
        let startY: CGFloat = 200
        
        for level in 1...100 {
            let row = (level - 1) / columnCount
            let positionInRow = (level - 1) % columnCount
            
            // Determine if this row goes left-to-right or right-to-left
            let isEvenRow = (row % 2) == 0
            let col = isEvenRow ? positionInRow : (columnCount - 1 - positionInRow)
            
            let x = startX + CGFloat(col) * spacing
            let y = startY + CGFloat(row) * spacing
            
            // Level is completed if player has passed it
            let isCompleted = level < currentLevel
            // Level is available if it's completed, currently playing, or next unlocked level
            let isAvailable = level <= currentLevel
            
            boxes.append(LevelBox(
                levelNumber: level,
                x: x,
                y: y,
                width: boxSize,
                height: boxSize,
                isCompleted: isCompleted,
                isAvailable: isAvailable
            ))
        }
        
        levelBoxes = boxes
        // Don't reset character position here - let the view control it
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

// ...existing code...
@Observable
class StickFigureGameState {
    var figurePosition: CGFloat = 0
    var animationFrame: Int = 0
    var isMovingRight: Bool = false
    var isMovingLeft: Bool = false
    var isJumping: Bool = false
    var jumpFrame: Int = 0
    var jumpHeight: CGFloat = 0
    var isWaving: Bool = false
    var waveFrame: Int = 0
    var shouldFlipWave: Bool = false
    
    // Generic action system
    var currentPerformingAction: String? = nil // ID of action being performed
    var actionFrame: Int = 0
    var actionFlip: Bool = false
    var actionTimer: Timer? = nil
    
    // Special case animations
    var isPerformingShaker: Bool = false
    var shakerFrame: Int = 0
    var shakerFlip: Bool = false
    var shakerCatchLocation: (x: CGFloat, y: CGFloat)?
    
    var animationTimer: Timer?
    var jumpTimer: Timer?
    var waveTimer: Timer?
    var shakerTimer: Timer?
    var idleTimer: Timer?
    var floatingTexts: [FloatingTextItem] = []
    var floatingTextTimer: Timer?
    var facingRight: Bool = true
    var timeSinceLastMovement: Double = 0
    var selectedAction: String = "Run"

    var currentLevel: Int = 1
    var currentPoints: Int = 0
    var sessionActions: Set<String> = []
    var sessionStartTime: Date = Date()
    var lastRunPointTime: Date = Date()
    
    var score: Int = 0
    var timeElapsed: Double = 0
    var highScore: Int = 0

    var actionTimes: [String: Double] = [:] // Dictionary to track time for each action
    var allTimeElapsed: Double = 0
    var totalLeavesCaught: Int = 0
    var totalShakersCaught: Int = 0

    var actionStartTime: Double = 0
    var currentAction: String = ""
    var statsSaveAccumulator: Double = 0
    
    // Signal for UI to return to map after level completion
    var shouldReturnToMap: Bool = false
    
    // Room and door system
    var currentRoomId: String = "room_1"
    var currentRoomName: String = "Room 1"
    var doors: [Door] = [] // Doors in current room
    
    var fallingLeaves: [FallingLeaf] = []
    var leafSpawnTimer: Timer?
    var fallingShakers: [FallingShaker] = []
    var shakerSpawnTimer: Timer?
    var leafUpdateTimer: Timer?
    var shakerUpdateTimer: Timer?
    var speedBoostEndTime: Date?
    var speedBoostTimer: Timer?
    var speedBoostTimeRemaining: Double = 0.0
    var fireworkParticles: [FireworkParticle] = []
    var fireworkUpdateTimer: Timer?

    private let highScoreKey = "game1_high_score"
    private let currentLevelKey = "game1_current_level"
    private let currentPointsKey = "game1_current_points"
    private let allTimeElapsedKey = "game1_all_time_elapsed"
    private let totalLeavesCaughtKey = "game1_total_leaves_caught"
    private let totalShakersCaughtKey = "game1_total_shakers_caught"
    
    // Dynamic keys for actions: "game1_action_time_{actionId}"
    private func actionTimeKey(for actionId: String) -> String {
        return "game1_action_time_\(actionId)"
    }

    init() {
        loadHighScore()
        loadStats()
        startFloatingTextTimer()
        startIdleTimer()
        startTimeElapsedTimer()
        startLeafSpawner()
        startShakerSpawner()
        startLeafUpdater()
        startShakerUpdater()
        startFireworkUpdater()
        initializeRoom(currentRoomId)
    }
    
    // MARK: - Room Management
    
    func initializeRoom(_ roomId: String) {
        currentRoomId = roomId
        
        // Check if it's a level room (level_1, level_2, etc.)
        if roomId.hasPrefix("level_"), let levelString = roomId.components(separatedBy: "_").last, let level = Int(levelString) {
            currentRoomName = "Level \(level)"
            // Create a single door that returns to map
            doors = [
                Door(
                    id: "door_return_right",
                    position: .right,
                    collisionSide: .left,
                    destinationRoomId: "map",
                    x: 0.95,
                    y: 0.85,
                    width: 0.05,
                    height: 0.25
                )
            ]
        } else {
            // Original room setup for testing
            switch roomId {
            case "room_1":
                currentRoomName = "Room 1"
                doors = [
                    Door(
                        id: "door_right",
                        position: .right,
                        collisionSide: .left,
                        destinationRoomId: "room_2",
                        x: 0.95,
                        y: 0.85,
                        width: 0.05,
                        height: 0.25
                    )
                ]
            case "room_2":
                currentRoomName = "Room 2"
                doors = [
                    Door(
                        id: "door_left",
                        position: .left,
                        collisionSide: .right,
                        destinationRoomId: "room_1",
                        x: 0.05,
                        y: 0.85,
                        width: 0.05,
                        height: 0.25
                    )
                ]
            default:
                currentRoomName = "Room Unknown"
                doors = []
            }
        }
    }
    
    // MARK: - Door and Screen Wrap Handling
    
    func checkDoorCollision(figureX: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat, isMovingRight: Bool, isMovingLeft: Bool) -> Door? {
        for door in doors {
            let doorScreenX = door.x * screenWidth
            let doorScreenY = door.y * screenHeight
            let doorWidth = door.width * screenWidth
            let doorHeight = door.height * screenHeight
            
            // Check if figure is within the door's horizontal bounds
            let doorLeftEdge = doorScreenX - (doorWidth / 2)
            let doorRightEdge = doorScreenX + (doorWidth / 2)
            let doorTopEdge = doorScreenY - (doorHeight / 2)
            let doorBottomEdge = doorScreenY + (doorHeight / 2)
            
            // Figure dimensions
            let figureWidth: CGFloat = 100
            let figureHeight: CGFloat = 150
            
            // Check vertical overlap
            let baseY = screenHeight - 80
            let figureY = baseY
            let figureTopEdge = figureY - (figureHeight / 2)
            let figureBottomEdge = figureY + (figureHeight / 2)
            
            let verticalOverlap = !(figureBottomEdge < doorTopEdge || figureTopEdge > doorBottomEdge)
            
            if verticalOverlap {
                // Check collision based on direction and collision side
                if door.collisionSide == .left && isMovingRight && figureX + (figureWidth / 2) >= doorLeftEdge && figureX < doorRightEdge {
                    return door
                } else if door.collisionSide == .right && isMovingLeft && figureX - (figureWidth / 2) <= doorRightEdge && figureX > doorLeftEdge {
                    return door
                }
            }
        }
        return nil
    }
    
    func handleScreenWrap(_ screenWidth: CGFloat) {
        // Right edge wrap
        if figurePosition > 1.0 {
            figurePosition = -1.0
        }
        // Left edge wrap
        else if figurePosition < -1.0 {
            figurePosition = 1.0
        }
    }
    
    func stopMovingLeft() {
        isMovingLeft = false
    }
    
    func stopMovingRight() {
        isMovingRight = false
    }

    private func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }

    func saveHighScore() {
        UserDefaults.standard.set(highScore, forKey: highScoreKey)
    }

    private func loadStats() {
        // Load action times dynamically
        for config in ACTION_CONFIGS {
            let key = actionTimeKey(for: config.id)
            actionTimes[config.id] = UserDefaults.standard.double(forKey: key)
        }
        
        allTimeElapsed = UserDefaults.standard.double(forKey: allTimeElapsedKey)
        totalLeavesCaught = UserDefaults.standard.integer(forKey: totalLeavesCaughtKey)
        totalShakersCaught = UserDefaults.standard.integer(forKey: totalShakersCaughtKey)
        currentLevel = max(1, UserDefaults.standard.integer(forKey: currentLevelKey))
        if currentLevel == 0 { currentLevel = 1 }
        currentPoints = UserDefaults.standard.integer(forKey: currentPointsKey)
    }

    func saveStats() {
        // Save action times dynamically
        for (actionId, time) in actionTimes {
            let key = actionTimeKey(for: actionId)
            UserDefaults.standard.set(time, forKey: key)
        }
        
        UserDefaults.standard.set(allTimeElapsed, forKey: allTimeElapsedKey)
        UserDefaults.standard.set(totalLeavesCaught, forKey: totalLeavesCaughtKey)
        UserDefaults.standard.set(totalShakersCaught, forKey: totalShakersCaughtKey)
        UserDefaults.standard.set(currentLevel, forKey: currentLevelKey)
        UserDefaults.standard.set(currentPoints, forKey: currentPointsKey)
    }

    private func startFloatingTextTimer() {
        floatingTextTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateFloatingTexts()
        }
    }

    private func startIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isMovingLeft && !self.isMovingRight && !self.isJumping && !self.isWaving && self.currentPerformingAction == nil && !self.isPerformingShaker {
                self.timeSinceLastMovement += 1.0
                if self.timeSinceLastMovement >= 15.0 {
                    self.triggerWave()
                    self.timeSinceLastMovement = 0
                }
            }
        }
    }

    private func startTimeElapsedTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeElapsed += 0.1
            self.allTimeElapsed += 0.1
            self.statsSaveAccumulator += 0.1
            if self.statsSaveAccumulator >= 1.0 {
                self.saveStats()
                self.statsSaveAccumulator = 0
            }
            
            // Award 1 point per 1 second of running
            if self.isMovingLeft || self.isMovingRight {
                let now = Date()
                if now.timeIntervalSince(self.lastRunPointTime) >= 1.0 {
                    self.addPoints(1, action: "run")
                    self.lastRunPointTime = now
                }
            }
        }
    }

    private func updateFloatingTexts() {
        for i in floatingTexts.indices {
            floatingTexts[i].age += 0.016
            floatingTexts[i].y -= 0.001
        }
        floatingTexts.removeAll { $0.age >= $0.lifespan }
    }
    
    private func startLeafSpawner() {
        leafSpawnTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.spawnLeaf()
        }
    }
    
    private func spawnLeaf() {
        let randomX = CGFloat.random(in: 0...1)
        let horizontalVel = CGFloat.random(in: -0.002...0.002)
        let leaf = FallingLeaf(x: randomX, y: 0, horizontalVelocity: horizontalVel)
        fallingLeaves.append(leaf)
    }
    
    private func startShakerSpawner() {
        shakerSpawnTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.spawnShaker()
        }
    }
    
    private func spawnShaker() {
        let randomX = CGFloat.random(in: 0...1)
        let shaker = FallingShaker(x: randomX, y: 0)
        fallingShakers.append(shaker)
    }
    
    private func startLeafUpdater() {
        leafUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateLeavesPositions()
        }
    }
    
    private func startShakerUpdater() {
        shakerUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateShakersPositions()
        }
    }
    
    private func updateLeavesPositions() {
        for i in fallingLeaves.indices.reversed() {
            fallingLeaves[i].y += fallingLeaves[i].verticalSpeed
            fallingLeaves[i].x += fallingLeaves[i].horizontalVelocity
            fallingLeaves[i].rotation += 2.0
            
            if fallingLeaves[i].y > 1.1 {
                fallingLeaves.remove(at: i)
            }
        }
    }
    
    private func updateShakersPositions() {
        for i in fallingShakers.indices.reversed() {
            fallingShakers[i].y += fallingShakers[i].verticalSpeed
            fallingShakers[i].rotation += 3.0
            
            if fallingShakers[i].y > 1.1 {
                fallingShakers.remove(at: i)
            }
        }
    }
    
    private func startFireworkUpdater() {
        fireworkUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateFireworkParticles()
        }
    }
    
    private func updateFireworkParticles() {
        for i in fireworkParticles.indices {
            fireworkParticles[i].x += fireworkParticles[i].velocityX
            fireworkParticles[i].y += fireworkParticles[i].velocityY
            fireworkParticles[i].velocityY += 0.001 // Gravity
            fireworkParticles[i].age += 0.016
        }
        fireworkParticles.removeAll { $0.age >= $0.lifespan }
    }
    
    func createFireworks(at x: CGFloat, y: CGFloat) {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        
        for _ in 0..<20 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 0.003...0.008)
            let velocityX = cos(angle) * speed
            let velocityY = sin(angle) * speed - 0.005 // Initial upward velocity
            let color = colors.randomElement() ?? .yellow
            
            let particle = FireworkParticle(
                x: x,
                y: y,
                velocityX: velocityX,
                velocityY: velocityY,
                color: color
            )
            fireworkParticles.append(particle)
        }
    }
    
    func addPoints(_ points: Int, action: String) {
        // Only add to sessionActions if it's a level-based action (not leaves/shakers)
        let levelBasedActionIDs = ACTION_CONFIGS.map { $0.id }
        if levelBasedActionIDs.contains(action) {
            sessionActions.insert(action)
        }
        
        // Get max possible combo for current level (number of unlocked level-based actions)
        let maxComboForLevel = currentLevel // Level 1=1 action, Level 2=2 actions, etc.
        
        // Only count level-based unlocked actions for combo
        let unlockedLevelBasedActions = ActionConfig.levelBasedActionIDs(forLevel: currentLevel)
        let validSessionActions = sessionActions.filter { unlockedLevelBasedActions.contains($0) }
        let comboCount = min(validSessionActions.count, maxComboForLevel)
        
        // Combo multiplier: base points + comboCount% bonus
        // e.g., 1 action = 1.0x, 2 actions = 1.02x, 3 actions = 1.03x, etc.
        let multiplier: Double = comboCount > 1 ? 1.0 + (Double(comboCount) * 0.01) : 1.0
        let exactPoints = Double(points) * multiplier
        let totalPoints = Int(ceil(exactPoints)) // Always round up
        currentPoints += totalPoints
        
        let pointsNeeded = pointsNeeded(forLevel: currentLevel)
        if currentPoints >= pointsNeeded {
            levelUp()
        }
        saveStats()
    }
    
    func getMaxComboForLevel(_ level: Int) -> Int {
        // Returns the maximum number of level-based actions (not including leaves/shakers)
        return level
    }
    
    func getValidComboCount() -> Int {
        let maxCombo = getMaxComboForLevel(currentLevel)
        let unlockedActions = ActionConfig.levelBasedActionIDs(forLevel: currentLevel)
        let validCount = sessionActions.filter { unlockedActions.contains($0) }.count
        return min(validCount, maxCombo)
    }
    
    func pointsNeeded(forLevel level: Int) -> Int {
        // Level 1 requires 50 points, all other levels require level * 100
        return level == 1 ? 50 : level * 100
    }
    
    func levelUp() {
        currentLevel += 1
        currentPoints = 0
        shouldReturnToMap = true // Signal to return to map
        
        // Show level up message with larger text and set selected action to new action
        if let newAction = ACTION_CONFIGS.first(where: { $0.unlockLevel == currentLevel }) {
            let message = "Level \(currentLevel)!\n\(newAction.displayName) Unlocked!"
            addFloatingText(message, x: 0.5, y: 0.4, color: .purple, fontSize: 24)
            // Automatically select the newly unlocked action
            selectedAction = newAction.displayName
        }
        saveStats()
    }
    
    func checkLeafCollisions(figureX: CGFloat, figureY: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat) {
        for i in fallingLeaves.indices.reversed() {
            let leafScreenX = fallingLeaves[i].x * screenWidth
            let leafScreenY = fallingLeaves[i].y * screenHeight
            
            let figureWidth: CGFloat = 100
            let figureHeight: CGFloat = 150
            // Only check collision with bottom half of figure (accounts for empty space at top of image)
            let collisionHeight: CGFloat = figureHeight / 2
            let adjustedFigureY = figureY + (figureHeight / 4) // Center the collision box on lower half
            
            if abs(leafScreenX - figureX) < figureWidth / 2 &&
               abs(leafScreenY - adjustedFigureY) < collisionHeight / 2 {
                totalLeavesCaught += 1
                addFloatingText("gotcha!", x: fallingLeaves[i].x, y: fallingLeaves[i].y, color: .green)
                addPoints(2, action: "leaves")
                fallingLeaves.remove(at: i)
            }
        }
    }
    
    func checkShakerCollisions(figureX: CGFloat, figureY: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat) {
        for i in fallingShakers.indices.reversed() {
            let shakerScreenX = fallingShakers[i].x * screenWidth
            let shakerScreenY = fallingShakers[i].y * screenHeight
            
            let figureWidth: CGFloat = 100
            let figureHeight: CGFloat = 150
            // Only check collision with bottom half of figure (accounts for empty space at top of image)
            let collisionHeight: CGFloat = figureHeight / 2
            let adjustedFigureY = figureY + (figureHeight / 4) // Center the collision box on lower half
            
            if abs(shakerScreenX - figureX) < figureWidth / 2 &&
               abs(shakerScreenY - adjustedFigureY) < collisionHeight / 2 {
                totalShakersCaught += 1
                addPoints(3, action: "shakers")
                // Store catch location for fireworks later
                shakerCatchLocation = (x: fallingShakers[i].x, y: fallingShakers[i].y)
                fallingShakers.remove(at: i)
                triggerShakerAnimation()
                activateSpeedBoost()
            }
        }
    }
    
    func activateSpeedBoost() {
        let boostDuration: TimeInterval = 10.0
        speedBoostEndTime = Date().addingTimeInterval(boostDuration)
        speedBoostTimeRemaining = boostDuration
        
        speedBoostTimer?.invalidate()
        speedBoostTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if let endTime = self.speedBoostEndTime {
                let remaining = endTime.timeIntervalSinceNow
                if remaining <= 0 {
                    self.speedBoostEndTime = nil
                    self.speedBoostTimeRemaining = 0.0
                    timer.invalidate()
                    self.speedBoostTimer = nil
                } else {
                    self.speedBoostTimeRemaining = remaining
                }
            } else {
                timer.invalidate()
                self.speedBoostTimer = nil
            }
        }
    }
    
    func triggerShakerAnimation() {
        guard !isPerformingShaker else { return }
        isPerformingShaker = true
        shakerFrame = 1
        shakerFlip = Bool.random()
        
        var step = 0
        shakerTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            step += 1
            
            if step == 1 {
                // Frame 1 (already set)
            } else if step == 2 {
                // Move to frame 2 (drinking)
                self.shakerFrame = 2
            } else if step >= 2 && step < 3 {
                // Hold frame 2 briefly (~0.15s)
            } else if step == 3 {
                // Back to frame 1
                self.shakerFrame = 1
            } else {
                // End animation
                timer.invalidate()
                self.shakerTimer = nil
                self.isPerformingShaker = false
                self.shakerFrame = 0
                self.shakerFlip = false
                
                // Trigger fireworks at catch location
                if let location = self.shakerCatchLocation {
                    self.createFireworks(at: location.x, y: location.y)
                    self.shakerCatchLocation = nil
                }
            }
        }
    }
    
    func addFloatingText(_ text: String, x: CGFloat, y: CGFloat, color: Color, fontSize: CGFloat = 12) {
        floatingTexts.append(FloatingTextItem(x: x, y: y, text: text, color: color, fontSize: fontSize))
    }

    func resetIdleTimer() {
        timeSinceLastMovement = 0
    }

    func triggerWave() {
        isWaving = true
        waveFrame = 1
        shouldFlipWave = Bool.random()

        var frameCount = 0
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            frameCount += 1
            self?.waveFrame = (frameCount - 1) % 2 + 1

            if frameCount >= 10 {
                self?.waveTimer?.invalidate()
                self?.waveTimer = nil
                self?.isWaving = false
                self?.waveFrame = 0
            }
        }
    }

    func recordActionTime(action: String, duration: Double) {
        actionTimes[action, default: 0] += duration
        saveStats()
    }

    func formatTimeDuration(_ milliseconds: Double) -> String {
        let totalSeconds = milliseconds / 1000.0

        let years = Int(totalSeconds / 31536000)
        let yearRemainder = totalSeconds.truncatingRemainder(dividingBy: 31536000)

        let months = Int(yearRemainder / 2592000)
        let monthRemainder = yearRemainder.truncatingRemainder(dividingBy: 2592000)

        let days = Int(monthRemainder / 86400)
        let dayRemainder = monthRemainder.truncatingRemainder(dividingBy: 86400)

        let hours = Int(dayRemainder / 3600)
        let hourRemainder = dayRemainder.truncatingRemainder(dividingBy: 3600)

        let minutes = Int(hourRemainder / 60)
        let seconds = Int(hourRemainder.truncatingRemainder(dividingBy: 60))
        let millis = Int(milliseconds.truncatingRemainder(dividingBy: 1000))

        var components: [String] = []
        if years > 0 { components.append("\(years)y") }
        if months > 0 { components.append("\(months)mo") }
        if days > 0 { components.append("\(days)d") }
        if hours > 0 { components.append("\(hours)h") }
        if minutes > 0 { components.append("\(minutes)m") }
        if seconds > 0 { components.append("\(seconds)s") }
        if millis > 0 { components.append("\(millis)ms") }

        return components.isEmpty ? "0ms" : components.joined(separator: " ")
    }

    deinit {
        floatingTextTimer?.invalidate()
        idleTimer?.invalidate()
        waveTimer?.invalidate()
        actionTimer?.invalidate()
        shakerTimer?.invalidate()
        leafSpawnTimer?.invalidate()
        shakerSpawnTimer?.invalidate()
        leafUpdateTimer?.invalidate()
        shakerUpdateTimer?.invalidate()
    }
}

// MARK: - Corner Radius Modifier

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Main Game View

// MARK: - Game Map View

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
    @Environment(ModuleState.self) var moduleState

    @ViewBuilder
    var body: some View {
        if showGameMap {
            mapScreen
        } else {
            gameplayScreen
        }
    }
    
    private var mapScreen: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar - Fixed at top
                HStack {
                        Button(action: {
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
                                hasInitializedMap = true
                            }
                            
                            mapState.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                                mapState.moveCharacterTowards(mapState.targetX, mapState.targetY, deltaTime: 0.08)
                                mapState.updateMapOffset(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                                
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
                                        showGameMap = false
                                        mapState.animationTimer?.invalidate()
                                        mapState.animationTimer = nil
                                    }
                                }
                            }
                        }
                        .onDisappear {
                            mapState.animationTimer?.invalidate()
                            mapState.animationTimer = nil
                        }
                }
            }
            
            // Stats overlay for map screen
            if showStats {
                VStack(spacing: 0) {
                    HStack {
                        Text("Statistics")
                            .font(.headline)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: { showStats = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color.white)

                    List {
                        StatRow(label: "Level", value: "\(gameState.currentLevel)")
                        StatRow(label: "Current Points", value: "\(gameState.currentPoints)/\(gameState.pointsNeeded(forLevel: gameState.currentLevel))")
                        StatRow(label: "Time Elapsed", value: String(format: "%.1f s", gameState.timeElapsed))
                        StatRow(label: "All Time Elapsed", value: gameState.formatTimeDuration(gameState.allTimeElapsed * 1000))
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
                        Text("Catchables (Always Available)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        StatRow(label: "Leaves", value: "\(gameState.totalLeavesCaught) caught", isUnlocked: true)
                        StatRow(label: "Shakers", value: "\(gameState.totalShakersCaught) caught", isUnlocked: true)
                        Divider()
                        Text("Combo Boost")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Mix different level-based actions (Run, Jump, Curls, etc.) in one session for a bonus! 2 actions = +2%, 3 actions = +3%, etc. Max combo = your current level. Leaves & shakers give points but don't count toward combo.")
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
                            Button(action: {
                                showLevelPicker = true
                            }) {
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
                        }
                        
                        Button(action: {
                            // Reset all game data
                            gameState.currentLevel = 1
                            gameState.currentPoints = 0
                            gameState.sessionActions.removeAll()
                            gameState.actionTimes.removeAll()
                            gameState.totalLeavesCaught = 0
                            gameState.totalShakersCaught = 0
                            gameState.allTimeElapsed = 0
                            gameState.timeElapsed = 0
                            gameState.score = 0
                            gameState.highScore = 0
                            gameState.saveStats()
                            gameState.saveHighScore()
                            // Reinitialize map level boxes after reset
                            mapState.initializeLevelBoxes(currentLevel: 1)
                        }) {
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

                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color.white)
                .cornerRadius(12, corners: [.topLeft, .topRight])
                .padding(.horizontal, 12)
                .padding(.top, 50)
                .transition(.move(edge: .bottom))
            }
            
            if showLevelPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showLevelPicker = false
                    }
                
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
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    .padding(.horizontal, 12)
                }
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    private var gameplayScreen: some View {
        ZStack {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 50)
                    HStack {
                        Button(action: {
                            gameState.animationTimer?.invalidate()
                            gameState.jumpTimer?.invalidate()
                            gameState.floatingTextTimer?.invalidate()
                            gameState.idleTimer?.invalidate()
                            gameState.waveTimer?.invalidate()
                            gameState.actionTimer?.invalidate()
                            gameState.sessionActions.removeAll() // Reset combo for next session
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
                        
                        // Combo Boost Bar
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

                // Speed Boost Timer
                if gameState.speedBoostEndTime != nil && gameState.speedBoostTimeRemaining > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                        Text(String(format: "%.1fs", gameState.speedBoostTimeRemaining))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.top, 4)
                }

                Spacer()

                GamePlayArea(
                    gameState: gameState,
                    mapState: mapState,
                    showGameMap: $showGameMap,
                    startMovingLeftAction: startMovingLeft,
                    stopMovingLeftAction: stopMovingLeft,
                    startMovingRightAction: startMovingRight,
                    stopMovingRightAction: stopMovingRight,
                    startJumpAction: startJump,
                    startActionAction: startAction
                )

                Spacer()

                VStack(spacing: 8) {
                    Text("Action")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button(action: {
                        showActionPicker = true
                    }) {
                        HStack(spacing: 6) {
                            Text(gameState.selectedAction)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.top, 50)
                .padding(.bottom, 50)
            }

            if showStats {
                VStack(spacing: 0) {
                    HStack {
                        Text("Statistics")
                            .font(.headline)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: { showStats = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color.white)

                    List {
                        StatRow(label: "Level", value: "\(gameState.currentLevel)")
                        StatRow(label: "Current Points", value: "\(gameState.currentPoints)/\(gameState.pointsNeeded(forLevel: gameState.currentLevel))")
                        StatRow(label: "Time Elapsed", value: String(format: "%.1f s", gameState.timeElapsed))
                        StatRow(label: "All Time Elapsed", value: gameState.formatTimeDuration(gameState.allTimeElapsed * 1000))
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
                        Text("Catchables (Always Available)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        StatRow(label: "Leaves", value: "\(gameState.totalLeavesCaught) caught", isUnlocked: true)
                        StatRow(label: "Shakers", value: "\(gameState.totalShakersCaught) caught", isUnlocked: true)
                        Divider()
                        Text("Combo Boost")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Mix different level-based actions (Run, Jump, Curls, etc.) in one session for a bonus! 2 actions = +2%, 3 actions = +3%, etc. Max combo = your current level. Leaves & shakers give points but don't count toward combo.")
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
                            Button(action: {
                                showLevelPicker = true
                            }) {
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
                        }
                        
                        Button(action: {
                            // Reset all game data
                            gameState.currentLevel = 1
                            gameState.currentPoints = 0
                            gameState.sessionActions.removeAll()
                            gameState.actionTimes.removeAll()
                            gameState.totalLeavesCaught = 0
                            gameState.totalShakersCaught = 0
                            gameState.allTimeElapsed = 0
                            gameState.timeElapsed = 0
                            gameState.score = 0
                            gameState.highScore = 0
                            gameState.saveStats()
                            gameState.saveHighScore()
                            // Reinitialize map level boxes after reset
                            mapState.initializeLevelBoxes(currentLevel: 1)
                        }) {
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

                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color.white)
                .cornerRadius(12, corners: [.topLeft, .topRight])
                .padding(.horizontal, 12)
                .padding(.top, 50)
                .transition(.move(edge: .bottom))
            }
            
            if showActionPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showActionPicker = false
                    }
                
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
                                        showActionPicker = false
                                    }
                                }
                            }
                        }
                        .background(Color.white)
                    }
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    .padding(.horizontal, 12)
                }
                .transition(.move(edge: .bottom))
            }
            
            if showLevelPicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showLevelPicker = false
                    }
                
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
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    .padding(.horizontal, 12)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onChange(of: gameState.shouldReturnToMap) { oldValue, newValue in
            if newValue {
                // Delay to show the "Level Complete" message before returning
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Update map level boxes for new level
                    mapState.initializeLevelBoxes(currentLevel: gameState.currentLevel)
                    
                    // Position character near the new unlocked level
                    if gameState.currentLevel <= mapState.levelBoxes.count {
                        let levelBox = mapState.levelBoxes[gameState.currentLevel - 1]
                        mapState.characterX = levelBox.x - 100
                        mapState.characterY = levelBox.y
                        mapState.targetX = levelBox.x - 100
                        mapState.targetY = levelBox.y
                    }
                    
                    showGameMap = true
                    gameState.shouldReturnToMap = false
                }
            }
        }
    }
    
    @ViewBuilder
    private func connectionLinesView(mapState: GameMapState) -> some View {
        ZStack {
            let levelBoxes = mapState.levelBoxes.sorted { $0.levelNumber < $1.levelNumber }
            
            ForEach(0..<levelBoxes.count - 1, id: \.self) { index in
                let from = levelBoxes[index]
                let to = levelBoxes[index + 1]
                
                drawConnectionLine(from: from, to: to, mapState: mapState)
            }
        }
    }
    
    private func drawConnectionLine(from: LevelBox, to: LevelBox, mapState: GameMapState) -> some View {
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
    @State private var collisionTimer: Timer?
    
    var startMovingLeftAction: (StickFigureGameState, GeometryProxy) -> Void
    var stopMovingLeftAction: (StickFigureGameState) -> Void
    var startMovingRightAction: (StickFigureGameState, GeometryProxy) -> Void
    var stopMovingRightAction: (StickFigureGameState) -> Void
    var startJumpAction: (StickFigureGameState, GeometryProxy) -> Void
    var startActionAction: (ActionConfig, StickFigureGameState) -> Void
    
    private func getStandImage() -> String {
        if gameState.selectedAction == "Bicep Curls" {
            return "guy_curls1"
        } else {
            return "guy_stand"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let figureX = ((gameState.figurePosition + 1.0) / 2.0) * geometry.size.width
            let baseY = geometry.size.height - 80
            let figureY = baseY - gameState.jumpHeight
            let textStartY = max(0.05, (baseY - 120) / geometry.size.height)
            let normX = figureX / geometry.size.width
            
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                            if isPressing {
                                startMovingLeftAction(gameState, geometry)
                            } else {
                                stopMovingLeftAction(gameState)
                            }
                        }, perform: {})

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                            if isPressing {
                                startMovingRightAction(gameState, geometry)
                            } else {
                                stopMovingRightAction(gameState)
                            }
                        }, perform: {})
                }

                VStack {
                    Spacer()

                    // Generic action rendering
                    if let actionId = gameState.currentPerformingAction,
                       let config = ACTION_CONFIGS.first(where: { $0.id == actionId }) {
                        Image("\(config.imagePrefix)\(gameState.actionFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
                            .scaleEffect(x: gameState.actionFlip ? -1 : 1, y: 1)
                            .position(x: figureX, y: figureY)
                            .onTapGesture {
                                // Ignore extra taps during animation
                            }
                    } else if gameState.isPerformingShaker {
                        Image("shaker\(gameState.shakerFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
                            .scaleEffect(x: gameState.shakerFlip ? -1 : 1, y: 1)
                            .position(x: figureX, y: figureY)
                            .onTapGesture {
                                // Ignore extra taps during animation
                            }
                    } else if gameState.isWaving {
                        Image("guy_wave\(gameState.waveFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
                            .scaleEffect(x: gameState.shouldFlipWave ? -1 : 1, y: 1)
                            .position(x: figureX, y: figureY)
                    } else if gameState.isJumping {
                        Image("guy_jump\(gameState.jumpFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
                            .scaleEffect(x: gameState.facingRight ? 1 : -1, y: 1)
                            .position(x: figureX, y: figureY)
                    } else {
                        Image(gameState.animationFrame == 0 ? getStandImage() : "guy_move\(gameState.animationFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
                            .scaleEffect(x: gameState.facingRight ? 1 : -1, y: 1)
                            .position(x: figureX, y: figureY)
                            .onTapGesture {
                                // Handle action taps dynamically
                                if gameState.selectedAction == "Jump" {
                                    if !gameState.isJumping && gameState.animationFrame == 0 {
                                        startJumpAction(gameState, geometry)
                                    }
                                } else if let config = ACTION_CONFIGS.first(where: { $0.displayName == gameState.selectedAction }) {
                                    if gameState.currentPerformingAction == nil && !gameState.isJumping {
                                        startActionAction(config, gameState)
                                    }
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
                        .position(x: floatingText.x * geometry.size.width, y: floatingText.y * geometry.size.height)
                }

                ForEach(gameState.fallingLeaves) { leaf in
                    Image(systemName: "leaf.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(.green)
                        .rotationEffect(.degrees(leaf.rotation))
                        .position(x: leaf.x * geometry.size.width, y: leaf.y * geometry.size.height)
                }

                ForEach(gameState.fallingShakers) { shaker in
                    Image("Shaker")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(shaker.rotation))
                        .position(x: shaker.x * geometry.size.width, y: shaker.y * geometry.size.height)
                }
                
                ForEach(gameState.fireworkParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: 4, height: 4)
                        .opacity(1.0 - (particle.age / particle.lifespan))
                        .position(x: particle.x * geometry.size.width, y: particle.y * geometry.size.height)
                }
                
                // Render doors
                ForEach(gameState.doors, id: \.id) { door in
                    let doorScreenX = door.x * geometry.size.width
                    let doorWidth = door.width * geometry.size.width
                    let doorHeight = door.height * geometry.size.height
                    let figureBottomY = baseY // Align with standing guy's bottom
                    let doorScreenY = figureBottomY - (doorHeight / 2) // Center door vertically on this bottom line
                    
                    Rectangle()
                        .fill(Color(red: 0.6, green: 0.4, blue: 0.2)) // Brown color
                        .frame(width: doorWidth, height: doorHeight)
                        .position(x: doorScreenX, y: doorScreenY)
                        .overlay(
                            Rectangle()
                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.0), lineWidth: 2) // Darker brown border
                                .frame(width: doorWidth, height: doorHeight)
                                .position(x: doorScreenX, y: doorScreenY)
                        )
                        .overlay(
                            Text("🚪")
                                .font(.system(size: 20))
                                .position(x: doorScreenX, y: doorScreenY)
                        )
                }
                
                // Room label
                VStack(alignment: .center) {
                    Text(gameState.currentRoomName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(6)
                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 16)
            }
            .onAppear {
                collisionTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak gameState] _ in
                    guard let gameState = gameState else { return }
                    let currentFigureX = ((gameState.figurePosition + 1.0) / 2.0) * geometry.size.width
                    let currentBaseY = geometry.size.height - 80
                    let currentFigureY = currentBaseY - gameState.jumpHeight
                    gameState.checkLeafCollisions(figureX: currentFigureX, figureY: currentFigureY, screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                    gameState.checkShakerCollisions(figureX: currentFigureX, figureY: currentFigureY, screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                    
                    // Check door collision with directional detection
                    if let door = gameState.checkDoorCollision(figureX: currentFigureX, screenWidth: geometry.size.width, screenHeight: geometry.size.height, isMovingRight: gameState.isMovingRight, isMovingLeft: gameState.isMovingLeft) {
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
                            
                            // Position character near the level they just exited
                            if gameState.currentLevel <= mapState.levelBoxes.count {
                                let levelBox = mapState.levelBoxes[gameState.currentLevel - 1]
                                // Position slightly to the left of the level box
                                mapState.characterX = levelBox.x - 150
                                mapState.characterY = levelBox.y
                                mapState.targetX = levelBox.x - 150
                                mapState.targetY = levelBox.y
                            }
                            showGameMap = true
                        } else {
                            // Enter the door - move to center of new room
                            gameState.initializeRoom(door.destinationRoomId)
                            gameState.figurePosition = 0 // Center
                            gameState.stopMovingLeft()
                            gameState.stopMovingRight()
                        }
                    }
                }
            }
            .onDisappear {
                collisionTimer?.invalidate()
                collisionTimer = nil
            }
            .onChange(of: gameState.isWaving) { _, isWaving in
                guard isWaving else { return }
                if Bool.random() {
                    let greeting = Bool.random() ? "*hi*" : "*hey*"
                    gameState.addFloatingText(greeting, x: normX, y: textStartY, color: .blue)
                }
            }
        }
    }
}

private func startMovingLeft(gameState: StickFigureGameState, geometry: GeometryProxy) {
    if gameState.isJumping || gameState.isWaving || gameState.currentPerformingAction != nil || gameState.isPerformingShaker { return }
    gameState.resetIdleTimer()
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

private func stopMovingLeft(gameState: StickFigureGameState) {
    gameState.isMovingLeft = false
    if !gameState.isMovingRight {
        if gameState.currentAction == "move" {
            let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
            gameState.recordActionTime(action: "move", duration: duration)
            gameState.currentAction = ""
        }
        stopAnimation(gameState: gameState)
    }
}

private func startMovingRight(gameState: StickFigureGameState, geometry: GeometryProxy) {
    if gameState.isJumping || gameState.isWaving || gameState.currentPerformingAction != nil || gameState.isPerformingShaker { return }
    gameState.resetIdleTimer()
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

private func stopMovingRight(gameState: StickFigureGameState) {
    gameState.isMovingRight = false
    if !gameState.isMovingLeft {
        if gameState.currentAction == "move" {
            let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
            gameState.recordActionTime(action: "move", duration: duration)
            gameState.currentAction = ""
        }
        stopAnimation(gameState: gameState)
    }
}

private func startAnimation(gameState: StickFigureGameState) {
    gameState.animationTimer?.invalidate()

    var currentFrame = 1
    gameState.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
        if gameState.isMovingLeft || gameState.isMovingRight {
            gameState.animationFrame = currentFrame
            currentFrame += 1
            if currentFrame > 4 {
                currentFrame = 1
            }

            // Apply speed boost multiplier if active
            let speedMultiplier: CGFloat = gameState.speedBoostEndTime != nil ? 2.0 : 1.0
            let moveSpeed = 0.03 * speedMultiplier

            if gameState.isMovingRight {
                gameState.figurePosition += moveSpeed
            } else if gameState.isMovingLeft {
                gameState.figurePosition -= moveSpeed
            }
            
            // Handle screen wrap-around
            gameState.handleScreenWrap(1.0) // Normalized width is 1.0
        }
    }
}

private func stopAnimation(gameState: StickFigureGameState) {
    gameState.animationTimer?.invalidate()
    gameState.animationTimer = nil
    gameState.animationFrame = 0
}// MARK: - Generic Action Handler

private func startAction(_ config: ActionConfig, gameState: StickFigureGameState) {
    // Stop other animations
    gameState.animationTimer?.invalidate()
    gameState.actionTimer?.invalidate()
    gameState.resetIdleTimer()
    
    // Set up action state
    gameState.currentPerformingAction = config.id
    gameState.actionFrame = config.animationFrames.first ?? 1
    gameState.actionFlip = config.supportsFlip ? Bool.random() : false
    
    let actionStartTime = Date().timeIntervalSince1970 * 1000
    
    // Handle variable timing (like pushups)
    if let variableTiming = config.variableTiming {
        startActionWithVariableTiming(config, gameState: gameState, variableTiming: variableTiming, startTime: actionStartTime)
    } else {
        startActionWithUniformTiming(config, gameState: gameState, startTime: actionStartTime)
    }
}

private func startActionWithUniformTiming(_ config: ActionConfig, gameState: StickFigureGameState, startTime: Double) {
    var frameIndex = 0
    let speedMultiplier = (config.supportsSpeedBoost && gameState.speedBoostEndTime != nil) ? 0.5 : 1.0
    let interval = config.baseFrameInterval * speedMultiplier
    
    gameState.actionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        if frameIndex < config.animationFrames.count {
            gameState.actionFrame = config.animationFrames[frameIndex]
            frameIndex += 1
        } else {
            // Animation complete
            gameState.actionTimer?.invalidate()
            gameState.actionTimer = nil
            gameState.currentPerformingAction = nil
            gameState.actionFrame = 0
            gameState.actionFlip = false
            
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
    let speedMultiplier = (config.supportsSpeedBoost && gameState.speedBoostEndTime != nil) ? 0.5 : 1.0
    
    func scheduleNextFrame() {
        guard frameIndex < config.animationFrames.count else {
            // Animation complete
            gameState.actionTimer?.invalidate()
            gameState.actionTimer = nil
            gameState.currentPerformingAction = nil
            gameState.actionFrame = 0
            gameState.actionFlip = false
            
            let duration = Date().timeIntervalSince1970 * 1000 - startTime
            gameState.recordActionTime(action: config.id, duration: duration)
            
            if gameState.currentLevel >= config.unlockLevel {
                gameState.addPoints(config.pointsPerCompletion, action: config.id)
            }
            return
        }
        
        let currentFrame = config.animationFrames[frameIndex]
        gameState.actionFrame = currentFrame
        frameIndex += 1
        
        // Use custom timing if specified, otherwise use base interval
        let baseInterval = variableTiming[currentFrame] ?? config.baseFrameInterval
        let interval = baseInterval * speedMultiplier
        
        gameState.actionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            scheduleNextFrame()
        }
    }
    
    scheduleNextFrame()
}

private func startJump(gameState: StickFigureGameState, geometry: GeometryProxy) {
    gameState.animationTimer?.invalidate()
    gameState.jumpTimer?.invalidate()
    gameState.resetIdleTimer()
    gameState.isJumping = true
    gameState.jumpFrame = 1
    gameState.jumpHeight = 0

    let figureX = ((gameState.figurePosition + 1.0) / 2.0)
    let baseY = geometry.size.height - 80
    let startY = max(0.05, (baseY - 120) / geometry.size.height)
    gameState.addFloatingText("*jump*", x: figureX, y: startY, color: .blue)

    let jumpStartTime = Date().timeIntervalSince1970 * 1000
    let jumpHeightPeak: CGFloat = 100

    var frameCount = 0
    // Apply speed boost: 0.1s normal, 0.05s boosted (2x faster)
    let baseInterval: TimeInterval = 0.1
    let interval = gameState.speedBoostEndTime != nil ? baseInterval / 2.0 : baseInterval
    
    gameState.jumpTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        frameCount += 1
        gameState.jumpFrame = min(frameCount, 3)

        if frameCount == 1 {
            gameState.jumpHeight = jumpHeightPeak * 0.5
        } else if frameCount == 2 {
            gameState.jumpHeight = jumpHeightPeak
        } else if frameCount == 3 {
            gameState.jumpHeight = jumpHeightPeak * 0.3
        } else if frameCount >= 4 {
            gameState.jumpHeight = 0
        }

        if frameCount >= 4 {
            gameState.jumpTimer?.invalidate()
            gameState.jumpTimer = nil
            gameState.isJumping = false
            gameState.jumpFrame = 0
            gameState.jumpHeight = 0

            let jumpDuration = Date().timeIntervalSince1970 * 1000 - jumpStartTime
            gameState.recordActionTime(action: "jump", duration: jumpDuration)
            if gameState.currentLevel >= 2 {
                gameState.addPoints(2, action: "jump")
            }
        }
    }
}

// MARK: - Stats Row

private struct StatRow: View {
    let label: String
    let value: String
    var isUnlocked: Bool = true
    var isCurrentLevel: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(isCurrentLevel ? .black : (isUnlocked ? .gray : Color.gray.opacity(0.4)))
            Spacer()
            Text(value)
                .fontWeight(isCurrentLevel ? .semibold : .regular)
                .foregroundColor(isCurrentLevel ? .black : (isUnlocked ? .black : Color.gray.opacity(0.4)))
        }
    }
}

// #Preview {
//     Game1Module().view(environment: .init())
// }
