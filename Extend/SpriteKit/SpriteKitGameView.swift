import SwiftUI
import UIKit

/// SwiftUI wrapper to present the SpriteKit game view controller
struct SpriteKitGameView: UIViewControllerRepresentable {
    var gameState: StickFigureGameState
    var mapState: GameMapState
    
    func makeUIViewController(context: Context) -> GameViewController {
        let vc = GameViewController()
        vc.gameState = gameState
        vc.mapState = mapState
        return vc
    }
    
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
        // Update state if needed
        uiViewController.gameState = gameState
        uiViewController.mapState = mapState
    }
}
