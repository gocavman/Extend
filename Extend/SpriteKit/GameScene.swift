import SpriteKit
import GameplayKit
import SwiftUI

/// Base scene class for all game scenes with touch handling
class GameScene: SKScene {
    var gameState: StickFigureGameState?
    var gameViewController: GameViewController?
    
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
            let locationInScene = convertViewToScene(locationInView)
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
            let locationInScene = convertViewToScene(locationInView)
            handleTouchMoved(to: locationInScene)
        }
    }
    
    /// Convert view coordinates to scene coordinates
    /// View: (0,0) at top-left, grows right and down
    /// Scene: (0,0) at bottom-left, grows right and up
    private func convertViewToScene(_ viewPoint: CGPoint) -> CGPoint {
        guard let view = self.view else { return viewPoint }
        
        let viewBounds = view.bounds
        
        // Normalize view coordinates to 0-1 range
        let normalizedX = viewPoint.x / viewBounds.width
        let normalizedY = viewPoint.y / viewBounds.height
        
        // Convert to scene coordinates (flip Y because scene is bottom-left origin)
        let sceneX = normalizedX * self.size.width
        let sceneY = (1.0 - normalizedY) * self.size.height  // Flip Y
        
        let scenePoint = CGPoint(x: sceneX, y: sceneY)
        print("📍 convertViewToScene - view: \(viewPoint), bounds: \(viewBounds), scene: \(scenePoint), sceneSize: \(self.size)")
        return scenePoint
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view else {
            print("⚠️ TouchesEnded: view is nil")
            return
        }
        for touch in touches {
            let locationInView = touch.location(in: view)
            let locationInScene = convertViewToScene(locationInView)
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

    func renderStickFigure(_ figure: StickFigure2D, at position: CGPoint, scale: CGFloat = 1.0, flipped: Bool = false, jointShapeSize: CGFloat = 1.0) -> SKNode {
        return renderStickFigureV2(figure, at: position, scale: scale, flipped: flipped, jointShapeSize: jointShapeSize)
    }

    // MARK: - V2 Unified Renderer

    func renderStickFigureV2(_ figure: StickFigure2D, at position: CGPoint, scale: CGFloat = 1.0, flipped: Bool = false, jointShapeSize: CGFloat = 1.0) -> SKNode {
        var mutableFigure = figure
        let container = SKNode()
        container.position = position
        container.xScale = flipped ? -1 : 1
        StickFigureAppearance.shared.applyToStickFigure(&mutableFigure)

        let baseCenter = CGPoint(x: 300, y: 360)

        func rel(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - baseCenter.x) * scale, y: (baseCenter.y - p.y) * scale)
        }
        func toSKColorV2(_ color: Color) -> SKColor { UIColor(color) }

        // Semantic muscle scales: slider range 0–10 maps directly to 0–1
        let muscleScale    = CGFloat(min(max(mutableFigure.fusiformBicep    / 10.0, 0.0), 1.0))
        let legMuscleScale = CGFloat(min(max(mutableFigure.fusiformUpperLegs / 10.0, 0.0), 1.0))

        // Separate base half-thicknesses for torso, arms, and legs
        let torsoBaseHalf = mutableFigure.strokeThickness       * scale * 0.5
        let armBaseHalf   = mutableFigure.strokeThicknessBicep  * scale * 0.5
        let legBaseHalf   = mutableFigure.strokeThicknessUpperLegs * scale * 0.5
        // Legacy alias used by neck/hand/foot sizing
        let baseHalf = torsoBaseHalf

        // ---- Unified bent-limb helper ----
        // Draws shoulder→elbow→wrist (or hip→knee→ankle) as one continuous filled shape.
        func drawUnifiedLimb(
            start: CGPoint, mid: CGPoint, end: CGPoint,
            startHalf: CGFloat, midHalf: CGFloat, endHalf: CGFloat,
            upperBulge: CGFloat, upperBulgePeak: CGFloat = 0.38,
            color: SKColor, zPos: CGFloat = 1.0
        ) {
            let s = rel(start), m = rel(mid), e = rel(end)

            let uaDx = m.x - s.x, uaDy = m.y - s.y
            let uaLen = hypot(uaDx, uaDy)
            guard uaLen > 0 else { return }
            let uaDir = CGPoint(x: uaDx / uaLen, y: uaDy / uaLen)
            let uaPerp = CGPoint(x: -uaDir.y, y: uaDir.x)

            let laDx = e.x - m.x, laDy = e.y - m.y
            let laLen = hypot(laDx, laDy)
            guard laLen > 0 else { return }
            let laDir = CGPoint(x: laDx / laLen, y: laDy / laLen)
            let laPerp = CGPoint(x: -laDir.y, y: laDir.x)

            // Bisector perpendicular at joint for a smooth continuous corner
            let bisX = uaDir.x + laDir.x, bisY = uaDir.y + laDir.y
            let bisLen = hypot(bisX, bisY)
            let jointPerp = bisLen > 0.01 ? CGPoint(x: -bisY / bisLen, y: bisX / bisLen) : uaPerp

            let N = 20
            var leftEdge: [CGPoint] = []
            var rightEdge: [CGPoint] = []

            for i in 0 ... N {
                let t = CGFloat(i) / CGFloat(N)
                let p = CGPoint(x: s.x + uaDir.x * uaLen * t, y: s.y + uaDir.y * uaLen * t)
                let baseW = startHalf + (midHalf - startHalf) * t
                let bRaw: CGFloat = t < upperBulgePeak
                    ? t / max(upperBulgePeak, 0.01)
                    : 1.0 - (t - upperBulgePeak) / max(1.0 - upperBulgePeak, 0.01)
                let w = baseW + upperBulge * max(0, bRaw)
                let perp = (i == N) ? jointPerp : uaPerp
                leftEdge.append(CGPoint(x: p.x + perp.x * w, y: p.y + perp.y * w))
                rightEdge.append(CGPoint(x: p.x - perp.x * w, y: p.y - perp.y * w))
            }
            for i in 1 ... N {
                let t = CGFloat(i) / CGFloat(N)
                let p = CGPoint(x: m.x + laDir.x * laLen * t, y: m.y + laDir.y * laLen * t)
                let w = midHalf + (endHalf - midHalf) * t
                leftEdge.append(CGPoint(x: p.x + laPerp.x * w, y: p.y + laPerp.y * w))
                rightEdge.append(CGPoint(x: p.x - laPerp.x * w, y: p.y - laPerp.y * w))
            }

            guard let firstPt = leftEdge.first else { return }
            let path = UIBezierPath()
            path.move(to: firstPt)
            for i in 1 ..< leftEdge.count {
                let prev = leftEdge[i - 1], curr = leftEdge[i]
                path.addQuadCurve(to: curr, controlPoint: CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2))
            }
            for i in stride(from: rightEdge.count - 1, through: 0, by: -1) {
                let curr = rightEdge[i]
                let nxt = i < rightEdge.count - 1 ? rightEdge[i + 1] : curr
                path.addQuadCurve(to: curr, controlPoint: CGPoint(x: (nxt.x + curr.x) / 2, y: (nxt.y + curr.y) / 2))
            }
            path.close()

            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = color
            shape.strokeColor = .clear
            shape.lineWidth = 0
            shape.zPosition = zPos
            container.addChild(shape)
        }

        // ---- Unified torso trapezoid ----
        func drawUnifiedTorso(
            leftShoulder: CGPoint, rightShoulder: CGPoint,
            waist: CGPoint, leftHip: CGPoint, rightHip: CGPoint,
            latFlare: CGFloat, waistIn: CGFloat,
            sideExpansion: CGFloat,   // extra outward expansion on each side (driven by baseHalf)
            color: SKColor, zPos: CGFloat = 1.5
        ) {
            var ls = rel(leftShoulder)
            var rs = rel(rightShoulder)
            var lh = rel(leftHip)
            var rh = rel(rightHip)

            // Collapse all four points to the torso center axis, then expand outward
            // by sideExpansion — so at bodyWidth=1 the torso is a slim vertical strip,
            // and it widens proportionally as the slider increases.
            let shoulderMidX = (ls.x + rs.x) / 2
            let hipMidX      = (lh.x + rh.x) / 2

            let sdx = rs.x - ls.x, sdy = rs.y - ls.y
            let sLen = hypot(sdx, sdy)
            if sLen > 0 {
                let sn = CGPoint(x: sdx / sLen, y: sdy / sLen)
                ls = CGPoint(x: shoulderMidX - sn.x * sideExpansion, y: ls.y)
                rs = CGPoint(x: shoulderMidX + sn.x * sideExpansion, y: rs.y)
            }
            let hdx = rh.x - lh.x, hdy = rh.y - lh.y
            let hLen = hypot(hdx, hdy)
            if hLen > 0 {
                let hn = CGPoint(x: hdx / hLen, y: hdy / hLen)
                lh = CGPoint(x: hipMidX - hn.x * sideExpansion * 0.85, y: lh.y)
                rh = CGPoint(x: hipMidX + hn.x * sideExpansion * 0.85, y: rh.y)
            }

            let shoulderHalfW = abs(rs.x - ls.x) / 2
            let torsoMidX = (ls.x + rs.x) / 2
            let topY = (ls.y + rs.y) / 2
            let botY = (lh.y + rh.y) / 2
            let latY   = topY + (botY - topY) * 0.35
            let waistY = topY + (botY - topY) * 0.62

            let rightLatCP   = CGPoint(x: rs.x + shoulderHalfW * latFlare * 0.7, y: latY)
            let rightWaistCP = CGPoint(x: torsoMidX + shoulderHalfW * max(0.25, 0.55 - waistIn * 0.35), y: waistY)
            let leftLatCP    = CGPoint(x: ls.x - shoulderHalfW * latFlare * 0.7, y: latY)
            let leftWaistCP  = CGPoint(x: torsoMidX - shoulderHalfW * max(0.25, 0.55 - waistIn * 0.35), y: waistY)

            let path = UIBezierPath()
            path.move(to: ls)
            path.addLine(to: rs)
            path.addCurve(to: rh, controlPoint1: rightLatCP, controlPoint2: rightWaistCP)
            path.addLine(to: lh)
            path.addCurve(to: ls, controlPoint1: leftWaistCP, controlPoint2: leftLatCP)
            path.close()

            let shape = SKShapeNode(path: path.cgPath)
            shape.fillColor = color
            shape.strokeColor = .clear
            shape.lineWidth = 0
            shape.zPosition = zPos
            container.addChild(shape)
        }

        // ---- Joint positions ----
        let waistPos        = mutableFigure.waistPosition
        let neckPos         = mutableFigure.neckPosition
        let headPos         = mutableFigure.headPosition
        let leftShoulderPos  = mutableFigure.leftShoulderPosition
        let rightShoulderPos = mutableFigure.rightShoulderPosition
        let leftUpperArmEnd  = mutableFigure.leftUpperArmEnd
        let rightUpperArmEnd = mutableFigure.rightUpperArmEnd
        let leftForearmEnd   = mutableFigure.leftForearmEnd
        let rightForearmEnd  = mutableFigure.rightForearmEnd
        let leftHipPos       = mutableFigure.leftHipPosition
        let rightHipPos      = mutableFigure.rightHipPosition
        let leftUpperLegEnd  = mutableFigure.leftUpperLegEnd
        let rightUpperLegEnd = mutableFigure.rightUpperLegEnd
        let leftFootEnd      = mutableFigure.leftFootEnd
        let rightFootEnd     = mutableFigure.rightFootEnd

        let bodyColor   = toSKColorV2(mutableFigure.torsoColor)
        let leftArmCol  = toSKColorV2(mutableFigure.leftUpperArmColor)
        let rightArmCol = toSKColorV2(mutableFigure.rightUpperArmColor)
        let leftLegCol  = toSKColorV2(mutableFigure.leftUpperLegColor)
        let rightLegCol = toSKColorV2(mutableFigure.rightUpperLegColor)

        // ---- Width parameters ----
        let armShoulderHalf = armBaseHalf * (1.1 + muscleScale * 0.6)
        let armElbowHalf    = armBaseHalf * (0.65 + muscleScale * 0.15)
        let armWristHalf    = armBaseHalf * 0.48
        let armBulge        = armBaseHalf * muscleScale * 1.4

        let legHipHalf   = legBaseHalf * (1.3 + legMuscleScale * 0.7)
        let legKneeHalf  = legBaseHalf * (0.85 + legMuscleScale * 0.2)
        let legAnkleHalf = legBaseHalf * (0.55 + legMuscleScale * 0.1)   // grows slightly with leg width
        let legBulge     = legBaseHalf * legMuscleScale * 1.2

        // ---- Draw: back to front ----

        // Legs
        drawUnifiedLimb(start: leftHipPos, mid: leftUpperLegEnd, end: leftFootEnd,
                        startHalf: legHipHalf, midHalf: legKneeHalf, endHalf: legAnkleHalf,
                        upperBulge: legBulge, upperBulgePeak: 0.4,
                        color: leftLegCol, zPos: 1.0)
        drawUnifiedLimb(start: rightHipPos, mid: rightUpperLegEnd, end: rightFootEnd,
                        startHalf: legHipHalf, midHalf: legKneeHalf, endHalf: legAnkleHalf,
                        upperBulge: legBulge, upperBulgePeak: 0.4,
                        color: rightLegCol, zPos: 1.0)

        // Torso
        drawUnifiedTorso(leftShoulder: leftShoulderPos, rightShoulder: rightShoulderPos,
                         waist: waistPos, leftHip: leftHipPos, rightHip: rightHipPos,
                         latFlare: muscleScale * 0.45, waistIn: max(0, 0.4 - muscleScale * 0.15),
                         sideExpansion: torsoBaseHalf * 5.0,
                         color: bodyColor, zPos: 1.5)

        // Shoulder crossbar — connects left and right shoulder, visible when torso is slim
        let crossbarWidth = max(torsoBaseHalf * 1.2, 1.5)
        let shoulderBar = UIBezierPath()
        shoulderBar.move(to: rel(leftShoulderPos))
        shoulderBar.addLine(to: rel(rightShoulderPos))
        let shoulderBarNode = SKShapeNode(path: shoulderBar.cgPath)
        shoulderBarNode.strokeColor = bodyColor
        shoulderBarNode.lineWidth = crossbarWidth * 2
        shoulderBarNode.lineCap = .round
        shoulderBarNode.zPosition = 1.55
        container.addChild(shoulderBarNode)

        // Hip crossbar — connects left and right hip
        let hipBar = UIBezierPath()
        hipBar.move(to: rel(leftHipPos))
        hipBar.addLine(to: rel(rightHipPos))
        let hipBarNode = SKShapeNode(path: hipBar.cgPath)
        hipBarNode.strokeColor = bodyColor
        hipBarNode.lineWidth = crossbarWidth * 2
        hipBarNode.lineCap = .round
        hipBarNode.zPosition = 1.55
        container.addChild(hipBarNode)

        // Shoulder caps — smooth seam between torso and arms
        let shoulderCapR = armShoulderHalf * 1.05
        for pos in [leftShoulderPos, rightShoulderPos] {
            let cap = SKShapeNode(circleOfRadius: shoulderCapR)
            cap.fillColor = bodyColor
            cap.strokeColor = .clear
            cap.lineWidth = 0
            cap.position = rel(pos)
            cap.zPosition = 1.6
            container.addChild(cap)
        }

        // Hip caps — smooth seam between torso and legs
        let hipCapR = legHipHalf * 1.05
        for pos in [leftHipPos, rightHipPos] {
            let cap = SKShapeNode(circleOfRadius: hipCapR)
            cap.fillColor = bodyColor
            cap.strokeColor = .clear
            cap.lineWidth = 0
            cap.position = rel(pos)
            cap.zPosition = 1.4
            container.addChild(cap)
        }

        // Neck — tapered rectangle, extended slightly into torso so there's no gap
        let headCanvasRadius = mutableFigure.headRadius * 1.2
        let neckHalfWide   = mutableFigure.neckWidth * scale * (0.5 + muscleScale * 0.15)
        let neckHalfNarrow = mutableFigure.neckWidth * scale * 0.38
        let neckRel = rel(neckPos)
        let headRel = rel(headPos)
        let nkDx = headRel.x - neckRel.x, nkDy = headRel.y - neckRel.y
        let nkLen = hypot(nkDx, nkDy)
        if nkLen > 0 {
            let nDir  = CGPoint(x: nkDx / nkLen, y: nkDy / nkLen)
            let nPerp = CGPoint(x: -nDir.y, y: nDir.x)
            let neckBot = CGPoint(x: neckRel.x - nDir.x * baseHalf * 0.8, y: neckRel.y - nDir.y * baseHalf * 0.8)
            let nkPath = UIBezierPath()
            nkPath.move(to: CGPoint(x: neckBot.x + nPerp.x * neckHalfWide, y: neckBot.y + nPerp.y * neckHalfWide))
            nkPath.addLine(to: CGPoint(x: headRel.x + nPerp.x * neckHalfNarrow, y: headRel.y + nPerp.y * neckHalfNarrow))
            nkPath.addLine(to: CGPoint(x: headRel.x - nPerp.x * neckHalfNarrow, y: headRel.y - nPerp.y * neckHalfNarrow))
            nkPath.addLine(to: CGPoint(x: neckBot.x - nPerp.x * neckHalfWide, y: neckBot.y - nPerp.y * neckHalfWide))
            nkPath.close()
            let nkShape = SKShapeNode(path: nkPath.cgPath)
            nkShape.fillColor = bodyColor
            nkShape.strokeColor = .clear
            nkShape.lineWidth = 0
            nkShape.zPosition = 2.5
            container.addChild(nkShape)
        }

        // Arms
        drawUnifiedLimb(start: leftShoulderPos, mid: leftUpperArmEnd, end: leftForearmEnd,
                        startHalf: armShoulderHalf, midHalf: armElbowHalf, endHalf: armWristHalf,
                        upperBulge: armBulge, upperBulgePeak: 0.38,
                        color: leftArmCol, zPos: 2.0)
        drawUnifiedLimb(start: rightShoulderPos, mid: rightUpperArmEnd, end: rightForearmEnd,
                        startHalf: armShoulderHalf, midHalf: armElbowHalf, endHalf: armWristHalf,
                        upperBulge: armBulge, upperBulgePeak: 0.38,
                        color: rightArmCol, zPos: 2.0)

        // Head
        let headSceneRadius = headCanvasRadius * scale
        let headCircle = SKShapeNode(circleOfRadius: headSceneRadius)
        headCircle.fillColor = SKColor(mutableFigure.headColor)
        headCircle.strokeColor = .clear
        headCircle.lineWidth = 0
        headCircle.position = headRel
        headCircle.zPosition = 3.0
        container.addChild(headCircle)

        // Eyes
        if mutableFigure.eyesEnabled {
            let eyeSceneR  = headSceneRadius * 0.3
            let irisSceneR = eyeSceneR * 0.5
            let eyeVertOff: CGFloat = headCanvasRadius * 0.1   // canvas space → converted via rel()
            let eyeColor  = SKColor(mutableFigure.eyeColor)
            let irisColor = mutableFigure.irisEnabled ? SKColor(mutableFigure.irisColor) : nil

            func addEye(at canvasPos: CGPoint) {
                let ep = rel(canvasPos)
                let eye = SKShapeNode(circleOfRadius: eyeSceneR)
                eye.fillColor = eyeColor; eye.strokeColor = .clear
                eye.position = ep; eye.zPosition = 3.5
                container.addChild(eye)
                if let ic = irisColor {
                    let iris = SKShapeNode(circleOfRadius: irisSceneR)
                    iris.fillColor = ic; iris.strokeColor = .clear
                    iris.position = ep; iris.zPosition = 3.6
                    container.addChild(iris)
                }
            }
            if mutableFigure.isSideView {
                addEye(at: CGPoint(x: headPos.x + headCanvasRadius * 0.45, y: headPos.y + eyeVertOff))
            } else {
                let hs = headCanvasRadius * 0.3
                addEye(at: CGPoint(x: headPos.x - hs, y: headPos.y + eyeVertOff))
                addEye(at: CGPoint(x: headPos.x + hs, y: headPos.y + eyeVertOff))
            }
        }

        // Hands — independent of torso/arm width, driven purely by handSize slider
        let handSceneR = scale * mutableFigure.handSize * 2.2
        let handColor  = toSKColorV2(mutableFigure.handColor)
        for pos in [leftForearmEnd, rightForearmEnd] {
            let h = SKShapeNode(circleOfRadius: handSceneR)
            h.fillColor = handColor; h.strokeColor = .clear
            h.position = rel(pos); h.zPosition = 2.5
            container.addChild(h)
        }

        // Feet — independent of torso/leg width, driven purely by footSize slider
        let footSceneR = scale * mutableFigure.footSize * 2.8
        let footColor  = toSKColorV2(mutableFigure.footColor)
        for pos in [leftFootEnd, rightFootEnd] {
            let f = SKShapeNode(circleOfRadius: footSceneR)
            f.fillColor = footColor; f.strokeColor = .clear
            f.position = rel(pos); f.zPosition = 1.5
            container.addChild(f)
        }

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
    
    /// Convert hex color string (e.g., "#6F4E37") to SKColor
    func hexToColor(_ hex: String) -> SKColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized
        
        // Default to gray if invalid
        guard hexSanitized.count == 6 else {
            return SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        }
        
        let scanner = Scanner(string: hexSanitized)
        var hexNumber: UInt64 = 0
        
        guard scanner.scanHexInt64(&hexNumber) else {
            return SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        }
        
        let red = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hexNumber & 0x0000FF) / 255.0
        
        return SKColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
