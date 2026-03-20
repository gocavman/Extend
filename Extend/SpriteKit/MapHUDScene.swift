import SpriteKit

/// Separate HUD scene overlay for map controls (Exit, Stats, Appearance, Editor)
/// This scene stays fixed on screen and doesn't move with the camera
class MapHUDScene: SKScene {
    weak var gameViewController: GameViewController?
    var gameState: StickFigureGameState?
    
    // Button nodes for hit detection
    private var exitButton: SKShapeNode?
    private var statsButton: SKShapeNode?
    private var appearanceButton: SKLabelNode?
    private var editorButton: SKShapeNode?
    private var levelLabel: SKLabelNode?
    private var pointsLabel: SKLabelNode?
    private var pointsValueLabel: SKLabelNode?  // Separate label for just the number
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        //print("🗺️ MapHUDScene didMove - size: \(size)")
        
        // Transparent background
        backgroundColor = SKColor.clear
        isUserInteractionEnabled = true
        
        setupHUD()
    }
    
    private func setupHUD() {
        // HUD bar at top of screen
        let topBarY: CGFloat = size.height - 50
        
        // MARK: - Exit Button (Top Left)
        let exitArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
        exitArea.position = CGPoint(x: 35, y: topBarY)
        exitArea.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        exitArea.strokeColor = .black
        exitArea.lineWidth = 2
        exitArea.name = "exitButton"
        exitArea.zPosition = 100
        addChild(exitArea)
        exitButton = exitArea
        
        let exitLabel = SKLabelNode(fontNamed: "Arial")
        exitLabel.text = "EXIT"
        exitLabel.fontSize = 11
        exitLabel.fontColor = .white
        exitLabel.position = CGPoint(x: 35, y: topBarY)
        exitLabel.zPosition = 101
        addChild(exitLabel)
        
        // MARK: - Stats Button (Top Right)
        let statsArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
        statsArea.position = CGPoint(x: size.width - 35, y: topBarY)
        statsArea.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        statsArea.strokeColor = .black
        statsArea.lineWidth = 2
        statsArea.name = "statsButton"
        statsArea.zPosition = 100
        addChild(statsArea)
        statsButton = statsArea
        
        let statsLabel = SKLabelNode(fontNamed: "Arial")
        statsLabel.text = "STATS"
        statsLabel.fontSize = 11
        statsLabel.fontColor = .white
        statsLabel.position = CGPoint(x: size.width - 35, y: topBarY)
        statsLabel.zPosition = 101
        addChild(statsLabel)
        
        // MARK: - Appearance Button (Left of Center)
        let appearanceLabel = SKLabelNode(fontNamed: "Arial")
        appearanceLabel.text = "🧍"
        appearanceLabel.fontSize = 20
        appearanceLabel.fontColor = .white
        appearanceLabel.position = CGPoint(x: size.width / 2 - 65, y: topBarY)
        appearanceLabel.name = "appearanceButton"
        appearanceLabel.zPosition = 101
        addChild(appearanceLabel)
        appearanceButton = appearanceLabel
        
        // MARK: - Editor Button (Right of Center)
        let editorArea = SKShapeNode(rectOf: CGSize(width: 60, height: 40))
        editorArea.position = CGPoint(x: size.width / 2 + 65, y: topBarY)
        editorArea.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        editorArea.strokeColor = .black
        editorArea.lineWidth = 2
        editorArea.name = "editorButton"
        editorArea.zPosition = 100
        addChild(editorArea)
        editorButton = editorArea
        
        let editorLabel = SKLabelNode(fontNamed: "Arial")
        editorLabel.text = "EDIT"
        editorLabel.fontSize = 11
        editorLabel.fontColor = .white
        editorLabel.position = CGPoint(x: size.width / 2 + 65, y: topBarY)
        editorLabel.zPosition = 101
        addChild(editorLabel)
        
        // MARK: - Level and Points Row (Below Buttons)
        let statsRowY: CGFloat = topBarY - 40
        
        // Level label on left side
        let levelLabel = SKLabelNode(fontNamed: "Arial")
        levelLabel.text = "Level: 1"
        levelLabel.fontSize = 14
        levelLabel.fontColor = .black
        levelLabel.position = CGPoint(x: size.width / 2 - 80, y: statsRowY)
        levelLabel.name = "levelLabel"
        levelLabel.zPosition = 101
        addChild(levelLabel)
        self.levelLabel = levelLabel
        
        // Points label on right side - split into two labels for separate animation
        let pointsLabelText = SKLabelNode(fontNamed: "Arial")
        pointsLabelText.text = "Points: "
        pointsLabelText.fontSize = 14
        pointsLabelText.fontColor = .black
        pointsLabelText.position = CGPoint(x: size.width / 2 + 50, y: statsRowY)
        pointsLabelText.name = "pointsLabelText"
        pointsLabelText.zPosition = 101
        addChild(pointsLabelText)
        self.pointsLabel = pointsLabelText
        
        // Points value label (animated separately)
        let pointsValueLabel = SKLabelNode(fontNamed: "Arial")
        pointsValueLabel.fontSize = 14
        pointsValueLabel.fontColor = .black
        pointsValueLabel.position = CGPoint(x: size.width / 2 + 110, y: statsRowY)
        pointsValueLabel.name = "pointsValueLabel"
        pointsValueLabel.zPosition = 101
        addChild(pointsValueLabel)
        self.pointsValueLabel = pointsValueLabel
        
        // Initialize points with actual game state value
        if let gameState = gameState {
            pointsValueLabel.text = "\(gameState.currentPoints)"
        } else {
            pointsValueLabel.text = "0"
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location)
    }
    
    private func handleTap(at point: CGPoint) {
        let topBarY: CGFloat = size.height - 50
        let tapDistance = abs(point.y - topBarY)
        
        // If tap is in top area
        if tapDistance < 40 {
            // Exit button
            if point.x < 70 {
                //print("🗺️ HUD: Exit button tapped!")
                gameViewController?.dismissGame()
                return
            }
            
            // Stats button
            if point.x > size.width - 70 {
                //print("🗺️ HUD: Stats button tapped!")
                gameViewController?.showStats()
                return
            }
            
            // Appearance button
            if point.x > size.width / 2 - 100 && point.x < size.width / 2 - 30 {
                //print("🗺️ HUD: Appearance button tapped!")
                gameViewController?.showAppearance()
                return
            }
            
            // Editor button
            if point.x > size.width / 2 + 30 && point.x < size.width / 2 + 100 {
                //print("🗺️ HUD: Editor button tapped!")
                gameViewController?.openStickFigureEditor()
                return
            }
        }
    }
    
    // MARK: - Update Methods
    
    func updateLevelPoints(level: Int, points: Int) {
        levelLabel?.text = "Level: \(level)"
        pointsValueLabel?.text = "\(points)"
    }
    
    func animatePointsValue(from startPoints: Int, to endPoints: Int) {
        guard let pointsValueLabel = pointsValueLabel else { return }
        
        let pointsToAdd = endPoints - startPoints
        let duration: TimeInterval = 0.8
        let updateInterval: TimeInterval = 0.01
        let updates = Int(duration / updateInterval)
        let pointsPerUpdate = Double(pointsToAdd) / Double(updates)
        
        var currentValue = Double(startPoints)
        
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            currentValue += pointsPerUpdate
            
            if currentValue >= Double(endPoints) {
                timer.invalidate()
                // Set final value - return to normal size
                pointsValueLabel.text = "\(endPoints)"
                pointsValueLabel.fontSize = 14
            } else {
                let displayValue = Int(currentValue)
                pointsValueLabel.text = "\(displayValue)"
                // Make only the value bold by increasing its size
                pointsValueLabel.fontSize = 16
            }
        }
    }
    
    @MainActor
    deinit {
        //print("🗺️ MapHUDScene deinit - cleaning up")
        removeAllChildren()
        removeAllActions()
    }
}
