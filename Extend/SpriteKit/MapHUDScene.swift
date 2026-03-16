import SpriteKit

/// Separate HUD scene overlay for map controls (Exit, Stats, Appearance, Editor)
/// This scene stays fixed on screen and doesn't move with the camera
class MapHUDScene: SKScene {
    weak var gameViewController: GameViewController?
    
    // Button nodes for hit detection
    private var exitButton: SKShapeNode?
    private var statsButton: SKShapeNode?
    private var appearanceButton: SKLabelNode?
    private var editorButton: SKShapeNode?
    
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
    
    @MainActor
    deinit {
        //print("🗺️ MapHUDScene deinit - cleaning up")
        removeAllChildren()
        removeAllActions()
    }
}
