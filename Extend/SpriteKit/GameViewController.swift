import UIKit
import SpriteKit
import SwiftUI

/// UIViewController that hosts the SpriteKit game
class GameViewController: UIViewController {
    var skView: SKView?
    var gameState: StickFigureGameState?
    var mapState: GameMapState?
    var currentScene: GameScene?
    
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
        
        // Show map first
        showMapScene()
    }
    
    /// Show the map/level selection scene
    func showMapScene() {
        guard let skView = skView, let gameState = gameState, let mapState = mapState else { return }
        
        let scene = MapScene(size: skView.bounds.size)
        scene.gameState = gameState
        scene.mapState = mapState
        scene.gameViewController = self  // Pass reference to view controller
        scene.scaleMode = .resizeFill
        
        skView.presentScene(scene, transition: SKTransition.fade(withDuration: 0.3))
        currentScene = scene
    }
    
    /// Show the gameplay scene
    func startGameplay() {
        guard let skView = skView, let gameState = gameState, let mapState = mapState else {
            print("❌ startGameplay: missing skView, gameState, or mapState")
            return
        }
        
        print("🎮 startGameplay called - creating GameplayScene with size: \(skView.bounds.size)")
        
        let scene = GameplayScene(size: skView.bounds.size)
        scene.gameState = gameState
        scene.mapState = mapState
        scene.gameViewController = self  // Pass reference to view controller
        scene.scaleMode = .resizeFill
        scene.isUserInteractionEnabled = true
        
        print("🎮 Presenting GameplayScene")
        skView.presentScene(scene, transition: SKTransition.fade(withDuration: 0.3))
        currentScene = scene
        
        print("🎮 GameplayScene is now active")
    }
    
    /// Dismiss the game and return to SwiftUI
    func dismissGame() {
        print("🎮 dismissGame() called")
        // Save state
        gameState?.saveStats()
        gameState?.saveMapPosition(mapState ?? GameMapState())
        
        // Dismiss view controller on main thread
        DispatchQueue.main.async {
            print("🎮 Dismissing GameViewController")
            self.dismiss(animated: true)
        }
    }
    
    /// Show the 2D stick figure editor
    func openStickFigureEditor() {
        print("🎮 Opening 2D Stick Figure Editor")
        
        // Present the editor view controller with a dismiss callback
        let editor = UIHostingController(rootView: StickFigure2DEditorView(onDismiss: { [weak self] in
            print("🎮 Editor closed - dismissing modal")
            self?.dismiss(animated: true)
        }))
        editor.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        
        present(editor, animated: true)
    }
    
    /// Show the stats overlay
    func showStats() {
        print("🎮 Opening Stats Window")
        
        guard let gameState = gameState else { return }
        
        // Create alert controller
        let alertController = UIAlertController(title: "📊 Statistics", message: nil, preferredStyle: .alert)
        
        // Build stats message
        var statsMessage = ""
        statsMessage += "━━━━━━━━━━━━━━━━━━━━━━━\n"
        statsMessage += "⭐ LEVEL & PROGRESS\n"
        statsMessage += "━━━━━━━━━━━━━━━━━━━━━━━\n"
        statsMessage += "Current Level: \(gameState.currentLevel)\n"
        statsMessage += "Current Points: \(gameState.currentPoints)\n"
        statsMessage += "High Score: \(gameState.highScore)\n\n"
        
        statsMessage += "━━━━━━━━━━━━━━━━━━━━━━━\n"
        statsMessage += "⏱️  TIME\n"
        statsMessage += "━━━━━━━━━━━━━━━━━━━━━━━\n"
        statsMessage += "Session Time: \(formatTime(gameState.timeElapsed))\n"
        statsMessage += "All Time: \(formatTime(gameState.allTimeElapsed))\n\n"
        
        statsMessage += "━━━━━━━━━━━━━━━━━━━━━━━\n"
        statsMessage += "📈 PERFORMANCE\n"
        statsMessage += "━━━━━━━━━━━━━━━━━━━━━━━\n"
        
        // Show action times if any
        if !gameState.actionTimes.isEmpty {
            statsMessage += "Actions Performed:\n"
            for (action, time) in gameState.actionTimes.sorted(by: { $0.key < $1.key }) {
                statsMessage += "  • \(action.capitalized): \(formatTime(time))\n"
            }
        } else {
            statsMessage += "No actions performed yet\n"
        }
        
        statsMessage += "\n━━━━━━━━━━━━━━━━━━━━━━━\n"
        statsMessage += "🎮 COLLECTIBLES\n"
        statsMessage += "━━━━━━━━━━━━━━━━━━━━━━━\n"
        statsMessage += "Total Coins: \(gameState.totalCoinsCollected)\n"
        
        if !gameState.catchablesCaught.isEmpty {
            statsMessage += "Catchables:\n"
            for (item, count) in gameState.catchablesCaught.sorted(by: { $0.key < $1.key }) {
                statsMessage += "  • \(item.capitalized): \(count)\n"
            }
        }
        
        statsMessage += "\n━━━━━━━━━━━━━━━━━━━━━━━"
        
        alertController.message = statsMessage
        
        let cancelAction = UIAlertAction(title: "Close", style: .default) { _ in
            print("🎮 Stats window closed")
        }
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
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
}
