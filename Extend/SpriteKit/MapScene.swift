import SpriteKit

/// SpriteKit scene for the level map
class MapScene: GameScene {
    private var characterNode: SKNode?
    private var levelBoxNodes: [SKShapeNode] = []
    private var selectedLevel: Int = 1
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        print("🗺️ MapScene didMove - size: \(size)")
        
        // Set background
        backgroundColor = SKColor(red: 0.85, green: 0.95, blue: 0.85, alpha: 1.0)
        
        // Create map UI
        setupMapUI()
        setupLevels()
        setupCharacter()
    }
    
    private func setupMapUI() {
        // Top bar with buttons - positioned below safe area
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
        
        // Editor button - top center
        let editorArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
        editorArea.position = CGPoint(x: size.width / 2, y: topBarY)
        editorArea.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.7)
        editorArea.strokeColor = .black
        editorArea.lineWidth = 2
        editorArea.name = "editorButton"
        editorArea.zPosition = 100
        addChild(editorArea)
        
        let editorLabel = SKLabelNode(fontNamed: "Arial")
        editorLabel.text = "EDIT"
        editorLabel.fontSize = 10
        editorLabel.fontColor = .white
        editorLabel.position = CGPoint(x: size.width / 2, y: topBarY)
        editorLabel.zPosition = 101
        addChild(editorLabel)
    }
    
    private func setupLevels() {
        guard let gameState = gameState else {
            print("⚠️ MapScene: gameState is nil!")
            return
        }
        
        print("🗺️ Setting up levels - current level: \(gameState.currentLevel)")
        
        let boxWidth: CGFloat = 80
        let boxHeight: CGFloat = 60
        let spacing: CGFloat = 12
        let cols = 4
        
        // Calculate grid dimensions
        let gridWidth = CGFloat(cols) * boxWidth + CGFloat(cols - 1) * spacing
        
        // Center the grid horizontally (calculate the left edge) and position vertically
        let gridStartX = (size.width - gridWidth) / 2
        let startY = size.height - 200
        
        // Create level boxes based on gameState
        for i in 0..<10 {
            let levelNum = i + 1
            let row = i / cols
            let col = i % cols
            
            // Position each box: left edge of grid + column offset + half box width (to center the box)
            let x = gridStartX + CGFloat(col) * (boxWidth + spacing) + boxWidth / 2
            let y = startY - CGFloat(row) * (boxHeight + spacing)
            
            // Check if level is available
            let isCompleted = levelNum < gameState.currentLevel
            let isAvailable = levelNum <= gameState.currentLevel
            let color: SKColor = isCompleted ? .green : (isAvailable ? .white : .gray)
            
            // Create level box
            let levelBox = SKShapeNode(rectOf: CGSize(width: boxWidth, height: boxHeight))
            levelBox.position = CGPoint(x: x, y: y)
            levelBox.fillColor = color
            levelBox.strokeColor = .black
            levelBox.lineWidth = 2
            levelBox.name = "level_\(levelNum)"
            levelBox.zPosition = 50
            addChild(levelBox)
            levelBoxNodes.append(levelBox)
            let label = SKLabelNode(fontNamed: "Arial")
            label.text = "Level \(levelNum)"
            label.fontSize = 12
            label.fontColor = isCompleted || isAvailable ? .black : .white
            label.position = CGPoint(x: x, y: y)
            label.zPosition = 51
            addChild(label)
            
            levelBoxNodes.append(levelBox)
        }
    }
    
    private func setupCharacter() {
        // Create character representation (simple blue circle for now)
        let character = SKShapeNode(circleOfRadius: 20)
        character.fillColor = SKColor.blue
        character.strokeColor = SKColor.black
        character.lineWidth = 2
        character.position = CGPoint(x: size.width / 2, y: 100)
        character.name = "character"
        character.zPosition = 10
        addChild(character)
        
        characterNode = character
    }
    
    override func handleTouchBegan(at point: CGPoint) {
        print("🗺️ Touch began at: \(point)")
        let touchedNode = atPoint(point)
        print("🗺️ Touched node: \(touchedNode.name ?? "unknown")")
    }
    
    override func handleTouchEnded(at point: CGPoint) {
        print("🗺️ Touch ended at: \(point)")
        print("🗺️ gameViewController is: \(gameViewController != nil ? "SET" : "NIL")")
        print("🗺️ Screen size: \(size), Safe area insets: \(view?.safeAreaInsets ?? UIEdgeInsets.zero)")
        
        let topBarY = size.height - 100
        let tapDistance = abs(point.y - topBarY)
        
        print("🗺️ Button bar at Y=\(topBarY), tap distance=\(tapDistance), tap Y=\(point.y)")
        
        // Check for top button taps
        if tapDistance < 35 {  // Increased from 25 to 35 for better hit detection
            // Exit button
            if point.x < 70 {
                print("🗺️ ✓ Exit button tapped! - calling dismissGame() to exit to dashboard")
                gameViewController?.dismissGame()
                return
            }
            // Stats button
            if point.x > size.width - 70 {
                print("🗺️ ✓ Stats button tapped!")
                gameViewController?.showStats()
                return
            }
            // Editor button
            if point.x > size.width / 2 - 35 && point.x < size.width / 2 + 35 {
                print("🗺️ ✓ Editor button tapped! - Opening 2D Stick Figure Editor")
                gameViewController?.openStickFigureEditor()
                return
            }
        }
        
        // Check level box taps
        for (index, levelBox) in levelBoxNodes.enumerated() {
            let distance = hypot(point.x - levelBox.position.x, point.y - levelBox.position.y)
            // Box is 80x60, so half-diagonal is sqrt(40^2 + 30^2) ≈ 50
            let boxRadius = sqrt(40.0 * 40.0 + 30.0 * 30.0)
            
            if distance < boxRadius {
                let levelNum = index + 1
                // Only allow tapping on available levels (levelNum <= currentLevel)
                if levelNum <= (gameState?.currentLevel ?? 1) {
                    print("🗺️ ✓ Level \(levelNum) tapped!")
                    gameState?.currentLevel = levelNum
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("🗺️ In dispatch block - gameViewController: \(self.gameViewController != nil ? "SET" : "NIL")")
                        self.gameViewController?.startGameplay()
                    }
                } else {
                    print("🗺️ Level \(levelNum) is locked!")
                }
                return
            }
        }
        
        print("🗺️ ✗ No node hit - touch at \(point)")
    }
    
    @MainActor
    deinit {
        print("🗺️ MapScene deinit - cleaning up")
        removeAllChildren()
        removeAllActions()
    }
}
