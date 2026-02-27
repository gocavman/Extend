import UIKit
import SwiftUI

/// Direct UIKit touch handling for reliable game controls
class GameplayTouchView: UIView {
    var gameState: StickFigureGameState?
    var geometry: GeometryProxy?
    
    // Zone boundaries (relative to this view)
    private let leftZoneWidth: CGFloat = 70
    private let centerZoneWidth: CGFloat = 10
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.isMultipleTouchEnabled = true
        self.isUserInteractionEnabled = true
        self.backgroundColor = .clear
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        handleTouchAt(location: location, isPress: true)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        handleTouchAt(location: location, isPress: true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        handleTouchAt(location: location, isPress: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        // Treat cancellation as release for all zones
        guard let gameState = gameState else { return }
        gameState.isMovingLeft = false
        gameState.isMovingRight = false
        if gameState.currentAction == "move" {
            let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
            gameState.recordActionTime(action: "move", duration: duration)
            gameState.currentAction = ""
        }
        gameState.stopAnimation(gameState: gameState)
    }
    
    private func handleTouchAt(location: CGPoint, isPress: Bool) {
        guard let gameState = gameState else { return }
        
        // Determine which zone was touched
        if location.x < leftZoneWidth {
            // LEFT ZONE
            if isPress {
                if gameState.currentLevel >= 2 {
                    gameState.resetIdleTimer()
                    if gameState.currentAction != "move" {
                        gameState.currentAction = "move"
                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                    }
                    gameState.isMovingLeft = true
                    gameState.isMovingRight = false
                    gameState.facingRight = false
                    if gameState.animationFrame == 0 {
                        gameState.startAnimation(gameState: gameState)
                    }
                }
            } else {
                // Release from left zone
                gameState.isMovingLeft = false
                if !gameState.isMovingRight {
                    if gameState.currentAction == "move" {
                        let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                        gameState.recordActionTime(action: "move", duration: duration)
                        gameState.currentAction = ""
                    }
                    gameState.stopAnimation(gameState: gameState)
                }
            }
        } else if location.x < leftZoneWidth + centerZoneWidth {
            // CENTER ZONE (Action button)
            if !isPress && gameState.isMovingLeft == false && gameState.isMovingRight == false {
                if gameState.selectedAction == "Jump" {
                    if let config = ACTION_CONFIGS.first(where: { $0.id == "jump" }) {
                        gameState.startAction(config, gameState: gameState)
                    }
                } else if let config = ACTION_CONFIGS.first(where: { $0.displayName == gameState.selectedAction }) {
                    if gameState.currentPerformingAction == nil {
                        gameState.startAction(config, gameState: gameState)
                    }
                }
            }
        } else {
            // RIGHT ZONE
            if isPress {
                if gameState.currentLevel >= 2 {
                    gameState.resetIdleTimer()
                    if gameState.currentAction != "move" {
                        gameState.currentAction = "move"
                        gameState.actionStartTime = Date().timeIntervalSince1970 * 1000
                    }
                    gameState.isMovingRight = true
                    gameState.isMovingLeft = false
                    gameState.facingRight = true
                    if gameState.animationFrame == 0 {
                        gameState.startAnimation(gameState: gameState)
                    }
                }
            } else {
                // Release from right zone
                gameState.isMovingRight = false
                if !gameState.isMovingLeft {
                    if gameState.currentAction == "move" {
                        let duration = Date().timeIntervalSince1970 * 1000 - gameState.actionStartTime
                        gameState.recordActionTime(action: "move", duration: duration)
                        gameState.currentAction = ""
                    }
                    gameState.stopAnimation(gameState: gameState)
                }
            }
        }
    }
}

/// SwiftUI wrapper for the UIKit touch view
struct GameplayTouchViewWrapper: UIViewRepresentable {
    let gameState: StickFigureGameState
    let geometry: GeometryProxy
    
    func makeUIView(context: Context) -> GameplayTouchView {
        let view = GameplayTouchView()
        view.gameState = gameState
        view.geometry = geometry
        return view
    }
    
    func updateUIView(_ uiView: GameplayTouchView, context: Context) {
        // Update reference in case it changed
        uiView.gameState = gameState
        uiView.geometry = geometry
    }
}
