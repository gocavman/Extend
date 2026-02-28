import SwiftUI
import UIKit

/// SwiftUI wrapper to present the SpriteKit game view controller
struct SpriteKitGameView: UIViewControllerRepresentable {
    var gameState: StickFigureGameState
    var mapState: GameMapState
    var onDismiss: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    func makeUIViewController(context: Context) -> GameViewController {
        let vc = GameViewController()
        vc.gameState = gameState
        vc.mapState = mapState
        vc.onDismissGame = context.coordinator.dismissGame
        return vc
    }
    
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
        // Update state if needed
        uiViewController.gameState = gameState
        uiViewController.mapState = mapState
    }
    
    class Coordinator {
        var onDismiss: (() -> Void)?
        
        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }
        
        func dismissGame() {
            print("🎮 Coordinator: dismissGame called")
            onDismiss?()
        }
    }
}
