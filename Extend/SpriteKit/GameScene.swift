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
        guard let view = self.view else {
            print("⚠️ TouchesBegan: view is nil")
            return
        }
        for touch in touches {
            let locationInView = touch.location(in: view)
            let locationInScene = self.convert(locationInView, from: view)
            handleTouchBegan(at: locationInScene)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view else {
            print("⚠️ TouchesMoved: view is nil")
            return
        }
        for touch in touches {
            let locationInView = touch.location(in: view)
            let locationInScene = self.convert(locationInView, from: view)
            handleTouchMoved(to: locationInScene)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view else {
            print("⚠️ TouchesEnded: view is nil")
            return
        }
        for touch in touches {
            let locationInView = touch.location(in: view)
            let locationInScene = self.convert(locationInView, from: view)
            handleTouchEnded(at: locationInScene)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view else {
            print("⚠️ TouchesCancelled: view is nil")
            return
        }
        for touch in touches {
            let locationInView = touch.location(in: view)
            let locationInScene = self.convert(locationInView, from: view)
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
        
        // Helper to draw a tapered segment (respects fusiform values)
        func drawTaperedSegment(from: CGPoint, to: CGPoint, color: SKColor, strokeThickness: CGFloat, fusiform: CGFloat, inverted: Bool) {
            // Convert to relative coordinates and apply scale
            let fromRelative = CGPoint(x: (from.x - baseCenter.x) * scale, y: (baseCenter.y - from.y) * scale)
            let toRelative = CGPoint(x: (to.x - baseCenter.x) * scale, y: (baseCenter.y - to.y) * scale)
            
            if fusiform <= 0 {
                // No taper, just draw a line
                let path = UIBezierPath()
                path.move(to: fromRelative)
                path.addLine(to: toRelative)
                let line = SKShapeNode(path: path.cgPath)
                line.strokeColor = color
                line.lineWidth = max(strokeThickness * scale, 1.0)
                line.zPosition = 1
                container.addChild(line)
            } else {
                // Draw tapered segment
                let dx = toRelative.x - fromRelative.x
                let dy = toRelative.y - fromRelative.y
                let length = sqrt(dx * dx + dy * dy)
                
                if length <= 0 {
                    return
                }
                
                let perpX = -dy / length
                let perpY = dx / length
                
                // Calculate width at start and end
                // Use a more conservative multiplier - torsos were getting too large
                // NOTE: Do NOT scale baseWidth by scale - it's a visual thickness, not a position
                let baseWidth = strokeThickness * 1.5
                
                // Simple taper: always wider at start, narrower at end
                // fusiform controls how much narrower the end gets
                // Use a more aggressive taper factor so the reduction is more visible
                let taperFactor = 1.0 - (fusiform * 0.18)  // Increased from 0.12 for better taper
                let endWidth = baseWidth * max(0.15, taperFactor)  // Keep at least 15% width at narrow end
                let startWidth = baseWidth
                
                // Create tapered path with curved sides
                let path = UIBezierPath()
                
                // Calculate key points to break up complex expressions
                let startLeftX = fromRelative.x + perpX * startWidth / 2
                let startLeftY = fromRelative.y + perpY * startWidth / 2
                let startRightX = fromRelative.x - perpX * startWidth / 2
                let startRightY = fromRelative.y - perpY * startWidth / 2
                let endLeftX = toRelative.x + perpX * endWidth / 2
                let endLeftY = toRelative.y + perpY * endWidth / 2
                let endRightX = toRelative.x - perpX * endWidth / 2
                let endRightY = toRelative.y - perpY * endWidth / 2
                let midX = fromRelative.x + (toRelative.x - fromRelative.x) * 0.5
                let midY = fromRelative.y + (toRelative.y - fromRelative.y) * 0.5
                
                // Start point left side
                path.move(to: CGPoint(x: startLeftX, y: startLeftY))
                // Top side to end (use curve for smooth taper)
                path.addQuadCurve(to: CGPoint(x: endLeftX, y: endLeftY),
                                 controlPoint: CGPoint(x: midX + perpX * startWidth / 2, y: midY + perpY * startWidth / 2))
                // End point right side
                path.addLine(to: CGPoint(x: endRightX, y: endRightY))
                // Bottom side back to start (use curve for smooth taper)
                path.addQuadCurve(to: CGPoint(x: startRightX, y: startRightY),
                                 controlPoint: CGPoint(x: midX - perpX * startWidth / 2, y: midY - perpY * startWidth / 2))
                
                path.close()
                
                let shape = SKShapeNode(path: path.cgPath)
                shape.fillColor = color
                shape.strokeColor = color
                shape.lineWidth = 0
                shape.zPosition = 1
                container.addChild(shape)
            }
        }
        
        // Helper to draw a line segment between two points
        func drawLine(from: CGPoint, to: CGPoint, color: SKColor, width: CGFloat = 2) {
            // Convert from base canvas coordinates to relative coordinates and apply scale
            let fromRelative = CGPoint(x: (from.x - baseCenter.x) * scale, y: (baseCenter.y - from.y) * scale)
            let toRelative = CGPoint(x: (to.x - baseCenter.x) * scale, y: (baseCenter.y - to.y) * scale)
            
            let path = UIBezierPath()
            path.move(to: fromRelative)
            path.addLine(to: toRelative)
            let line = SKShapeNode(path: path.cgPath)
            line.strokeColor = color
            line.lineWidth = max(width * scale, 1.0)
            line.zPosition = 1
            container.addChild(line)
        }
        
        // Helper to draw a circle at a position
        func drawCircle(at point: CGPoint, radius: CGFloat, color: SKColor) {
            let relativePos = CGPoint(x: (point.x - baseCenter.x) * scale, y: (baseCenter.y - point.y) * scale)
            let circle = SKShapeNode(circleOfRadius: radius * scale)
            circle.fillColor = color
            circle.strokeColor = color
            circle.lineWidth = 0
            circle.position = relativePos
            circle.zPosition = 2
            container.addChild(circle)
        }
        
        // Draw lower body first (back) - with fusiform
        drawTaperedSegment(from: waistPos, to: leftUpperLegEnd, color: SKColor(cgColor: figure.leftUpperLegColor.cgColor!), strokeThickness: figure.strokeThicknessUpperLegs, fusiform: figure.fusiformUpperLegs, inverted: true)
        drawTaperedSegment(from: leftUpperLegEnd, to: leftFootEnd, color: SKColor(cgColor: figure.leftLowerLegColor.cgColor!), strokeThickness: figure.strokeThicknessLowerLegs, fusiform: figure.fusiformLowerLegs, inverted: true)
        drawTaperedSegment(from: waistPos, to: rightUpperLegEnd, color: SKColor(cgColor: figure.rightUpperLegColor.cgColor!), strokeThickness: figure.strokeThicknessUpperLegs, fusiform: figure.fusiformUpperLegs, inverted: true)
        drawTaperedSegment(from: rightUpperLegEnd, to: rightFootEnd, color: SKColor(cgColor: figure.rightLowerLegColor.cgColor!), strokeThickness: figure.strokeThicknessLowerLegs, fusiform: figure.fusiformLowerLegs, inverted: true)
        
        // Draw torso - with fusiform
        drawTaperedSegment(from: waistPos, to: midTorsoPos, color: SKColor(cgColor: figure.torsoColor.cgColor!), strokeThickness: figure.strokeThicknessLowerTorso, fusiform: figure.fusiformLowerTorso, inverted: true)
        drawTaperedSegment(from: midTorsoPos, to: neckPos, color: SKColor(cgColor: figure.torsoColor.cgColor!), strokeThickness: figure.strokeThicknessUpperTorso, fusiform: figure.fusiformUpperTorso, inverted: true)
        drawLine(from: neckPos, to: headPos, color: SKColor(cgColor: figure.torsoColor.cgColor!), width: figure.strokeThickness)
        
        // Draw arms - with fusiform
        drawTaperedSegment(from: leftShoulderPos, to: leftUpperArmEnd, color: SKColor(cgColor: figure.leftUpperArmColor.cgColor!), strokeThickness: figure.strokeThicknessUpperArms, fusiform: figure.fusiformUpperArms, inverted: true)
        drawTaperedSegment(from: leftUpperArmEnd, to: leftForearmEnd, color: SKColor(cgColor: figure.leftLowerArmColor.cgColor!), strokeThickness: figure.strokeThicknessLowerArms, fusiform: figure.fusiformLowerArms, inverted: true)
        
        drawTaperedSegment(from: rightShoulderPos, to: rightUpperArmEnd, color: SKColor(cgColor: figure.rightUpperArmColor.cgColor!), strokeThickness: figure.strokeThicknessUpperArms, fusiform: figure.fusiformUpperArms, inverted: true)
        drawTaperedSegment(from: rightUpperArmEnd, to: rightForearmEnd, color: SKColor(cgColor: figure.rightLowerArmColor.cgColor!), strokeThickness: figure.strokeThicknessLowerArms, fusiform: figure.fusiformLowerArms, inverted: true)
        
        // Draw hands and feet
        let handColor = SKColor(cgColor: figure.handColor.cgColor!)
        let footColor = SKColor(cgColor: figure.footColor.cgColor!)
        
        // Simple hand/foot representation as small circles at the end points
        // Don't scale the radius - these are visual indicators, not positional
        drawCircle(at: leftForearmEnd, radius: max(1.0, figure.strokeThicknessLowerArms * 0.5), color: handColor)
        drawCircle(at: rightForearmEnd, radius: max(1.0, figure.strokeThicknessLowerArms * 0.5), color: handColor)
        drawCircle(at: leftFootEnd, radius: max(1.0, figure.strokeThicknessLowerLegs * 0.5), color: footColor)
        drawCircle(at: rightFootEnd, radius: max(1.0, figure.strokeThicknessLowerLegs * 0.5), color: footColor)
        
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
