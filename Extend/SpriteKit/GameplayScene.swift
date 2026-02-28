import SpriteKit

/// SpriteKit scene for gameplay with character movement and interactions
class GameplayScene: GameScene {
    private var characterNode: SKNode?
    var levelLabel: SKLabelNode?
    var animationFrameIndex: Int = 0
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        print("🎮 GameplayScene didMove")
        print("🎮 Scene size: \(size)")
        print("🎮 View bounds: \(view.bounds)")
        print("🎮 Safe area: \(view.safeAreaInsets)")
        
        // Initialize gameState if needed
        guard let gameState = gameState else {
            print("🎮 ERROR: gameState is nil!")
            return
        }
        
        // Ensure the room is initialized with stick figure data
        if gameState.standFrame == nil {
            print("🎮 standFrame is nil, initializing room for level \(gameState.currentLevel)...")
            gameState.initializeRoom("level_\(gameState.currentLevel)")
            print("🎮 After initializeRoom: standFrame = \(gameState.standFrame != nil ? "SET" : "STILL NIL")")
        } else {
            print("🎮 standFrame is already SET")
        }
        
        backgroundColor = SKColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        
        // Create UI
        print("🎮 Setting up UI...")
        setupUI()
        print("🎮 UI setup complete")
        
        // Create character
        print("🎮 Setting up character...")
        setupCharacter()
        print("🎮 Character setup complete")
        
        // Create touch zones (debug visualization)
        print("🎮 Setting up control zones...")
        setupControlZones()
        print("🎮 Control zones setup complete")
        
        // Start game loop
        print("🎮 Starting game loop...")
        startGameLoop()
        print("🎮 Game loop started")
    }
    
    private func setupUI() {
        print("🎮 Screen size: \(size)")
        
        // TOP BAR - Moved down to avoid safe area
        let topBarY: CGFloat = size.height - 100
        
        // Exit button - top left
        let exitArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
        exitArea.position = CGPoint(x: 35, y: topBarY)
        exitArea.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.7)
        exitArea.strokeColor = .black
        exitArea.lineWidth = 2
        exitArea.name = "exitButton"
        exitArea.zPosition = 100
        addChild(exitArea)
        
        let exitLabel = SKLabelNode(fontNamed: "Arial")
        exitLabel.text = "EXIT"
        exitLabel.fontSize = 10
        exitLabel.fontColor = .white
        exitLabel.position = CGPoint(x: 35, y: topBarY)
        exitLabel.zPosition = 101
        addChild(exitLabel)
        
        // Stats button - top right
        let statsArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
        statsArea.position = CGPoint(x: size.width - 35, y: topBarY)
        statsArea.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.7)
        statsArea.strokeColor = .black
        statsArea.lineWidth = 2
        statsArea.name = "statsButton"
        statsArea.zPosition = 100
        addChild(statsArea)
        
        let statsLabel = SKLabelNode(fontNamed: "Arial")
        statsLabel.text = "STATS"
        statsLabel.fontSize = 10
        statsLabel.fontColor = .white
        statsLabel.position = CGPoint(x: size.width - 35, y: topBarY)
        statsLabel.zPosition = 101
        addChild(statsLabel)
        
        // Appearance button - left of Stats button (icon only, no background box)
        // Create SF Symbol image for figure.stand and display it
        if let sfSymbolImage = createSFSymbolImage(name: "figure.stand", size: CGSize(width: 24, height: 24), color: UIColor.white) {
            let appearanceIcon = SKSpriteNode(texture: SKTexture(image: sfSymbolImage))
            appearanceIcon.position = CGPoint(x: size.width - 100, y: topBarY)
            appearanceIcon.name = "appearanceButton"
            appearanceIcon.zPosition = 101
            addChild(appearanceIcon)
        } else {
            // Fallback to emoji if SF Symbol creation fails
            let appearanceLabel = SKLabelNode(fontNamed: "Arial")
            appearanceLabel.text = "🧍"
            appearanceLabel.fontSize = 16
            appearanceLabel.fontColor = .white
            appearanceLabel.position = CGPoint(x: size.width - 100, y: topBarY)
            appearanceLabel.name = "appearanceButton"
            appearanceLabel.zPosition = 101
            addChild(appearanceLabel)
        }
        
        // Level display - top center
        levelLabel = SKLabelNode(fontNamed: "Arial")
        levelLabel?.fontSize = 12
        levelLabel?.fontColor = .black
        levelLabel?.position = CGPoint(x: size.width / 2, y: topBarY)
        levelLabel?.text = "Level \(gameState?.currentLevel ?? 1) | Points: 0"
        levelLabel?.zPosition = 101
        if let label = levelLabel { addChild(label) }
    }
    
    private func setupCharacter() {
        guard let gameState = gameState else {
            print("🎮 ERROR: gameState is nil in setupCharacter")
            return
        }
        
        print("🎮 setupCharacter: standFrame = \(gameState.standFrame != nil ? "SET" : "NIL")")
        print("🎮 setupCharacter: moveFrames.count = \(gameState.moveFrames.count)")
        print("🎮 standFrame fusiform values: upper=\(gameState.standFrame?.fusiformUpperTorso ?? 0), lower=\(gameState.standFrame?.fusiformLowerTorso ?? 0)")
        print("🎮 standFrame ALL fusiforms: upperTorso=\(gameState.standFrame?.fusiformUpperTorso ?? 0), lowerTorso=\(gameState.standFrame?.fusiformLowerTorso ?? 0), upperArms=\(gameState.standFrame?.fusiformUpperArms ?? 0), lowerArms=\(gameState.standFrame?.fusiformLowerArms ?? 0), upperLegs=\(gameState.standFrame?.fusiformUpperLegs ?? 0), lowerLegs=\(gameState.standFrame?.fusiformLowerLegs ?? 0)")
        
        // Use the Stand frame from gameState
        if let standFrame = gameState.standFrame {
            print("🎮 Rendering stand frame from gameState")
            
            // Create a container node
            let characterContainer = SKNode()
            characterContainer.position = CGPoint(x: size.width / 2, y: size.height / 2)
            characterContainer.name = "character"
            characterContainer.zPosition = 10
            
            // Use renderStickFigure with proper scale
            // The figure is in 600x720 base canvas
            // Scale 1.2 provides good visible size without rendering issues
            print("🎮 About to call renderStickFigure...")
            let stickFigureNode = renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2, flipped: false)
            print("🎮 renderStickFigure returned successfully")
            characterContainer.addChild(stickFigureNode)
            
            addChild(characterContainer)
            characterNode = characterContainer
            
            print("🎮 Stand frame rendered successfully with scale 0.1")
            print("🎮 Character node added to scene with zPosition: \(characterContainer.zPosition)")
        } else {
            print("🎮 No standFrame available, using fallback blue circle")
            
            // Fallback: create a placeholder circle
            let character = SKShapeNode(circleOfRadius: 30)
            character.fillColor = SKColor.blue
            character.strokeColor = SKColor.black
            character.lineWidth = 2
            character.position = CGPoint(x: size.width / 2, y: size.height / 2)
            character.name = "character"
            character.zPosition = 10
            addChild(character)
            
            characterNode = character
        }
    }
    
    private func setupControlZones() {
        // Define touch zones at BOTTOM of screen
        // Left (40%), Center (20%), Right (40%)
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
        leftLabel.text = "LEFT"
        leftLabel.fontSize = 12
        leftLabel.fontColor = .black
        leftLabel.position = CGPoint(x: leftZoneWidth / 2, y: zoneHeight / 2)
        leftLabel.zPosition = 6
        addChild(leftLabel)
        
        // Center zone (action) - BOTTOM CENTER (20%)
        let centerZone = SKShapeNode(rectOf: CGSize(width: centerZoneWidth, height: zoneHeight))
        centerZone.position = CGPoint(x: leftZoneWidth + centerZoneWidth / 2, y: zoneHeight / 2)
        centerZone.fillColor = SKColor.red.withAlphaComponent(0.4)
        centerZone.strokeColor = .black
        centerZone.lineWidth = 2
        centerZone.name = "centerZone"
        centerZone.zPosition = 5
        addChild(centerZone)
        
        let centerLabel = SKLabelNode(fontNamed: "Arial")
        centerLabel.text = "ACTION"
        centerLabel.fontSize = 10
        centerLabel.fontColor = .black
        centerLabel.position = CGPoint(x: leftZoneWidth + centerZoneWidth / 2, y: zoneHeight / 2)
        centerLabel.zPosition = 6
        addChild(centerLabel)
        
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
        rightLabel.text = "RIGHT"
        rightLabel.fontSize = 12
        rightLabel.fontColor = .black
        rightLabel.position = CGPoint(x: leftZoneWidth + centerZoneWidth + rightZoneWidth / 2, y: zoneHeight / 2)
        rightLabel.zPosition = 6
        addChild(rightLabel)
    }
    
    override func handleTouchBegan(at point: CGPoint) {
        print("🎮 ===== TOUCH BEGAN =====")
        print("🎮 Touch point: \(point)")
        print("🎮 Scene size: \(size)")
        print("🎮 Zone width would be: \(size.width / 3)")
        print("🎮 Touch in left zone? \(point.x < size.width / 3 && point.y < 100)")
        print("🎮 Touch in right zone? \(point.x >= (size.width * 2 / 3) && point.y < 100)")
        
        handleTouchAtLocation(point, isPress: true)
    }
    
    override func handleTouchEnded(at point: CGPoint) {
        print("🎮 ===== TOUCH ENDED =====")
        print("🎮 Touch point: \(point)")
        
        // First, check for button taps at the top
        let topBarY = size.height - 100
        let tapDistance = abs(point.y - topBarY)
        
        if tapDistance < 35 { // Within the top button area (increased from 25 to 35)
            // Exit button
            if point.x < 70 {
                print("🎮 Exit button tapped!")
                gameViewController?.dismissGame()
                return
            }
            // Appearance button (left of Stats)
            if point.x > size.width - 135 && point.x < size.width - 65 {
                print("🎮 Appearance button tapped!")
                gameViewController?.showAppearance()
                return
            }
            // Stats button
            if point.x > size.width - 70 {
                print("🎮 Stats button tapped!")
                gameViewController?.showStats()
                return
            }
        }
        
        // If no button was tapped, handle movement release
        handleTouchAtLocation(point, isPress: false)
    }
    
    private func handleTouchAtLocation(_ point: CGPoint, isPress: Bool) {
        guard let gameState = gameState else {
            print("🎮 ERROR: gameState is nil")
            return
        }
        
        let topButtonY = size.height - 120  // Top button area (safe zone)
        
        // Only ignore PRESS events in top button area
        // Always allow RELEASE events to stop movement
        if isPress && point.y > topButtonY {
            print("🎮 Touch in top button area, ignoring press")
            return
        }
        
        print("🎮 Checking zones - point: \(point), topButtonY: \(topButtonY), isPress: \(isPress)")
        
        // Get character position
        guard let character = characterNode else {
            print("🎮 ERROR: characterNode is nil")
            return
        }
        
        let characterX = character.position.x
        print("🎮 Character position: \(characterX), Tap position: \(point.x)")
        
        // Smart directional movement: determine direction based on tap position relative to character
        // If tap is to the left of character, move left (regardless of zone)
        // If tap is to the right of character, move right (regardless of zone)
        
        if point.x < characterX {
            // Tap is to the LEFT of character - move left
            if isPress {
                print("🎮 ✓ TAP LEFT OF CHARACTER - MOVE LEFT")
                gameState.isMovingLeft = true
                gameState.isMovingRight = false
                gameState.facingRight = false
            } else {
                print("🎮 ✓ RELEASE - STOP MOVING (was moving left)")
                gameState.isMovingLeft = false
                gameState.isMovingRight = false
            }
        } else if point.x > characterX {
            // Tap is to the RIGHT of character - move right
            if isPress {
                print("🎮 ✓ TAP RIGHT OF CHARACTER - MOVE RIGHT")
                gameState.isMovingRight = true
                gameState.isMovingLeft = false
                gameState.facingRight = true
            } else {
                print("🎮 ✓ RELEASE - STOP MOVING (was moving right)")
                gameState.isMovingRight = false
                gameState.isMovingLeft = false
            }
        } else {
            // Tap is directly on character - do nothing or trigger action
            if isPress {
                print("🎮 Touch directly on character (center action zone)")
            } else {
                print("🎮 ✓ RELEASE - STOP MOVING (was on character)")
                gameState.isMovingLeft = false
                gameState.isMovingRight = false
            }
        }
        
        print("🎮 After handling: isMovingLeft=\(gameState.isMovingLeft), isMovingRight=\(gameState.isMovingRight)")
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
        
        // Check if character is moving - update animation
        if gameState.isMovingLeft || gameState.isMovingRight {
            // Start animation if not already running
            if character.action(forKey: "moveAnimation") == nil {
                startMovementAnimation()
            }
        } else {
            // Stop animation if running
            if character.action(forKey: "moveAnimation") != nil {
                stopMovementAnimation()
            }
        }
        
        // Update character position based on movement
        let speed: CGFloat = 5.0
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
        
        // Update level label
        levelLabel?.text = "Level \(gameState.currentLevel) | Points: \(gameState.currentPoints)"
    }
    
    private func startMovementAnimation() {
        print("🎮 Starting movement animation")
        
        // Stop any existing animation first
        characterNode?.removeAction(forKey: "moveAnimation")
        animationFrameIndex = 0
        
        // Use SKAction sequence instead of Timer for better performance
        var actions: [SKAction] = []
        
        // Create actions for each move frame
        for i in 0..<4 {
            let moveFrameIndex = i
            
            actions.append(SKAction.run { [weak self] in
                guard let self = self, let gameState = self.gameState else { return }
                guard moveFrameIndex < gameState.moveFrames.count else { return }
                
                let moveFrame = gameState.moveFrames[moveFrameIndex]
                print("🎮 Updating to move frame \(moveFrameIndex + 1)")
                
                // Remove old stick figure and add new one
                if let characterContainer = self.characterNode {
                    characterContainer.removeAllChildren()
                    let shouldFlip = !gameState.facingRight
                    let stickFigureNode = self.renderStickFigure(moveFrame, at: CGPoint.zero, scale: 1.2, flipped: shouldFlip)
                    characterContainer.addChild(stickFigureNode)
                }
            })
            
            // Wait before next frame
            actions.append(SKAction.wait(forDuration: 0.15))
        }
        
        // Run the sequence on the character node
        if !actions.isEmpty {
            let sequence = SKAction.sequence(actions)
            let repeatAction = SKAction.repeatForever(sequence)
            characterNode?.run(repeatAction, withKey: "moveAnimation")
        }
    }
    
    private func stopMovementAnimation() {
        print("🎮 Stopping movement animation")
        
        // Stop the animation action
        characterNode?.removeAction(forKey: "moveAnimation")
        
        // Show stand frame
        if let gameState = gameState, let standFrame = gameState.standFrame {
            if let characterContainer = characterNode {
                characterContainer.removeAllChildren()
                let shouldFlip = !gameState.facingRight
                let stickFigureNode = renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2, flipped: shouldFlip)
                characterContainer.addChild(stickFigureNode)
            }
        }
    }
    
    /// Refresh the character appearance when colors are changed in the customizer
    func refreshCharacterAppearance() {
        print("🎮 Refreshing character appearance after color change")
        
        guard let gameState = gameState, let characterContainer = characterNode else { return }
        
        // Clear existing character
        characterContainer.removeAllChildren()
        characterContainer.removeAction(forKey: "moveAnimation")
        
        // Re-render with current frame
        if gameState.isMovingLeft || gameState.isMovingRight {
            // If moving, use current animation frame
            if animationFrameIndex < gameState.moveFrames.count {
                let moveFrame = gameState.moveFrames[animationFrameIndex]
                let shouldFlip = !gameState.facingRight
                let stickFigureNode = renderStickFigure(moveFrame, at: CGPoint.zero, scale: 1.2, flipped: shouldFlip)
                characterContainer.addChild(stickFigureNode)
            }
        } else {
            // Otherwise show stand frame
            if let standFrame = gameState.standFrame {
                let shouldFlip = !gameState.facingRight
                let stickFigureNode = renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2, flipped: shouldFlip)
                characterContainer.addChild(stickFigureNode)
            }
        }
    }
    
    @MainActor
    deinit {
        print("🎮 GameplayScene deinit - cleaning up")
        removeAllChildren()
        removeAllActions()
    }
}
