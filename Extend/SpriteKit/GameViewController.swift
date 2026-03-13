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
        hasInitializedScene = true
        
        // Ensure the SKView actually has the scene
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //print("🎮 Verifying scene is displayed: \(self.skView?.scene != nil ? "YES" : "NO")")
        }
    }
    
    /// Show the map/level selection scene
    func showMapScene() {
        guard let skView = skView, let gameState = gameState, let mapState = mapState else { return }
        
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
