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
        
        print("🎮 DEBUG: Neck=\(neckPos), Waist=\(waistPos), UpperTorso fusiform=\(mutableFigure.fusiformUpperTorso), Bicep fusiform=\(mutableFigure.fusiformBicep), Tricep fusiform=\(mutableFigure.fusiformTricep)")
        
        print("🎮 DEBUG: Neck=\(neckPos), Waist=\(waistPos), UpperTorso fusiform=\(mutableFigure.fusiformUpperTorso), Bicep fusiform=\(mutableFigure.fusiformBicep), Tricep fusiform=\(mutableFigure.fusiformTricep)")
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
            
            // Draw top edge with curves
            for i in 1..<topEdgePoints.count {
                let prev = topEdgePoints[i - 1]
                let curr = topEdgePoints[i]
                
                let controlX = (prev.x + curr.x) / 2
                let controlY = (prev.y + curr.y) / 2
                let control = CGPoint(x: controlX, y: controlY)
                
                path.addQuadCurve(to: curr, controlPoint: control)
            }
            
            // Draw bottom edge in reverse with curves
            for i in stride(from: bottomEdgePoints.count - 1, through: 0, by: -1) {
                let curr = bottomEdgePoints[i]
                let prev = i > 0 ? bottomEdgePoints[i - 1] : curr
                
                let controlX = (curr.x + prev.x) / 2
                let controlY = (curr.y + prev.y) / 2
                let control = CGPoint(x: controlX, y: controlY)
                
                path.addQuadCurve(to: curr, controlPoint: control)
            }
            
            path.close()
            
            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = color
            shape.strokeColor = .clear
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
            
            // If fusiform is 0, just draw a simple line with the provided strokeThickness
            if fusiform == 0 {
                let path = UIBezierPath()
                path.move(to: fromRelative)
                path.addLine(to: toRelative)
                let line = SKShapeNode(path: path.cgPath)
                line.strokeColor = color
                // Use the strokeThickness parameter so sliders actually control visibility
                line.lineWidth = max(strokeThickness * scale, 0.5)
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
            
            var minWidth = CGFloat.infinity
            var maxWidth = -CGFloat.infinity
            var debugFirstPass = true
            
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
                    // Add minimum width of 0.3 so it doesn't taper to zero at the endpoints
                    widthFactorLeft = 0.3 + (fusiform * 0.7 * easeTLeft)
                    
                    // Calculate width factor for right edge
                    var distFromPeakRight: CGFloat
                    if t <= peakTRight {
                        distFromPeakRight = (peakTRight - t) / peakTRight
                    } else {
                        distFromPeakRight = (t - peakTRight) / (1.0 - peakTRight)
                    }
                    let easeTRight = max(0, 1.0 - (distFromPeakRight * distFromPeakRight))
                    // Add minimum width of 0.3 so it doesn't taper to zero at the endpoints
                    widthFactorRight = 0.3 + (fusiform * 0.7 * easeTRight)
                    
                    // Apply leg asymmetry: primary side expands outward, secondary side at 1/4 size
                    if legAsymmetry == "left" {
                        // Left leg: expand more on left side, 1/4 on right side
                        widthFactorRight = widthFactorRight * 0.45
                    } else if legAsymmetry == "right" {
                        // Right leg: expand more on right side, 1/4 on left side
                        widthFactorLeft = widthFactorLeft * 0.45
                    }
                    // If "none", both sides expand normally
                    
                    // DEBUG: Log first deltoid pass
                    if debugFirstPass && i == 0 {
                        print("🎨 DELTOID DEBUG START: fusiform=\(fusiform), peakTLeft=\(peakTLeft), peakTRight=\(peakTRight), legAsymmetry='\(legAsymmetry)'")
                    }
                    if debugFirstPass && (i == 0 || i == numSegments/2 || i == numSegments) {
                        print("🎨 DELTOID DEBUG: i=\(i), t=\(t), distFromPeakLeft=\(distFromPeakLeft), easeTLeft=\(easeTLeft), widthFactorLeft=\(widthFactorLeft)")
                    }
                } else {
                    // NORMAL: Middle BULGE profile with smooth curve (not sharp) - uses peakPosition
                    let angle = (t - peakPosition) * CGFloat.pi
                    let curveShape = cos(angle)
                    // Blend between a minimum width and the fusiform bulge to allow tapering
                    // This gives more natural tapering at small fusiform values
                    let bulge = 0.5 + (fusiform * max(0, curveShape))
                    widthFactorLeft = bulge
                    widthFactorRight = bulge
                }
                
                let widthLeft = (strokeThickness / 2) * widthFactorLeft
                let widthRight = (strokeThickness / 2) * widthFactorRight
                
                if debugFirstPass {
                    minWidth = min(minWidth, widthLeft, widthRight)
                    maxWidth = max(maxWidth, widthLeft, widthRight)
                }
                
                // Top and bottom edges (asymmetric)
                let topPoint = CGPoint(x: pos.x + perpX * widthLeft, y: pos.y + perpY * widthLeft)
                let bottomPoint = CGPoint(x: pos.x - perpX * widthRight, y: pos.y - perpY * widthRight)
                
                topEdgePoints.append(topPoint)
                bottomEdgePoints.append(bottomPoint)
            }
            
            if debugFirstPass {
                print("🎨 DELTOID DEBUG SUMMARY: minWidth=\(minWidth), maxWidth=\(maxWidth), ratio=\(maxWidth/minWidth)")
                debugFirstPass = false
            }
            
            // Create the path by drawing the top edge, then the bottom edge backwards
            let path = UIBezierPath()
            
            if let firstPoint = topEdgePoints.first {
                path.move(to: firstPoint)
            }
            
            // Draw top edge with curves for smooth fusiform shape
            for i in 1..<topEdgePoints.count {
                let prev = topEdgePoints[i - 1]
                let curr = topEdgePoints[i]
                
                // Use quadratic curve for smooth edges
                let controlX = (prev.x + curr.x) / 2
                let controlY = (prev.y + curr.y) / 2
                let control = CGPoint(x: controlX, y: controlY)
                
                path.addQuadCurve(to: curr, controlPoint: control)
            }
            
            // Draw bottom edge in reverse with curves
            for i in stride(from: bottomEdgePoints.count - 1, through: 0, by: -1) {
                let curr = bottomEdgePoints[i]
                let prev = i > 0 ? bottomEdgePoints[i - 1] : curr
                
                // Use quadratic curve for smooth edges
                let controlX = (curr.x + prev.x) / 2
                let controlY = (curr.y + prev.y) / 2
                let control = CGPoint(x: controlX, y: controlY)
                
                path.addQuadCurve(to: curr, controlPoint: control)
            }
            
            path.close()
            
            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = color
            shape.strokeColor = .clear
            shape.lineWidth = 0
            shape.zPosition = 1
            container.addChild(shape)
        }
        
        // Helper to draw bicep/tricep with independent left/right control
        // bicepFusiform controls one side, tricepFusiform controls the other side
        // armMuscleSide determines which muscle is on which side:
        // - "normal" = bicep on bottom/inner, tricep on top/outer
        // - "flipped" = bicep on top/outer, tricep on bottom/inner
        // - "both" = both muscles visible on both sides
        func drawArmWithBicepTricep(
            from: CGPoint,
            to: CGPoint,
            color: SKColor,
            strokeThicknessBicep: CGFloat,
            strokeThicknessTricep: CGFloat,
            bicepFusiform: CGFloat,
            tricepFusiform: CGFloat,
            peakPositionBicep: CGFloat = 0.5,
            peakPositionTricep: CGFloat = 0.5,
            armMuscleSide: String = "normal",
            isLeftArm: Bool = false
        ) {
            print("🎨 DEBUG drawArmWithBicepTricep: armMuscleSide=\(armMuscleSide), isLeftArm=\(isLeftArm), bicepFusiform=\(bicepFusiform), tricepFusiform=\(tricepFusiform)")
            // Convert to relative coordinates and apply scale
            let fromRelative = CGPoint(x: (from.x - baseCenter.x) * scale, y: (baseCenter.y - from.y) * scale)
            let toRelative = CGPoint(x: (to.x - baseCenter.x) * scale, y: (baseCenter.y - to.y) * scale)
            
            let dx = toRelative.x - fromRelative.x
            let dy = toRelative.y - fromRelative.y
            let length = sqrt(dx * dx + dy * dy)
            
            guard length > 0 else { return }
            
            let dirX = dx / length
            let dirY = dy / length
            let perpX = -dirY
            let perpY = dirX
            
            var topEdgePoints: [CGPoint] = []
            var bottomEdgePoints: [CGPoint] = []
            
            let numSegments = 20
            for i in 0...numSegments {
                let t = CGFloat(i) / CGFloat(numSegments)
                let pos = CGPoint(x: fromRelative.x + dirX * t * length, y: fromRelative.y + dirY * t * length)
                
                // Calculate bicep width (bottom/inner side)
                var bicepWidthFactor: CGFloat = 0.3
                if bicepFusiform > 0 {
                    let angle = (t - peakPositionBicep) * CGFloat.pi
                    let curveShape = cos(angle)
                    bicepWidthFactor = 0.5 + (bicepFusiform * max(0, curveShape))
                }
                let bicepWidth = (strokeThicknessBicep / 2) * bicepWidthFactor
                
                // Calculate tricep width (top/outer side)
                var tricepWidthFactor: CGFloat = 0.3
                if tricepFusiform > 0 {
                    let angle = (t - peakPositionTricep) * CGFloat.pi
                    let curveShape = cos(angle)
                    tricepWidthFactor = 0.5 + (tricepFusiform * max(0, curveShape))
                }
                let tricepWidth = (strokeThicknessTricep / 2) * tricepWidthFactor
                
                // Determine which muscle appears on which side based on armMuscleSide
                // For left arm: + perpendicular = inner/bottom, - perpendicular = outer/top
                // For right arm: + perpendicular = outer/top, - perpendicular = inner/bottom
                let topPoint: CGPoint
                let bottomPoint: CGPoint
                
                switch armMuscleSide {
                case "flipped":
                    // Flipped: bicep on top/outer, tricep on bottom/inner
                    if isLeftArm {
                        topPoint = CGPoint(x: pos.x - perpX * bicepWidth, y: pos.y - perpY * bicepWidth)
                        bottomPoint = CGPoint(x: pos.x + perpX * tricepWidth, y: pos.y + perpY * tricepWidth)
                    } else {
                        topPoint = CGPoint(x: pos.x + perpX * bicepWidth, y: pos.y + perpY * bicepWidth)
                        bottomPoint = CGPoint(x: pos.x - perpX * tricepWidth, y: pos.y - perpY * tricepWidth)
                    }
                case "both":
                    // Both: average the widths on both sides
                    let avgWidth = (bicepWidth + tricepWidth) / 2
                    topPoint = CGPoint(x: pos.x + perpX * avgWidth, y: pos.y + perpY * avgWidth)
                    bottomPoint = CGPoint(x: pos.x - perpX * avgWidth, y: pos.y - perpY * avgWidth)
                default: // "normal"
                    // Normal: bicep on bottom/inner, tricep on top/outer
                    if isLeftArm {
                        topPoint = CGPoint(x: pos.x - perpX * tricepWidth, y: pos.y - perpY * tricepWidth)
                        bottomPoint = CGPoint(x: pos.x + perpX * bicepWidth, y: pos.y + perpY * bicepWidth)
                    } else {
                        topPoint = CGPoint(x: pos.x + perpX * tricepWidth, y: pos.y + perpY * tricepWidth)
                        bottomPoint = CGPoint(x: pos.x - perpX * bicepWidth, y: pos.y - perpY * bicepWidth)
                    }
                }
                
                topEdgePoints.append(topPoint)
                bottomEdgePoints.append(bottomPoint)
            }
            
            // Create the path
            let path = UIBezierPath()
            
            if let firstPoint = topEdgePoints.first {
                path.move(to: firstPoint)
            }
            
            // Draw top edge (tricep side) with curves
            for i in 1..<topEdgePoints.count {
                let prev = topEdgePoints[i - 1]
                let curr = topEdgePoints[i]
                
                let controlX = (prev.x + curr.x) / 2
                let controlY = (prev.y + curr.y) / 2
                let control = CGPoint(x: controlX, y: controlY)
                
                path.addQuadCurve(to: curr, controlPoint: control)
            }
            
            // Draw bottom edge (bicep side) in reverse with curves
            for i in stride(from: bottomEdgePoints.count - 1, through: 0, by: -1) {
                let curr = bottomEdgePoints[i]
                let prev = i > 0 ? bottomEdgePoints[i - 1] : curr
                
                let controlX = (curr.x + prev.x) / 2
                let controlY = (curr.y + prev.y) / 2
                let control = CGPoint(x: controlX, y: controlY)
                
                path.addQuadCurve(to: curr, controlPoint: control)
            }
            
            path.close()
            
            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = color
            shape.strokeColor = .clear
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
        
        // Helper to draw a curved tapered segment that bulges through a point
        func drawCurvedTaperedSegment(
            from: CGPoint,
            to: CGPoint,
            bulgePoint: CGPoint,
            color: SKColor,
            strokeThickness: CGFloat,
            fusiform: CGFloat,
            inverted: Bool,
            peakPosition: CGFloat = 0.2,
            in container: SKNode,
            baseCenter: CGPoint,
            scale: CGFloat
        ) {
            // Convert all points to relative coordinates
            let fromRelative = CGPoint(x: (from.x - baseCenter.x) * scale, y: (baseCenter.y - from.y) * scale)
            let toRelative = CGPoint(x: (to.x - baseCenter.x) * scale, y: (baseCenter.y - to.y) * scale)
            let bulgeRelative = CGPoint(x: (bulgePoint.x - baseCenter.x) * scale, y: (baseCenter.y - bulgePoint.y) * scale)
            
            if fusiform == 0 {
                // No tapered - just draw a curved line
                let path = UIBezierPath()
                path.move(to: fromRelative)
                path.addQuadCurve(to: toRelative, controlPoint: bulgeRelative)
                let line = SKShapeNode(path: path.cgPath)
                line.strokeColor = color
                line.lineWidth = max(strokeThickness * scale, 1.0)
                line.lineCap = .round
                line.zPosition = 1
                container.addChild(line)
                return
            }
            
            // Generate points along the quadratic bezier curve
            let numSegments = 20
            var pathPoints: [CGPoint] = []
            
            for i in 0...numSegments {
                let t = CGFloat(i) / CGFloat(numSegments)
                
                // Quadratic bezier: P(t) = (1-t)²*P0 + 2(1-t)t*P1 + t²*P2
                let mt = 1.0 - t
                let x = mt * mt * fromRelative.x + 2 * mt * t * bulgeRelative.x + t * t * toRelative.x
                let y = mt * mt * fromRelative.y + 2 * mt * t * bulgeRelative.y + t * t * toRelative.y
                pathPoints.append(CGPoint(x: x, y: y))
            }
            
            // Create tapered shape along the curve
            var topEdgePoints: [CGPoint] = []
            var bottomEdgePoints: [CGPoint] = []
            
            for i in 0..<pathPoints.count {
                let curr = pathPoints[i]
                let t = CGFloat(i) / CGFloat(numSegments)
                
                // Calculate direction at this point on the curve
                let mt = 1.0 - t
                let dxdt = 2 * mt * (bulgeRelative.x - fromRelative.x) + 2 * t * (toRelative.x - bulgeRelative.x)
                let dydt = 2 * mt * (bulgeRelative.y - fromRelative.y) + 2 * t * (toRelative.y - bulgeRelative.y)
                
                let dirLength = sqrt(dxdt * dxdt + dydt * dydt)
                guard dirLength > 0 else { continue }
                
                // Normalized direction and perpendicular
                let dirX = dxdt / dirLength
                let dirY = dydt / dirLength
                let perpX = -dirY
                let perpY = dirX
                
                // Calculate width at this point (inverted diamond taper)
                var widthFactor: CGFloat = 1.0
                
                if inverted {
                    let peakT = peakPosition
                    var distFromPeak: CGFloat
                    
                    if t <= peakT {
                        distFromPeak = (peakT - t) / peakT
                    } else {
                        distFromPeak = (t - peakT) / (1.0 - peakT)
                    }
                    
                    let easeT = max(0, 1.0 - (distFromPeak * distFromPeak))
                    widthFactor = fusiform * easeT
                } else {
                    let distFromCenter = abs(t - 0.5) * 2.0
                    widthFactor = 1.0 + (fusiform * (1.0 - distFromCenter))
                }
                
                let halfWidth = (strokeThickness / 2) * (1 + widthFactor)
                
                // Create edge points
                topEdgePoints.append(CGPoint(x: curr.x + perpX * halfWidth, y: curr.y + perpY * halfWidth))
                bottomEdgePoints.append(CGPoint(x: curr.x - perpX * halfWidth, y: curr.y - perpY * halfWidth))
            }
            
            // Draw the curved tapered shape
            if !topEdgePoints.isEmpty {
                let path = UIBezierPath()
                path.move(to: topEdgePoints[0])
                
                // Draw top edge with curves
                for i in 1..<topEdgePoints.count {
                    let prev = topEdgePoints[i - 1]
                    let curr = topEdgePoints[i]
                    
                    let controlX = (prev.x + curr.x) / 2
                    let controlY = (prev.y + curr.y) / 2
                    let control = CGPoint(x: controlX, y: controlY)
                    
                    path.addQuadCurve(to: curr, controlPoint: control)
                }
                
                // Draw bottom edge in reverse with curves
                for i in (0..<bottomEdgePoints.count).reversed() {
                    let curr = bottomEdgePoints[i]
                    let prev = i > 0 ? bottomEdgePoints[i - 1] : curr
                    
                    let controlX = (curr.x + prev.x) / 2
                    let controlY = (curr.y + prev.y) / 2
                    let control = CGPoint(x: controlX, y: controlY)
                    
                    path.addQuadCurve(to: curr, controlPoint: control)
                }
                
                path.close()
                
                let shape = SKShapeNode(path: path.cgPath)
                shape.fillColor = color
                shape.strokeColor = .clear
                shape.lineWidth = 0
                shape.zPosition = 1
                container.addChild(shape)
            }
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
            shape.strokeColor = .clear
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
        
        // Upper torso: draw straight from neck to midTorso
        drawTaperedSegment(from: neckPos, to: midTorsoPos, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessUpperTorso, fusiform: mutableFigure.fusiformUpperTorso, inverted: true, peakPosition: mutableFigure.peakPositionUpperTorso)

        // Lower torso from mid-torso
        // This keeps the lower torso connected to the visual mid-torso dot
        
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
        
        // Draw trapezius (traps) as triangular shape from neck to both shoulder joints
        // Skip if both stroke thickness and fusiform are 0
        print("🔍 TRAPEZIUS CHECK: strokeThicknessUpperTorso=\(mutableFigure.strokeThicknessUpperTorso), fusiformShoulders=\(mutableFigure.fusiformShoulders)")
        if mutableFigure.strokeThicknessUpperTorso > 0 || mutableFigure.fusiformShoulders > 0 {
            print("🔍 TRAPEZIUS: DRAWING with fusiformShoulders=\(mutableFigure.fusiformShoulders)")
            drawTrapezius(neckPos: neckPos, leftShoulderPos: leftShoulderPos, rightShoulderPos: rightShoulderPos, color: toSKColor(mutableFigure.torsoColor), strokeThickness: mutableFigure.strokeThicknessTrapezius, fusiform: mutableFigure.fusiformShoulders, peakPosition: mutableFigure.peakPositionUpperTorso, baseCenter: baseCenter, scale: scale, container: container)
        } else {
            print("🔍 TRAPEZIUS: SKIPPED (both strokeThickness and fusiform are 0)")
        }
        
        // Draw deltoids (shoulder caps) - render BEFORE upper arms so they appear behind
        // Skip if both stroke thickness and fusiform are 0
        if mutableFigure.strokeThicknessDeltoids > 0 || mutableFigure.fusiformDeltoids > 0 {
            // Left deltoid: from shoulder joint, extending down ~1/2 of upper arm, following shoulder rotation (longer for visible taper)
            let leftArmVector = CGPoint(x: leftUpperArmEnd.x - leftShoulderPos.x, y: leftUpperArmEnd.y - leftShoulderPos.y)
            let leftArmLength = sqrt(leftArmVector.x * leftArmVector.x + leftArmVector.y * leftArmVector.y)
            let leftDeltoidLength = leftArmLength * 0.5  // ~1/2 of upper arm length (increased for taper visibility)
            let leftDeltoidDir = CGPoint(x: leftArmVector.x / leftArmLength, y: leftArmVector.y / leftArmLength)
            let leftDeltoidEnd = CGPoint(x: leftShoulderPos.x + leftDeltoidDir.x * leftDeltoidLength, y: leftShoulderPos.y + leftDeltoidDir.y * leftDeltoidLength)
            // Deltoid start point: on the shoulder line, 1/3 of the way towards the neck (towards RIGHT/center for left shoulder)
            let leftDeltoidStart = CGPoint(x: leftShoulderPos.x + (neckPos.x - leftShoulderPos.x) * 0.5, y: leftShoulderPos.y)
            // Deltoid peak controlled by peakPositionDeltoids slider
            drawTaperedSegment(from: leftDeltoidStart, to: leftDeltoidEnd, color: toSKColor(mutableFigure.leftUpperArmColor), strokeThickness: mutableFigure.strokeThicknessDeltoids, fusiform: mutableFigure.fusiformDeltoids, inverted: true, peakPosition: mutableFigure.peakPositionDeltoids, legAsymmetry: "right")
            
            // Right deltoid: from shoulder joint, extending down ~1/2 of upper arm, following shoulder rotation (longer for visible taper)
            let rightArmVector = CGPoint(x: rightUpperArmEnd.x - rightShoulderPos.x, y: rightUpperArmEnd.y - rightShoulderPos.y)
            let rightArmLength = sqrt(rightArmVector.x * rightArmVector.x + rightArmVector.y * rightArmVector.y)
            let rightDeltoidLength = rightArmLength * 0.5  // ~1/2 of upper arm length (increased for taper visibility)
            let rightDeltoidDir = CGPoint(x: rightArmVector.x / rightArmLength, y: rightArmVector.y / rightArmLength)
            let rightDeltoidEnd = CGPoint(x: rightShoulderPos.x + rightDeltoidDir.x * rightDeltoidLength, y: rightShoulderPos.y + rightDeltoidDir.y * rightDeltoidLength)
            // Deltoid start point: on the shoulder line, 1/3 of the way towards the neck (towards LEFT/center for right shoulder)
            let rightDeltoidStart = CGPoint(x: rightShoulderPos.x - (rightShoulderPos.x - neckPos.x) * 0.5, y: rightShoulderPos.y)
            // Deltoid peak controlled by peakPositionDeltoids slider
            drawTaperedSegment(from: rightDeltoidStart, to: rightDeltoidEnd, color: toSKColor(mutableFigure.rightUpperArmColor), strokeThickness: mutableFigure.strokeThicknessDeltoids, fusiform: mutableFigure.fusiformDeltoids, inverted: true, peakPosition: mutableFigure.peakPositionDeltoids, legAsymmetry: "left")
        }
        
        // Draw arms - with independent bicep/tricep control
        // Control which side the muscles appear on with armMuscleSide property
        drawArmWithBicepTricep(from: leftShoulderPos, to: leftUpperArmEnd, color: toSKColor(mutableFigure.leftUpperArmColor), strokeThicknessBicep: mutableFigure.strokeThicknessBicep, strokeThicknessTricep: mutableFigure.strokeThicknessTricep, bicepFusiform: mutableFigure.fusiformBicep, tricepFusiform: mutableFigure.fusiformTricep, peakPositionBicep: mutableFigure.peakPositionBicep, peakPositionTricep: mutableFigure.peakPositionTricep, armMuscleSide: mutableFigure.armMuscleSide, isLeftArm: true)
        // Lower arms: peak position controlled by slider
        drawTaperedSegment(from: leftUpperArmEnd, to: leftForearmEnd, color: toSKColor(mutableFigure.leftLowerArmColor), strokeThickness: mutableFigure.strokeThicknessLowerArms, fusiform: mutableFigure.fusiformLowerArms, inverted: true, peakPosition: mutableFigure.peakPositionLowerArms)
        
        // Right arm: bicep on bottom (inner), tricep on top (outer)
        drawArmWithBicepTricep(from: rightShoulderPos, to: rightUpperArmEnd, color: toSKColor(mutableFigure.rightUpperArmColor), strokeThicknessBicep: mutableFigure.strokeThicknessBicep, strokeThicknessTricep: mutableFigure.strokeThicknessTricep, bicepFusiform: mutableFigure.fusiformBicep, tricepFusiform: mutableFigure.fusiformTricep, peakPositionBicep: mutableFigure.peakPositionBicep, peakPositionTricep: mutableFigure.peakPositionTricep, armMuscleSide: mutableFigure.armMuscleSide, isLeftArm: false)
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
        func drawSkeletonConnector(from: CGPoint, to: CGPoint, color: SKColor, skeletonSizeMultiplier: CGFloat) {
            let lineWidth = max(mutableFigure.strokeThicknessJoints * 0.8 * scale * skeletonSizeMultiplier, 1.0)
            print("🦴 Drawing skeleton connector: lineWidth=\(lineWidth), skeletonSize=\(skeletonSizeMultiplier), jointThickness=\(mutableFigure.strokeThicknessJoints), scale=\(scale)")
            
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
        let torsoLineWidth = max(mutableFigure.strokeThicknessFullTorso * 0.8 * scale * mutableFigure.skeletonSizeTorso, 1.0)
        let neckRelative = toRelative(neckPos)
        let midTorsoRelative = toRelative(midTorsoPos)
        let waistRelative = toRelative(waistPos)

        let torsoPath = UIBezierPath()
        
        // Upper torso segment: neck to midtorso
        torsoPath.move(to: neckRelative)
        torsoPath.addLine(to: midTorsoRelative)
        
        // Lower torso segment: midtorso (PINNED, no offset) to waist
        torsoPath.addLine(to: midTorsoRelative)
        torsoPath.addLine(to: waistRelative)
        
        let torsoLine = SKShapeNode(path: torsoPath.cgPath)
        torsoLine.strokeColor = toSKColor(mutableFigure.torsoColor)
        torsoLine.lineWidth = torsoLineWidth
        torsoLine.lineCap = .round
        torsoLine.lineJoin = .round
        torsoLine.zPosition = 1.5
        container.addChild(torsoLine)
        
        // LEFT LEG connectors: Use their respective leg colors and skeletonSizeLeg
        drawSkeletonConnector(from: leftHipPos, to: leftUpperLegMid, color: toSKColor(mutableFigure.leftUpperLegColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeLeg)
        drawSkeletonConnector(from: leftUpperLegMid, to: leftUpperLegEnd, color: toSKColor(mutableFigure.leftUpperLegColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeLeg)
        drawSkeletonConnector(from: leftUpperLegEnd, to: leftLowerLegMid, color: toSKColor(mutableFigure.leftLowerLegColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeLeg)
        
        // RIGHT LEG connectors: Use their respective leg colors and skeletonSizeLeg
        drawSkeletonConnector(from: rightHipPos, to: rightUpperLegMid, color: toSKColor(mutableFigure.rightUpperLegColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeLeg)
        drawSkeletonConnector(from: rightUpperLegMid, to: rightUpperLegEnd, color: toSKColor(mutableFigure.rightUpperLegColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeLeg)
        drawSkeletonConnector(from: rightUpperLegEnd, to: rightLowerLegMid, color: toSKColor(mutableFigure.rightLowerLegColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeLeg)
        
        // LEFT ARM connectors: Use their respective arm colors and skeletonSizeArm
        drawSkeletonConnector(from: leftShoulderPos, to: leftUpperArmMid, color: toSKColor(mutableFigure.leftUpperArmColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeArm)
        drawSkeletonConnector(from: leftUpperArmMid, to: leftUpperArmEnd, color: toSKColor(mutableFigure.leftUpperArmColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeArm)
        drawSkeletonConnector(from: leftUpperArmEnd, to: leftLowerArmMid, color: toSKColor(mutableFigure.leftLowerArmColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeArm)
        
        // RIGHT ARM connectors: Use their respective arm colors and skeletonSizeArm
        drawSkeletonConnector(from: rightShoulderPos, to: rightUpperArmMid, color: toSKColor(mutableFigure.rightUpperArmColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeArm)
        drawSkeletonConnector(from: rightUpperArmMid, to: rightUpperArmEnd, color: toSKColor(mutableFigure.rightUpperArmColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeArm)
        drawSkeletonConnector(from: rightUpperArmEnd, to: rightLowerArmMid, color: toSKColor(mutableFigure.rightLowerArmColor), skeletonSizeMultiplier: mutableFigure.skeletonSizeArm)
        
        // Add joint caps at connection points to fill gaps (elbows, knees, waist, shoulders)
        let jointCapRadius = mutableFigure.strokeThicknessJoints * 0.3 * scale * jointShapeSize
        
        // Only draw joint caps if radius > 0 (when both strokeThicknessJoints and jointShapeSize > 0)
        guard jointCapRadius > 0 else {
            print("🎮 Stick figure rendered with \(container.children.count) nodes!")
            return container
        }
        
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
    
    // MARK: - Trapezius Drawing
    func drawTrapezius(neckPos: CGPoint, leftShoulderPos: CGPoint, rightShoulderPos: CGPoint, color: SKColor, strokeThickness: CGFloat, fusiform: CGFloat, peakPosition: CGFloat, baseCenter: CGPoint, scale: CGFloat, container: SKNode) {
        // Draw TWO triangular trapezius muscles (left and right)
        // Each triangle is pinned to:
        //   - Top corner: top of neck
        //   - Bottom corner: bottom of neck
        //   - Far corner: left or right shoulder joint
        // The fusiform slider controls the HEIGHT up the neck (how far the triangles extend)
        // The long edge (along the neck) should be slightly curved
        
        print("🔍 drawTrapezius called: fusiform=\(fusiform), strokeThickness=\(strokeThickness), scale=\(scale)")
        
        // Convert to relative coordinates
        let neckRelative = CGPoint(x: (neckPos.x - baseCenter.x) * scale, y: (baseCenter.y - neckPos.y) * scale)
        let leftShoulderRelative = CGPoint(x: (leftShoulderPos.x - baseCenter.x) * scale, y: (baseCenter.y - leftShoulderPos.y) * scale)
        let rightShoulderRelative = CGPoint(x: (rightShoulderPos.x - baseCenter.x) * scale, y: (baseCenter.y - rightShoulderPos.y) * scale)
        
        // Calculate the applied stroke thickness
        let appliedStrokeThickness = max(strokeThickness * scale, 0.5)
        
        // The neck has a visual height - we need to estimate top and bottom based on neckWidth and strokeThicknessUpperTorso
        // The bottom of the neck is at neckPos
        // The top of the neck is offset upward by the neck length
        let neckHeight = 20 * scale  // Approximate neck height based on typical neck proportions
        let neckTopRelative = CGPoint(x: neckRelative.x, y: neckRelative.y + neckHeight)
        let neckBottomRelative = neckRelative  // Bottom of neck
        
        // Fusiform controls how far UP the neck the triangles extend
        // fusiform = 0: triangles don't appear (or very minimal)
        // fusiform = 10: triangles extend full height from bottom to top of neck
        let heightFactor = min(fusiform / 10.0, 1.0)  // Normalize to 0.0 to 1.0
        
        // Calculate the actual top point based on height factor
        let actualNeckTop = CGPoint(
            x: neckRelative.x,
            y: neckBottomRelative.y + (neckTopRelative.y - neckBottomRelative.y) * heightFactor
        )
        
        print("🔍 drawTrapezius: neckTop=\(actualNeckTop), neckBottom=\(neckBottomRelative), leftShoulder=\(leftShoulderRelative), heightFactor=\(heightFactor)")
        
        // LEFT TRAPEZIUS TRIANGLE
        // Vertices: actualNeckTop, neckBottomRelative, leftShoulderRelative
        let leftPath = UIBezierPath()
        leftPath.move(to: actualNeckTop)
        
        // Left side: from neck top to shoulder (straight line)
        leftPath.addLine(to: leftShoulderRelative)
        
        // Bottom: from shoulder to neck bottom (straight line)
        leftPath.addLine(to: neckBottomRelative)
        
        // Right side: from neck bottom to neck top with pronounced inward curve
        let neckMidpoint = CGPoint(
            x: (neckBottomRelative.x + actualNeckTop.x) / 2.0,
            y: (neckBottomRelative.y + actualNeckTop.y) / 2.0
        )
        // Bulge the neck edge inward (toward center) with pronounced curve
        let neckCurveControl = CGPoint(
            x: neckMidpoint.x + 12.0 * scale,  // More pronounced bulge inward
            y: neckMidpoint.y
        )
        leftPath.addQuadCurve(to: actualNeckTop, controlPoint: neckCurveControl)
        leftPath.close()
        
        let leftShape = SKShapeNode(path: leftPath.cgPath)
        leftShape.fillColor = color
        leftShape.strokeColor = color
        leftShape.lineWidth = appliedStrokeThickness
        leftShape.zPosition = 1
        container.addChild(leftShape)
        
        // RIGHT TRAPEZIUS TRIANGLE
        // Vertices: actualNeckTop, neckBottomRelative, rightShoulderRelative
        let rightPath = UIBezierPath()
        rightPath.move(to: actualNeckTop)
        
        // Right side: from neck top to shoulder (straight line)
        rightPath.addLine(to: rightShoulderRelative)
        
        // Bottom: from shoulder to neck bottom (straight line)
        rightPath.addLine(to: neckBottomRelative)
        
        // Left side: from neck bottom to neck top with pronounced inward curve
        let rightNeckCurveControl = CGPoint(
            x: neckMidpoint.x - 12.0 * scale,  // More pronounced bulge inward
            y: neckMidpoint.y
        )
        rightPath.addQuadCurve(to: actualNeckTop, controlPoint: rightNeckCurveControl)
        rightPath.close()
        
        let rightShape = SKShapeNode(path: rightPath.cgPath)
        rightShape.fillColor = color
        rightShape.strokeColor = color
        rightShape.lineWidth = appliedStrokeThickness
        rightShape.zPosition = 1
        container.addChild(rightShape)
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
