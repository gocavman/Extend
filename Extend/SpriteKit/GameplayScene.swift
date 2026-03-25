
import SpriteKit

// MARK: - Falling Item

struct FallingItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let itemType: String  // catchable ID like "leaf", "heart", etc.
    var x: CGFloat
    var y: CGFloat
    var rotation: Double = 0
    var horizontalVelocity: CGFloat = 0
    var verticalSpeed: CGFloat = 0.001
    
    static func == (lhs: FallingItem, rhs: FallingItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// SpriteKit scene for gameplay with character movement and interactions
class GameplayScene: GameScene {
private var characterNode: SKNode?
var levelLabel: SKLabelNode?
var pointsTextLabel: SKLabelNode?  // Label for "Points: " text
var pointsValueLabel: SKLabelNode?  // Separate label for just the points number
var animationFrameIndex: Int = 0

// Eye blinking properties
private var lastInteractionTime: TimeInterval = 0
private var isEyesBlinking: Bool = false
private var eyesBlinkEndTime: TimeInterval = 0
private let inactivityThreshold: TimeInterval = 15.0  // 15 seconds
private let blinkDuration: TimeInterval = 0.25  // 1/2 second

// Button areas for UI
private var exitButtonArea: SKShapeNode?
private var statsButtonArea: SKShapeNode?
private var appearanceButtonNode: SKNode?

// Catchables properties
private var fallingItems: [FallingItem] = []
private var catchableNodes: [UUID: SKNode] = [:]  // Track rendered nodes by item ID
private let catchableContainerNode = SKNode()  // Container for all catchable sprites
private var lastSpawnTime: [String: TimeInterval] = [:]  // Track last spawn time per catchable ID
private var lastGlobalSpawnTime: TimeInterval = 0  // Global spawn timer for weighted pool system

// Boost properties
private var boostEndTime: TimeInterval = 0
private var boostTimerLabel: SKLabelNode?
private var floatingTexts: [FloatingText] = []
private let floatingTextContainer = SKNode()  // Container for floating text

// Countdown properties
private var countdownTimerLabel: SKLabelNode?

// Current selected action
private var selectedAction: ActionConfig?
private var selectedActionLabel: SKLabelNode?  // Label to display selected action name
private var actionZoneNode: SKShapeNode?  // Reference to action zone for visual updates

// Edit mode properties - REMOVED (now on Map Screen)
// private var isEditMode: Bool = false
// private var editButtonArea: SKShapeNode?
// private var figurePositionX: CGFloat = 0
// private var figurePositionY: CGFloat = 0

// Interactive joint dragging for edit mode - REMOVED
// private var draggedJointName: String?
// private var dragStartPoint: CGPoint = .zero
// private var dragStartAngle: CGFloat = 0

override func didMove(to view: SKView) {
    super.didMove(to: view)
    
    // Initialize gameState if needed
    guard let gameState = gameState else {
        print("🎮 ERROR: gameState is nil!")
        return
    }
    
    // Ensure the room is initialized with stick figure data
    if gameState.standFrame == nil {
        gameState.initializeRoom("level_\(gameState.currentLevel)")
    }
    
    backgroundColor = SKColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
    
    // Setup catchables container
    catchableContainerNode.zPosition = 3  // In front of background but behind UI
    addChild(catchableContainerNode)
    
    // Setup floating text container
    floatingTextContainer.zPosition = 50  // In front of everything
    addChild(floatingTextContainer)
    
    // Create UI
    setupUI()
    
    // Create character
    setupCharacter()
    
    // Setup brick ground
    setupBrickGround()
    
    // Create touch zones
    setupControlZones()
    
    // Set up callback for action/exercise points floating animation
    gameState.onPointsAwarded = { [weak self] points, x, y in
        let pointsText = "+\(points)"
        self?.addFloatingText(pointsText, x: x, y: y, color: .green, points: points)
        
        // Haptic feedback for points awarded
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // Set up callback for level up notification
    gameState.onLevelUp = { [weak self] newLevel in
        self?.levelLabel?.text = "Level: \(newLevel)"
    }
    
    // Auto-select action from gameState if available
    if !gameState.selectedAction.isEmpty,
       let actionConfig = ACTION_CONFIGS.first(where: { $0.id == gameState.selectedAction }) {
        selectedAction = actionConfig
        selectedActionLabel?.text = actionConfig.displayName
        print("🎮 Auto-selected action: \(actionConfig.displayName)")
    }
    
    // Initialize eye blinking timer
    lastInteractionTime = CACurrentMediaTime()
    
    // Start game loop
    startGameLoop()
}

private func setupUI() {
    // TOP BAR - Moved down to avoid safe area
    let topBarY: CGFloat = size.height - 100
    
    // Exit button - top left
    exitButtonArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
    exitButtonArea?.position = CGPoint(x: 35, y: topBarY)
    exitButtonArea?.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.7)
    exitButtonArea?.strokeColor = .black
    exitButtonArea?.lineWidth = 2
    exitButtonArea?.name = "exitButton"
    exitButtonArea?.zPosition = 100
    addChild(exitButtonArea!)
    
    let exitLabel = SKLabelNode(fontNamed: "Arial")
    exitLabel.text = "EXIT"
    exitLabel.fontSize = 10
    exitLabel.fontColor = .white
    exitLabel.position = CGPoint(x: 35, y: topBarY)
    exitLabel.zPosition = 101
    addChild(exitLabel)
    
    // Stats button - top right
    statsButtonArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
    statsButtonArea?.position = CGPoint(x: size.width - 35, y: topBarY)
    statsButtonArea?.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.7)
    statsButtonArea?.strokeColor = .black
    statsButtonArea?.lineWidth = 2
    statsButtonArea?.name = "statsButton"
    statsButtonArea?.zPosition = 100
    addChild(statsButtonArea!)
    
    let statsLabel = SKLabelNode(fontNamed: "Arial")
    statsLabel.text = "STATS"
    statsLabel.fontSize = 10
    statsLabel.fontColor = .white
    statsLabel.position = CGPoint(x: size.width - 35, y: topBarY)
    statsLabel.zPosition = 101
    addChild(statsLabel)
    
    // Appearance button - left of Stats button (icon only, no background box)
    if let sfSymbolImage = createSFSymbolImage(name: "figure.stand", size: CGSize(width: 24, height: 24), color: UIColor.white) {
        appearanceButtonNode = SKSpriteNode(texture: SKTexture(image: sfSymbolImage))
        appearanceButtonNode?.position = CGPoint(x: size.width - 100, y: topBarY)
        appearanceButtonNode?.name = "appearanceButton"
        appearanceButtonNode?.zPosition = 101
        addChild(appearanceButtonNode!)
    } else {
        // Fallback to emoji if SF Symbol creation fails
        appearanceButtonNode = SKLabelNode(fontNamed: "Arial")
        (appearanceButtonNode as? SKLabelNode)?.text = "🧍"
        (appearanceButtonNode as? SKLabelNode)?.fontSize = 16
        (appearanceButtonNode as? SKLabelNode)?.fontColor = .white
        appearanceButtonNode?.position = CGPoint(x: size.width - 100, y: topBarY)
        appearanceButtonNode?.name = "appearanceButton"
        appearanceButtonNode?.zPosition = 101
        addChild(appearanceButtonNode!)
    }
    
    // Level display - top center left (level ONLY, no points)
    levelLabel = SKLabelNode(fontNamed: "Arial")
    levelLabel?.fontSize = 12
    levelLabel?.fontColor = .black
    levelLabel?.position = CGPoint(x: size.width / 2 - 80, y: topBarY)
    levelLabel?.text = "Level: \(gameState?.currentLevel ?? 1)"
    levelLabel?.zPosition = 101
    if let label = levelLabel { addChild(label) }
    
    // Points label text - "Points: " (static)
    pointsTextLabel = SKLabelNode(fontNamed: "Arial")
    pointsTextLabel?.fontSize = 12
    pointsTextLabel?.fontColor = .black
    pointsTextLabel?.position = CGPoint(x: size.width / 2 - 5, y: topBarY)
    pointsTextLabel?.text = "Points: "
    pointsTextLabel?.zPosition = 101
    if let label = pointsTextLabel { addChild(label) }
    
    // Points display - separate value label (animates separately, close to "Points:" label)
    pointsValueLabel = SKLabelNode(fontNamed: "Arial")
    pointsValueLabel?.fontSize = 12
    pointsValueLabel?.fontColor = .black
    pointsValueLabel?.position = CGPoint(x: size.width / 2 + 40, y: topBarY)
    pointsValueLabel?.text = "\(gameState?.currentPoints ?? 0)"
    pointsValueLabel?.zPosition = 101
    if let label = pointsValueLabel { addChild(label) }
    
    // Boost timer - top center below level label
    boostTimerLabel = SKLabelNode(fontNamed: "Arial")
    boostTimerLabel?.fontSize = 11
    boostTimerLabel?.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)  // Orange
    boostTimerLabel?.position = CGPoint(x: size.width / 2, y: topBarY - 25)
    boostTimerLabel?.text = ""
    boostTimerLabel?.zPosition = 101
    boostTimerLabel?.isHidden = true
    if let label = boostTimerLabel { addChild(label) }
    
    // Countdown timer - positioned above stick figure (will be updated during updateCountdownTimer)
    countdownTimerLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
    countdownTimerLabel?.fontSize = 14
    countdownTimerLabel?.fontColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)  // Green
    countdownTimerLabel?.position = CGPoint(x: size.width / 2, y: size.height / 2 + 100)  // Default position, will be updated
    countdownTimerLabel?.text = ""
    countdownTimerLabel?.zPosition = 101
    countdownTimerLabel?.isHidden = true
    if let label = countdownTimerLabel { addChild(label) }
}

    private func setupCharacter() {
        guard let gameState = gameState else {
            print("🎮 ERROR: gameState is nil in setupCharacter")
            return
        }
        
        // Use the Stand frame from gameState
        if let standFrame = gameState.standFrame {
            // Apply muscle scaling to the stand frame
            let scaledFrame = applyMuscleScaling(to: standFrame)
            // Apply appearance colors to the frame
            var frameWithAppearance = scaledFrame
            StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
            
            // Create a container node
            let characterContainer = SKNode()
            characterContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
            characterContainer.name = "character"
            characterContainer.zPosition = 10
            
            // Use renderStickFigure with proper scale and figure offsets
            let offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, y: frameWithAppearance.figureOffsetY)
            let stickFigureNode = renderStickFigure(frameWithAppearance, at: offsetPosition, scale: 1.2, flipped: false, jointShapeSize: frameWithAppearance.jointShapeSize)
            characterContainer.addChild(stickFigureNode)
            
            // Render stand frame objects
            renderFrameObjects(gameState.standFrameObjects, on: characterContainer, scale: 1.2, figureOffsetX: frameWithAppearance.figureOffsetX, figureOffsetY: frameWithAppearance.figureOffsetY, shouldFlip: false)
            
            addChild(characterContainer)
            characterNode = characterContainer
        }
}

private func setupBrickGround() {
    let groundNode = SKNode()
    groundNode.name = "brickGround"
    groundNode.zPosition = 5  // Behind character (which is at zPosition 10)
    
    // Brick dimensions
    let brickWidth: CGFloat = 40
    let brickHeight: CGFloat = 20
    let mortar: CGFloat = 1  // Spacing between bricks
    
    // Character is at y = size.height * 0.35
    // We want ground to be just below character feet
    let groundY = size.height * 0.35 - 80  // Slightly below character position
    
    // DEBUG: Print screen dimensions
    print("🧱 BRICK DEBUG: Scene size = \(size)")
    print("🧱 BRICK DEBUG: Scene width = \(size.width), height = \(size.height)")
    print("🧱 BRICK DEBUG: Scene scaleMode = \(scaleMode)")
    if let view = view {
        print("🧱 BRICK DEBUG: View size = \(view.bounds.size)")
        print("🧱 BRICK DEBUG: View frame = \(view.frame)")
    }
    
    // Colors for brick effect (dark red/orange/gray/black)
    let brickColors: [SKColor] = [
        SKColor(red: 0.6, green: 0.2, blue: 0.1, alpha: 1.0),    // Dark red
        SKColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 1.0),    // Dark orange
        SKColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1.0),    // Gray/brown
        SKColor(red: 0.3, green: 0.2, blue: 0.2, alpha: 1.0)     // Dark gray/black
    ]
    
    // Create 3 rows of bricks
    for row in 0..<3 {
        let rowY = groundY - CGFloat(row) * (brickHeight + mortar)
        
        // Offset every other row by half a brick width (brick bond pattern)
        let offsetX = row % 2 == 1 ? brickWidth / 2 : 0
        
        // Calculate how many bricks needed to cover full screen width plus overlap
        // From left edge (-width/2) to right edge (+width/2) = full width
        // With offset applied, we need: width + offset + extra safety margin
        let distanceToCover = size.width + offsetX + brickWidth * 2  // Extra margin on both sides
        let bricksPerRow = Int(ceil(distanceToCover / (brickWidth + mortar)))
        
        print("🧱 BRICK DEBUG: Row \(row) - bricksPerRow = \(bricksPerRow), offsetX = \(offsetX)")
        
        var minX: CGFloat = CGFloat.infinity
        var maxX: CGFloat = -CGFloat.infinity
        
        for brickIndex in 0..<bricksPerRow {
            // Position bricks from 0 to size.width (match character positioning at size.width/2)
            let brickX = offsetX + CGFloat(brickIndex) * (brickWidth + mortar)
            minX = min(minX, brickX)
            maxX = max(maxX, brickX + brickWidth)
            
            // Create brick rectangle - use precise size and position
            let brick = SKShapeNode(rectOf: CGSize(width: brickWidth, height: brickHeight))
            brick.position = CGPoint(x: brickX, y: rowY)
            brick.zPosition = 5  // Explicit z-position
            brick.lineJoin = .bevel
            brick.fillColor = brickColors.randomElement() ?? brickColors[0]  // Random color for each brick
            brick.strokeColor = SKColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)  // Dark outline
            brick.lineWidth = 1
            
            // Add slight 3D effect with darker bottom shading
            let shadowRect = SKShapeNode(rectOf: CGSize(width: brickWidth - 2, height: 3))
            shadowRect.position = CGPoint(x: 0, y: -brickHeight / 2 + 1.5)
            shadowRect.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.3)
            shadowRect.strokeColor = .clear
            brick.addChild(shadowRect)
            
            // Add mortar lines (lighter horizontal lines)
            let mortarLine = SKShapeNode(rectOf: CGSize(width: brickWidth + mortar, height: mortar))
            mortarLine.position = CGPoint(x: 0, y: -brickHeight / 2)
            mortarLine.fillColor = SKColor(red: 0.8, green: 0.75, blue: 0.7, alpha: 0.6)
            mortarLine.strokeColor = .clear
            brick.addChild(mortarLine)
            
            groundNode.addChild(brick)
        }
        
    }
    
    addChild(groundNode)
}

private func setupControlZones() {
    // ...existing code...
    let zoneHeight: CGFloat = 120
    let leftZoneWidth = size.width * 0.4
    let centerZoneWidth = size.width * 0.2
    let rightZoneWidth = size.width * 0.4
    
    // Left zone (move left) - BOTTOM LEFT (40%)
    let leftZone = SKShapeNode(rectOf: CGSize(width: leftZoneWidth, height: zoneHeight))
    leftZone.position = CGPoint(x: leftZoneWidth / 2, y: zoneHeight / 2)
    leftZone.fillColor = SKColor.yellow.withAlphaComponent(0.4)
    leftZone.strokeColor = .black
    leftZone.lineWidth = 2
    leftZone.name = "leftZone"
    leftZone.zPosition = 5
    addChild(leftZone)
    
    let leftLabel = SKLabelNode(fontNamed: "Arial")
    leftLabel.text = "◀︎"  // Left arrow icon
    leftLabel.fontSize = 24  // Larger for visibility
    leftLabel.fontColor = .black
    leftLabel.position = CGPoint(x: leftZoneWidth / 2, y: zoneHeight / 2)
    leftLabel.zPosition = 6
    addChild(leftLabel)
    
    // Center zone (action) - BOTTOM CENTER (20%)
    let centerZone = SKShapeNode(rectOf: CGSize(width: centerZoneWidth, height: zoneHeight))
    centerZone.position = CGPoint(x: leftZoneWidth + centerZoneWidth / 2, y: zoneHeight / 2)
    // Enhanced appearance: gradient-like effect with bright red
    centerZone.fillColor = SKColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 0.6)  // Brighter red
    centerZone.strokeColor = SKColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)  // Bright red border
    centerZone.lineWidth = 3  // Thicker border for prominence
    centerZone.name = "centerZone"
    centerZone.zPosition = 5
    addChild(centerZone)
    self.actionZoneNode = centerZone  // Store reference
    
    let centerLabel = SKLabelNode(fontNamed: "Arial-BoldMT")  // Use bold font
    centerLabel.text = "ACTION"
    centerLabel.fontSize = 12
    centerLabel.fontColor = .white  // White text for contrast
    centerLabel.position = CGPoint(x: leftZoneWidth + centerZoneWidth / 2, y: zoneHeight / 2 + 15)
    centerLabel.zPosition = 6
    addChild(centerLabel)
    
    // Label to display selected action name
    selectedActionLabel = SKLabelNode(fontNamed: "Arial")
    selectedActionLabel?.text = "-"
    selectedActionLabel?.fontSize = 10
    selectedActionLabel?.fontColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    selectedActionLabel?.position = CGPoint(x: leftZoneWidth + centerZoneWidth / 2, y: zoneHeight / 2 - 10)
    selectedActionLabel?.zPosition = 6
    addChild(selectedActionLabel!)
    
    // Right zone (move right) - BOTTOM RIGHT (40%)
    let rightZone = SKShapeNode(rectOf: CGSize(width: rightZoneWidth, height: zoneHeight))
    rightZone.position = CGPoint(x: leftZoneWidth + centerZoneWidth + rightZoneWidth / 2, y: zoneHeight / 2)
    rightZone.fillColor = SKColor.purple.withAlphaComponent(0.4)
    rightZone.strokeColor = .black
    rightZone.lineWidth = 2
    rightZone.name = "rightZone"
    rightZone.zPosition = 5
    addChild(rightZone)
    
    let rightLabel = SKLabelNode(fontNamed: "Arial")
    rightLabel.text = "▶︎"  // Right arrow icon
    rightLabel.fontSize = 24  // Larger for visibility
    rightLabel.fontColor = .black
    rightLabel.position = CGPoint(x: leftZoneWidth + centerZoneWidth + rightZoneWidth / 2, y: zoneHeight / 2)
    rightLabel.zPosition = 6
    addChild(rightLabel)
}

    override func handleTouchBegan(at point: CGPoint) {
        // Reset interaction timer for eye blinking
        lastInteractionTime = CACurrentMediaTime()
        
        handleTouchAtLocation(point, isPress: true)
    }
    
    override func handleTouchMoved(to point: CGPoint) {
        // Reset interaction timer for eye blinking
        lastInteractionTime = CACurrentMediaTime()
        
        // Continuously update movement direction as finger moves
        // This allows the character to follow the finger across the screen
        handleTouchAtLocation(point, isPress: true)
    }
    
    override func handleTouchEnded(at point: CGPoint) {
        // Check for Action button in bottom center zone FIRST
        let zoneHeight: CGFloat = 120
        let leftZoneWidth = size.width * 0.4
        let centerZoneWidth = size.width * 0.2
        
        // Check if touch is in ACTION zone (center zone at bottom)
        let centerZoneX = leftZoneWidth + centerZoneWidth / 2
        if point.y < zoneHeight && abs(point.x - centerZoneX) < centerZoneWidth / 2 {
            showActionSelection()
            return
        }
        
        // First, check for button taps at the top
        let topBarY = size.height - 100
        let tapDistance = abs(point.y - topBarY)
        
        if tapDistance < 35 { // Within the top button area
            // Exit button - go back to map
            if point.x < 70 {
                gameViewController?.showMapScene()
                return
            }
            // Appearance button (left of Stats)
            if point.x > size.width - 135 && point.x < size.width - 65 {
                gameViewController?.showAppearance()
                return
            }
            // Stats button
            if point.x > size.width - 70 {
                gameViewController?.showStats()
                return
            }
        }
        
        // If no button was tapped, handle movement release
        handleTouchAtLocation(point, isPress: false)
    }

override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
}

private func handleTouchAtLocation(_ point: CGPoint, isPress: Bool) {
    guard let gameState = gameState else {
        print("🎮 ERROR: gameState is nil")
        return
    }
    
    let topButtonY = size.height - 120  // Top button area (safe zone)
    let zoneHeight: CGFloat = 120
    
    // Only ignore PRESS events in top button area
    // Always allow RELEASE events to stop movement
    if isPress && point.y > topButtonY {
        print("🎮 Touch in top button area, ignoring press")
        return
    }
    
    // Ignore ACTION zone presses - they should not trigger movement
    let leftZoneWidth = size.width * 0.4
    let centerZoneWidth = size.width * 0.2
    let centerZoneX = leftZoneWidth + centerZoneWidth / 2
    if isPress && point.y < zoneHeight && abs(point.x - centerZoneX) < centerZoneWidth / 2 {
        print("🎮 Touch in ACTION zone press, ignoring movement")
        return
    }
    
    //print("🎮 Checking zones - point: \(point), topButtonY: \(topButtonY), isPress: \(isPress)")
    
    // Get character position
    guard let character = characterNode else {
        print("🎮 ERROR: characterNode is nil")
        return
    }
    
    let characterX = character.position.x
    let characterY = character.position.y
    //print("🎮 Character position: \(characterX), Tap position: \(point.x)")
    
    // Check if tapping directly on the character (within visible bounds)
    let characterTapThreshold: CGFloat = 60  // Horizontal threshold (half of 150px width)
    let characterHeight: CGFloat = 225  // Character height
    let characterHalfHeight = characterHeight / 2
    
    // Check both horizontal AND vertical bounds
    let isCharacterTap = abs(point.x - characterX) <= characterTapThreshold &&
                         point.y > zoneHeight &&
                         abs(point.y - characterY) <= characterHalfHeight
    
    if isCharacterTap && isPress {
        // Character was tapped - trigger the selected action
        //print("🎮 ✓ CHARACTER TAPPED - Attempting to trigger action")
        
        if let selectedAction = selectedAction {
            //print("🎮 ✓ Selected action is set: \(selectedAction.displayName)")
            // Only start action if not already performing one and not moving
            if gameState.currentPerformingAction == nil && !gameState.isMovingLeft && !gameState.isMovingRight {
                //print("🎮 ✓ Starting action animation: \(selectedAction.id)")
                gameState.startAction(selectedAction, gameState: gameState)
            } else {
                print("🎮 ⚠️ Cannot start action - currently performing: \(gameState.currentPerformingAction ?? "none"), moving: L=\(gameState.isMovingLeft) R=\(gameState.isMovingRight)")
            }
        } else {
            print("🎮 ⚠️ No action selected yet - tap ACTION button to select one")
        }
        return  // Exit early, don't process movement
    }
    
    // Check if movement is allowed by the current action
    if let currentAction = gameState.currentPerformingAction,
       let config = ACTION_CONFIGS.first(where: { $0.id == currentAction }),
       !config.allowMovement {
        // Movement is disabled by the current action
        print("🎮 ⚠️ Movement disabled for action: \(currentAction)")
        return
    }
    
    // Define movement zones (using already declared leftZoneWidth and centerZoneWidth)
    let rightZoneX = leftZoneWidth + centerZoneWidth
    
    // Determine which zone the touch is in
    if point.x < leftZoneWidth {
        // LEFT ZONE - always move left
        if isPress {
            print("🎮 ✓ LEFT ZONE TAP - MOVE LEFT")
            gameState.isMovingLeft = true
            gameState.isMovingRight = false
            gameState.facingRight = false
        } else {
            // Release - stop moving
            gameState.isMovingLeft = false
            gameState.isMovingRight = false
        }
    } else if point.x > rightZoneX {
        // RIGHT ZONE - always move right
        if isPress {
            print("🎮 ✓ RIGHT ZONE TAP - MOVE RIGHT")
            gameState.isMovingRight = true
            gameState.isMovingLeft = false
            gameState.facingRight = true
        } else {
            // Release - stop moving
            gameState.isMovingRight = false
            gameState.isMovingLeft = false
        }
    } else {
        // CENTER ZONE - stop movement
        if isPress {
            //print("🎮 Touch in center zone - no movement")
        } else {
            //print("🎮 ✓ RELEASE - STOP MOVING")
            gameState.isMovingLeft = false
            gameState.isMovingRight = false
        }
    }
    
    //print("🎮 After handling: isMovingLeft=\(gameState.isMovingLeft), isMovingRight=\(gameState.isMovingRight)")
}

private func startGameLoop() {
    // Update game state every frame
    let updateAction = SKAction.sequence([
        SKAction.run { [weak self] in
            self?.updateGameLogic()
        },
        SKAction.wait(forDuration: 0.016) // ~60 FPS
    ])
    
    run(SKAction.repeatForever(updateAction), withKey: "gameLoop")
}

private func updateGameLogic() {
    guard let gameState = gameState, let character = characterNode else { return }
    
    // Update eye blinking
    updateEyeBlinking()
    
    // Check if an action animation is currently playing
    if let currentStickFigure = gameState.currentStickFigure {
        //print("🎮 [UPDATE] Rendering action frame for: \(currentAction)")
        
        // Apply muscle scaling and appearance to the action frame
        let scaledFrame = applyMuscleScaling(to: currentStickFigure)
        var frameWithAppearance = scaledFrame
        StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
        
        // Clear character node and render the new frame with offsets
        character.removeAllChildren()
        let shouldFlip = gameState.actionFlip
        var offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, y: frameWithAppearance.figureOffsetY)
        
        // Mirror the X offset when flipping
        if shouldFlip {
            offsetPosition.x = -offsetPosition.x
        }
        
        let stickFigureNode = renderStickFigure(frameWithAppearance, at: offsetPosition, scale: 1.2, flipped: shouldFlip, jointShapeSize: frameWithAppearance.jointShapeSize)
        character.addChild(stickFigureNode)
        
        // Render action frame objects with flip applied
        if gameState.currentFrameIndex < gameState.actionStickFigureObjects.count {
            renderFrameObjects(gameState.actionStickFigureObjects[gameState.currentFrameIndex], on: character, scale: 1.2, figureOffsetX: offsetPosition.x, figureOffsetY: offsetPosition.y, shouldFlip: shouldFlip)
        }
        
    } else if gameState.isMovingLeft || gameState.isMovingRight {
        // Check if character is moving - update animation
        // Start animation if not already running
        if character.action(forKey: "moveAnimation") == nil {
            startMovementAnimation()
        }
    } else {
        // Stop animation if running
        if character.action(forKey: "moveAnimation") != nil {
            stopMovementAnimation()
        }
        
        // If not moving and not performing action, make sure we show stand frame
        // This handles the case where action just finished
        if let standFrame = gameState.standFrame {
            let scaledFrame = applyMuscleScaling(to: standFrame)
            var frameWithAppearance = scaledFrame
            StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
            
            character.removeAllChildren()
            let shouldFlip = !gameState.facingRight
            let offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, y: frameWithAppearance.figureOffsetY)
            let stickFigureNode = renderStickFigure(frameWithAppearance, at: offsetPosition, scale: 1.2, flipped: shouldFlip, jointShapeSize: frameWithAppearance.jointShapeSize)
            character.addChild(stickFigureNode)
            
            // Render stand frame objects
            renderFrameObjects(gameState.standFrameObjects, on: character, scale: 1.2, figureOffsetX: frameWithAppearance.figureOffsetX, figureOffsetY: frameWithAppearance.figureOffsetY, shouldFlip: shouldFlip)
        }
    }
    
    // Update character position based on movement
    let baseSpeed: CGFloat = 5.0
    let speedMultiplier = isBoostActive() ? 1.5 : 1.0  // 50% faster when boosted
    let speed = baseSpeed * speedMultiplier
    
    if gameState.isMovingLeft {
        character.position.x -= speed
    } else if gameState.isMovingRight {
        character.position.x += speed
    }
    
    // Wrap character around screen edges instead of clamping
    // When character moves off right side, appear on left
    // When character moves off left side, appear on right
    if character.position.x > size.width + 50 {
        character.position.x = -50
    } else if character.position.x < -50 {
        character.position.x = size.width + 50
    }
    
    // Update level label (level ONLY, no points)
    levelLabel?.text = "Level: \(gameState.currentLevel)"
    
    // NOTE: pointsValueLabel is updated only by animateHeaderPointsCounter during animation
    // Do NOT update it here - let the animation handle all points label updates
    
    // Update floating text
    updateFloatingText()
    
    // Update boost timer
    updateBoostTimer()
    
    // Update countdown timer
    updateCountdownTimer()
    
    // Handle catchables
    spawnFallingCatchables(gameState: gameState)
    checkCatchableCollisions(gameState: gameState, characterPosition: character.position, screenSize: size)
    renderFallingCatchables()
}

private func startMovementAnimation() {
    print("🎮 Starting movement animation")
    
    // Stop any existing animation first
    characterNode?.removeAction(forKey: "moveAnimation")
    animationFrameIndex = 0
    
    guard let gameState = gameState else {
        print("🎮 ERROR: gameState is nil in startMovementAnimation")
        return
    }
    
    print("🎮 Available moveFrames count in gameState: \(gameState.moveFrames.count)")
    
    // Get frame interval and frame numbers from config
    var frameInterval: TimeInterval = 0.15
    var frameNumbers: [Int] = [0, 1, 2, 3] // Default fallback
    
    //print("🎮 DEBUG ACTION_CONFIGS.count=\(ACTION_CONFIGS.count), IDs: \(ACTION_CONFIGS.map { $0.id })")
    
    if let config = ACTION_CONFIGS.first(where: { $0.id == "run" }),
       let animation = config.stickFigureAnimation {
        frameInterval = animation.baseFrameInterval
        frameNumbers = animation.frameNumbers.map { $0 - 1 }
        //print("🎮 ✓ Got config from ACTION_CONFIGS: \(animation.frameNumbers.count) frames")
        //print("🎮   Frame numbers from config (1-indexed): \(animation.frameNumbers)")
        //print("🎮   Frame indices for array (0-indexed): \(frameNumbers)")
    } else {
        print("🎮 ⚠️  ACTION_CONFIGS not available or missing 'run' config")
        // FALLBACK: Use all available frames from gameState instead of hardcoded [0,1,2,3]
        if gameState.moveFrames.count > 0 {
            frameNumbers = Array(0..<gameState.moveFrames.count)
            //print("🎮 ✓ Using all \(frameNumbers.count) available frames from gameState: \(frameNumbers)")
        } else {
            print("🎮 ✗ No frames available in gameState either, will use default [0,1,2,3]")
        }
    }
    
    if gameState.moveFrames.count > 0 {
        //print("🎮 ✓ moveFrames is populated with \(gameState.moveFrames.count) frames")
    } else {
        print("🎮 ✗ WARNING: moveFrames is EMPTY!")
    }
    
    // Use SKAction sequence instead of Timer for better performance
    var actions: [SKAction] = []
    
    //print("🎮 ANIMATION SEQUENCE - Creating \(frameNumbers.count) frame actions:")
    
    // Create actions for each frame in the animation
    for (_, frameNum) in frameNumbers.enumerated() {
        let moveFrameIndex = frameNum
        
        //print("🎮   [\(index)] Frame index: \(moveFrameIndex)")
        
        actions.append(SKAction.run { [weak self] in
            guard let self = self, let gameState = self.gameState else { return }
            guard moveFrameIndex < gameState.moveFrames.count else {
                //print("🎮 ❌ moveFrameIndex \(moveFrameIndex) >= moveFrames.count \(gameState.moveFrames.count), skipping")
                return
            }
            
            let moveFrame = gameState.moveFrames[moveFrameIndex]
            //print("🎮 🎬 Rendering move frame \(moveFrameIndex + 1)/\(gameState.moveFrames.count)")
            
            // Remove old stick figure and add new one
            if let characterContainer = self.characterNode {
                characterContainer.removeAllChildren()
                let shouldFlip = !gameState.facingRight
                let scaledFrame = self.applyMuscleScaling(to: moveFrame)
                // Apply appearance colors to the frame
                var frameWithAppearance = scaledFrame
                StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
                let offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, y: frameWithAppearance.figureOffsetY)
                let stickFigureNode = self.renderStickFigure(frameWithAppearance, at: offsetPosition, scale: 1.2, flipped: shouldFlip, jointShapeSize: frameWithAppearance.jointShapeSize)
                characterContainer.addChild(stickFigureNode)
                
                // Render move frame objects
                if moveFrameIndex < gameState.moveFrameObjects.count {
                    self.renderFrameObjects(gameState.moveFrameObjects[moveFrameIndex], on: characterContainer, scale: 1.2, figureOffsetX: frameWithAppearance.figureOffsetX, figureOffsetY: frameWithAppearance.figureOffsetY, shouldFlip: shouldFlip)
                }
            }
        })
        
        // Wait before next frame using configured interval
        actions.append(SKAction.wait(forDuration: frameInterval))
    }
    
    //print("🎮 TOTAL ACTIONS CREATED: \(actions.count) (frames + delays)")
    
    // Run the sequence on the character node
    if !actions.isEmpty {
        let sequence = SKAction.sequence(actions)
        let repeatAction = SKAction.repeatForever(sequence)
        characterNode?.run(repeatAction, withKey: "moveAnimation")
        //print("🎮 ✅ Animation loop started with \(frameNumbers.count) frames repeating forever")
    } else {
        print("🎮 ❌ No actions to run!")
    }
}

private func stopMovementAnimation() {
    //print("🎮 Stopping movement animation")
    
    // Stop the animation action
    characterNode?.removeAction(forKey: "moveAnimation")
    
    // Show stand frame with muscle scaling applied
    if let gameState = gameState, let standFrame = gameState.standFrame {
        if let characterContainer = characterNode {
            characterContainer.removeAllChildren()
            let shouldFlip = !gameState.facingRight
            let scaledFrame = applyMuscleScaling(to: standFrame)
            // Apply appearance colors to the frame
            var frameWithAppearance = scaledFrame
            StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
            let offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, y: frameWithAppearance.figureOffsetY)
            let stickFigureNode = renderStickFigure(frameWithAppearance, at: offsetPosition, scale: 1.2, flipped: shouldFlip, jointShapeSize: frameWithAppearance.jointShapeSize)
            characterContainer.addChild(stickFigureNode)
            
            // Render stand frame objects
            renderFrameObjects(gameState.standFrameObjects, on: characterContainer, scale: 1.2, figureOffsetX: frameWithAppearance.figureOffsetX, figureOffsetY: frameWithAppearance.figureOffsetY, shouldFlip: shouldFlip)
        }
    }
}

private func updateEyeBlinking() {
    guard gameState != nil else { return }
    guard StickFigureAppearance.shared.eyesEnabled else { return }
    
    let currentTime = CACurrentMediaTime()
    let timeSinceLastInteraction = currentTime - lastInteractionTime
    
    // Check if we should trigger a blink
    if timeSinceLastInteraction >= inactivityThreshold && !isEyesBlinking {
        //print("👁️ BLINK: Triggering blink after \(timeSinceLastInteraction) seconds of inactivity")
        triggerEyeBlink()
    }
    
    // Check if blink should end
    if isEyesBlinking && currentTime >= eyesBlinkEndTime {
        //print("👁️ BLINK: Ending blink, restoring eyes")
        isEyesBlinking = false
        lastInteractionTime = CACurrentMediaTime()  // Reset timer after blink
        refreshCharacterAppearance()
    }
}

private func triggerEyeBlink() {
    isEyesBlinking = true
    eyesBlinkEndTime = CACurrentMediaTime() + blinkDuration
    refreshCharacterAppearance()
}

/// Refresh the character appearance when colors are changed in the customizer
func refreshCharacterAppearance() {
    //print("🎮 Refreshing character appearance after color change")
    
    guard let gameState = gameState, let characterContainer = characterNode else { return }
    
    // Clear existing character
    characterContainer.removeAllChildren()
    characterContainer.removeAction(forKey: "moveAnimation")
    
    // Store original eye state if we're blinking
    let originalEyesEnabled = StickFigureAppearance.shared.eyesEnabled
    if isEyesBlinking {
        StickFigureAppearance.shared.eyesEnabled = false
    }
    
    // Re-render with current frame
        if gameState.isMovingLeft || gameState.isMovingRight {
        // If moving, use current animation frame
        if animationFrameIndex < gameState.moveFrames.count {
            let moveFrame = gameState.moveFrames[animationFrameIndex]
            let shouldFlip = !gameState.facingRight
            let scaledFrame = applyMuscleScaling(to: moveFrame)
            // Apply appearance colors to the frame
            var frameWithAppearance = scaledFrame
            StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
            let offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, y: frameWithAppearance.figureOffsetY)
            let stickFigureNode = renderStickFigure(frameWithAppearance, at: offsetPosition, scale: 1.2, flipped: shouldFlip, jointShapeSize: frameWithAppearance.jointShapeSize)
            characterContainer.addChild(stickFigureNode)
            
            // Render move frame objects
            if animationFrameIndex < gameState.moveFrameObjects.count {
                renderFrameObjects(gameState.moveFrameObjects[animationFrameIndex], on: characterContainer, scale: 1.2, figureOffsetX: frameWithAppearance.figureOffsetX, figureOffsetY: frameWithAppearance.figureOffsetY, shouldFlip: shouldFlip)
            }
        }
    } else {
        // Otherwise show stand frame
        if let standFrame = gameState.standFrame {
            let shouldFlip = !gameState.facingRight
            let scaledFrame = applyMuscleScaling(to: standFrame)
            // Apply appearance colors to the frame
            var frameWithAppearance = scaledFrame
            StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
            let offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, y: frameWithAppearance.figureOffsetY)
            let stickFigureNode = renderStickFigure(frameWithAppearance, at: offsetPosition, scale: 1.2, flipped: shouldFlip, jointShapeSize: frameWithAppearance.jointShapeSize)
            characterContainer.addChild(stickFigureNode)
            
            // Render stand frame objects
            renderFrameObjects(gameState.standFrameObjects, on: characterContainer, scale: 1.2, figureOffsetX: frameWithAppearance.figureOffsetX, figureOffsetY: frameWithAppearance.figureOffsetY, shouldFlip: shouldFlip)
        }
    }
    
    // Restore original eye state
    StickFigureAppearance.shared.eyesEnabled = originalEyesEnabled
}

/// Render objects associated with a frame

/// Determine which base frame to use based on average muscle points
private func getBaseFrameForMusclePoints(_ avgPoints: Double) -> StickFigure2D? {
    guard gameState != nil else { return nil }
    
    // Map muscle points to frame progression
    if avgPoints < 12.5 {
        // 0-25: Use Extra Small Stand frame (0 points)
        return loadFrameNamed("Extra Small Stand")
    } else if avgPoints < 37.5 {
        // 25-50: Use Small Stand frame (25 points)
        return loadFrameNamed("Small Stand")
    } else if avgPoints < 62.5 {
        // 50-75: Use Stand frame (50 points)
        return loadFrameNamed("Stand")
    } else if avgPoints < 87.5 {
        // 75-100: Use Large Stand frame (75 points)
        return loadFrameNamed("Large Stand")
    } else {
        // 100: Use Extra Large Stand frame (100 points)
        return loadFrameNamed("Extra Large Stand")
    }
}

/// Load a frame by name from animations.json
private func loadFrameNamed(_ name: String) -> StickFigure2D? {
    let bundle = Bundle.main
    guard let url = bundle.url(forResource: "animations", withExtension: "json"),
          let data = try? Data(contentsOf: url) else {
        print("🎮 ERROR: Could not find animations.json")
        return nil
    }
    
    do {
        let frames = try JSONDecoder().decode([SavedEditFrame].self, from: data)
        
        for frame in frames {
            if frame.name == name {
                // Convert SavedEditFrame to StickFigure2D
                var figure = StickFigure2D()
                // Copy all relevant properties from SavedEditFrame
                figure.fusiformShoulders = frame.fusiformShoulders
                figure.fusiformUpperTorso = frame.fusiformUpperTorso
                figure.fusiformLowerTorso = frame.fusiformLowerTorso
                figure.fusiformBicep = frame.fusiformBicep
                figure.fusiformTricep = frame.fusiformTricep
                figure.fusiformLowerArms = frame.fusiformLowerArms
                figure.fusiformUpperLegs = frame.fusiformUpperLegs
                figure.fusiformLowerLegs = frame.fusiformLowerLegs
                figure.neckWidth = frame.neckWidth
                figure.neckLength = frame.neckLength
                figure.handSize = frame.handSize
                figure.footSize = frame.footSize
                // Copy all stroke thickness values
                figure.strokeThicknessUpperTorso = frame.strokeThicknessUpperTorso
                figure.strokeThicknessLowerTorso = frame.strokeThicknessLowerTorso
                figure.strokeThicknessBicep = frame.strokeThicknessBicep
                figure.strokeThicknessTricep = frame.strokeThicknessTricep
                figure.strokeThicknessLowerArms = frame.strokeThicknessLowerArms
                figure.strokeThicknessUpperLegs = frame.strokeThicknessUpperLegs
                figure.strokeThicknessLowerLegs = frame.strokeThicknessLowerLegs
                figure.strokeThicknessJoints = frame.strokeThicknessJoints
                figure.skeletonSizeTorso = frame.skeletonSizeTorso
                figure.skeletonSizeArm = frame.skeletonSizeArm
                figure.skeletonSizeLeg = frame.skeletonSizeLeg
                figure.waistThicknessMultiplier = frame.waistThicknessMultiplier
                figure.waistWidthMultiplier = frame.waistWidthMultiplier
                //print("🎮 ✓ Loaded frame '\(name)' successfully")
                return figure
            }
        }
        
        print("🎮 WARNING: Frame '\(name)' not found in animations.json")
        return nil
    } catch {
        print("🎮 ERROR: Failed to decode animations.json: \(error)")
        return nil
    }
}

private func applyMuscleScaling(to figure: StickFigure2D) -> StickFigure2D {
    guard let gameState = gameState else { return figure }
    
    // Ensure frames are loaded before attempting interpolation
    MuscleSystem.shared.ensureStandFramesLoaded()
    
    // Store the frame's explicit shoulder and waist width multipliers
    // These should NOT be overridden by muscle scaling (they're frame-specific for front vs side views)
    let frameShoulderWidth = figure.shoulderWidthMultiplier
    let frameWaistWidth = figure.waistWidthMultiplier
    var scaledFigure = figure
    
    // Apply each property's interpolated values to the figure
    if let properties = MuscleSystem.shared.config?.properties {
        for property in properties {
            let propertyPoints = gameState.muscleState.getPoints(for: property.id)
            let interpolatedValue = MuscleSystem.shared.interpolateProperty(property.id, musclePoints: propertyPoints)
            
            // Apply the interpolated value to the appropriate figure property
            switch property.id {
            case "fusiformShoulders": scaledFigure.fusiformShoulders = interpolatedValue
            case "fusiformUpperTorso": scaledFigure.fusiformUpperTorso = interpolatedValue
            case "fusiformLowerTorso": scaledFigure.fusiformLowerTorso = interpolatedValue
            case "fusiformBicep": scaledFigure.fusiformBicep = interpolatedValue
            case "fusiformTricep": scaledFigure.fusiformTricep = interpolatedValue
            case "fusiformLowerArms": scaledFigure.fusiformLowerArms = interpolatedValue
            case "fusiformUpperLegs": scaledFigure.fusiformUpperLegs = interpolatedValue
            case "fusiformLowerLegs": scaledFigure.fusiformLowerLegs = interpolatedValue
            case "fusiformDeltoids": scaledFigure.fusiformDeltoids = interpolatedValue
            case "neckWidth": scaledFigure.neckWidth = interpolatedValue
            case "handSize": scaledFigure.handSize = interpolatedValue
            case "footSize": scaledFigure.footSize = interpolatedValue
            case "strokeThicknessUpperTorso": scaledFigure.strokeThicknessUpperTorso = interpolatedValue
            case "strokeThicknessLowerTorso": scaledFigure.strokeThicknessLowerTorso = interpolatedValue
            case "strokeThicknessBicep": scaledFigure.strokeThicknessBicep = interpolatedValue
            case "strokeThicknessTricep": scaledFigure.strokeThicknessTricep = interpolatedValue
            case "strokeThicknessLowerArms": scaledFigure.strokeThicknessLowerArms = interpolatedValue
            case "strokeThicknessUpperLegs": scaledFigure.strokeThicknessUpperLegs = interpolatedValue
            case "strokeThicknessLowerLegs": scaledFigure.strokeThicknessLowerLegs = interpolatedValue
            case "strokeThicknessDeltoids": scaledFigure.strokeThicknessDeltoids = interpolatedValue
            case "strokeThicknessTrapezius": scaledFigure.strokeThicknessTrapezius = interpolatedValue
            case "strokeThicknessJoints": scaledFigure.strokeThicknessJoints = interpolatedValue
            case "jointShapeSize": scaledFigure.jointShapeSize = interpolatedValue
            case "skeletonSizeTorso": scaledFigure.skeletonSizeTorso = interpolatedValue
            case "skeletonSizeArm": scaledFigure.skeletonSizeArm = interpolatedValue
            case "skeletonSizeLeg": scaledFigure.skeletonSizeLeg = interpolatedValue
            case "peakPositionBicep": scaledFigure.peakPositionBicep = interpolatedValue
            case "peakPositionTricep": scaledFigure.peakPositionTricep = interpolatedValue
            case "peakPositionLowerArms": scaledFigure.peakPositionLowerArms = interpolatedValue
            case "peakPositionUpperLegs": scaledFigure.peakPositionUpperLegs = interpolatedValue
            case "peakPositionLowerLegs": scaledFigure.peakPositionLowerLegs = interpolatedValue
            case "peakPositionUpperTorso": scaledFigure.peakPositionUpperTorso = interpolatedValue
            case "peakPositionLowerTorso": scaledFigure.peakPositionLowerTorso = interpolatedValue
            case "peakPositionDeltoids": scaledFigure.peakPositionDeltoids = interpolatedValue
            case "fusiformFullTorso": scaledFigure.fusiformFullTorso = interpolatedValue
            case "peakPositionFullTorsoTop": scaledFigure.peakPositionFullTorsoTop = interpolatedValue
            case "peakPositionFullTorsoMiddle": scaledFigure.peakPositionFullTorsoMiddle = interpolatedValue
            case "peakPositionFullTorsoBottom": scaledFigure.peakPositionFullTorsoBottom = interpolatedValue
            case "waistThicknessMultiplier": scaledFigure.waistThicknessMultiplier = interpolatedValue
            default: break
            }
        }
    } else {
        print("🎮 ERROR applyMuscleScaling: No properties configured!")
    }
    
    scaledFigure.shoulderWidthMultiplier = frameShoulderWidth
    scaledFigure.waistWidthMultiplier = frameWaistWidth
    
    // Apply properties from the muscle system (both regular and derived)
    let handSize = MuscleSystem.shared.getDerivedPropertyValue(for: "handSize", state: gameState.muscleState)
    let footSize = MuscleSystem.shared.getDerivedPropertyValue(for: "footSize", state: gameState.muscleState)
    let skeletonSizeTorso = MuscleSystem.shared.getDerivedPropertyValue(for: "skeletonSizeTorso", state: gameState.muscleState)
    let skeletonSizeArm = MuscleSystem.shared.getDerivedPropertyValue(for: "skeletonSizeArm", state: gameState.muscleState)
    let skeletonSizeLeg = MuscleSystem.shared.getDerivedPropertyValue(for: "skeletonSizeLeg", state: gameState.muscleState)
    let waistThicknessMultiplier = MuscleSystem.shared.getDerivedPropertyValue(for: "waistThicknessMultiplier", state: gameState.muscleState)
    let strokeThicknessFullTorso = MuscleSystem.shared.getDerivedPropertyValue(for: "strokeThicknessFullTorso", state: gameState.muscleState)
    
    // neckWidth is now a regular property (belongs to Shoulders), not derived
    let neckWidthPoints = gameState.muscleState.getPoints(for: "neckWidth")
    let neckWidth = MuscleSystem.shared.interpolateProperty("neckWidth", musclePoints: neckWidthPoints)
    
    scaledFigure.neckWidth = neckWidth
    scaledFigure.handSize = handSize
    scaledFigure.footSize = footSize
    scaledFigure.skeletonSizeTorso = skeletonSizeTorso
    scaledFigure.skeletonSizeArm = skeletonSizeArm
    scaledFigure.skeletonSizeLeg = skeletonSizeLeg
    scaledFigure.waistThicknessMultiplier = waistThicknessMultiplier
    scaledFigure.strokeThicknessFullTorso = strokeThicknessFullTorso
    
    // Determine if this is a side view based on whether character is currently moving
    //let isSideView = gameState.isMovingLeft || gameState.isMovingRight
    let isSideView = scaledFigure.shoulderWidthMultiplier < 0.1 && scaledFigure.waistWidthMultiplier < 0.1
    
    if isSideView {
        scaledFigure.strokeThicknessUpperTorso = min(scaledFigure.strokeThicknessUpperTorso, 5.0)
        scaledFigure.fusiformShoulders = min(scaledFigure.fusiformShoulders, 3.0)
        //scaledFigure.strokeThicknessFullTorso = min(scaledFigure.strokeThicknessFullTorso, 5.0)
        scaledFigure.strokeThicknessDeltoids = min(scaledFigure.strokeThicknessDeltoids, 3.0)
        //scaledFigure.skeletonSizeTorso = min(scaledFigure.skeletonSizeTorso, 3.0)
        
    }
    
    // Debug deltoid interpolation
    //let deltoidPoints = gameState.muscleState.getPoints(for: "fusiformDeltoids")
    //let deltoidStroke = MuscleSystem.shared.interpolateProperty("strokeThicknessDeltoids", musclePoints: gameState.muscleState.getPoints(for: "strokeThicknessDeltoids"))
    //let deltoidFusiform = MuscleSystem.shared.interpolateProperty("fusiformDeltoids", musclePoints: deltoidPoints)
    //print("🔍 DELTOID SCALING: points=\(deltoidPoints), fusiform=\(deltoidFusiform), stroke=\(deltoidStroke)")
    
    return scaledFigure
}

private func renderFrameObjects(_ objects: [AnimationObject], on container: SKNode, scale: CGFloat, figureOffsetX: CGFloat = 0, figureOffsetY: CGFloat = 0, shouldFlip: Bool = false) {
    for object in objects {
        let node: SKNode
        
        if object.type == .box {
            // Render box with exact size from editor - no scaling
            let boxNode = SKShapeNode(rectOf: CGSize(width: object.width, height: object.height))
            let boxColor = UIColor(hex: object.color) ?? UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            boxNode.fillColor = boxColor
            boxNode.strokeColor = .black
            boxNode.lineWidth = 2
            boxNode.zPosition = 5
            boxNode.name = "object_box_\(object.id)"
            node = boxNode
        } else {
            // Render image with exact size from editor
            let sprite = SKSpriteNode(imageNamed: object.imageName)
            // Set to the exact size saved in the editor (width/height are in pixels)
            sprite.size = CGSize(width: object.width, height: object.height)
            sprite.zPosition = 5
            sprite.name = "object_image_\(object.imageName)"
            node = sprite
        }
        
        // Objects positioned exactly as they appear in the editor
        // Convert from editor coordinates to gameplay coordinates
        
        let estimatedEditorSize: CGFloat = 402
        let editorCenter = estimatedEditorSize / 2
        
        // Editor: origin at top-left, Y increases downward
        // Gameplay: origin at scene center, Y increases upward
        var relativePos = CGPoint(
            x: object.position.x - editorCenter,
            y: -(editorCenter - object.position.y)
        )
        
        // Apply horizontal flip to object position and rotation if needed
        var objectRotation = CGFloat(object.rotation)
        if shouldFlip {
            relativePos.x = -relativePos.x
            node.xScale = -1.0
            // Mirror the rotation angle when flipping
            objectRotation = -objectRotation
        }
        
        // Position object exactly as it appears in the editor
        node.position = relativePos
        node.zRotation = objectRotation
        container.addChild(node)
        
        print("🎮 renderFrameObjects: object=\(object.imageName), editorPos=\(object.position), relativePos=\(relativePos)")
    }
}

/// Show action selection window
private func showActionSelection() {
    guard let gameState = gameState, let gameViewController = gameViewController else {
        print("🎮 ❌ showActionSelection FAILED: gameState=\(gameState != nil), gameViewController=\(gameViewController != nil)")
        return
    }
    
    print("🎮 showActionSelection called for level \(gameState.currentLevel)")
    print("🎮 gameViewController class: \(type(of: gameViewController))")
    print("🎮 LEVEL_CONFIGS.count=\(LEVEL_CONFIGS.count), ACTION_CONFIGS.count=\(ACTION_CONFIGS.count)")
    
    // Get the level config
    guard let levelConfig = LEVEL_CONFIGS.first(where: { $0.id == gameState.currentLevel }) else {
        print("🎮 ❌ Level config not found for level \(gameState.currentLevel)")
        print("🎮 Available level IDs: \(LEVEL_CONFIGS.map { $0.id })")
        return
    }
    
    print("🎮 Level config found: \(levelConfig.name)")
    print("🎮 Available action IDs in level config: \(levelConfig.availableActions)")
    
    // Get actions that match the available action IDs for this level
    let availableActions = ACTION_CONFIGS.filter { config in
        levelConfig.availableActions.contains(config.id)
    }
    
    print("🎮 Filtered available actions: \(availableActions.map { $0.id })")
    
    if availableActions.isEmpty {
        print("🎮 ⚠️ No actions available for level \(gameState.currentLevel)")
        return
    }
    
    print("🎮 ✓ Found \(availableActions.count) available actions for level \(gameState.currentLevel)")
    
    // Create action selection controller
    let actionSelectionVC = ActionSelectionViewController()
    actionSelectionVC.actions = availableActions
    
    print("🎮 Created ActionSelectionViewController")
    print("🎮 About to present ActionSelectionViewController")
    print("🎮 gameViewController: \(gameViewController)")
    print("🎮 gameViewController.view: \(String(describing: gameViewController.view))")
    
    // Handle action selection
    actionSelectionVC.onActionSelected = { [weak self] selectedAction in
        print("🎮 Action selected: \(selectedAction.id)")
        self?.selectedAction = selectedAction
        // Update the label on the action zone
        self?.selectedActionLabel?.text = selectedAction.displayName
        print("🎮 ✓ Updated action label to: \(selectedAction.displayName)")
    }
    
    // Handle dismissal
    actionSelectionVC.onDismiss = { [weak self] in
        print("🎮 Action selection dismissed")
        _ = self  // Use self to avoid warning
    }
    
    // Present the view controller on main thread
    DispatchQueue.main.async {
        print("🎮 Presenting ActionSelectionViewController with modal style: \(actionSelectionVC.modalPresentationStyle)")
        gameViewController.present(actionSelectionVC, animated: true)
        print("🎮 ✓ ActionSelectionViewController presented")
    }
}

// MARK: - Catchables Implementation

private func spawnFallingCatchables(gameState: StickFigureGameState) {
    // Filter catchables by unlock level
    let unlockedItems = CATCHABLE_CONFIGS.filter { $0.unlockLevel <= gameState.currentLevel }
    guard !unlockedItems.isEmpty else { return }
    
    let currentTime = Date().timeIntervalSince1970
    
    // Global spawn pool system: try to spawn ONE random item every few seconds
    // Initialize lastGlobalSpawnTime if needed
    if lastGlobalSpawnTime == 0 {
        lastGlobalSpawnTime = currentTime
    }
    
    // Spawn interval: 5-20 seconds (choose randomly each spawn)
    let spawnInterval = Double.random(in: 5.0...20.0)
    let timeSinceLastSpawn = currentTime - lastGlobalSpawnTime
    
    guard timeSinceLastSpawn >= spawnInterval else { return }
    
    // Time to spawn! Pick ONE random item based on spawn weights
    // Calculate total weight
    let totalWeight = unlockedItems.reduce(0) { $0 + $1.spawnWeight }
    guard totalWeight > 0 else { return }
    
    // Pick a random weight and find which item it corresponds to
    var randomWeight = Double.random(in: 0..<totalWeight)
    var selectedItem: CatchableConfig? = nil
    
    for itemConfig in unlockedItems {
        randomWeight -= itemConfig.spawnWeight
        if randomWeight <= 0 {
            selectedItem = itemConfig
            break
        }
    }
    
    guard let itemConfig = selectedItem else { return }
    
    // Check if we've hit the max for this item
    let maxOnScreen = itemConfig.maxOnScreen ?? 1
    let countOfThisType = fallingItems.filter { $0.itemType == itemConfig.id }.count
    guard countOfThisType < maxOnScreen else {
        // Max reached, try again next cycle
        lastGlobalSpawnTime = currentTime
        return
    }
    
    // Spawn this item
    let horizontalVel: CGFloat
    if itemConfig.direction == "falls" {
        // Falls: moves sideways while falling
        horizontalVel = CGFloat.random(in: -0.002...0.002)
    } else {
        // Vertical: straight down, no horizontal movement
        horizontalVel = 0.0
    }
    
    let item = FallingItem(
        itemType: itemConfig.id,
        x: CGFloat.random(in: 0.1...0.9),
        y: -0.1,  // Spawn above screen
        rotation: Double.random(in: 0...360),
        horizontalVelocity: horizontalVel,
        verticalSpeed: CGFloat.random(in: itemConfig.baseVerticalSpeed...itemConfig.baseVerticalSpeedMax)
    )
    fallingItems.append(item)
    
    // Update last global spawn time for next spawn
    lastGlobalSpawnTime = currentTime
}

private func renderFallingCatchables() {
    // Update positions and rotations of existing items
    for item in fallingItems {
        // Create node if it doesn't exist
        if catchableNodes[item.id] == nil {
            if let node = createCatchableNode(for: item) {
                catchableContainerNode.addChild(node)
                catchableNodes[item.id] = node
            }
        }
        
        if let node = catchableNodes[item.id] {
            // Update position (convert normalized coordinates to screen coordinates)
            let screenX = item.x * size.width
            let screenY = item.y * size.height
            node.position = CGPoint(x: screenX, y: size.height - screenY)  // Flip Y for SpriteKit coordinates
            
            // Update rotation if configured
            if let config = CATCHABLE_CONFIGS.first(where: { $0.id == item.itemType }), config.spins {
                node.zRotation = CGFloat(item.rotation * Double.pi / 180.0)  // Convert to radians
            }
        }
    }
}

private func checkCatchableCollisions(gameState: StickFigureGameState, characterPosition: CGPoint, screenSize: CGSize) {
    for i in fallingItems.indices.reversed() {
        let item = fallingItems[i]
        
        // Update item position
        fallingItems[i].y += fallingItems[i].verticalSpeed
        fallingItems[i].x += fallingItems[i].horizontalVelocity
        
        // Update rotation if needed
        if let config = CATCHABLE_CONFIGS.first(where: { $0.id == item.itemType }), config.spins {
            fallingItems[i].rotation += config.spinSpeed
        }
        
        // Check collision with character
        let itemScreenX = fallingItems[i].x * screenSize.width
        let itemScreenY = (1.0 - fallingItems[i].y) * screenSize.height  // Convert to SpriteKit coordinates
        let dx = itemScreenX - characterPosition.x
        let dy = itemScreenY - characterPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Collision radius
        let collisionRadius: CGFloat = 60
        
        if distance < collisionRadius {
            // Collision detected!
            if let config = CATCHABLE_CONFIGS.first(where: { $0.id == item.itemType }) {
                // Update stats
                gameState.catchablesCaught[config.id, default: 0] += 1
                
                // Award points
                gameState.addPoints(config.points, action: item.itemType)
                
                // IMMEDIATELY save points after catchable collected
                gameState.saveStats()
                
                // Display floating text with points
                let pointsText = "+\(config.points)"
                let textColor = UIColor(hex: config.color ?? "#808080") ?? .white
                addFloatingText(pointsText, x: fallingItems[i].x, y: fallingItems[i].y, color: textColor, points: config.points)
                
                // Haptic feedback for catchable collision
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                
                // Trigger collision animation if configured (e.g., Shaker)
                if let collisionAnimName = config.collisionAnimation {
                    print("🎮 COLLISION ANIM DETECTED: \(collisionAnimName)")
                    // Find the action config with matching id
                    let searchId = collisionAnimName.lowercased()
                    print("🎮 Searching for action with id: \(searchId)")
                    print("🎮 Available actions: \(ACTION_CONFIGS.map { $0.id })")
                    
                    if let actionConfig = ACTION_CONFIGS.first(where: { $0.id == searchId }) {
                        print("🎮 Found action config: \(actionConfig.displayName)")
                        // Check if we can start the action
                        let canStart = gameState.currentPerformingAction == nil && !gameState.isMovingLeft && !gameState.isMovingRight
                        print("🎮 Can start action: \(canStart) (performing: \(gameState.currentPerformingAction ?? "none"), movL: \(gameState.isMovingLeft), movR: \(gameState.isMovingRight))")
                        
                        if canStart {
                            print("🎮 ✅ STARTING ACTION: \(actionConfig.displayName)")
                            gameState.startAction(actionConfig, gameState: gameState)
                            // Also activate boost for Shaker if applicable
                            if collisionAnimName == "Shaker" {
                                print("🎮 Activating boost for Shaker")
                                activateBoost()
                            }
                        } else {
                            print("🎮 ⚠️ Cannot start action - character is busy. Force-starting anyway...")
                            // Stop current movement
                            gameState.isMovingLeft = false
                            gameState.isMovingRight = false
                            // Start the action
                            gameState.startAction(actionConfig, gameState: gameState)
                            if collisionAnimName == "Shaker" {
                                print("🎮 Activating boost for Shaker")
                                activateBoost()
                            }
                        }
                    } else {
                        print("🎮 ❌ Action config not found for: \(searchId)")
                    }
                }
            }
            
            // Remove rendered node
            if let node = catchableNodes[item.id] {
                node.removeFromParent()
                catchableNodes.removeValue(forKey: item.id)
            }
            
            // Remove from items array
            fallingItems.remove(at: i)
            continue
        }
        
        // Remove if off-screen (bottom only) - wrap around horizontally
        if fallingItems[i].y > 1.1 {
            // Catchable has fallen below the screen - remove it
            if let node = catchableNodes[item.id] {
                node.removeFromParent()
                catchableNodes.removeValue(forKey: item.id)
            }
            fallingItems.remove(at: i)
        } else if fallingItems[i].x < 0 || fallingItems[i].x > 1 {
            // Catchable has drifted off the side - wrap it around horizontally immediately
            if fallingItems[i].x < 0 {
                // Wrap from left to right - move just barely on-screen on the right
                fallingItems[i].x += 1.0
            } else if fallingItems[i].x > 1 {
                // Wrap from right to left - move just barely on-screen on the left
                fallingItems[i].x -= 1.0
            }
        }
    }
}

// Create or update rendered node for a catchable
private func createCatchableNode(for item: FallingItem) -> SKNode? {
    guard let config = CATCHABLE_CONFIGS.first(where: { $0.id == item.itemType }) else {
        return nil
    }
    
    let container = SKNode()
    container.zPosition = 3
    
    // Get size from config, or use defaults (36x36)
    let width = config.width ?? 36.0
    let height = config.height ?? 36.0
    let size = CGSize(width: width, height: height)
    
    // Try to render as SF Symbol first (if iconName is set and assetName is nil)
    if let iconName = config.iconName, config.assetName == nil {
        // Map SF Symbol names to emoji that support coloring
        let emojiMap: [String: String] = [
            "leaf.fill": "🍀",
            "heart.fill": "❤️",
            "brain.fill": "🧠",
            "sun.max.fill": "☀️",
            "apple": "🍎",
            "orange": "🍊",
            "banana": "🍌",
            "strawberry": "🍓",
            "grapes": "🍇",
            "diamond.fill": "💎",
            "coin.fill": "🪙",
            "gift.fill": "🎁",
            "star.fill": "⭐️",
            "waterdrop.fill": "💧",
            "snowflake": "❄️",
            "moon.fill": "🌙",
            "seedling.fill": "🌱"
        ]
        
        let emoji = emojiMap[iconName] ?? "●"
        
        let label = SKLabelNode(fontNamed: "Arial")
        label.text = emoji
        label.fontSize = 24
        label.zPosition = 3
        
        // Apply color if configured
        if let hexColor = config.color, let color = UIColor(hex: hexColor) {
            label.fontColor = color
        }
        
        container.addChild(label)
    }
    // Try to render as asset image
    else if let assetName = config.assetName {
        let sprite = SKSpriteNode(imageNamed: assetName)
        sprite.size = size
        sprite.zPosition = 3
        container.addChild(sprite)
    }
    
    return container
}

// MARK: - Floating Text Management

private func addFloatingText(_ text: String, x: CGFloat, y: CGFloat, color: UIColor, points: Int = 0) {
    let label = SKLabelNode(fontNamed: "Arial-BoldMT")
    label.text = text
    label.fontSize = 32  // Make it larger for point text
    label.fontColor = color
    
    // Convert normalized coordinates to screen coordinates
    let screenX = x * size.width
    let screenY = (1.0 - y) * size.height
    label.position = CGPoint(x: screenX, y: screenY)
    label.zPosition = 50
    
    floatingTextContainer.addChild(label)
    
    floatingTexts.append(FloatingText(
        node: label,
        x: screenX,
        y: screenY,
        color: color
    ))
    
    // If this is a points text, animate it to the HUD and trigger counter animation
    if points > 0 && text.starts(with: "+") {
        animatePointsToHUD(label: label, points: points, startX: screenX, startY: screenY)
    }
}

    private func animatePointsToHUD(label: SKLabelNode, points: Int, startX: CGFloat, startY: CGFloat) {
        guard let pointsValueLabel = pointsValueLabel else { return }
        
        // Target the points value label on the right side of the screen
        let targetX = pointsValueLabel.position.x
        let targetY = pointsValueLabel.position.y
        
        // Animate floating text to header points position over 0.8 seconds
        let moveAction = SKAction.move(to: CGPoint(x: targetX, y: targetY), duration: 0.8)
        let fadeAction = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveAction, fadeAction])
        let removeAction = SKAction.removeFromParent()
        let sequence = SKAction.sequence([group, removeAction])
        
        label.run(sequence)
        
        // Trigger the points counter animation immediately
        guard let gameState = gameState else { return }
        let newTotal = gameState.currentPoints
        let previousTotal = newTotal - points
        // Clamp previousTotal to 0 to prevent negative points display on level up
        // (When level up happens, currentPoints is reset to 0 before points animation is triggered)
        let clampedPreviousTotal = max(0, previousTotal)
        animateHeaderPointsCounter(from: clampedPreviousTotal, to: newTotal)
    }
    
    private func animateHeaderPointsCounter(from startPoints: Int, to endPoints: Int) {
        guard let pointsValueLabel = pointsValueLabel else { return }
        
        let pointsToAdd = endPoints - startPoints
        let duration: TimeInterval = 0.8
        
        // Initialize the label with the starting value immediately and make it bold
        pointsValueLabel.text = "\(startPoints)"
        pointsValueLabel.fontSize = 14
        pointsValueLabel.fontName = "Arial-BoldMT"
        
        // Ensure minimum 10 updates for smooth animation, even for 1 point
        let minUpdates = 10
        let updates = max(minUpdates, pointsToAdd)
        let updateInterval: TimeInterval = duration / Double(updates)
        var currentIncrement = 0
        
        var timer: Timer?
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            currentIncrement += 1
            
            // Calculate which point value to show based on progress through the animation
            let pointsToShowThisFrame = Int(Double(pointsToAdd) * Double(currentIncrement) / Double(updates))
            let newValue = startPoints + pointsToShowThisFrame
            
            if currentIncrement >= updates {
                timer?.invalidate()
                // Set final value - return to normal formatting
                pointsValueLabel.text = "\(endPoints)"
                pointsValueLabel.fontSize = 12  // Return to normal size
                pointsValueLabel.fontName = "Arial"  // Return to normal (not bold)
                
                // Trigger fireworks effect at the score location
                self?.createFireworksAtScore()
            } else {
                // Update to the new value
                pointsValueLabel.text = "\(newValue)"
                // Keep it larger and bold while incrementing
                pointsValueLabel.fontSize = 14
                pointsValueLabel.fontName = "Arial-BoldMT"
            }
        }
    }
    
    private func createFireworksAtScore() {
        guard let pointsValueLabel = pointsValueLabel else { return }
        
        let fireworkCount = 20  // Even more particles for denser effect
        let colors: [SKColor] = [.yellow, .orange, .red, .cyan, .green, .magenta, .white, .systemYellow, .systemRed, .systemGreen]
        
        for i in 0..<fireworkCount {
            let angle = CGFloat(i) * (2.0 * .pi / CGFloat(fireworkCount))
            
            // Much slower burst speed (20-60 range - very slow)
            let baseSpeed: CGFloat = CGFloat.random(in: 20...60)
            let velocityX = cos(angle) * baseSpeed
            let velocityY = sin(angle) * baseSpeed
            
            // Randomize particle size (2-6 radius for variety)
            let particleRadius = CGFloat.random(in: 2...6)
            let particle = SKShapeNode(circleOfRadius: particleRadius)
            particle.fillColor = colors[i % colors.count]
            particle.strokeColor = .white
            particle.lineWidth = 1
            particle.position = pointsValueLabel.position
            particle.zPosition = 50
            addChild(particle)
            
            // Much slower animation with minimal gravity - floaty effect
            let duration: TimeInterval = 2.5  // Very long duration - 2.5 seconds
            let moveAction = SKAction.customAction(withDuration: duration) { node, elapsedTime in
                let progress = elapsedTime / duration
                
                // Apply initial velocity with VERY weak gravity - particles float more than fall
                let newX = node.position.x + (velocityX * CGFloat(elapsedTime))
                
                // Much weaker gravity (100 instead of 500) - particles float longer before falling
                let gravity: CGFloat = 100
                let newY = node.position.y + (velocityY * CGFloat(elapsedTime)) - (0.5 * gravity * CGFloat(elapsedTime) * CGFloat(elapsedTime))
                node.position = CGPoint(x: newX, y: newY)
                
                // Fade out very gradually - takes full 2.5 seconds
                node.alpha = 1.0 - progress
                
                // Slight scale down as it falls
                node.setScale(1.0 - (progress * 0.2))
            }
            
            let removeAction = SKAction.removeFromParent()
            let sequence = SKAction.sequence([moveAction, removeAction])
            particle.run(sequence)
        }
    }

private func updateFloatingText() {
    guard let gameState = gameState else { return }
    
    let deltaTime: TimeInterval = 0.016  // ~60 FPS
    
    // Render and update gameState's floating texts (from actions like Rest)
    for floatingText in gameState.floatingTexts {
        // Check if we've already created a node for this floating text
        if let existingNode = floatingTextContainer.children.first(where: { $0.name == floatingText.id.uuidString }) as? SKLabelNode {
            // Update existing node position
            let screenX = floatingText.x * size.width
            let screenY = (1.0 - floatingText.y) * size.height
            existingNode.position = CGPoint(x: screenX, y: screenY)
            
            // Update alpha based on age
            let alpha = max(0, 1.0 - (floatingText.age / floatingText.lifespan))
            existingNode.alpha = CGFloat(alpha)
        } else {
            // Create new node for this floating text
            let label = SKLabelNode(fontNamed: "Arial-BoldMT")
            label.text = floatingText.text
            label.fontSize = CGFloat(floatingText.fontSize)
            label.name = floatingText.id.uuidString
            label.fontColor = floatingText.color
            
            // Convert normalized coordinates to screen coordinates
            let screenX = floatingText.x * size.width
            let screenY = (1.0 - floatingText.y) * size.height
            label.position = CGPoint(x: screenX, y: screenY)
            label.zPosition = 50
            
            floatingTextContainer.addChild(label)
        }
    }
    
    // Clean up removed gameState floating texts
    for node in floatingTextContainer.children {
        if gameState.floatingTexts.first(where: { $0.id.uuidString == node.name }) == nil && node.name?.isEmpty == false {
            // This node's floating text has been removed from gameState
            if !floatingTexts.contains(where: { $0.node === node }) {
                // It's not one of our SpriteKit floating texts, so remove it
                node.removeFromParent()
            }
        }
    }
    
    // Update existing SpriteKit floating texts
    for i in floatingTexts.indices.reversed() {
        floatingTexts[i].age += deltaTime
        
        // Move upward
        floatingTexts[i].y += 40 * deltaTime
        floatingTexts[i].node.position.y = floatingTexts[i].y
        
        // Fade out
        let alpha = max(0, 1.0 - (floatingTexts[i].age / floatingTexts[i].lifespan))
        floatingTexts[i].node.alpha = CGFloat(alpha)
        
        // Remove if expired
        if floatingTexts[i].age >= floatingTexts[i].lifespan {
            floatingTexts[i].node.removeFromParent()
            floatingTexts.remove(at: i)
        }
    }
}

// MARK: - Boost Management

private func activateBoost() {
    boostEndTime = CACurrentMediaTime() + 6.0  // 6 second boost
    // Also update gameState's speedBoostEndTime so animations can use it
    gameState?.speedBoostEndTime = Date().addingTimeInterval(6.0)
}

private func updateBoostTimer() {
    let currentTime = CACurrentMediaTime()
    let timeRemaining = boostEndTime - currentTime
    
    if timeRemaining > 0 {
        let seconds = Int(timeRemaining)
        boostTimerLabel?.text = "⚡ Boost: \(seconds)s"
        boostTimerLabel?.isHidden = false
    } else {
        boostTimerLabel?.isHidden = true
        boostEndTime = 0
    }
}

private func isBoostActive() -> Bool {
    return CACurrentMediaTime() < boostEndTime
}

private func updateCountdownTimer() {
    guard let gameState = gameState else { return }
    guard let character = characterNode else { return }
    
    // Only show countdown if an action is being performed and countdown is enabled
    let timeRemaining = gameState.actionCountdownTimeRemaining
    let totalDuration = gameState.actionCountdownTotalDuration
    
    if timeRemaining > 0 && totalDuration > 0 {
        // Format time: MM:SS
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)
        
        // Calculate color based on time remaining (green → yellow → red)
        let percentRemaining = timeRemaining / totalDuration
        var textColor: SKColor
        
        if percentRemaining > 0.5 {
            // Green for first half
            textColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
        } else if percentRemaining > 0.25 {
            // Yellow for second half
            textColor = SKColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        } else {
            // Red for last quarter
            textColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        }
        
        // Position countdown label above the stick figure
        countdownTimerLabel?.position = CGPoint(x: character.position.x, y: character.position.y + 120)
        countdownTimerLabel?.text = timeString
        countdownTimerLabel?.fontColor = textColor
        countdownTimerLabel?.isHidden = false
    } else {
        countdownTimerLabel?.isHidden = true
    }
}

// MARK: - Floating Text Structure

struct FloatingText {
    var node: SKLabelNode
    var x: CGFloat
    var y: CGFloat
    var age: TimeInterval = 0
    let lifespan: TimeInterval = 2.0
    let color: UIColor
}

@MainActor
deinit {
    //print("🎮 GameplayScene deinit - cleaning up")
    removeAllChildren()
    removeAllActions()
}
}

// MARK: - UIColor Extension for Hex Support

extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        
        let rgbValue = UInt32(hex, radix: 16) ?? 0
        let red = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgbValue & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
