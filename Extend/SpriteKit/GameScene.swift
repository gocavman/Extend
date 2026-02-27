import SpriteKit
import GameplayKit
import SwiftUI

/// Base scene class for all game scenes with touch handling
class GameScene: SKScene {
    var gameState: StickFigureGameState?
    var mapState: GameMapState?
    var gameViewController: GameViewController?  // Add reference to view controller
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Set up scene
        backgroundColor = SKColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        scaleMode = .resizeFill
        
        // Enable touch handling
        isUserInteractionEnabled = true
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // Convert from view coordinates to scene coordinates
            let locationInView = touch.location(in: self.view!)
            let locationInScene = self.convert(locationInView, from: self.view!)
            handleTouchBegan(at: locationInScene)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let locationInView = touch.location(in: self.view!)
            let locationInScene = self.convert(locationInView, from: self.view!)
            handleTouchMoved(to: locationInScene)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let locationInView = touch.location(in: self.view!)
            let locationInScene = self.convert(locationInView, from: self.view!)
            handleTouchEnded(at: locationInScene)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let locationInView = touch.location(in: self.view!)
            let locationInScene = self.convert(locationInView, from: self.view!)
            handleTouchCancelled(at: locationInScene)
        }
    }
    
    // Override these in subclasses
    func handleTouchBegan(at point: CGPoint) {}
    func handleTouchMoved(to point: CGPoint) {}
    func handleTouchEnded(at point: CGPoint) {}
    func handleTouchCancelled(at point: CGPoint) {}
    
    // MARK: - Helper Methods
    
    /// Render a stick figure using the exact same logic as StickFigure2DView
    func renderStickFigure(_ figure: StickFigure2D, at position: CGPoint, scale: CGFloat = 1.0, flipped: Bool = false) -> SKNode {
        let container = SKNode()
        container.position = position
        container.xScale = flipped ? -1 : 1
        
        print("🎮 renderStickFigure: Drawing using StickFigure2D computed properties, scale: \(scale)")
        
        // Base canvas dimensions (matching StickFigure2D)
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        // Get all joint positions from the figure's computed properties
        let waistPos = figure.waistPosition
        let midTorsoPos = figure.midTorsoPosition
        let neckPos = figure.neckPosition
        let headPos = figure.headPosition
        let leftShoulderPos = figure.leftShoulderPosition
        let rightShoulderPos = figure.rightShoulderPosition
        let leftUpperArmEnd = figure.leftUpperArmEnd
        let rightUpperArmEnd = figure.rightUpperArmEnd
        let leftForearmEnd = figure.leftForearmEnd
        let rightForearmEnd = figure.rightForearmEnd
        let leftUpperLegEnd = figure.leftUpperLegEnd
        let rightUpperLegEnd = figure.rightUpperLegEnd
        let leftFootEnd = figure.leftFootEnd
        let rightFootEnd = figure.rightFootEnd
        
        print("🎮 Waist: \(waistPos), Neck: \(neckPos), Head: \(headPos)")
        print("🎮 Left arm: shoulder->elbow->forearm = \(leftShoulderPos) -> \(leftUpperArmEnd) -> \(leftForearmEnd)")
        
        // Helper to draw a line segment between two points
        func drawLine(from: CGPoint, to: CGPoint, color: SKColor, width: CGFloat = 2) {
            // Convert from base canvas coordinates to relative coordinates
            let fromRelative = CGPoint(x: from.x - baseCenter.x, y: baseCenter.y - from.y)
            let toRelative = CGPoint(x: to.x - baseCenter.x, y: baseCenter.y - to.y)
            
            let path = UIBezierPath()
            path.move(to: fromRelative)
            path.addLine(to: toRelative)
            let line = SKShapeNode(path: path.cgPath)
            line.strokeColor = color
            line.lineWidth = width * 1.5  // Reduced from 3.0 to 1.5 for slightly thinner lines
            line.zPosition = 1
            container.addChild(line)
        }
        
        // Helper to draw a circle at a position
        func drawCircle(at point: CGPoint, radius: CGFloat, color: SKColor) {
            let relativePos = CGPoint(x: point.x - baseCenter.x, y: baseCenter.y - point.y)
            let circle = SKShapeNode(circleOfRadius: radius)
            circle.fillColor = color
            circle.strokeColor = color
            circle.lineWidth = 0
            circle.position = relativePos
            circle.zPosition = 2
            container.addChild(circle)
        }
        
        // Draw lower body first (back)
        drawLine(from: waistPos, to: leftUpperLegEnd, color: SKColor(cgColor: figure.leftLegColor.cgColor!), width: figure.strokeThickness)
        drawLine(from: leftUpperLegEnd, to: leftFootEnd, color: SKColor(cgColor: figure.footColor.cgColor!), width: figure.strokeThickness)
        drawLine(from: waistPos, to: rightUpperLegEnd, color: SKColor(cgColor: figure.rightLegColor.cgColor!), width: figure.strokeThickness)
        drawLine(from: rightUpperLegEnd, to: rightFootEnd, color: SKColor(cgColor: figure.footColor.cgColor!), width: figure.strokeThickness)
        
        // Draw torso
        drawLine(from: waistPos, to: midTorsoPos, color: SKColor(cgColor: figure.torsoColor.cgColor!), width: figure.strokeThickness)
        drawLine(from: midTorsoPos, to: neckPos, color: SKColor(cgColor: figure.torsoColor.cgColor!), width: figure.strokeThickness)
        drawLine(from: neckPos, to: headPos, color: SKColor(cgColor: figure.torsoColor.cgColor!), width: figure.strokeThickness)
        
        // Draw arms
        drawLine(from: leftShoulderPos, to: leftUpperArmEnd, color: SKColor(cgColor: figure.leftArmColor.cgColor!), width: figure.strokeThickness)
        drawLine(from: leftUpperArmEnd, to: leftForearmEnd, color: SKColor(cgColor: figure.leftArmColor.cgColor!), width: figure.strokeThickness)
        
        drawLine(from: rightShoulderPos, to: rightUpperArmEnd, color: SKColor(cgColor: figure.rightArmColor.cgColor!), width: figure.strokeThickness)
        drawLine(from: rightUpperArmEnd, to: rightForearmEnd, color: SKColor(cgColor: figure.rightArmColor.cgColor!), width: figure.strokeThickness)
        
        // Draw head
        let headRadius = figure.headRadius * 1.2  // Reduced from 3.5 to 1.2 - much smaller
        print("🎮 Drawing head at \(headPos) with radius \(headRadius)")
        drawCircle(at: headPos, radius: headRadius, color: SKColor(cgColor: figure.headColor.cgColor!))
        
        print("🎮 Stick figure rendered with \(container.children.count) nodes!")
        return container
    }
    
    /// Calculate if a point is within a rectangular zone
    func isPoint(_ point: CGPoint, inZoneFrom start: CGPoint, width: CGFloat, height: CGFloat) -> Bool {
        return point.x >= start.x && point.x <= start.x + width &&
               point.y >= start.y && point.y <= start.y + height
    }
}
