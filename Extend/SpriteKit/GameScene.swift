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
    func renderStickFigure(_ figure: StickFigure2D, at position: CGPoint, scale: CGFloat = 1.0, flipped: Bool = false, jointShapeSize: CGFloat = 1.0) -> SKNode {
        var mutableFigure = figure
        
        let container = SKNode()
        container.position = position
        container.xScale = flipped ? -1 : 1
        
        // Apply custom appearance colors from UserDefaults
        StickFigureAppearance.shared.applyToStickFigure(&mutableFigure)
        print("🎨 Applied appearance colors - torso: \(mutableFigure.torsoColor), leftUpperArm: \(mutableFigure.leftUpperArmColor), leftLowerArm: \(mutableFigure.leftLowerArmColor)")
        
        print("🎮 renderStickFigure: Drawing using StickFigure2D computed properties, scale: \(scale)")
        
        // Base canvas dimensions (matching StickFigure2D)
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        // Get all joint positions from the figure's computed properties
        let waistPos = mutableFigure.waistPosition
        let neckPos = mutableFigure.neckPosition
        let midTorsoPos = mutableFigure.midTorsoPosition
        let headPos = mutableFigure.headPosition
        let leftShoulderPos = mutableFigure.leftShoulderPosition
        let rightShoulderPos = mutableFigure.rightShoulderPosition
        
        print("🎮 DEBUG: Neck=\(neckPos), Waist=\(waistPos), UpperTorso fusiform=\(mutableFigure.fusiformUpperTorso), UpperArms fusiform=\(mutableFigure.fusiformUpperArms)")
        
        print("🎮 DEBUG: Neck=\(neckPos), Waist=\(waistPos), UpperTorso fusiform=\(mutableFigure.fusiformUpperTorso), UpperArms fusiform=\(mutableFigure.fusiformUpperArms)")
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
        
        // Helper to draw a tapered segment with custom taper direction
        // This allows the width perpendicular to point toward a specific direction (e.g., toward waist)
        func drawTaperedSegmentWithCustomTaper(
            from: CGPoint,
            to: CGPoint,
            color: SKColor,
            strokeThickness: CGFloat,
            fusiform: CGFloat,
            inverted: Bool,
            peakPosition: CGFloat = 0.2,
            customTaperDirection: CGPoint,  // Custom direction for width perpendicular
            in container: SKNode,
            baseCenter: CGPoint,
            scale: CGFloat
        ) {
            let fromRelative = CGPoint(x: (from.x - baseCenter.x) * scale, y: (baseCenter.y - from.y) * scale)
            let toRelative = CGPoint(x: (to.x - baseCenter.x) * scale, y: (baseCenter.y - to.y) * scale)
            
            // If fusiform is 0, just draw a simple line
            if fusiform == 0 {
                let path = UIBezierPath()
                path.move(to: fromRelative)
                path.addLine(to: toRelative)
                let line = SKShapeNode(path: path.cgPath)
                line.strokeColor = color
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
            
            // Normalized direction along the segment
            let dirX = dx / length
            let dirY = dy / length
            
            // Use the custom taper direction (pointing toward waist) instead of perpendicular
            let perpX = customTaperDirection.x
            let perpY = customTaperDirection.y
            
            // Create a tapered polygon with smooth width variation
            var topEdgePoints: [CGPoint] = []
            var bottomEdgePoints: [CGPoint] = []
            
            let numSegments = 50
            
            for i in 0...numSegments {
                let t = CGFloat(i) / CGFloat(numSegments)
                let pos = CGPoint(x: fromRelative.x + dirX * t * length, y: fromRelative.y + dirY * t * length)
                
                // Calculate width factor for this point along the segment
                var widthFactor: CGFloat = 1.0
                
                if inverted {
                    // NORMAL: Middle BULGE profile
                    let angle = (t - 0.5) * CGFloat.pi
                    let curveShape = cos(angle)
                    let bulge = 1.0 + (fusiform * max(0, curveShape))
                    widthFactor = bulge
                } else {
                    // Standard taper
                    widthFactor = 1.0
                }
                
                let width = (strokeThickness / 2) * widthFactor
                
                // Top and bottom edges using custom taper direction
                let topPoint = CGPoint(x: pos.x + perpX * width, y: pos.y + perpY * width)
                let bottomPoint = CGPoint(x: pos.x - perpX * width, y: pos.y - perpY * width)
                
                topEdgePoints.append(topPoint)
                bottomEdgePoints.append(bottomPoint)
            }
            
            // Create the path
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
        
        // Helper to draw a tapered segment (respects fusiform values) - matches StickFigure2D editor exactly
        func drawTaperedSegment(
            from: CGPoint,
            to: CGPoint,
            color: SKColor,
            strokeThickness: CGFloat,
            fusiform: CGFloat,
            inverted: Bool,
            peakPosition: CGFloat = 0.2,
            legAsymmetry: String = "none",  // "left", "right", or "none" - controls which side expands
            peakPositionLeftEdge: CGFloat? = nil,  // Optional: for calves, different peak for left edge
            peakPositionRightEdge: CGFloat? = nil  // Optional: for calves, different peak for right edge
        ) {
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
                
                // Calculate width factors for left and right edges (for asymmetric legs)
                var widthFactorLeft: CGFloat = 1.0
                var widthFactorRight: CGFloat = 1.0
                
                if inverted {
                    // For asymmetric legs, calculate separate peak positions for each edge
                    let peakTLeft = peakPositionLeftEdge ?? peakPosition
                    let peakTRight = peakPositionRightEdge ?? peakPosition
                    
                    // Calculate width factor for left edge
                    var distFromPeakLeft: CGFloat
                    if t <= peakTLeft {
                        distFromPeakLeft = (peakTLeft - t) / peakTLeft
                    } else {
                        distFromPeakLeft = (t - peakTLeft) / (1.0 - peakTLeft)
                    }
                    let easeTLeft = max(0, 1.0 - (distFromPeakLeft * distFromPeakLeft))
                    widthFactorLeft = fusiform * easeTLeft
                    
                    // Calculate width factor for right edge
                    var distFromPeakRight: CGFloat
                    if t <= peakTRight {
                        distFromPeakRight = (peakTRight - t) / peakTRight
                    } else {
                        distFromPeakRight = (t - peakTRight) / (1.0 - peakTRight)
                    }
                    let easeTRight = max(0, 1.0 - (distFromPeakRight * distFromPeakRight))
                    widthFactorRight = fusiform * easeTRight
                    
                    // Apply leg asymmetry: only expand outward (away from center)
                    if legAsymmetry == "left" {
                        // Left leg: expand only on left side, not on right
                        widthFactorRight = 0.0
                    } else if legAsymmetry == "right" {
                        // Right leg: expand only on right side, not on left
                        widthFactorLeft = 0.0
                    }
                    // If "none", both sides expand normally
                } else {
                    // NORMAL: Middle BULGE profile with smooth curve (not sharp)
                    let angle = (t - 0.5) * CGFloat.pi
                    let curveShape = cos(angle)
                    let bulge = 1.0 + (fusiform * max(0, curveShape))
                    widthFactorLeft = bulge
                    widthFactorRight = bulge
                }
                
                let widthLeft = (strokeThickness / 2) * widthFactorLeft
                let widthRight = (strokeThickness / 2) * widthFactorRight
                
                // Top and bottom edges (asymmetric)
                let topPoint = CGPoint(x: pos.x + perpX * widthLeft, y: pos.y + perpY * widthLeft)
                let bottomPoint = CGPoint(x: pos.x - perpX * widthRight, y: pos.y - perpY * widthRight)
                
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
            line.lineCap = .round  // Add rounded line caps
            line.zPosition = 1
            container.addChild(line)
        }
        
        // Helper to draw a rounded corner line (for waist connectors)
        func drawRoundedLine(from: CGPoint, to: CGPoint, color: SKColor, width: CGFloat = 2) {
            // Convert from base canvas coordinates to relative coordinates and apply scale
            let fromRelative = CGPoint(x: (from.x - baseCenter.x) * scale, y: (baseCenter.y - from.y) * scale)
            let toRelative = CGPoint(x: (to.x - baseCenter.x) * scale, y: (baseCenter.y - to.y) * scale)
            
            let path = UIBezierPath()
            path.move(to: fromRelative)
            path.addLine(to: toRelative)
            let line = SKShapeNode(path: path.cgPath)
            line.strokeColor = color
            line.lineWidth = max(width * scale, 1.0)
            line.lineCap = .round  // Rounded caps
            line.lineJoin = .round  // Rounded joins
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
        func drawHandOrFoot(at position: CGPoint, from startPoint: CGPoint, color: SKColor, isHand: Bool = false, sizeMultiplier: CGFloat = 1.0) {
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
            let radius = max(5.0, 1.0 * scale * sizeMultiplier)
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
        
        // Helper to draw triangle-shaped waist with rounded bottom corners
        func drawWaistTriangle(from midTorsoPoint: CGPoint, to waistPoint: CGPoint, color: SKColor, strokeThickness: CGFloat, fusiform: CGFloat = 0, pointPosition: CGFloat, leftHipPos: CGPoint, rightHipPos: CGPoint) {
            // Convert all points to relative coordinates and apply scale
            // IMPORTANT: The top point is PINNED to midTorsoPoint (which already includes the offset)
            let topPointRelative = CGPoint(x: (midTorsoPoint.x - baseCenter.x) * scale, y: (baseCenter.y - midTorsoPoint.y) * scale)
            let waistRelative = CGPoint(x: (waistPoint.x - baseCenter.x) * scale, y: (baseCenter.y - waistPoint.y) * scale)
            let leftHipRelative = CGPoint(x: (leftHipPos.x - baseCenter.x) * scale, y: (baseCenter.y - leftHipPos.y) * scale)
            let rightHipRelative = CGPoint(x: (rightHipPos.x - baseCenter.x) * scale, y: (baseCenter.y - rightHipPos.y) * scale)
            
            print("🔺 TRIANGLE DEBUG:")
            print("  topPoint: \(midTorsoPoint) -> \(topPointRelative)")
            print("  waist: \(waistPoint) -> \(waistRelative)")
            print("  leftHip: \(leftHipPos) -> \(leftHipRelative)")
            print("  rightHip: \(rightHipPos) -> \(rightHipRelative)")
            print("  pointPosition: \(pointPosition)")
            print("  fusiform: \(fusiform), strokeThickness: \(strokeThickness)")
            
            // Apply fusiform to hip width - fusiform expands the hips
            let hipDistance = sqrt(pow(rightHipRelative.x - leftHipRelative.x, 2) + pow(rightHipRelative.y - leftHipRelative.y, 2))
            let hipExpansion = hipDistance * (fusiform * 0.1)  // Scale fusiform effect proportionally
            
            // BOTTOM corners - apply fusiform expansion to hip width
            let bottomLeft = CGPoint(x: leftHipRelative.x - hipExpansion, y: leftHipRelative.y)
            let bottomRight = CGPoint(x: rightHipRelative.x + hipExpansion, y: rightHipRelative.y)
            
            // Calculate rounded corner radius based on the distance between hips
            let cornerRadius = hipDistance * 0.2  // 20% of hip distance for rounding
            
            // TOP point is PINNED to topPoint (which is midTorsoPoint including offset) and stays there
            // pointPosition controls how "full" the triangle is (0.0 = no triangle, 1.0 = full triangle to midTorso)
            let pointPos = topPointRelative
            
            // Scale the stroke thickness with the figure scale
            let appliedStrokeThickness = max(strokeThickness * scale, 1.0)
            
            // When pointPosition < 1.0, we need to interpolate the sides to taper toward the waist
            // This creates the expanding/contracting effect
            if pointPosition >= 1.0 {
                // Full triangle - point pinned to mid-torso, base at hips
                let path = UIBezierPath()
                
                // Start at bottom-left corner
                path.move(to: bottomLeft)
                
                // Draw rounded corner at bottom-left
                let bottomLeftControl = CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y)
                path.addQuadCurve(to: bottomLeftControl, controlPoint: bottomLeft)
                
                // Go up the left side to the point
                path.addLine(to: pointPos)
                
                // Go down the right side from point to rounded bottom-right corner start
                let bottomRightControl = CGPoint(x: bottomRight.x - cornerRadius, y: bottomRight.y)
                path.addLine(to: bottomRightControl)
                
                // Draw rounded corner at bottom-right
                path.addQuadCurve(to: bottomRight, controlPoint: bottomRight)
                
                // Close back to starting point
                path.addLine(to: bottomLeft)
                
                path.close()
                
                let shape = SKShapeNode(path: path.cgPath)
                shape.fillColor = color
                shape.strokeColor = color
                shape.lineWidth = appliedStrokeThickness
                shape.zPosition = 1
                container.addChild(shape)
            } else {
                // Partial triangle - taper from hips toward waist based on pointPosition
                let taperingFactor = pointPosition  // 0.0 to 1.0
                
                // Interpolate left side: from hip to waist, then toward midTorso
                let leftTaperedX = bottomLeft.x + (waistRelative.x - bottomLeft.x) * (1.0 - taperingFactor)
                let leftTaperedY = bottomLeft.y + (waistRelative.y - bottomLeft.y) * (1.0 - taperingFactor)
                let leftTaperedPoint = CGPoint(x: leftTaperedX, y: leftTaperedY)
                
                // Interpolate right side: from hip to waist, then toward midTorso
                let rightTaperedX = bottomRight.x + (waistRelative.x - bottomRight.x) * (1.0 - taperingFactor)
                let rightTaperedY = bottomRight.y + (waistRelative.y - bottomRight.y) * (1.0 - taperingFactor)
                let rightTaperedPoint = CGPoint(x: rightTaperedX, y: rightTaperedY)
                
                let path = UIBezierPath()
                
                // Start at bottom-left corner
                path.move(to: bottomLeft)
                
                // Draw rounded corner at bottom-left
                let bottomLeftControl = CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y)
                path.addQuadCurve(to: bottomLeftControl, controlPoint: bottomLeft)
                
                // Go up the left side to tapered point
                path.addLine(to: leftTaperedPoint)
                
                // Go to the midTorso point
                path.addLine(to: pointPos)
                
                // Go down the right side from midTorso to tapered point
                path.addLine(to: rightTaperedPoint)
                
                // Go to bottom-right corner start
                let bottomRightControl = CGPoint(x: bottomRight.x - cornerRadius, y: bottomRight.y)
                path.addLine(to: bottomRightControl)
                
                // Draw rounded corner at bottom-right
                path.addQuadCurve(to: bottomRight, controlPoint: bottomRight)
                
                // Close back to starting point
                path.addLine(to: bottomLeft)
                
                path.close()
                
                let shape = SKShapeNode(path: path.cgPath)
                shape.fillColor = color
                shape.strokeColor = color
                shape.lineWidth = appliedStrokeThickness
                shape.zPosition = 1
                container.addChild(shape)
            }
        }
        
        // Draw lower body first (back) - with fusiform
        let leftHipPos = mutableFigure.leftHipPosition
        let rightHipPos = mutableFigure.rightHipPosition
        
        // ALWAYS draw connectors from waist to hips - they're part of the triangle base when triangle is active
        drawRoundedLine(from: waistPos, to: leftHipPos, color: toSKColor(mutableFigure.torsoColor), width: mutableFigure.strokeThicknessUpperLegs * 1.5)
        drawRoundedLine(from: waistPos, to: rightHipPos, color: toSKColor(mutableFigure.torsoColor), width: mutableFigure.strokeThicknessUpperLegs * 1.5)
        
        // Upper legs: expand only outward (left leg to left, right leg to right)
        drawTaperedSegment(from: leftHipPos, to: leftUpperLegEnd, color: toSKColor(mutableFigure.leftUpperLegColor), strokeThickness: mutableFigure.strokeThicknessUpperLegs, fusiform: mutableFigure.fusiformUpperLegs, inverted: true, peakPosition: mutableFigure.peakPositionUpperLegs, legAsymmetry: "right")
        
        // Left lower leg: peak on right side at top-right 3rd, left side normal
        drawTaperedSegment(from: leftUpperLegEnd, to: leftFootEnd, color: toSKColor(mutableFigure.leftLowerLegColor), strokeThickness: mutableFigure.strokeThicknessLowerLegs, fusiform: mutableFigure.fusiformLowerLegs, inverted: true, peakPosition: mutableFigure.peakPositionLowerLegs, peakPositionLeftEdge: mutableFigure.peakPositionLowerLegs, peakPositionRightEdge: 0.33)
        
        drawTaperedSegment(from: rightHipPos, to: rightUpperLegEnd, color: toSKColor(mutableFigure.rightUpperLegColor), strokeThickness: mutableFigure.strokeThicknessUpperLegs, fusiform: mutableFigure.fusiformUpperLegs, inverted: true, peakPosition: mutableFigure.peakPositionUpperLegs, legAsymmetry: "left")
        
        // Right lower leg: peak on left side at top-left 3rd, right side normal
        drawTaperedSegment(from: rightUpperLegEnd, to: rightFootEnd, color: toSKColor(mutableFigure.rightLowerLegColor), strokeThickness: mutableFigure.strokeThicknessLowerLegs, fusiform: mutableFigure.fusiformLowerLegs, inverted: true, peakPosition: mutableFigure.peakPositionLowerLegs, peakPositionLeftEdge: 0.33, peakPositionRightEdge: mutableFigure.peakPositionLowerLegs)
        
        // Draw torso - SPLIT INTO TWO SEGMENTS: upper and lower
        // IMPORTANT: Draw upper torso FIRST, then lower torso, so lower torso appears on top
        
        // Apply mid-torso Y offset as a pinning constraint
        // The offset is defined in the upper torso's LOCAL coordinate system
        // where Y points downward along the upper torso segment
        // We rotate this offset by the total torso rotation to get world space
        let totalTorsoRotationRadians = (mutableFigure.waistTorsoAngle + mutableFigure.midTorsoAngle) * .pi / 180
        
        // In upper torso's local space: offset is purely in Y direction (down the torso)
        let offsetLocalX = CGFloat(0)
        let offsetLocalY = mutableFigure.midTorsoYOffset
        
        // Rotate offset into world space using the upper torso's rotation
        let rotatedOffsetX = offsetLocalX * cos(CGFloat(totalTorsoRotationRadians)) - offsetLocalY * sin(CGFloat(totalTorsoRotationRadians))
        let rotatedOffsetY = offsetLocalX * sin(CGFloat(totalTorsoRotationRadians)) + offsetLocalY * cos(CGFloat(totalTorsoRotationRadians))
        
        // Apply offset from midTorso
        let midTorsoWithOffset = CGPoint(
            x: midTorsoPos.x + rotatedOffsetX,
            y: midTorsoPos.y + rotatedOffsetY
        )
        
        // Upper torso: neck to mid-torso (with offset applied to match editor)
        drawTaperedSegment(from: neckPos, to: midTorsoWithOffset, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessUpperTorso, fusiform: mutableFigure.fusiformUpperTorso, inverted: true, peakPosition: mutableFigure.peakPositionUpperTorso)

        // Lower torso from mid-torso (PINNED, no offset) to waist
        // The lower torso stays pinned to midTorsoPos (without offset)
        // Only the upper torso's bottom point moves with the offset
        
        if mutableFigure.waistThicknessMultiplier > 0.0 {
            // Draw triangle-shaped lower torso with rounded bottom corners
            // waistThicknessMultiplier controls point position: 0.0 = at waist, 1.0 = at mid-torso
            // fusiformLowerTorso controls the hip width expansion
            drawWaistTriangle(from: midTorsoPos, to: waistPos, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessLowerTorso, fusiform: mutableFigure.fusiformLowerTorso, pointPosition: mutableFigure.waistThicknessMultiplier, leftHipPos: leftHipPos, rightHipPos: rightHipPos)
        } else {
            // No triangle at 0.0 - standard tapered segment
            drawTaperedSegment(from: midTorsoPos, to: waistPos, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessLowerTorso, fusiform: mutableFigure.fusiformLowerTorso, inverted: true, peakPosition: mutableFigure.peakPositionLowerTorso)
        }
        drawLine(from: neckPos, to: headPos, color: toSKColor(mutableFigure.torsoColor), width: mutableFigure.strokeThickness * mutableFigure.neckWidth)
        
        // Draw shoulder joints with fusiformShoulders tapering
        drawTaperedSegment(from: neckPos, to: leftShoulderPos, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessUpperTorso, fusiform: mutableFigure.fusiformShoulders, inverted: false, peakPosition: 0.5)
        drawTaperedSegment(from: neckPos, to: rightShoulderPos, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessUpperTorso, fusiform: mutableFigure.fusiformShoulders, inverted: false, peakPosition: 0.5)
        
        // Draw arms - with correct peak positions matching the editor
        // Upper arms: peak position controlled by slider
        drawTaperedSegment(from: leftShoulderPos, to: leftUpperArmEnd, color: toSKColor(mutableFigure.leftUpperArmColor), strokeThickness: mutableFigure.strokeThicknessUpperArms, fusiform: mutableFigure.fusiformUpperArms, inverted: true, peakPosition: mutableFigure.peakPositionUpperArms)
        // Lower arms: peak position controlled by slider
        drawTaperedSegment(from: leftUpperArmEnd, to: leftForearmEnd, color: toSKColor(mutableFigure.leftLowerArmColor), strokeThickness: mutableFigure.strokeThicknessLowerArms, fusiform: mutableFigure.fusiformLowerArms, inverted: true, peakPosition: mutableFigure.peakPositionLowerArms)
        
        drawTaperedSegment(from: rightShoulderPos, to: rightUpperArmEnd, color: toSKColor(mutableFigure.rightUpperArmColor), strokeThickness: mutableFigure.strokeThicknessUpperArms, fusiform: mutableFigure.fusiformUpperArms, inverted: true, peakPosition: mutableFigure.peakPositionUpperArms)
        drawTaperedSegment(from: rightUpperArmEnd, to: rightForearmEnd, color: toSKColor(mutableFigure.rightLowerArmColor), strokeThickness: mutableFigure.strokeThicknessLowerArms, fusiform: mutableFigure.fusiformLowerArms, inverted: true, peakPosition: mutableFigure.peakPositionLowerArms)
        
        // Draw hands and feet with overlap
        let handColor = toSKColor(mutableFigure.handColor)
        let footColor = toSKColor(mutableFigure.footColor)
        
        // Draw hands with overlap into lower arms (isHand: true makes bottom narrower)
        drawHandOrFoot(at: leftForearmEnd, from: leftUpperArmEnd, color: handColor, isHand: true, sizeMultiplier: mutableFigure.handSize)
        drawHandOrFoot(at: rightForearmEnd, from: rightUpperArmEnd, color: handColor, isHand: true, sizeMultiplier: mutableFigure.handSize)
        
        // Draw feet with overlap into lower legs (isHand: false keeps them wider)
        drawHandOrFoot(at: leftFootEnd, from: leftUpperLegEnd, color: footColor, isHand: false, sizeMultiplier: mutableFigure.footSize)
        drawHandOrFoot(at: rightFootEnd, from: rightUpperLegEnd, color: footColor, isHand: false, sizeMultiplier: mutableFigure.footSize)
        
        // Draw head
        let headRadius = mutableFigure.headRadius * 1.2  // Reduced from 3.5 to 1.2 - much smaller
        print("🎮 Drawing head at \(headPos) with radius \(headRadius)")
        drawCircle(at: headPos, radius: headRadius, color: SKColor(mutableFigure.headColor))
        
        // NOW DRAW THE SKELETON CONNECTORS LAST (on top of everything else)
        // Each skeleton piece uses the color of its corresponding body part
        
        // Helper to convert coordinates to relative (scaled) space
        func toRelative(_ point: CGPoint) -> CGPoint {
            return CGPoint(x: (point.x - baseCenter.x) * scale, y: (baseCenter.y - point.y) * scale)
        }
        
        // Helper to draw a skeleton connector line with the color of its body part
        // Simple lines that bend around joints
        func drawSkeletonConnector(from: CGPoint, to: CGPoint, color: SKColor) {
            let lineWidth = max(mutableFigure.strokeThicknessJoints * 0.8 * scale * mutableFigure.skeletonSize, 1.0)
            print("🦴 Drawing skeleton connector: lineWidth=\(lineWidth), skeletonSize=\(mutableFigure.skeletonSize), jointThickness=\(mutableFigure.strokeThicknessJoints), scale=\(scale)")
            
            // Convert to relative coordinates
            let fromRelative = toRelative(from)
            let toRelative = toRelative(to)
            
            // Create a simple line path with smooth curves
            let path = UIBezierPath()
            path.move(to: fromRelative)
            
            // Add a smooth curve to the end point (bends naturally around joints)
            // Use quadratic curves for smooth bending
            let midPoint = CGPoint(x: (fromRelative.x + toRelative.x) * 0.5,
                                 y: (fromRelative.y + toRelative.y) * 0.5)
            path.addQuadCurve(to: toRelative, controlPoint: midPoint)
            
            let line = SKShapeNode(path: path.cgPath)
            line.strokeColor = color  // Use the actual body part color
            line.lineWidth = lineWidth
            line.lineCap = .round  // Rounded ends
            line.lineJoin = .round  // Rounded joins
            line.zPosition = 1.5  // Normal position (in front of body but behind other elements)
            container.addChild(line)
        }
        
        // Calculate midpoints for connectors
        let leftUpperLegMid = CGPoint(x: (leftHipPos.x + leftUpperLegEnd.x) * 0.5, y: (leftHipPos.y + leftUpperLegEnd.y) * 0.5)
        let rightUpperLegMid = CGPoint(x: (rightHipPos.x + rightUpperLegEnd.x) * 0.5, y: (rightHipPos.y + rightUpperLegEnd.y) * 0.5)
        let leftLowerLegMid = CGPoint(x: (leftUpperLegEnd.x + leftFootEnd.x) * 0.5, y: (leftUpperLegEnd.y + leftFootEnd.y) * 0.5)
        let rightLowerLegMid = CGPoint(x: (rightUpperLegEnd.x + rightFootEnd.x) * 0.5, y: (rightUpperLegEnd.y + rightFootEnd.y) * 0.5)
        let leftUpperArmMid = CGPoint(x: (leftShoulderPos.x + leftUpperArmEnd.x) * 0.5, y: (leftShoulderPos.y + leftUpperArmEnd.y) * 0.5)
        let leftLowerArmMid = CGPoint(x: (leftUpperArmEnd.x + leftForearmEnd.x) * 0.5, y: (leftUpperArmEnd.y + leftForearmEnd.y) * 0.5)
        let rightUpperArmMid = CGPoint(x: (rightShoulderPos.x + rightUpperArmEnd.x) * 0.5, y: (rightShoulderPos.y + rightUpperArmEnd.y) * 0.5)
        let rightLowerArmMid = CGPoint(x: (rightUpperArmEnd.x + rightForearmEnd.x) * 0.5, y: (rightUpperArmEnd.y + rightForearmEnd.y) * 0.5)
        
        // Always draw skeleton and joints - they're controlled by sliders in the editor
        // In gameplay, they'll be hidden/shown based on other logic later
        
        // NOTE: SPINE/TORSO is now drawn separately using strokeThicknessFullTorso
        // It is NOT part of strokeThicknessJoints rendering
        
        // SPINE/TORSO CONNECTOR: Uses strokeThicknessFullTorso instead of strokeThicknessJoints
        // Draws as two segments that bend at midtorso: neck->midtorso and midtorso->waist
        let torsoLineWidth = max(mutableFigure.strokeThicknessFullTorso * 0.8 * scale * mutableFigure.skeletonSize, 1.0)
        let neckRelative = toRelative(neckPos)
        let midTorsoOffsetRelative = toRelative(midTorsoWithOffset)  // Use offset position for upper torso
        let midTorsoRelative = toRelative(midTorsoPos)  // Keep lower torso pinned to unoffset midtorso
        let waistRelative = toRelative(waistPos)

        let torsoPath = UIBezierPath()
        
        // Upper torso segment: neck to midtorso (with offset applied)
        torsoPath.move(to: neckRelative)
        let upperTorsoMidPoint = CGPoint(x: (neckRelative.x + midTorsoOffsetRelative.x) * 0.5,
                                         y: (neckRelative.y + midTorsoOffsetRelative.y) * 0.5)
        torsoPath.addQuadCurve(to: midTorsoOffsetRelative, controlPoint: upperTorsoMidPoint)
        
        // Lower torso segment: midtorso (PINNED, no offset) to waist
        let lowerTorsoMidPoint = CGPoint(x: (midTorsoRelative.x + waistRelative.x) * 0.5,
                                         y: (midTorsoRelative.y + waistRelative.y) * 0.5)
        torsoPath.addQuadCurve(to: waistRelative, controlPoint: lowerTorsoMidPoint)
        
        let torsoLine = SKShapeNode(path: torsoPath.cgPath)
        torsoLine.strokeColor = toSKColor(mutableFigure.torsoColor)
        torsoLine.lineWidth = torsoLineWidth
        torsoLine.lineCap = .round
        torsoLine.lineJoin = .round
        torsoLine.zPosition = 1.5
        container.addChild(torsoLine)
        
        // LEFT LEG connectors: Use their respective leg colors
        drawSkeletonConnector(from: leftHipPos, to: leftUpperLegMid, color: toSKColor(mutableFigure.leftUpperLegColor))
        drawSkeletonConnector(from: leftUpperLegMid, to: leftUpperLegEnd, color: toSKColor(mutableFigure.leftUpperLegColor))
        drawSkeletonConnector(from: leftUpperLegEnd, to: leftLowerLegMid, color: toSKColor(mutableFigure.leftLowerLegColor))
        
        // RIGHT LEG connectors: Use their respective leg colors
        drawSkeletonConnector(from: rightHipPos, to: rightUpperLegMid, color: toSKColor(mutableFigure.rightUpperLegColor))
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
        
        // Add joint caps at connection points to fill gaps (elbows, knees, waist, shoulders)
        let jointCapRadius = max(mutableFigure.strokeThicknessJoints * 0.3 * scale * jointShapeSize, 1.0)
        
        // LEFT ARM ELBOW - blend upper and lower arm colors by using upper arm color
        drawCircle(at: leftUpperArmEnd, radius: jointCapRadius, color: toSKColor(mutableFigure.leftUpperArmColor))
        
        // RIGHT ARM ELBOW
        drawCircle(at: rightUpperArmEnd, radius: jointCapRadius, color: toSKColor(mutableFigure.rightUpperArmColor))
        
        // LEFT LEG KNEE - blend upper and lower leg colors by using upper leg color
        drawCircle(at: leftUpperLegEnd, radius: jointCapRadius, color: toSKColor(mutableFigure.leftUpperLegColor))
        
        // RIGHT LEG KNEE
        drawCircle(at: rightUpperLegEnd, radius: jointCapRadius, color: toSKColor(mutableFigure.rightUpperLegColor))
        
        // LEFT SHOULDER - connect shoulders to upper arms
        drawCircle(at: leftShoulderPos, radius: jointCapRadius, color: toSKColor(mutableFigure.torsoColor))
        
        // RIGHT SHOULDER
        drawCircle(at: rightShoulderPos, radius: jointCapRadius, color: toSKColor(mutableFigure.torsoColor))
        
        
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
