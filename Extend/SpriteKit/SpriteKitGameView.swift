import SwiftUI
import UIKit

/// SwiftUI wrapper to present the SpriteKit game view controller
struct SpriteKitGameView: UIViewControllerRepresentable {
    var gameState: StickFigureGameState
    var onDismiss: (() -> Void)?
    var onShowEditor: (() -> Void)?  // Called when the EDIT button is tapped — lets SwiftUI own the presentation

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss, onShowEditor: onShowEditor)
    }

    func makeUIViewController(context: Context) -> GameViewController {
        let vc = GameViewController()
        vc.gameState = gameState
        vc.onDismissGame = context.coordinator.dismissGame
        vc.onShowEditor = context.coordinator.showEditor
        return vc
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
        uiViewController.gameState = gameState
        uiViewController.onShowEditor = context.coordinator.showEditor
    }

    class Coordinator {
        var onDismiss: (() -> Void)?
        var onShowEditor: (() -> Void)?

        init(onDismiss: (() -> Void)?, onShowEditor: (() -> Void)?) {
            self.onDismiss = onDismiss
            self.onShowEditor = onShowEditor
        }

        func dismissGame() {
            print("🎮 Coordinator: dismissGame called")
            onDismiss?()
        }

        func showEditor() {
            print("🎮 Coordinator: showEditor called")
            onShowEditor?()
        }
    }
}
