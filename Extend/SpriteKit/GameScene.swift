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
        var mutableFigure = figure
        
        let container = SKNode()
        container.position = position
        container.xScale = flipped ? -1 : 1
        
        // Apply custom appearance colors from UserDefaults
        StickFigureAppearance.shared.applyToStickFigure(&mutableFigure)
        print("🎨 Applied appearance colors - torso: \(mutableFigure.torsoColor), leftUpperArm: \(mutableFigure.leftUpperArmColor), leftLowerArm: \(mutableFigure.leftLowerArmColor)")
        
        // Apply muscle development points to fusiforms
        let musclePoints = MusclePointsManager.shared
        
        // Calculate average muscle development for all muscle groups
        let avgMusclePoints = musclePoints.musclePoints.values.isEmpty ? 0 :
            musclePoints.musclePoints.values.reduce(0, +) / CGFloat(musclePoints.musclePoints.count)
        
        // Apply muscle development to fusiforms (0.0 at 0% development, current values at 100%)
        let developmentFactor = avgMusclePoints / 100.0  // Normalize to 0.0-1.0
        
        mutableFigure.fusiformUpperArms *= developmentFactor
        mutableFigure.fusiformLowerArms *= developmentFactor
        mutableFigure.fusiformUpperLegs *= developmentFactor
        mutableFigure.fusiformLowerLegs *= developmentFactor
        mutableFigure.fusiformUpperTorso *= developmentFactor
        mutableFigure.fusiformLowerTorso *= developmentFactor
        
        print("🎮 renderStickFigure: Drawing using StickFigure2D computed properties, scale: \(scale), developmentFactor: \(developmentFactor)")
        
        // Base canvas dimensions (matching StickFigure2D)
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        // Get all joint positions from the figure's computed properties
        let waistPos = mutableFigure.waistPosition
        let neckPos = mutableFigure.neckPosition
        let headPos = mutableFigure.headPosition
        let leftShoulderPos = mutableFigure.leftShoulderPosition
        let rightShoulderPos = mutableFigure.rightShoulderPosition
        let leftUpperArmEnd = mutableFigure.leftUpperArmEnd
        let rightUpperArmEnd = mutableFigure.rightUpperArmEnd
        let leftForearmEnd = mutableFigure.leftForearmEnd
        let rightForearmEnd = mutableFigure.rightForearmEnd
        let leftUpperLegEnd = mutableFigure.leftUpperLegEnd
        let rightUpperLegEnd = mutableFigure.rightUpperLegEnd
        let leftFootEnd = mutableFigure.leftFootEnd
        let rightFootEnd = mutableFigure.rightFootEnd
        
        print("🎮 Waist: \(waistPos), Neck: \(neckPos), Head: \(headPos)")
        print("🎮 Left arm: shoulder->elbow->forearm = \(leftShoulderPos) -> \(leftUpperArmEnd) -> \(leftForearmEnd)")
        
        // Helper to convert SwiftUI Color to SKColor properly - MUST BE DEFINED FIRST
        func toSKColor(_ color: Color) -> SKColor {
            return UIColor(color)
        }
        
        // Helper to draw a tapered segment (respects fusiform values) - matches StickFigure2D editor exactly
        func drawTaperedSegment(from: CGPoint, to: CGPoint, color: SKColor, strokeThickness: CGFloat, fusiform: CGFloat, inverted: Bool, peakPosition: CGFloat = 0.2) {
            // Convert to relative coordinates and apply scale
            let fromRelative = CGPoint(x: (from.x - baseCenter.x) * scale, y: (baseCenter.y - from.y) * scale)
            let toRelative = CGPoint(x: (to.x - baseCenter.x) * scale, y: (baseCenter.y - to.y) * scale)
            
            // If fusiform is 0, just draw a simple line with minimal/consistent stroke thickness
            if fusiform == 0 {
                let path = UIBezierPath()
                path.move(to: fromRelative)
                path.addLine(to: toRelative)
                let line = SKShapeNode(path: path.cgPath)
                line.strokeColor = color
                // Use a minimal, consistent thickness at 0% development (all segments same size)
                line.lineWidth = max(2.0 * scale, 1.0)
                line.zPosition = 1
                container.addChild(line)
                return
            }
            
            // Calculate the direction and length of the segment
            let dx = toRelative.x - fromRelative.x
            let dy = toRelative.y - fromRelative.y
            let length = sqrt(dx * dx + dy * dy)
            
            guard length > 0 else { return }
            
            // Normalized direction
            let dirX = dx / length
            let dirY = dy / length
            
            // Perpendicular direction (for width)
            let perpX = -dirY
            let perpY = dirX
            
            // Create a tapered polygon with smooth width variation
            var topEdgePoints: [CGPoint] = []
            var bottomEdgePoints: [CGPoint] = []
            
            // Generate points along the length with varying width - use MORE segments for smooth curves at larger scales
            let numSegments = 50  // Increased from 20 to 50 for smoother curves at larger scales
            
            for i in 0...numSegments {
                let t = CGFloat(i) / CGFloat(numSegments)
                let pos = CGPoint(x: fromRelative.x + dirX * t * length, y: fromRelative.y + dirY * t * length)
                
                // Calculate width at this point based on taper profile
                var widthFactor: CGFloat = 1.0
                
                if inverted {
                    // DIAMOND: Point at START and END, wide in MIDDLE
                    let peakT = peakPosition
                    var distFromPeak: CGFloat
                    
                    if t <= peakT {
                        // Top half: from start to peak
                        distFromPeak = (peakT - t) / peakT  // Normalized: 1 at start, 0 at peak
                    } else {
                        // Bottom half: from peak to end
                        distFromPeak = (t - peakT) / (1.0 - peakT)  // Normalized: 0 at peak, 1 at end
                    }
                    
                    // Use inverted quadratic easing to create smooth diamond shape
                    let easeT = max(0, 1.0 - (distFromPeak * distFromPeak))
                    widthFactor = fusiform * easeT
                } else {
                    // NORMAL: Middle BULGE profile, small at both ends
                    let distFromCenter = abs(t - 0.5) * 2.0  // 0 at middle, 1 at ends
                    widthFactor = 1.0 + (fusiform * (1.0 - distFromCenter))
                }
                
                let width = (strokeThickness / 2) * widthFactor
                
                // Top and bottom edges
                let topPoint = CGPoint(x: pos.x + perpX * width, y: pos.y + perpY * width)
                let bottomPoint = CGPoint(x: pos.x - perpX * width, y: pos.y - perpY * width)
                
                topEdgePoints.append(topPoint)
                bottomEdgePoints.append(bottomPoint)
            }
            
            // Create the path by drawing the top edge, then the bottom edge backwards
            let path = UIBezierPath()
            
            if let firstPoint = topEdgePoints.first {
                path.move(to: firstPoint)
            }
            
            // Draw top edge
            for i in 1..<topEdgePoints.count {
                path.addLine(to: topEdgePoints[i])
            }
            
            // Draw bottom edge in reverse
            for i in stride(from: bottomEdgePoints.count - 1, through: 0, by: -1) {
                path.addLine(to: bottomEdgePoints[i])
            }
            
            path.close()
            
            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = color
            shape.strokeColor = color
            shape.lineWidth = 0
            shape.zPosition = 1
            container.addChild(shape)
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
        
        // Helper to draw hands/feet with proper tapering at top
        func drawHandOrFoot(at position: CGPoint, from startPoint: CGPoint, color: SKColor, isHand: Bool = false) {
            // Calculate direction from start to end (the limb direction)
            let dx = position.x - startPoint.x
            let dy = position.y - startPoint.y
            let length = sqrt(dx * dx + dy * dy)
            
            // Position the hand/foot slightly before the endpoint to create overlap
            let overlapAmount = 0.05  // 5% back from the endpoint
            let offsetX = (length > 0) ? (dx / length) * length * overlapAmount : 0
            let offsetY = (length > 0) ? (dy / length) * length * overlapAmount : 0
            
            let overlappedPos = CGPoint(x: position.x - offsetX, y: position.y - offsetY)
            let relativePos = CGPoint(x: (overlappedPos.x - baseCenter.x) * scale, y: (baseCenter.y - overlappedPos.y) * scale)
            
            // Create a tapered shape that's narrower at top and wider at bottom
            let radius = max(5.0, 1.0 * scale)
            let path = UIBezierPath()
            
            // Top (narrow) - where it connects to forearm/ankle
            let topLeft = CGPoint(x: -radius * 0.4, y: radius * 0.8)
            let topRight = CGPoint(x: radius * 0.4, y: radius * 0.8)
            
            // Bottom (wide) - the foot/hand base
            // For hands, make the bottom narrower (multiply by 0.6)
            // For feet, keep it wider (multiply by 1.0)
            let bottomWidthMultiplier: CGFloat = isHand ? 0.6 : 1.0
            let bottomLeft = CGPoint(x: -radius * bottomWidthMultiplier, y: -radius * 0.6)
            let bottomRight = CGPoint(x: radius * bottomWidthMultiplier, y: -radius * 0.6)
            
            // Draw tapered shape: start at top left, curve around bottom, back to top right
            path.move(to: topLeft)
            
            // Left side - curve from top to bottom
            path.addCurve(to: bottomLeft,
                         controlPoint1: CGPoint(x: topLeft.x - radius * 0.3, y: topLeft.y - radius * 0.3),
                         controlPoint2: CGPoint(x: bottomLeft.x - radius * 0.2, y: bottomLeft.y + radius * 0.2))
            
            // Bottom - slight curve
            path.addCurve(to: bottomRight,
                         controlPoint1: CGPoint(x: bottomLeft.x + radius * 0.5, y: bottomLeft.y - radius * 0.15),
                         controlPoint2: CGPoint(x: bottomRight.x - radius * 0.5, y: bottomRight.y - radius * 0.15))
            
            // Right side - curve from bottom to top
            path.addCurve(to: topRight,
                         controlPoint1: CGPoint(x: bottomRight.x + radius * 0.2, y: bottomRight.y + radius * 0.2),
                         controlPoint2: CGPoint(x: topRight.x + radius * 0.3, y: topRight.y - radius * 0.3))
            
            // Close the path
            path.close()
            
            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = color
            shape.strokeColor = color
            shape.lineWidth = 0
            shape.position = relativePos
            shape.zPosition = 2
            container.addChild(shape)
        }
        
        // Draw lower body first (back) - with fusiform
        drawTaperedSegment(from: waistPos, to: leftUpperLegEnd, color: toSKColor(mutableFigure.leftUpperLegColor), strokeThickness: mutableFigure.strokeThicknessUpperLegs, fusiform: mutableFigure.fusiformUpperLegs, inverted: true, peakPosition: 0.2)
        drawTaperedSegment(from: leftUpperLegEnd, to: leftFootEnd, color: toSKColor(mutableFigure.leftLowerLegColor), strokeThickness: mutableFigure.strokeThicknessLowerLegs, fusiform: mutableFigure.fusiformLowerLegs, inverted: true, peakPosition: 0.2)
        drawTaperedSegment(from: waistPos, to: rightUpperLegEnd, color: toSKColor(mutableFigure.rightUpperLegColor), strokeThickness: mutableFigure.strokeThicknessUpperLegs, fusiform: mutableFigure.fusiformUpperLegs, inverted: true, peakPosition: 0.2)
        drawTaperedSegment(from: rightUpperLegEnd, to: rightFootEnd, color: toSKColor(mutableFigure.rightLowerLegColor), strokeThickness: mutableFigure.strokeThicknessLowerLegs, fusiform: mutableFigure.fusiformLowerLegs, inverted: true, peakPosition: 0.2)
        
        // Draw torso - ONE SEGMENT from neck to waist, NOT split into upper/lower
        // This is the critical fix - the editor draws it as one continuous piece
        drawTaperedSegment(from: neckPos, to: waistPos, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessUpperTorso, fusiform: mutableFigure.fusiformUpperTorso, inverted: true, peakPosition: 0.2)
        drawLine(from: neckPos, to: headPos, color: toSKColor(mutableFigure.torsoColor), width: mutableFigure.strokeThickness)
        
        // Draw arms - with correct peak positions matching the editor
        // Upper arms: peak at 50% (middle of bicep)
        drawTaperedSegment(from: leftShoulderPos, to: leftUpperArmEnd, color: toSKColor(mutableFigure.leftUpperArmColor), strokeThickness: mutableFigure.strokeThicknessUpperArms, fusiform: mutableFigure.fusiformUpperArms, inverted: true, peakPosition: 0.5)
        // Lower arms: peak at 35% (closer to elbow)
        drawTaperedSegment(from: leftUpperArmEnd, to: leftForearmEnd, color: toSKColor(mutableFigure.leftLowerArmColor), strokeThickness: mutableFigure.strokeThicknessLowerArms, fusiform: mutableFigure.fusiformLowerArms, inverted: true, peakPosition: 0.35)
        
        drawTaperedSegment(from: rightShoulderPos, to: rightUpperArmEnd, color: toSKColor(mutableFigure.rightUpperArmColor), strokeThickness: mutableFigure.strokeThicknessUpperArms, fusiform: mutableFigure.fusiformUpperArms, inverted: true, peakPosition: 0.5)
        drawTaperedSegment(from: rightUpperArmEnd, to: rightForearmEnd, color: toSKColor(mutableFigure.rightLowerArmColor), strokeThickness: mutableFigure.strokeThicknessLowerArms, fusiform: mutableFigure.fusiformLowerArms, inverted: true, peakPosition: 0.35)
        
        // Draw hands and feet with overlap
        let handColor = toSKColor(mutableFigure.handColor)
        let footColor = toSKColor(mutableFigure.footColor)
        
        // Draw hands with overlap into lower arms (isHand: true makes bottom narrower)
        drawHandOrFoot(at: leftForearmEnd, from: leftUpperArmEnd, color: handColor, isHand: true)
        drawHandOrFoot(at: rightForearmEnd, from: rightUpperArmEnd, color: handColor, isHand: true)
        
        // Draw feet with overlap into lower legs (isHand: false keeps them wider)
        drawHandOrFoot(at: leftFootEnd, from: leftUpperLegEnd, color: footColor, isHand: false)
        drawHandOrFoot(at: rightFootEnd, from: rightUpperLegEnd, color: footColor, isHand: false)
        
        // Draw head
        let headRadius = mutableFigure.headRadius * 1.2  // Reduced from 3.5 to 1.2 - much smaller
        print("🎮 Drawing head at \(headPos) with radius \(headRadius)")
        drawCircle(at: headPos, radius: headRadius, color: SKColor(mutableFigure.headColor))
        
        // NOW DRAW THE SKELETON CONNECTORS LAST (on top of everything else)
        // Each skeleton piece uses the color of its corresponding body part
        let jointThickness = mutableFigure.strokeThicknessJoints
        
        // Helper to convert coordinates to relative (scaled) space
        func toRelative(_ point: CGPoint) -> CGPoint {
            return CGPoint(x: (point.x - baseCenter.x) * scale, y: (baseCenter.y - point.y) * scale)
        }
        
        // Helper to draw a skeleton connector line with the color of its body part
        func drawSkeletonConnector(from: CGPoint, to: CGPoint, color: SKColor) {
            let path = UIBezierPath()
            path.move(to: toRelative(from))
            path.addLine(to: toRelative(to))
            let line = SKShapeNode(path: path.cgPath)
            line.strokeColor = color
            line.lineWidth = max(jointThickness * 0.8 * scale, 1.0)
            line.fillColor = .clear
            line.zPosition = 0.5  // BEHIND the fusiforms (which are at z=1)
            container.addChild(line)
        }
        
        // Calculate midpoints for connectors
        let leftUpperLegMid = CGPoint(x: (waistPos.x + leftUpperLegEnd.x) * 0.5, y: (waistPos.y + leftUpperLegEnd.y) * 0.5)
        let rightUpperLegMid = CGPoint(x: (waistPos.x + rightUpperLegEnd.x) * 0.5, y: (waistPos.y + rightUpperLegEnd.y) * 0.5)
        let leftLowerLegMid = CGPoint(x: (leftUpperLegEnd.x + leftFootEnd.x) * 0.5, y: (leftUpperLegEnd.y + leftFootEnd.y) * 0.5)
        let rightLowerLegMid = CGPoint(x: (rightUpperLegEnd.x + rightFootEnd.x) * 0.5, y: (rightUpperLegEnd.y + rightFootEnd.y) * 0.5)
        let leftUpperArmMid = CGPoint(x: (leftShoulderPos.x + leftUpperArmEnd.x) * 0.5, y: (leftShoulderPos.y + leftUpperArmEnd.y) * 0.5)
        let leftLowerArmMid = CGPoint(x: (leftUpperArmEnd.x + leftForearmEnd.x) * 0.5, y: (leftUpperArmEnd.y + leftForearmEnd.y) * 0.5)
        let rightUpperArmMid = CGPoint(x: (rightShoulderPos.x + rightUpperArmEnd.x) * 0.5, y: (rightShoulderPos.y + rightUpperArmEnd.y) * 0.5)
        let rightLowerArmMid = CGPoint(x: (rightUpperArmEnd.x + rightForearmEnd.x) * 0.5, y: (rightUpperArmEnd.y + rightForearmEnd.y) * 0.5)
        
        // Only show skeleton if muscles are developed (avgMusclePoints > 0)
        if avgMusclePoints > 0 {
            // SPINE/TORSO: Uses torso color
            drawSkeletonConnector(from: neckPos, to: waistPos, color: toSKColor(mutableFigure.torsoColor))
            
            // LEFT LEG connectors: Use their respective leg colors
            drawSkeletonConnector(from: waistPos, to: leftUpperLegMid, color: toSKColor(mutableFigure.leftUpperLegColor))
            drawSkeletonConnector(from: leftUpperLegMid, to: leftUpperLegEnd, color: toSKColor(mutableFigure.leftUpperLegColor))
            drawSkeletonConnector(from: leftUpperLegEnd, to: leftLowerLegMid, color: toSKColor(mutableFigure.leftLowerLegColor))
            
            // RIGHT LEG connectors: Use their respective leg colors
            drawSkeletonConnector(from: waistPos, to: rightUpperLegMid, color: toSKColor(mutableFigure.rightUpperLegColor))
            drawSkeletonConnector(from: rightUpperLegMid, to: rightUpperLegEnd, color: toSKColor(mutableFigure.rightUpperLegColor))
            drawSkeletonConnector(from: rightUpperLegEnd, to: rightLowerLegMid, color: toSKColor(mutableFigure.rightLowerLegColor))
            
            // LEFT ARM connectors: Use their respective arm colors
            drawSkeletonConnector(from: leftShoulderPos, to: leftUpperArmMid, color: toSKColor(mutableFigure.leftUpperArmColor))
            drawSkeletonConnector(from: leftUpperArmMid, to: leftUpperArmEnd, color: toSKColor(mutableFigure.leftUpperArmColor))
            drawSkeletonConnector(from: leftUpperArmEnd, to: leftLowerArmMid, color: toSKColor(mutableFigure.leftLowerArmColor))
            
            // RIGHT ARM connectors: Use their respective arm colors
            drawSkeletonConnector(from: rightShoulderPos, to: rightUpperArmMid, color: toSKColor(mutableFigure.rightUpperArmColor))
            drawSkeletonConnector(from: rightUpperArmMid, to: rightUpperArmEnd, color: toSKColor(mutableFigure.rightUpperArmColor))
            drawSkeletonConnector(from: rightUpperArmEnd, to: rightLowerArmMid, color: toSKColor(mutableFigure.rightLowerArmColor))
        }
        
        
        print("🎮 Stick figure rendered with \(container.children.count) nodes!")
        return container
    }
    
    /// Calculate if a point is within a rectangular zone
    func isPoint(_ point: CGPoint, inZoneFrom start: CGPoint, width: CGFloat, height: CGFloat) -> Bool {
        return point.x >= start.x && point.x <= start.x + width &&
               point.y >= start.y && point.y <= start.y + height
    }
    
    /// Create a UIImage from an SF Symbol name
    func createSFSymbolImage(name: String, size: CGSize, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size.width, weight: .regular, scale: .large)
        let image = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysTemplate)
        return image
    }
}

