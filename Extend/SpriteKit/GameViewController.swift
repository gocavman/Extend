import UIKit
import SpriteKit
import SwiftUI

/// UIViewController that hosts the SpriteKit game
class GameViewController: UIViewController {
    var skView: SKView?
    var gameState: StickFigureGameState?
    var mapState: GameMapState?
    var currentScene: GameScene?
    weak var gameplayScene: GameplayScene?
    var onDismissGame: (() -> Void)?  // Callback for SwiftUI dismissal
    private var hasInitializedScene = false  // Track if we've shown the initial scene
    private var hudContainer: UIStackView?  // HUD buttons container
    private var infoContainer: UIStackView?  // Info labels container (room name, level, points)
    private var roomNameLabel: UILabel?  // Room name display
    private var levelLabel: UILabel?  // Level display
    private var pointsTextLabel: UILabel?  // "Points: " text label
    private var pointsValueLabel: UILabel?  // Points value (number only)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create SKView
        let skView = SKView(frame: view.bounds)
        skView.ignoresSiblingOrder = true
        view.addSubview(skView)
        view.sendSubviewToBack(skView)
        self.skView = skView
        
        // Initialize states if not provided
        if gameState == nil {
            gameState = StickFigureGameState()
        }
        if mapState == nil {
            mapState = GameMapState()
        }
        
        // Show map on first load
        //print("🎮 GameViewController viewDidLoad - showing map for first time")
        showMapScene()
        setupHUD()  // Add HUD buttons to UIView
        hasInitializedScene = true
        
        // Ensure the SKView actually has the scene
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //print("🎮 Verifying scene is displayed: \(self.skView?.scene != nil ? "YES" : "NO")")
        }
    }
    
    private func setupHUD() {
        // Create HUD container at top of screen
        let hudStack = UIStackView()
        hudStack.axis = .horizontal
        hudStack.spacing = 10
        hudStack.distribution = .fillEqually
        hudStack.alignment = .center
        
        // Add to view below safe area
        view.addSubview(hudStack)
        hudStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Position below safe area with more padding so buttons are fully visible and clickable
        let topInset = view.safeAreaInsets.top + 60  // Increased from 10 to 60
        NSLayoutConstraint.activate([
            hudStack.topAnchor.constraint(equalTo: view.topAnchor, constant: topInset),
            hudStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            hudStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            hudStack.heightAnchor.constraint(equalToConstant: 60)
        ])

        // Create buttons
        let exitBtn = createHUDButton(title: "EXIT", color: UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.9), action: #selector(exitTapped))
        let appearanceBtn = createAppearanceButton()
        let editBtn = createHUDButton(title: "EDIT", color: UIColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 0.9), action: #selector(editTapped))
        let resetLevelBtn = createHUDButton(title: "LVL", color: UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 0.9), action: #selector(resetLevelTapped))
        let statsBtn = createHUDButton(title: "STATS", color: UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.9), action: #selector(statsTapped))
        
        hudStack.addArrangedSubview(exitBtn)
        hudStack.addArrangedSubview(appearanceBtn)
        hudStack.addArrangedSubview(editBtn)
        hudStack.addArrangedSubview(resetLevelBtn)
        hudStack.addArrangedSubview(statsBtn)
        
        self.hudContainer = hudStack
        
        // Create info labels container below buttons (no spacing)
        let infoStack = UIStackView()
        infoStack.axis = .horizontal
        infoStack.spacing = 20
        infoStack.distribution = .fillEqually
        infoStack.alignment = .center
        
        view.addSubview(infoStack)
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: hudStack.bottomAnchor, constant: 0),
            infoStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            infoStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            infoStack.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Create room name label
        let roomLabel = UILabel()
        roomLabel.textAlignment = .center
        roomLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        roomLabel.textColor = .black
        roomLabel.text = "Main Training Area"
        infoStack.addArrangedSubview(roomLabel)
        self.roomNameLabel = roomLabel
        
        // Create level label
        let levelLabel = UILabel()
        levelLabel.textAlignment = .center
        levelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        levelLabel.textColor = .black
        // Initialize with actual gameState level
        levelLabel.text = "Level: \(gameState?.currentLevel ?? 1)"
        infoStack.addArrangedSubview(levelLabel)
        self.levelLabel = levelLabel
        
        // Create points label stack - closer spacing between "Points:" and value
        let pointsStack = UIStackView()
        pointsStack.axis = .horizontal
        pointsStack.spacing = 2  // Very tight spacing
        pointsStack.distribution = .fillProportionally
        pointsStack.alignment = .center
        infoStack.addArrangedSubview(pointsStack)
        
        let pointsTextLabel = UILabel()
        pointsTextLabel.textAlignment = .right
        pointsTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        pointsTextLabel.textColor = .black
        pointsTextLabel.text = "Points:"
        pointsStack.addArrangedSubview(pointsTextLabel)
        self.pointsTextLabel = pointsTextLabel
        
        let pointsValueLabel = UILabel()
        pointsValueLabel.textAlignment = .left
        pointsValueLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        pointsValueLabel.textColor = .black
        // Initialize with actual gameState points, not hardcoded 0
        pointsValueLabel.text = "\(gameState?.currentPoints ?? 0)"
        pointsStack.addArrangedSubview(pointsValueLabel)
        self.pointsValueLabel = pointsValueLabel
        
        // Store reference to info container so we can hide it during gameplay
        self.infoContainer = infoStack
    }
    
    func setHUDVisible(_ visible: Bool) {
        hudContainer?.isHidden = !visible
        infoContainer?.isHidden = !visible
    }
    
    /// Update HUD labels with current room, level, and points
    func updateHUDInfo(roomName: String, level: Int, points: Int) {
        roomNameLabel?.text = "📍 \(roomName)"
        levelLabel?.text = "Level: \(level)"
        pointsValueLabel?.text = "\(points)"
    }
    
    /// Animate points counting from current to new total
    func animatePointsIncrease(from startPoints: Int, to endPoints: Int) {
        let pointsToAdd = endPoints - startPoints
        let duration: TimeInterval = 0.8
        let updateInterval: TimeInterval = 0.01
        let updates = Int(duration / updateInterval)
        let pointsPerUpdate = Double(pointsToAdd) / Double(updates)
        
        var currentValue = Double(startPoints)
        
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            currentValue += pointsPerUpdate
            
            if currentValue >= Double(endPoints) {
                timer.invalidate()
                // Set final value - return to normal size and weight
                self?.pointsValueLabel?.text = "\(endPoints)"
                self?.pointsValueLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            } else {
                let displayValue = Int(currentValue)
                self?.pointsValueLabel?.text = "\(displayValue)"
                // Make it larger and bold while incrementing
                self?.pointsValueLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            }
        }
    }
    
    private func createHUDButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    private func createAppearanceButton() -> UIButton {
        let button = UIButton(type: .system)
        
        // Create SF Symbol image
        if let image = UIImage(systemName: "figure.stand") {
            let resizedImage = image.withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .bold))
            button.setImage(resizedImage, for: .normal)
            button.tintColor = .black
        }
        
        button.backgroundColor = UIColor(red: 0.7, green: 0.4, blue: 0.8, alpha: 0.9)
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(appearanceTapped), for: .touchUpInside)
        return button
    }
    
    @objc private func exitTapped() {
        print("🎮 EXIT tapped from HUD")
        dismissGame()
    }
    
    @objc private func appearanceTapped() {
        print("🎮 APPEARANCE tapped from HUD")
        showAppearance()
    }
    
    @objc private func editTapped() {
        print("🎮 EDIT tapped from HUD")
        openStickFigureEditor()
    }
    
    @objc private func resetLevelTapped() {
        print("🎮 RESET LEVEL tapped from HUD (Developer Mode)")
        
        guard let gameState = gameState else { return }
        
        // Show alert with level selection
        let alert = UIAlertController(title: "Reset to Level", message: "Select which level to reset to:", preferredStyle: .alert)
        
        // Add options for levels 1-10 (or however many levels you have)
        for level in 1...10 {
            alert.addAction(UIAlertAction(title: "Level \(level)", style: .default) { [weak self] _ in
                gameState.currentLevel = level
                print("🎮 Developer: Reset to Level \(level)")
                // Refresh the map to show updated level colors
                self?.showMapScene()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func statsTapped() {
        print("🎮 STATS tapped from HUD")
        showStats()
    }
    
    /// Show the map/level selection scene
    func showMapScene() {
        guard let skView = skView, let gameState = gameState, let mapState = mapState else { return }
        
        // Show HUD on the map
        setHUDVisible(true)
        
        // Position character next to the level they just exited (not on top of it)
        if let levelConfig = LEVEL_CONFIGS.first(where: { $0.id == gameState.currentLevel }) {
            // Position character slightly below and to the left of the level station
            let offsetDistance: CGFloat = 120  // pixels away from station
            mapState.characterX = levelConfig.mapX - offsetDistance
            mapState.characterY = levelConfig.mapY - offsetDistance
        }
        
        // Update HUD with current room info
        let roomName = getRoomConfig("main_map")?.name ?? "Main Map"
        updateHUDInfo(roomName: roomName, level: gameState.currentLevel, points: gameState.currentPoints)
        
        // Remove previous scene if it exists
        if let currentScene = currentScene {
            currentScene.removeAllChildren()
            currentScene.removeAllActions()
            currentScene.removeFromParent()  // Remove from view
        }
        
        let scene = MapScene(size: skView.bounds.size)
        scene.gameState = gameState
        scene.mapState = mapState
        scene.gameViewController = self  // Pass reference to view controller
        scene.scaleMode = .resizeFill
        
        skView.presentScene(scene)  // Remove transition for now to avoid conflicts
        currentScene = scene
    }
    
    /// Show the gameplay scene
    func startGameplay() {
        guard let skView = skView, let gameState = gameState, let mapState = mapState else {
            print("❌ startGameplay: missing skView, gameState, or mapState")
            return
        }
        
        // Hide HUD during gameplay
        setHUDVisible(false)
        
        //print("🎮 startGameplay called - creating GameplayScene with size: \(skView.bounds.size)")
        
        // CRITICAL: Remove the old scene completely from the SKView
        if let oldScene = skView.scene {
            //print("🎮 SKView had existing scene: \(type(of: oldScene)) - removing it completely")
            oldScene.removeAllChildren()
            oldScene.removeAllActions()
            oldScene.removeFromParent()
        }
        
        // Also clean up our currentScene reference
        if let currentScene = currentScene {
            //print("🎮 Cleaning up currentScene reference")
            currentScene.removeAllChildren()
            currentScene.removeAllActions()
        }
        
        let scene = GameplayScene(size: skView.bounds.size)
        scene.gameState = gameState
        scene.mapState = mapState
        scene.gameViewController = self
        scene.scaleMode = .resizeFill
        scene.isUserInteractionEnabled = true
        
        //print("🎮 About to present GameplayScene to SKView")
        //print("🎮 SKView scene before presentScene: \(skView.scene != nil ? "HAS SCENE" : "NO SCENE")")
        
        // Present the scene directly without transition to avoid conflicts
        skView.presentScene(scene)
        
        //print("🎮 SKView scene after presentScene: \(skView.scene != nil ? "HAS SCENE" : "NO SCENE")")
        //print("🎮 Scene type: \(type(of: skView.scene))")
        currentScene = scene
        gameplayScene = scene  // Store reference for edit mode
        //print("🎮 GameplayScene is now active")
    }
    
    /// Dismiss the game and return to SwiftUI
    func dismissGame() {
        //print("🎮 dismissGame() called")
        // Save state
        gameState?.saveStats()
        gameState?.saveMapPosition(mapState ?? GameMapState())
        
        // Call the callback to notify SwiftUI
        DispatchQueue.main.async {
            //print("🎮 Calling onDismissGame callback")
            self.onDismissGame?()
        }
    }
    
    /// Show the stick figure gameplay editor (new UIKit version)
    func openStickFigureEditor() {
        //print("🎮 Opening Stick Figure Gameplay Editor (UIKit)")
        
        let editor = StickFigureGameplayEditorViewController()
        editor.gameState = gameState
        editor.modalPresentationStyle = .fullScreen
        
        present(editor, animated: true)
    }
    
    func showStats() {
        //print("🎮 Opening Stats Window")
        
        guard let gameState = gameState else { return }
        
        // Create and present the stats view controller
        let statsVC = StatsViewController()
        statsVC.gameState = gameState
        
        // Configure sheet presentation to slide up from bottom
        statsVC.modalPresentationStyle = .pageSheet
        
        if let sheet = statsVC.sheetPresentationController {
            // Allow both large and medium detents, default to large
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }
        
        present(statsVC, animated: true)
    }
    
    /// Format time in seconds to readable format
    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
    
    /// Show the appearance customization view
    func showAppearance() {
        //print("🎮 Opening Appearance Customization")
        
        // IMPORTANT: Always use the main gameState, not just from gameplay scene
        // This ensures muscle points changes work from both map and gameplay
        var gameState: StickFigureGameState? = self.gameState
        if gameState == nil && currentScene is GameplayScene {
            if let gameplayScene = currentScene as? GameplayScene {
                gameState = gameplayScene.gameState
            }
        }
        
        // If still no gameState, create one (shouldn't normally happen)
        if gameState == nil {
            gameState = StickFigureGameState()
            self.gameState = gameState
        }
        
        // Present the appearance view controller with callbacks to refresh the game
        let appearance = StickFigureAppearanceViewController()
        appearance.gameState = gameState
        appearance.onDismiss = { [weak self] in
            //print("🎮 Appearance customization closed - refreshing gameplay character")
            // Notify the current scene to refresh its character rendering
            if let gameplayScene = self?.currentScene as? GameplayScene {
                gameplayScene.refreshCharacterAppearance()
            }
        }
        appearance.onMusclePointsChanged = { [weak self] in
            //print("🎮 Muscle points changed - refreshing gameplay character in real-time")
            // Refresh the character in real-time when muscle points change
            if let gameplayScene = self?.currentScene as? GameplayScene {
                gameplayScene.refreshCharacterAppearance()
            }
        }
        
        appearance.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        
        // Set preferred height for the sheet (approximately 80% of screen)
        if let sheet = appearance.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.preferredCornerRadius = 12
        }
        
        present(appearance, animated: true)
    }

    
    deinit {
        //print("🎮 GameViewController deinit - cleaning up")
        // Clean up current scene
        currentScene?.removeAllChildren()
        currentScene?.removeAllActions()
    }
}
