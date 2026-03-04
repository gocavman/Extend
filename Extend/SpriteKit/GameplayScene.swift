import SpriteKit

/// SpriteKit scene for gameplay with character movement and interactions
class GameplayScene: GameScene {
    private var characterNode: SKNode?
    var levelLabel: SKLabelNode?
    var animationFrameIndex: Int = 0
    
    // Button areas for UI
    private var exitButtonArea: SKShapeNode?
    private var statsButtonArea: SKShapeNode?
    private var appearanceButtonNode: SKNode?
    
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
            return
        }
        
        // Ensure the room is initialized with stick figure data
        if gameState.standFrame == nil {
            gameState.initializeRoom("level_\(gameState.currentLevel)")
        } else {
        }
        
        backgroundColor = SKColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        
        // Create UI
        setupUI()
        
        // Create character
        setupCharacter()
        
        // Create touch zones (debug visualization)
        setupControlZones()
        
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
        
        // Level display - top center
        levelLabel = SKLabelNode(fontNamed: "Arial")
        levelLabel?.fontSize = 12
        levelLabel?.fontColor = .black
        levelLabel?.position = CGPoint(x: size.width / 2, y: topBarY)
        levelLabel?.text = "Level \(gameState?.currentLevel ?? 1) | Points: \(0)"
        levelLabel?.zPosition = 101
        if let label = levelLabel { addChild(label) }
    }
    
    private func setupCharacter() {
        guard let gameState = gameState else {
            return
        }
        
        
        // Use the Stand frame from gameState
        if let standFrame = gameState.standFrame {
            
            // Create a container node
            let characterContainer = SKNode()
            characterContainer.position = CGPoint(x: size.width / 2, y: size.height / 2)
            characterContainer.name = "character"
            characterContainer.zPosition = 10
            
            // Use renderStickFigure with proper scale
            // The figure is in 600x720 base canvas
            // Scale 1.2 provides good visible size without rendering issues
            let stickFigureNode = renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2, flipped: false)
            characterContainer.addChild(stickFigureNode)
            
            // Render stand frame objects
            renderFrameObjects(gameState.standFrameObjects, on: characterContainer, scale: 1.2)
            
            addChild(characterContainer)
            characterNode = characterContainer
            
        } else {
            
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
        
        handleTouchAtLocation(point, isPress: true)
    }
    
    override func handleTouchEnded(at point: CGPoint) {
        
        // First, check for button taps at the top
        let topBarY = size.height - 100
        let tapDistance = abs(point.y - topBarY)
        
        if tapDistance < 35 { // Within the top button area (increased from 25 to 35)
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
            return
        }
        
        let topButtonY = size.height - 120  // Top button area (safe zone)
        
        // Only ignore PRESS events in top button area
        // Always allow RELEASE events to stop movement
        if isPress && point.y > topButtonY {
            return
        }
        
        
        // Get character position
        guard let character = characterNode else {
            return
        }
        
        let characterX = character.position.x
        
        // Smart directional movement: determine direction based on tap position relative to character
        // If tap is to the left of character, move left (regardless of zone)
        // If tap is to the right of character, move right (regardless of zone)
        
        if point.x < characterX {
            // Tap is to the LEFT of character - move left
            if isPress {
                gameState.isMovingLeft = true
                gameState.isMovingRight = false
                gameState.facingRight = false
            } else {
                gameState.isMovingLeft = false
                gameState.isMovingRight = false
            }
        } else if point.x > characterX {
            // Tap is to the RIGHT of character - move right
            if isPress {
                gameState.isMovingRight = true
                gameState.isMovingLeft = false
                gameState.facingRight = true
            } else {
                gameState.isMovingRight = false
                gameState.isMovingLeft = false
            }
        } else {
            // Tap is directly on character - do nothing or trigger action
            if isPress {
            } else {
                gameState.isMovingLeft = false
                gameState.isMovingRight = false
            }
        }
        
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
                
                // Remove old stick figure and add new one
                if let characterContainer = self.characterNode {
                    characterContainer.removeAllChildren()
                    let shouldFlip = !gameState.facingRight
                    let stickFigureNode = self.renderStickFigure(moveFrame, at: CGPoint.zero, scale: 1.2, flipped: shouldFlip)
                    characterContainer.addChild(stickFigureNode)
                    
                    // Render move frame objects
                    if moveFrameIndex < gameState.moveFrameObjects.count {
                        self.renderFrameObjects(gameState.moveFrameObjects[moveFrameIndex], on: characterContainer, scale: 1.2)
                    }
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
        
        // Stop the animation action
        characterNode?.removeAction(forKey: "moveAnimation")
        
        // Show stand frame
        if let gameState = gameState, let standFrame = gameState.standFrame {
            if let characterContainer = characterNode {
                characterContainer.removeAllChildren()
                let shouldFlip = !gameState.facingRight
                let stickFigureNode = renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2, flipped: shouldFlip)
                characterContainer.addChild(stickFigureNode)
                
                // Render stand frame objects
                renderFrameObjects(gameState.standFrameObjects, on: characterContainer, scale: 1.2)
            }
        }
    }
    
    /// Refresh the character appearance when colors are changed in the customizer
    func refreshCharacterAppearance() {
        
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
                
                // Render move frame objects
                if animationFrameIndex < gameState.moveFrameObjects.count {
                    renderFrameObjects(gameState.moveFrameObjects[animationFrameIndex], on: characterContainer, scale: 1.2)
                }
            }
        } else {
            // Otherwise show stand frame
            if let standFrame = gameState.standFrame {
                let shouldFlip = !gameState.facingRight
                let stickFigureNode = renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2, flipped: shouldFlip)
                characterContainer.addChild(stickFigureNode)
                
                // Render stand frame objects
                renderFrameObjects(gameState.standFrameObjects, on: characterContainer, scale: 1.2)
            }
        }
    }
    
    /// Render objects associated with a frame
    private func renderFrameObjects(_ objects: [AnimationObject], on container: SKNode, scale: CGFloat) {
        for object in objects {
            let sprite = SKSpriteNode(imageNamed: object.imageName)
            sprite.position = object.position * scale
            sprite.zRotation = CGFloat(object.rotation)
            sprite.xScale *= object.scale
            sprite.yScale *= object.scale
            sprite.zPosition = 5  // Behind stick figure (which is 10+)
            sprite.name = "object_\(object.imageName)"
            container.addChild(sprite)
        }
    }
    
    @MainActor
    deinit {
        removeAllChildren()
        removeAllActions()
    }
}
