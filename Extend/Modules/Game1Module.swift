////
////  Game1Module.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/16/26.
////
// Stick figure running and jumping game

import SwiftUI

public struct Game1Module: AppModule {
    public let id: UUID = ModuleIDs.game1
    public let displayName: String = "Game 1"
    public let iconName: String = "gamecontroller.fill"
    public let description: String = "Stick figure running game"

    public var order: Int = 0
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        let view = Game1ModuleView(module: self)
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
    var isPerformingCurls: Bool = false
    var curlFrame: Int = 0
    var curlFlip: Bool = false
    var isPerformingKettlebell: Bool = false
    var kettlebellFrame: Int = 0
    var kettlebellFlip: Bool = false
    var isPerformingShaker: Bool = false
    var shakerFrame: Int = 0
    var shakerFlip: Bool = false
    var shakerCatchLocation: (x: CGFloat, y: CGFloat)?
    var isPerformingPullup: Bool = false
    var pullupFrame: Int = 0
    var animationTimer: Timer?
    var jumpTimer: Timer?
    var waveTimer: Timer?
    var curlsTimer: Timer?
    var kettlebellTimer: Timer?
    var shakerTimer: Timer?
    var pullupTimer: Timer?
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

    var totalJumpTime: Double = 0
    var totalMoveTime: Double = 0
    var totalCurlsTime: Double = 0
    var totalKettlebellTime: Double = 0
    var totalPullupTime: Double = 0
    var allTimeElapsed: Double = 0
    var totalLeavesCaught: Int = 0
    var totalShakersCaught: Int = 0

    var actionStartTime: Double = 0
    var currentAction: String = ""
    var statsSaveAccumulator: Double = 0
    
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
    private let totalJumpKey = "game1_total_jump_time"
    private let totalMoveKey = "game1_total_move_time"
    private let totalCurlsKey = "game1_total_curls_time"
    private let totalKettlebellKey = "game1_total_kettlebell_time"
    private let totalPullupKey = "game1_total_pullup_time"
    private let allTimeElapsedKey = "game1_all_time_elapsed"
    private let totalLeavesCaughtKey = "game1_total_leaves_caught"
    private let totalShakersCaughtKey = "game1_total_shakers_caught"

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
    }

    private func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }

    func saveHighScore() {
        UserDefaults.standard.set(highScore, forKey: highScoreKey)
    }

    private func loadStats() {
        totalJumpTime = UserDefaults.standard.double(forKey: totalJumpKey)
        totalMoveTime = UserDefaults.standard.double(forKey: totalMoveKey)
        totalCurlsTime = UserDefaults.standard.double(forKey: totalCurlsKey)
        totalKettlebellTime = UserDefaults.standard.double(forKey: totalKettlebellKey)
        totalPullupTime = UserDefaults.standard.double(forKey: totalPullupKey)
        allTimeElapsed = UserDefaults.standard.double(forKey: allTimeElapsedKey)
        totalLeavesCaught = UserDefaults.standard.integer(forKey: totalLeavesCaughtKey)
        totalShakersCaught = UserDefaults.standard.integer(forKey: totalShakersCaughtKey)
        currentLevel = max(1, UserDefaults.standard.integer(forKey: currentLevelKey))
        if currentLevel == 0 { currentLevel = 1 }
        currentPoints = UserDefaults.standard.integer(forKey: currentPointsKey)
    }

    func saveStats() {
        UserDefaults.standard.set(totalJumpTime, forKey: totalJumpKey)
        UserDefaults.standard.set(totalMoveTime, forKey: totalMoveKey)
        UserDefaults.standard.set(totalCurlsTime, forKey: totalCurlsKey)
        UserDefaults.standard.set(totalKettlebellTime, forKey: totalKettlebellKey)
        UserDefaults.standard.set(totalPullupTime, forKey: totalPullupKey)
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
            if !self.isMovingLeft && !self.isMovingRight && !self.isJumping && !self.isWaving && !self.isPerformingCurls && !self.isPerformingKettlebell && !self.isPerformingShaker && !self.isPerformingPullup {
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
        let levelBasedActions = ["run", "jump", "curls", "kettlebell", "pullup"]
        if levelBasedActions.contains(action) {
            sessionActions.insert(action)
        }
        
        // Get max possible combo for current level (number of unlocked level-based actions)
        let maxComboForLevel = currentLevel // Level 1=1 action, Level 2=2 actions, etc.
        
        // Only count level-based unlocked actions for combo
        let unlockedLevelBasedActions = getLevelBasedActionsForLevel(currentLevel)
        let validSessionActions = sessionActions.filter { unlockedLevelBasedActions.contains($0) }
        let comboCount = min(validSessionActions.count, maxComboForLevel)
        
        // Combo multiplier: base points + comboCount% bonus
        // e.g., 1 action = 1.0x, 2 actions = 1.02x, 3 actions = 1.03x, etc.
        let multiplier: Double = comboCount > 1 ? 1.0 + (Double(comboCount) * 0.01) : 1.0
        let exactPoints = Double(points) * multiplier
        let totalPoints = Int(ceil(exactPoints)) // Always round up
        currentPoints += totalPoints
        
        print("DEBUG: Action=\(action), BasePoints=\(points), ComboCount=\(comboCount)/\(maxComboForLevel), Multiplier=\(multiplier), ExactPoints=\(exactPoints), RoundedPoints=\(totalPoints)")
        
        let pointsNeeded = currentLevel * 100
        if currentPoints >= pointsNeeded {
            levelUp()
        }
        saveStats()
    }
    
    func getMaxComboForLevel(_ level: Int) -> Int {
        // Returns the maximum number of level-based actions (not including leaves/shakers)
        // Level 1: 1 action (run)
        // Level 2: 2 actions (run, jump)
        // Level 3: 3 actions (run, jump, curls)
        // Level 4: 4 actions (run, jump, curls, kettlebell)
        // Level 5: 5 actions (run, jump, curls, kettlebell, pullup)
        return level
    }
    
    func getLevelBasedActionsForLevel(_ level: Int) -> Set<String> {
        // Only level-based actions, not leaves/shakers
        var actions: Set<String> = ["run"] // Level 1
        if level >= 2 { actions.insert("jump") }
        if level >= 3 { actions.insert("curls") }
        if level >= 4 { actions.insert("kettlebell") }
        if level >= 5 { actions.insert("pullup") }
        return actions
    }
    
    func getValidComboCount() -> Int {
        let maxCombo = getMaxComboForLevel(currentLevel)
        let unlockedActions = getLevelBasedActionsForLevel(currentLevel)
        let validCount = sessionActions.filter { unlockedActions.contains($0) }.count
        return min(validCount, maxCombo)
    }
    
    func levelUp() {
        currentLevel += 1
        currentPoints = 0
        
        // Show level up message with larger text
        let newAction = getActionUnlockedAtLevel(currentLevel)
        let message = "Level \(currentLevel)!\n\(newAction) Unlocked!"
        addFloatingText(message, x: 0.5, y: 0.4, color: .purple, fontSize: 24)
        saveStats()
    }
    
    func getActionUnlockedAtLevel(_ level: Int) -> String {
        switch level {
        case 2: return "Jump"
        case 3: return "Curls"
        case 4: return "Kettlebell swings"
        case 5: return "Pull ups"
        default: return ""
        }
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
        shakerTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
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
            } else if step >= 2 && step < 5 {
                // Hold frame 2 for ~1 second (3 more intervals of 0.3s)
            } else if step == 5 {
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
        if action == "jump" {
            totalJumpTime += duration
        } else if action == "move" {
            totalMoveTime += duration
        } else if action == "curls" {
            totalCurlsTime += duration
        } else if action == "kettlebell" {
            totalKettlebellTime += duration
        } else if action == "pullup" {
            totalPullupTime += duration
        }
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
        curlsTimer?.invalidate()
        kettlebellTimer?.invalidate()
        shakerTimer?.invalidate()
        leafSpawnTimer?.invalidate()
        shakerSpawnTimer?.invalidate()
        leafUpdateTimer?.invalidate()
        shakerUpdateTimer?.invalidate()
    }
}

// MARK: - Main Game View

private struct Game1ModuleView: View {
    let module: Game1Module
    @State private var gameState = StickFigureGameState()
    @State private var showStats = false
    @State private var showActionPicker = false
    @Environment(ModuleState.self) var moduleState

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.98)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        gameState.animationTimer?.invalidate()
                        gameState.jumpTimer?.invalidate()
                        gameState.floatingTextTimer?.invalidate()
                        gameState.idleTimer?.invalidate()
                        gameState.waveTimer?.invalidate()
                        gameState.curlsTimer?.invalidate()
                        gameState.kettlebellTimer?.invalidate()
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
                            let pointsNeeded = gameState.currentLevel * 100
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
                        
                        Text("\(gameState.currentPoints)/\(gameState.currentLevel * 100)")
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

                GamePlayArea(gameState: gameState)

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
                .padding(.bottom, 12)
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
                        StatRow(label: "Current Points", value: "\(gameState.currentPoints)/\(gameState.currentLevel * 100)")
                        StatRow(label: "Time Elapsed", value: String(format: "%.1f s", gameState.timeElapsed))
                        StatRow(label: "All Time Elapsed", value: gameState.formatTimeDuration(gameState.allTimeElapsed * 1000))
                        Divider()
                        Text("Actions & Points")
                            .font(.headline)
                            .foregroundColor(.primary)
                        StatRow(label: "Lvl 1: Run", value: gameState.formatTimeDuration(gameState.totalMoveTime), isUnlocked: true, isCurrentLevel: true)
                        StatRow(label: "Lvl 2: Jump", value: gameState.formatTimeDuration(gameState.totalJumpTime), isUnlocked: gameState.currentLevel >= 2)
                        StatRow(label: "Lvl 3: Curls", value: gameState.formatTimeDuration(gameState.totalCurlsTime), isUnlocked: gameState.currentLevel >= 3)
                        StatRow(label: "Lvl 4: Kettlebell swings", value: gameState.formatTimeDuration(gameState.totalKettlebellTime), isUnlocked: gameState.currentLevel >= 4)
                        StatRow(label: "Lvl 5: Pull ups", value: gameState.formatTimeDuration(gameState.totalPullupTime), isUnlocked: gameState.currentLevel >= 5)
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
                            Picker("Level", selection: Binding(
                                get: { gameState.currentLevel },
                                set: { newLevel in
                                    gameState.currentLevel = newLevel
                                    gameState.currentPoints = 0
                                    gameState.saveStats()
                                }
                            )) {
                                ForEach(1...5, id: \.self) { level in
                                    Text("Level \(level)").tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Button(action: {
                            // Reset all game data
                            gameState.currentLevel = 1
                            gameState.currentPoints = 0
                            gameState.sessionActions.removeAll()
                            gameState.totalJumpTime = 0
                            gameState.totalMoveTime = 0
                            gameState.totalCurlsTime = 0
                            gameState.totalKettlebellTime = 0
                            gameState.totalPullupTime = 0
                            gameState.totalLeavesCaught = 0
                            gameState.totalShakersCaught = 0
                            gameState.allTimeElapsed = 0
                            gameState.timeElapsed = 0
                            gameState.score = 0
                            gameState.highScore = 0
                            gameState.saveStats()
                            gameState.saveHighScore()
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
                .padding(.top, 12)
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
                            ActionPickerButton(title: "Run", isSelected: gameState.selectedAction == "Run") {
                                gameState.selectedAction = "Run"
                                showActionPicker = false
                            }
                            
                            if gameState.currentLevel >= 2 {
                                Divider()
                                ActionPickerButton(title: "Jump", isSelected: gameState.selectedAction == "Jump") {
                                    gameState.selectedAction = "Jump"
                                    showActionPicker = false
                                }
                            }
                            
                            if gameState.currentLevel >= 3 {
                                Divider()
                                ActionPickerButton(title: "Bicep Curls", isSelected: gameState.selectedAction == "Bicep Curls") {
                                    gameState.selectedAction = "Bicep Curls"
                                    showActionPicker = false
                                }
                            }
                            
                            if gameState.currentLevel >= 4 {
                                Divider()
                                ActionPickerButton(title: "Kettlebell swings", isSelected: gameState.selectedAction == "Kettlebell swings") {
                                    gameState.selectedAction = "Kettlebell swings"
                                    showActionPicker = false
                                }
                            }
                            
                            if gameState.currentLevel >= 5 {
                                Divider()
                                ActionPickerButton(title: "Pull ups", isSelected: gameState.selectedAction == "Pull ups") {
                                    gameState.selectedAction = "Pull ups"
                                    showActionPicker = false
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
    @State private var collisionTimer: Timer?
    
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
                                startMovingLeft(gameState: gameState, geometry: geometry)
                            } else {
                                stopMovingLeft(gameState: gameState)
                            }
                        }, perform: {})

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                            if isPressing {
                                startMovingRight(gameState: gameState, geometry: geometry)
                            } else {
                                stopMovingRight(gameState: gameState)
                            }
                        }, perform: {})
                }

                VStack {
                    Spacer()

                    if gameState.isPerformingPullup {
                        Image("pullup\(gameState.pullupFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
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
                    } else if gameState.isPerformingKettlebell {
                        Image("kb\(gameState.kettlebellFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
                            .scaleEffect(x: gameState.kettlebellFlip ? -1 : 1, y: 1)
                            .position(x: figureX, y: figureY)
                            .onTapGesture {
                                // Ignore extra taps during animation
                            }
                    } else if gameState.isPerformingCurls {
                        Image("guy_curls\(gameState.curlFrame)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 150)
                            .scaleEffect(x: gameState.curlFlip ? -1 : 1, y: 1)
                            .position(x: figureX, y: figureY)
                            .onTapGesture {
                                if gameState.selectedAction == "Bicep Curls" {
                                    // Ignore extra taps during animation
                                }
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
                                if gameState.selectedAction == "Bicep Curls" {
                                    if !gameState.isPerformingCurls && !gameState.isJumping {
                                        startCurls(gameState: gameState)
                                    }
                                } else if gameState.selectedAction == "Kettlebell swings" {
                                    if !gameState.isPerformingKettlebell && !gameState.isJumping {
                                        startKettlebell(gameState: gameState)
                                    }
                                } else if gameState.selectedAction == "Pull ups" {
                                    if !gameState.isPerformingPullup && !gameState.isJumping {
                                        startPullup(gameState: gameState)
                                    }
                                } else if gameState.selectedAction == "Jump" {
                                    if !gameState.isJumping && gameState.animationFrame == 0 {
                                        startJump(gameState: gameState, geometry: geometry)
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
            }
            .onAppear {
                collisionTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak gameState] _ in
                    guard let gameState = gameState else { return }
                    let currentFigureX = ((gameState.figurePosition + 1.0) / 2.0) * geometry.size.width
                    let currentBaseY = geometry.size.height - 80
                    let currentFigureY = currentBaseY - gameState.jumpHeight
                    gameState.checkLeafCollisions(figureX: currentFigureX, figureY: currentFigureY, screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                    gameState.checkShakerCollisions(figureX: currentFigureX, figureY: currentFigureY, screenWidth: geometry.size.width, screenHeight: geometry.size.height)
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
                    gameState.addFloatingText(greeting, x: normX, y: textStartY, color: .orange)
                }
            }
        }
    }
}

private func startMovingLeft(gameState: StickFigureGameState, geometry: GeometryProxy) {
    if gameState.isJumping || gameState.isWaving || gameState.isPerformingCurls || gameState.isPerformingKettlebell || gameState.isPerformingShaker || gameState.isPerformingPullup { return }
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
    if gameState.isJumping || gameState.isWaving || gameState.isPerformingCurls || gameState.isPerformingKettlebell || gameState.isPerformingShaker || gameState.isPerformingPullup { return }
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
                gameState.figurePosition = min(gameState.figurePosition + moveSpeed, 1.0)
            } else if gameState.isMovingLeft {
                gameState.figurePosition = max(gameState.figurePosition - moveSpeed, -1.0)
            }
        }
    }
}

private func stopAnimation(gameState: StickFigureGameState) {
    gameState.animationTimer?.invalidate()
    gameState.animationTimer = nil
    gameState.animationFrame = 0
}

private func startCurls(gameState: StickFigureGameState) {
    gameState.animationTimer?.invalidate()
    gameState.curlsTimer?.invalidate()
    gameState.resetIdleTimer()
    gameState.isPerformingCurls = true
    gameState.curlFrame = 1
    gameState.curlFlip = false

    let curlStartTime = Date().timeIntervalSince1970 * 1000
    let animationSequence = [2, 1, 2, 1, 3, 1]
    let flipSequence: [Bool] = [false, false, true, false, false, false]

    var frameIndex = 0
    // Apply speed boost: 0.2s normal, 0.1s boosted (2x faster)
    let baseInterval: TimeInterval = 0.2
    let interval = gameState.speedBoostEndTime != nil ? baseInterval / 2.0 : baseInterval
    
    gameState.curlsTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        if frameIndex < animationSequence.count {
            gameState.curlFrame = animationSequence[frameIndex]
            gameState.curlFlip = flipSequence[frameIndex]
            frameIndex += 1
        } else {
            gameState.curlsTimer?.invalidate()
            gameState.curlsTimer = nil
            gameState.isPerformingCurls = false
            gameState.curlFrame = 0
            gameState.curlFlip = false

            let curlDuration = Date().timeIntervalSince1970 * 1000 - curlStartTime
            gameState.recordActionTime(action: "curls", duration: curlDuration)
            if gameState.currentLevel >= 3 {
                gameState.addPoints(3, action: "curls")
            }
        }
    }
}

private func startKettlebell(gameState: StickFigureGameState) {
    gameState.animationTimer?.invalidate()
    gameState.kettlebellTimer?.invalidate()
    gameState.resetIdleTimer()
    gameState.isPerformingKettlebell = true
    gameState.kettlebellFrame = 1
    gameState.kettlebellFlip = Bool.random()

    let kettlebellStartTime = Date().timeIntervalSince1970 * 1000
    let animationSequence = [1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 7, 8, 7, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1]

    var frameIndex = 0
    // Apply speed boost: 0.15s normal, 0.075s boosted (2x faster)
    let baseInterval: TimeInterval = 0.15
    let interval = gameState.speedBoostEndTime != nil ? baseInterval / 2.0 : baseInterval
    
    gameState.kettlebellTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        if frameIndex < animationSequence.count {
            gameState.kettlebellFrame = animationSequence[frameIndex]
            frameIndex += 1
        } else {
            gameState.kettlebellTimer?.invalidate()
            gameState.kettlebellTimer = nil
            gameState.isPerformingKettlebell = false
            gameState.kettlebellFrame = 0
            gameState.kettlebellFlip = false

            let kettlebellDuration = Date().timeIntervalSince1970 * 1000 - kettlebellStartTime
            gameState.recordActionTime(action: "kettlebell", duration: kettlebellDuration)
            if gameState.currentLevel >= 4 {
                gameState.addPoints(4, action: "kettlebell")
            }
        }
    }
}

private func startPullup(gameState: StickFigureGameState) {
    gameState.animationTimer?.invalidate()
    gameState.pullupTimer?.invalidate()
    gameState.resetIdleTimer()
    gameState.isPerformingPullup = true
    gameState.pullupFrame = 1

    let pullupStartTime = Date().timeIntervalSince1970 * 1000
    // Animation sequence: 1,2,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,2,1 (7 reps at top)
    let animationSequence = [1, 2, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 4, 3, 2, 1]

    var frameIndex = 0
    // Apply speed boost: 0.2s normal, 0.1s boosted (2x faster)
    let baseInterval: TimeInterval = 0.2
    let interval = gameState.speedBoostEndTime != nil ? baseInterval / 2.0 : baseInterval
    
    gameState.pullupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        if frameIndex < animationSequence.count {
            gameState.pullupFrame = animationSequence[frameIndex]
            frameIndex += 1
        } else {
            gameState.pullupTimer?.invalidate()
            gameState.pullupTimer = nil
            gameState.isPerformingPullup = false
            gameState.pullupFrame = 0

            let pullupDuration = Date().timeIntervalSince1970 * 1000 - pullupStartTime
            gameState.recordActionTime(action: "pullup", duration: pullupDuration)
            if gameState.currentLevel >= 5 {
                gameState.addPoints(5, action: "pullup")
            }
        }
    }
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

#Preview {
    Game1ModuleView(module: Game1Module())
}
