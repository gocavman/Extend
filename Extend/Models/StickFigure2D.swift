import SwiftUI
import Combine
import PhotosUI

// MARK: - Saveable Animation Frame

struct AnimationFrame: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let frameNumber: Int
    let pose: StickFigure2DPose
    let objects: [AnimationObject]  // Objects associated with this frame
    let createdAt: Date
    
    init(name: String, frameNumber: Int, pose: StickFigure2D, objects: [AnimationObject] = []) {
        self.id = UUID()
        self.name = name
        self.frameNumber = frameNumber
        self.pose = StickFigure2DPose(from: pose)
        self.objects = objects
        self.createdAt = Date()
    }
    
    init(id: UUID, name: String, frameNumber: Int, pose: StickFigure2D, objects: [AnimationObject] = []) {
        self.id = id
        self.name = name
        self.frameNumber = frameNumber
        self.pose = StickFigure2DPose(from: pose)
        self.objects = objects
        self.createdAt = Date()
    }
    
    // Custom decoding to handle old JSON without objects field
    enum CodingKeys: String, CodingKey {
        case id, name, frameNumber, pose, objects, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        frameNumber = try container.decode(Int.self, forKey: .frameNumber)
        pose = try container.decode(StickFigure2DPose.self, forKey: .pose)
        // objects is optional - if not present, default to empty array
        objects = try container.decodeIfPresent([AnimationObject].self, forKey: .objects) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    // Equatable conformance
    static func == (lhs: AnimationFrame, rhs: AnimationFrame) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.frameNumber == rhs.frameNumber
    }
}

// MARK: - Animation Objects

struct AnimationObject: Codable, Identifiable, Equatable {
    let id: UUID
    var imageName: String
    var position: CGPoint
    var rotation: Double // in degrees
    var scale: Double
    
    init(imageName: String, position: CGPoint, rotation: Double = 0, scale: Double = 1.0) {
        self.id = UUID()
        self.imageName = imageName
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}

struct StickFigure2DPose: Codable {
    let waistPosition: CGPoint  // Add waist position
    let waistTorsoAngle: Double
    let midTorsoAngle: Double
    let headAngle: Double
    let leftShoulderAngle: Double
    let rightShoulderAngle: Double
    let leftElbowAngle: Double
    let rightElbowAngle: Double
    let leftHandAngle: Double
    let rightHandAngle: Double
    let leftKneeAngle: Double
    let rightKneeAngle: Double
    let leftFootAngle: Double
    let rightFootAngle: Double
    let headColor: String
    let torsoColor: String
    let leftArmColor: String
    let rightArmColor: String
    let leftLegColor: String
    let rightLegColor: String
    let handColor: String
    let footColor: String
    let strokeThickness: CGFloat
    let scale: Double
    let headRadiusMultiplier: Double
    
    init(from figure: StickFigure2D) {
        self.waistPosition = figure.waistPosition  // Save waist position
        self.waistTorsoAngle = figure.waistTorsoAngle
        self.midTorsoAngle = figure.midTorsoAngle
        self.headAngle = figure.headAngle
        self.leftShoulderAngle = figure.leftShoulderAngle
        self.rightShoulderAngle = figure.rightShoulderAngle
        self.leftElbowAngle = figure.leftElbowAngle
        self.rightElbowAngle = figure.rightElbowAngle
        self.leftHandAngle = figure.leftHandAngle
        self.rightHandAngle = figure.rightHandAngle
        self.leftKneeAngle = figure.leftKneeAngle
        self.rightKneeAngle = figure.rightKneeAngle
        self.leftFootAngle = figure.leftFootAngle
        self.rightFootAngle = figure.rightFootAngle
        self.headColor = figure.headColor.toHex()
        self.torsoColor = figure.torsoColor.toHex()
        self.leftArmColor = figure.leftArmColor.toHex()
        self.rightArmColor = figure.rightArmColor.toHex()
        self.leftLegColor = figure.leftLegColor.toHex()
        self.rightLegColor = figure.rightLegColor.toHex()
        self.handColor = figure.handColor.toHex()
        self.footColor = figure.footColor.toHex()
        self.strokeThickness = figure.strokeThickness
        self.scale = figure.scale
        self.headRadiusMultiplier = figure.headRadiusMultiplier
    }
    
    func toStickFigure2D() -> StickFigure2D {
        var figure = StickFigure2D()
        figure.waistPosition = waistPosition  // Restore waist position
        figure.waistTorsoAngle = waistTorsoAngle
        figure.midTorsoAngle = midTorsoAngle
        figure.headAngle = headAngle
        figure.leftShoulderAngle = leftShoulderAngle
        figure.rightShoulderAngle = rightShoulderAngle
        figure.leftElbowAngle = leftElbowAngle
        figure.rightElbowAngle = rightElbowAngle
        figure.leftHandAngle = leftHandAngle
        figure.rightHandAngle = rightHandAngle
        figure.leftKneeAngle = leftKneeAngle
        figure.rightKneeAngle = rightKneeAngle
        figure.leftFootAngle = leftFootAngle
        figure.rightFootAngle = rightFootAngle
        figure.headColor = Color(hex: headColor) ?? .black
        figure.torsoColor = Color(hex: torsoColor) ?? .black
        figure.leftArmColor = Color(hex: leftArmColor) ?? .black
        figure.rightArmColor = Color(hex: rightArmColor) ?? .black
        figure.leftLegColor = Color(hex: leftLegColor) ?? .black
        figure.rightLegColor = Color(hex: rightLegColor) ?? .black
        figure.handColor = Color(hex: handColor) ?? .black
        figure.footColor = Color(hex: footColor) ?? .black
        figure.strokeThickness = strokeThickness
        figure.scale = scale
        figure.headRadiusMultiplier = headRadiusMultiplier
        return figure
    }
    
    // Custom Codable to handle CGPoint
    enum CodingKeys: String, CodingKey {
        case waistPositionX, waistPositionY
        case waistTorsoAngle, midTorsoAngle, headAngle
        case leftShoulderAngle, rightShoulderAngle
        case leftElbowAngle, rightElbowAngle
        case leftHandAngle, rightHandAngle
        case leftKneeAngle, rightKneeAngle
        case leftFootAngle, rightFootAngle
        case headColor, torsoColor, leftArmColor, rightArmColor
        case leftLegColor, rightLegColor, handColor, footColor
        case strokeThickness, scale, headRadiusMultiplier
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(waistPosition.x, forKey: .waistPositionX)
        try container.encode(waistPosition.y, forKey: .waistPositionY)
        try container.encode(waistTorsoAngle, forKey: .waistTorsoAngle)
        try container.encode(midTorsoAngle, forKey: .midTorsoAngle)
        try container.encode(headAngle, forKey: .headAngle)
        try container.encode(leftShoulderAngle, forKey: .leftShoulderAngle)
        try container.encode(rightShoulderAngle, forKey: .rightShoulderAngle)
        try container.encode(leftElbowAngle, forKey: .leftElbowAngle)
        try container.encode(rightElbowAngle, forKey: .rightElbowAngle)
        try container.encode(leftHandAngle, forKey: .leftHandAngle)
        try container.encode(rightHandAngle, forKey: .rightHandAngle)
        try container.encode(leftKneeAngle, forKey: .leftKneeAngle)
        try container.encode(rightKneeAngle, forKey: .rightKneeAngle)
        try container.encode(leftFootAngle, forKey: .leftFootAngle)
        try container.encode(rightFootAngle, forKey: .rightFootAngle)
        try container.encode(headColor, forKey: .headColor)
        try container.encode(torsoColor, forKey: .torsoColor)
        try container.encode(leftArmColor, forKey: .leftArmColor)
        try container.encode(rightArmColor, forKey: .rightArmColor)
        try container.encode(leftLegColor, forKey: .leftLegColor)
        try container.encode(rightLegColor, forKey: .rightLegColor)
        try container.encode(handColor, forKey: .handColor)
        try container.encode(footColor, forKey: .footColor)
        try container.encode(strokeThickness, forKey: .strokeThickness)
        try container.encode(scale, forKey: .scale)
        try container.encode(headRadiusMultiplier, forKey: .headRadiusMultiplier)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Waist position is optional - if not present, default to center
        let x = try container.decodeIfPresent(CGFloat.self, forKey: .waistPositionX) ?? 300
        let y = try container.decodeIfPresent(CGFloat.self, forKey: .waistPositionY) ?? 360
        self.waistPosition = CGPoint(x: x, y: y)
        self.waistTorsoAngle = try container.decode(Double.self, forKey: .waistTorsoAngle)
        self.midTorsoAngle = try container.decode(Double.self, forKey: .midTorsoAngle)
        self.headAngle = try container.decode(Double.self, forKey: .headAngle)
        self.leftShoulderAngle = try container.decode(Double.self, forKey: .leftShoulderAngle)
        self.rightShoulderAngle = try container.decode(Double.self, forKey: .rightShoulderAngle)
        self.leftElbowAngle = try container.decode(Double.self, forKey: .leftElbowAngle)
        self.rightElbowAngle = try container.decode(Double.self, forKey: .rightElbowAngle)
        self.leftHandAngle = try container.decode(Double.self, forKey: .leftHandAngle)
        self.rightHandAngle = try container.decode(Double.self, forKey: .rightHandAngle)
        self.leftKneeAngle = try container.decode(Double.self, forKey: .leftKneeAngle)
        self.rightKneeAngle = try container.decode(Double.self, forKey: .rightKneeAngle)
        self.leftFootAngle = try container.decode(Double.self, forKey: .leftFootAngle)
        self.rightFootAngle = try container.decode(Double.self, forKey: .rightFootAngle)
        self.headColor = try container.decode(String.self, forKey: .headColor)
        self.torsoColor = try container.decode(String.self, forKey: .torsoColor)
        self.leftArmColor = try container.decode(String.self, forKey: .leftArmColor)
        self.rightArmColor = try container.decode(String.self, forKey: .rightArmColor)
        self.leftLegColor = try container.decode(String.self, forKey: .leftLegColor)
        self.rightLegColor = try container.decode(String.self, forKey: .rightLegColor)
        self.handColor = try container.decode(String.self, forKey: .handColor)
        self.footColor = try container.decode(String.self, forKey: .footColor)
        self.strokeThickness = try container.decode(CGFloat.self, forKey: .strokeThickness)
        self.scale = try container.decode(Double.self, forKey: .scale)
        self.headRadiusMultiplier = try container.decode(Double.self, forKey: .headRadiusMultiplier)
    }
}

struct Animation: Codable, Identifiable {
    let id: UUID
    let name: String
    var frames: [AnimationFrame]
    let createdAt: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.frames = []
        self.createdAt = Date()
    }
}


// MARK: - Color Extensions

fileprivate extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255.0)
        let g = Int(components.count > 1 ? components[1] * 255.0 : 0)
        let b = Int(components.count > 2 ? components[2] * 255.0 : 0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        default:
            return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 2D Stick Figure Model with Joint Hierarchy and Colors

/// 2D Stick Figure with angle-based joint hierarchy and customizable colors
struct StickFigure2D {
    // Root position (centered in 600x720 base canvas)
    var waistPosition: CGPoint = CGPoint(x: 300, y: 360)
    
    // Joint angles (in degrees, 0° points up, 90° points right)
    var waistTorsoAngle: Double = 0 // Rotation of entire upper body around waist (orange dot)
    var midTorsoAngle: Double = 0 // Rotation of mid-torso around the mid-torso center (center of analog clock)
    var torsoRotationAngle: Double = 0 // Rotation of upper-torso/head around the neck (purple dot - minute hand)
    var headAngle: Double = 0
    var leftShoulderAngle: Double = 0 // Rotation of left upper arm around left shoulder
    var rightShoulderAngle: Double = 0 // Rotation of right upper arm around right shoulder
    var leftElbowAngle: Double = 45
    var rightElbowAngle: Double = 45
    var leftHandAngle: Double = -45
    var rightHandAngle: Double = -45
    var leftKneeAngle: Double = 0
    var rightKneeAngle: Double = 0
    var leftFootAngle: Double = 0
    var rightFootAngle: Double = 0
    
    // Scale
    var scale: Double = 2.4 // Size multiplier (2.4 = 200% - default size for editing)
    var headRadiusMultiplier: Double = 1.0 // Head size multiplier (1.0 = normal size)
    
    // Colors for each body part
    var headColor: Color = .black
    var torsoColor: Color = .black
    var leftArmColor: Color = .black
    var rightArmColor: Color = .black
    var leftLegColor: Color = .black
    var rightLegColor: Color = .black
    var handColor: Color = .black
    var footColor: Color = .black
    
    // Stroke thickness
    var strokeThickness: CGFloat = 4.0
    
    // Static default Stand pose
    static func defaultStand() -> StickFigure2D {
        // ALWAYS load from Bundle's animations.json (the authoritative default)
        // Ignore Documents folder - that's for user edits, not defaults
        
        if let bundleURL = Bundle.main.url(forResource: "animations", withExtension: "json") {
            do {
                let data = try Data(contentsOf: bundleURL)
                let decoder = JSONDecoder()
                let frames = try decoder.decode([AnimationFrame].self, from: data)
                print("DEBUG defaultStand: Loaded \(frames.count) frames from Bundle")
                
                // Look for Stand frame 0 in Bundle
                if let standFrame = frames.first(where: { $0.name == "Stand" && $0.frameNumber == 0 }) {
                    print("DEBUG defaultStand: ✓ Found Stand frame 0 in Bundle - using it")
                    return standFrame.pose.toStickFigure2D()
                } else {
                    print("DEBUG defaultStand: ✗ Stand frame 0 not found in Bundle")
                }
            } catch {
                print("DEBUG defaultStand: Error loading from Bundle: \(error)")
            }
        } else {
            print("DEBUG defaultStand: Bundle/animations.json not found")
        }
        
        // Final fallback: return default constructor values
        print("DEBUG defaultStand: Using default constructor fallback")
        return StickFigure2D()
    }
    
    // Segment lengths (these stay constant)
    let torsoLength: CGFloat = 50
    let neckLength: CGFloat = 15
    let headRadius: CGFloat = 12
    let upperArmLength: CGFloat = 25
    let forearmLength: CGFloat = 26
    let handLength: CGFloat = 8
    let upperLegLength: CGFloat = 34
    let lowerLegLength: CGFloat = 30
    let footLength: CGFloat = 10
    let shoulderWidth: CGFloat = 30
    
    // Calculated positions
    var hipPosition: CGPoint { waistPosition }
    
    var shoulderMidPosition: CGPoint {
        // The torso extends upward from the waist
        // When the waist rotates, the entire upper body rotates around the waist
        let baseX = 0.0  // centered on waist horizontally
        let baseY = -torsoLength  // above waist
        
        let radians = waistTorsoAngle * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)
        
        let x = waistPosition.x + baseX * cosValue - baseY * sinValue
        let y = waistPosition.y + baseX * sinValue + baseY * cosValue
        return CGPoint(x: x, y: y)
    }
    
    var midTorsoPosition: CGPoint {
        // Midpoint between waist and shoulder
        // Rotates around the waist with waistTorsoAngle
        let baseX = 0.0
        let baseY = -(torsoLength / 2)
        
        let radians = waistTorsoAngle * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)
        
        let x = waistPosition.x + baseX * cosValue - baseY * sinValue
        let y = waistPosition.y + baseX * sinValue + baseY * cosValue
        return CGPoint(x: x, y: y)
    }
    
    var neckPosition: CGPoint {
        // Neck is at the top of the upper torso
        // The upper torso rotates around the mid-torso with midTorsoAngle + waistTorsoAngle
        let upperTorsoLength = torsoLength / 2
        let radians = (midTorsoAngle + waistTorsoAngle) * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)

        let baseX = 0.0
        let baseY = -upperTorsoLength

        let x = midTorsoPosition.x + baseX * cosValue - baseY * sinValue
        let y = midTorsoPosition.y + baseX * sinValue + baseY * cosValue
        return CGPoint(x: x, y: y)
    }
    
    var headPosition: CGPoint {
        // Head maintains absolute world orientation, but the attachment point (dot) rotates with torso
        // The offset from neck to head is rotated by torso angles
        let totalTorsoRotation = waistTorsoAngle + midTorsoAngle

        // Create the base offset (pointing up, with head angle applied)
        let headRadians = headAngle * .pi / 180
        let offsetX = neckLength * sin(headRadians)  // 0° = up
        let offsetY = -neckLength * cos(headRadians)
        
        // Rotate this offset by the total torso rotation
        let torsoRadians = totalTorsoRotation * .pi / 180
        let rotatedX = offsetX * cos(torsoRadians) - offsetY * sin(torsoRadians)
        let rotatedY = offsetX * sin(torsoRadians) + offsetY * cos(torsoRadians)
        
        return CGPoint(x: neckPosition.x + rotatedX, y: neckPosition.y + rotatedY)
    }
    
    var leftShoulderPosition: CGPoint {
        // Shoulders originate at the neck position
        neckPosition
    }
    
    var rightShoulderPosition: CGPoint {
        // Shoulders originate at the neck position
        neckPosition
    }
    
    // Left arm positions (upper body rotates, so we need to apply waistTorsoAngle)
    var leftUpperArmEnd: CGPoint {
        let baseAngle = 270.0 + leftShoulderAngle
        let totalAngle = baseAngle + waistTorsoAngle + midTorsoAngle
        let radians = totalAngle * .pi / 180
        let x = leftShoulderPosition.x + upperArmLength * cos(radians)
        let y = leftShoulderPosition.y + upperArmLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var leftForearmEnd: CGPoint {
        let baseAngle = 270.0 + leftShoulderAngle + leftElbowAngle
        let totalAngle = baseAngle + waistTorsoAngle + midTorsoAngle
        let radians = totalAngle * .pi / 180
        let x = leftUpperArmEnd.x + forearmLength * cos(radians)
        let y = leftUpperArmEnd.y + forearmLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var leftHandEnd: CGPoint {
        let baseAngle = 270.0 + leftShoulderAngle + leftElbowAngle + leftHandAngle
        let totalAngle = baseAngle + waistTorsoAngle + midTorsoAngle
        let radians = totalAngle * .pi / 180
        let x = leftForearmEnd.x + handLength * cos(radians)
        let y = leftForearmEnd.y + handLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    // Right arm positions
    var rightUpperArmEnd: CGPoint {
        let baseAngle = 270.0 + rightShoulderAngle
        let totalAngle = baseAngle + waistTorsoAngle + midTorsoAngle
        let radians = totalAngle * .pi / 180
        let x = rightShoulderPosition.x + upperArmLength * cos(radians)
        let y = rightShoulderPosition.y + upperArmLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var rightForearmEnd: CGPoint {
        let baseAngle = 270.0 + rightShoulderAngle + rightElbowAngle
        let totalAngle = baseAngle + waistTorsoAngle + midTorsoAngle
        let radians = totalAngle * .pi / 180
        let x = rightUpperArmEnd.x + forearmLength * cos(radians)
        let y = rightUpperArmEnd.y + forearmLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var rightHandEnd: CGPoint {
        let baseAngle = 270.0 + rightShoulderAngle + rightElbowAngle + rightHandAngle
        let totalAngle = baseAngle + waistTorsoAngle + midTorsoAngle
        let radians = totalAngle * .pi / 180
        let x = rightForearmEnd.x + handLength * cos(radians)
        let y = rightForearmEnd.y + handLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    // Shoulder drag handle positions (halfway down the upper arm)
    var leftShoulderDragHandle: CGPoint {
        let midX = (neckPosition.x + leftUpperArmEnd.x) / 2
        let midY = (neckPosition.y + leftUpperArmEnd.y) / 2
        return CGPoint(x: midX, y: midY)
    }
    
    var rightShoulderDragHandle: CGPoint {
        let midX = (neckPosition.x + rightUpperArmEnd.x) / 2
        let midY = (neckPosition.y + rightUpperArmEnd.y) / 2
        return CGPoint(x: midX, y: midY)
    }
    
    // Left leg positions (lower body doesn't rotate with waist)
    // Legs rotate directly from waist center - no fixed X offset
    var leftUpperLegEnd: CGPoint {
        let angle = 270.0 + leftKneeAngle // 270° = pointing down
        let radians = angle * .pi / 180
        let x = waistPosition.x + upperLegLength * cos(radians)
        let y = waistPosition.y + upperLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var leftFootEnd: CGPoint {
        let angle = 270.0 + leftKneeAngle + leftFootAngle
        let radians = angle * .pi / 180
        let x = leftUpperLegEnd.x + lowerLegLength * cos(radians)
        let y = leftUpperLegEnd.y + lowerLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    // Right leg positions
    // Legs rotate directly from waist center - no fixed X offset
    var rightUpperLegEnd: CGPoint {
        let angle = 270.0 + rightKneeAngle
        let radians = angle * .pi / 180
        let x = waistPosition.x + upperLegLength * cos(radians)
        let y = waistPosition.y + upperLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var rightFootEnd: CGPoint {
        let angle = 270.0 + rightKneeAngle + rightFootAngle
        let radians = angle * .pi / 180
        let x = rightUpperLegEnd.x + lowerLegLength * cos(radians)
        let y = rightUpperLegEnd.y + lowerLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Grid Overlay

struct GridOverlay: View {
    let canvasSize: CGSize
    let gridSpacing: CGFloat = 30  // Grid cell size (increased from 20)
    
    var body: some View {
        Canvas { context, size in
            drawGrid(in: context, size: size)
        }
    }
    
    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        var path = Path()
        
        // Calculate offset to center grid on the waist position (canvas center)
        // The waist is at the center of the canvas
        let canvasCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let offset = gridSpacing / 2  // Offset to center grid on intersection point
        
        // Draw vertical lines - centered on canvas center
        var x: CGFloat = canvasCenter.x - offset
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += gridSpacing
        }
        
        // Also draw lines to the left of center
        x = canvasCenter.x - offset - gridSpacing
        while x >= 0 {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x -= gridSpacing
        }
        
        // Draw horizontal lines - centered on canvas center
        var y: CGFloat = canvasCenter.y - offset
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += gridSpacing
        }
        
        // Also draw lines above center
        y = canvasCenter.y - offset - gridSpacing
        while y >= 0 {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y -= gridSpacing
        }
        
        // Stroke the grid with a darker color
        context.stroke(
            path,
            with: .color(Color.gray.opacity(0.3)),  // Darker (from 0.15)
            lineWidth: 0.5
        )
    }
}

// MARK: - Drawing View

struct StickFigure2DView: View {
    let figure: StickFigure2D
    let canvasSize: CGSize
    var showJoints: Bool = false  // Default to not showing joints (for gameplay)
    let jointRadius: CGFloat = 5
    let jointColor: Color = .blue
    
    var body: some View {
        Canvas { context, size in
            drawFigure(in: context)
        }
    }
    
    private func drawFigure(in context: GraphicsContext) {
        // Get canvas center for scaling
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        
        // Base canvas dimensions (the coordinate space figure positions are in)
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        // Helper function to scale a point from base coordinates to actual canvas
        func scalePoint(_ point: CGPoint) -> CGPoint {
            // First, scale from base canvas to actual canvas size
            let canvasScale = canvasSize.width / baseCanvasSize.width
            
            // Calculate offset from base center
            let dx = point.x - baseCenter.x
            let dy = point.y - baseCenter.y
            
            // Apply both canvas scaling and figure scaling around the center
            return CGPoint(
                x: canvasCenter.x + dx * canvasScale * figure.scale,
                y: canvasCenter.y + dy * canvasScale * figure.scale
            )
        }
        
        // Scale all positions
        let waistPos = scalePoint(figure.waistPosition)
        // shoulderMidPos removed (unused)
        let midTorsoPos = scalePoint(figure.midTorsoPosition)
        let neckPos = scalePoint(figure.neckPosition)
        let headPos = scalePoint(figure.headPosition)
        let leftUpperArmEnd = scalePoint(figure.leftUpperArmEnd)
        let rightUpperArmEnd = scalePoint(figure.rightUpperArmEnd)
        let leftForearmEnd = scalePoint(figure.leftForearmEnd)
        let rightForearmEnd = scalePoint(figure.rightForearmEnd)
        let leftShoulderPos = scalePoint(figure.leftShoulderPosition)
        let rightShoulderPos = scalePoint(figure.rightShoulderPosition)
        let leftUpperLegEnd = scalePoint(figure.leftUpperLegEnd)
        let rightUpperLegEnd = scalePoint(figure.rightUpperLegEnd)
        let leftFootEnd = scalePoint(figure.leftFootEnd)
        let rightFootEnd = scalePoint(figure.rightFootEnd)
        
        // Draw lower body first (back)
        drawSegment(from: waistPos, to: leftUpperLegEnd, color: figure.leftLegColor, in: context)
        drawSegment(from: leftUpperLegEnd, to: leftFootEnd, color: figure.footColor, in: context)
        drawSegment(from: waistPos, to: rightUpperLegEnd, color: figure.rightLegColor, in: context)
        drawSegment(from: rightUpperLegEnd, to: rightFootEnd, color: figure.footColor, in: context)
        
        // Draw torso
        drawSegment(from: waistPos, to: midTorsoPos, color: figure.torsoColor, in: context)
        drawSegment(from: midTorsoPos, to: neckPos, color: figure.torsoColor, in: context)
        drawSegment(from: neckPos, to: headPos, color: figure.torsoColor, in: context)
        
        // Draw arms (back arm first)
        drawSegment(from: leftShoulderPos, to: leftUpperArmEnd, color: figure.leftArmColor, in: context)
        drawSegment(from: leftUpperArmEnd, to: leftForearmEnd, color: figure.leftArmColor, in: context)
        
        drawSegment(from: rightShoulderPos, to: rightUpperArmEnd, color: figure.rightArmColor, in: context)
        drawSegment(from: rightUpperArmEnd, to: rightForearmEnd, color: figure.rightArmColor, in: context)
        
        // Draw head
        // Calculate canvasScale (scalePoint already applied figure.scale, so we only need canvasScale here)
        let canvasScale = canvasSize.width / baseCanvasSize.width
        let scaledHeadRadius = figure.headRadius * canvasScale * figure.scale * figure.headRadiusMultiplier
        let headCircle = Circle().path(in: CGRect(
            x: headPos.x - scaledHeadRadius,
            y: headPos.y - scaledHeadRadius,
            width: scaledHeadRadius * 2,
            height: scaledHeadRadius * 2
        ))
        context.fill(headCircle, with: .color(figure.headColor))
        context.stroke(headCircle, with: .color(figure.headColor.opacity(0.8)), lineWidth: figure.strokeThickness)
        
        // Draw joints only if showJoints is enabled (for editor mode)
        if showJoints {
            drawJoint(at: waistPos, in: context)
            drawJoint(at: midTorsoPos, in: context)
            drawJoint(at: neckPos, in: context)
            drawJoint(at: leftUpperArmEnd, in: context)
            drawJoint(at: rightUpperArmEnd, in: context)
            drawJoint(at: leftUpperLegEnd, in: context)
            drawJoint(at: rightUpperLegEnd, in: context)
        }
    }
    
    private func drawSegment(from: CGPoint, to: CGPoint, color: Color, in context: GraphicsContext) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), lineWidth: figure.strokeThickness)
    }
    
    private func drawJoint(at position: CGPoint, in context: GraphicsContext) {
        let circle = Circle().path(in: CGRect(
            x: position.x - jointRadius,
            y: position.y - jointRadius,
            width: jointRadius * 2,
            height: jointRadius * 2
        ))
        context.fill(circle, with: .color(jointColor))
    }
}

// MARK: - Image Picker View

struct ImagePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var objects: [AnimationObject]
    
    let availableImages = [
        // Useful assets only
        "Apple", "Dumbbell", "Kettlebell", "Shaker"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Built-in objects only (removed Photos tab)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                        // Image objects
                        ForEach(availableImages, id: \.self) { imageName in
                            VStack {
                                if let uiImage = UIImage(named: imageName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 60)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 60)
                                        .overlay(
                                            Text("?").font(.caption)
                                        )
                                }
                                
                                Button(action: {
                                    let newObject = AnimationObject(
                                        imageName: imageName,
                                        position: CGPoint(x: 300, y: 360),
                                        rotation: 0,
                                        scale: 1.0
                                    )
                                    objects.append(newObject)
                                    dismiss()
                                }) {
                                    Text("Add")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Line object
                        VStack {
                            VStack(spacing: 4) {
                                Line()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(height: 40)
                                    .padding(10)
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text("Thickness")
                                    .font(.caption2)
                            }
                            .frame(height: 60)
                            
                            Button(action: {
                                let newObject = AnimationObject(
                                    imageName: "line",
                                    position: CGPoint(x: 300, y: 480),
                                    rotation: 0,
                                    scale: 1.0
                                )
                                objects.append(newObject)
                                dismiss()
                            }) {
                                Text("Add")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Object")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Line Shape

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Frames Manager View

struct FramesManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var savedFrames: [AnimationFrame]
    var onSelectFrame: (AnimationFrame) -> Void
    var onSave: () -> Void
    
    @State private var editingFrameId: UUID?
    @State private var editingName: String = ""
    @State private var editingFrameNumber: String = ""
    @State private var frameToDelete: AnimationFrame?
    @State private var showDeleteConfirmation = false
    @State private var isEditMode = false
    @State private var persistedFrames: Set<UUID> = [] // Track which frames are persisted
    @State private var searchText = ""
    
    // MARK: - Search Filter
    
    private var filteredFrames: [AnimationFrame] {
        if searchText.isEmpty {
            return savedFrames
        }
        return savedFrames.filter { frame in
            frame.name.lowercased().contains(searchText.lowercased()) ||
            String(frame.frameNumber).contains(searchText)
        }
    }
    
    // MARK: - Persistence Functions
    
    private func loadPersistedFrames() {
        persistedFrames = AnimationPersistence.loadPersistedFrameMarkers()
    }
    
    private func savePersistedFrameMarkers() {
        AnimationPersistence.savePersistedFrameMarkers(persistedFrames)
    }
    
    
    var body: some View {
        NavigationView {
            VStack {
                if savedFrames.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No saved frames yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Save frames to create animations")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search frames...", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        
                        List {
                            ForEach(filteredFrames) { frame in
                            if editingFrameId == frame.id {
                                // Edit mode for this frame
                                VStack(spacing: 8) {
                                    TextField("Frame Name", text: $editingName)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    TextField("Frame Number", text: $editingFrameNumber)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                    
                                    HStack {
                                        Button("Cancel") {
                                            editingFrameId = nil
                                        }
                                        .buttonStyle(.bordered)
                                        
                                        Spacer()
                                        
                                        Button("Save") {
                                            if let index = savedFrames.firstIndex(where: { $0.id == frame.id }) {
                                                let frameNum = Int(editingFrameNumber) ?? frame.frameNumber
                                                let newFrame = AnimationFrame(
                                                    id: frame.id,
                                                    name: editingName,
                                                    frameNumber: frameNum,
                                                    pose: savedFrames[index].pose.toStickFigure2D()
                                                )
                                                savedFrames[index] = newFrame
                                                onSave()
                                                editingFrameId = nil
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .padding(.vertical, 8)
                            } else {
                                // Normal display mode
                                HStack(spacing: 12) {
                                    Button(action: {
                                        onSelectFrame(frame)
                                    }) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 8) {
                                                    Text(frame.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                    
                                                    // Checkbox indicator (in animations.json)
                                                    let bundleFrames = AnimationPersistence.loadFramesFromDisk()
                                                    if bundleFrames.contains(where: { $0.id == frame.id }) {
                                                        Image(systemName: "checkmark.square.fill")
                                                            .font(.caption)
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                                
                                                HStack(spacing: 12) {
                                                    Text("Frame #\(frame.frameNumber)")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                    
                                                    Text(frame.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Copy to clipboard button
                                    Button(action: {
                                        copyFrameToClipboard(frame)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                            .font(.body)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Only show rename/delete buttons when in Edit mode
                                    if isEditMode {
                                        // Rename button
                                        Button(action: {
                                            editingFrameId = frame.id
                                            editingName = frame.name
                                            editingFrameNumber = "\(frame.frameNumber)"
                                        }) {
                                            Image(systemName: "pencil.circle")
                                                .foregroundColor(.blue)
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        // Delete button
                                        Button(action: {
                                            frameToDelete = frame
                                            showDeleteConfirmation = true
                                        }) {
                                            Image(systemName: "trash.circle")
                                                .foregroundColor(.red)
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .onMove { indices, newOffset in
                            savedFrames.move(fromOffsets: indices, toOffset: newOffset)
                            onSave()
                        }
                    }
                    .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Saved Frames")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load which frames are marked as persisted
                loadPersistedFrames()
                
                // Initialize Stand frame as persisted by default if not already set
                if persistedFrames.isEmpty {
                    if let standFrame = savedFrames.first(where: { $0.name == "Stand" && $0.frameNumber == 0 }) {
                        persistedFrames.insert(standFrame.id)
                    }
                }
                // Also save on first load
                loadPersistedFrames()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isEditMode.toggle()
                    }) {
                        Text(isEditMode ? "Done" : "Edit")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Frame?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let frame = frameToDelete {
                        savedFrames.removeAll { $0.id == frame.id }
                        onSave()
                    }
                }
            } message: {
                if let frame = frameToDelete {
                    Text("Are you sure you want to delete '\(frame.name)'?")
                }
            }
        }
    }
    
    private func copyFrameToClipboard(_ frame: AnimationFrame) {
        AnimationPersistence.exportFramesAsJSON([frame]) { jsonString, error in
            if let jsonString = jsonString {
                UIPasteboard.general.string = jsonString
                print("✓ Copied frame '\(frame.name)' to clipboard")
            } else if let error = error {
                print("✗ Error copying frame: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Save Frame Dialog

struct SaveFrameDialog: View {
    @Binding var frameName: String
    @Binding var frameNumber: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Save Animation Frame")
                .font(.headline)
                .padding()
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frame Name")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    TextField("e.g., Jump Start, Wave Hello", text: $frameName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frame Number")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    TextField("1", text: $frameNumber)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }
            .padding()
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(10)
                }
                .buttonStyle(.bordered)
                
                Button(action: onSave) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Editor View
struct StickFigure2DEditorView: View {
    @Environment(\.dismiss) var dismiss
    var onDismiss: (() -> Void)? = nil
    
    @State private var figure = StickFigure2D()
    @State private var draggedJoint: String? = nil
    @State private var lastWaistAngle: Double = 0
    @State private var lastMidTorsoAngle: Double = 0
    @State private var showSaveFrameDialog = false
    @State private var frameName = ""
    @State private var frameNumber = "1"
    @State private var savedFrames: [AnimationFrame] = []
    @State private var showDeleteConfirmation = false
    @State private var frameToDelete: AnimationFrame? = nil
    @State private var isEditingFrames = false
    @State private var showFramesManager = false // New state for frames manager sheet
    @State private var scrollToCanvas = false
    @State private var objects: [AnimationObject] = []
    @State private var showImagePicker = false
    @State private var selectedObjectId: UUID? = nil
    @State private var selectedAnimationName = ""
    @State private var frameSequence = "1,2,3,4,3,2,1"
    @State private var isPlayingAnimation = false
    @State private var loopAnimation = false // Loop animation checkbox state
    @State private var currentFrameIndex = 0
    @State private var animationTimer: Timer? = nil
    @State private var isControlsCollapsed = true // Controls start collapsed
    @State private var isColorsCollapsed = true // Colors start collapsed
    @State private var isAnimationPlaybackCollapsed = true // Animation Playback starts collapsed
    @State private var canvasOffset: CGSize = .zero // Offset for panning the canvas
    @State private var lastCanvasOffset: CGSize = .zero // Last offset before new drag
    @State private var availableWidth: CGFloat = 390 // Default to iPhone width
    
    var canvasSize: CGSize {
        let width = availableWidth - 32 // Account for padding
        // Scale proportionally from 600x720 base (1.2 ratio for wider canvas with extra space)
        // This gives more horizontal space around the figure
        let scale = width / 600.0
        let height = 720.0 * scale // Much taller canvas for figure at all scales
        return CGSize(width: width, height: height)
    }

    private func wrapAngle(_ angle: Double) -> Double {
        var wrapped = angle.truncatingRemainder(dividingBy: 360)
        if wrapped <= -180 {
            wrapped += 360
        } else if wrapped > 180 {
            wrapped -= 360
        }
        return wrapped
    }

    private func shortestAngleDelta(from current: Double, to target: Double) -> Double {
        wrapAngle(target - current)
    }

    private func smoothedAngle(last: Double, target: Double, alpha: Double) -> Double {
        let delta = shortestAngleDelta(from: last, to: target)
        return wrapAngle(last + delta * alpha)
    }
    
    // Helper to adjust and wrap an angle by a delta
    private func adjustAngle(_ currentAngle: Double, by delta: Double) -> Double {
        wrapAngle(currentAngle + delta)
    }
    
    var body: some View {
        baseView
            .onAppear {
                // Load saved frames list (all animations come from Bundle only)
                loadSavedFrames()
                // Load the last saved figure state, or default Stand pose if none exists
                loadLastFigureState()
                // Always ensure scale is at 200% (2.4) when opening
                if figure.scale != 2.4 {
                    figure.scale = 2.4
                }
            }
            .onDisappear {
                // Save the current figure state when leaving the editor
                saveCurrentFigureState()
            }
    }
    
    var baseView: some View {
        contentWithScaleOnChanges
    }
    
    var contentWithScaleOnChanges: some View {
        contentWithLegOnChanges
            .onChange(of: figure.scale) { oldValue, newValue in
                saveCurrentFigureState()
                // Reset canvas offset when scale returns to 100% or below
                if newValue <= 1.2 && canvasOffset != .zero {
                    canvasOffset = .zero
                    lastCanvasOffset = .zero
                }
            }
            .onChange(of: figure.strokeThickness) { saveCurrentFigureState() }
            .onChange(of: savedFrames) { oldValue, newValue in
                // Persist frames whenever they change
                persistFramesToStorage()
            }
    }
    
    var contentWithLegOnChanges: some View {
        contentWithArmOnChanges
            .onChange(of: figure.leftKneeAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightKneeAngle) { saveCurrentFigureState() }
            .onChange(of: figure.leftFootAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightFootAngle) { saveCurrentFigureState() }
    }
    
    var contentWithArmOnChanges: some View {
        contentWithTorsoOnChanges
            .onChange(of: figure.leftShoulderAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightShoulderAngle) { saveCurrentFigureState() }
            .onChange(of: figure.leftElbowAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightElbowAngle) { saveCurrentFigureState() }
            .onChange(of: figure.waistTorsoAngle) { saveCurrentFigureState() }
            .onChange(of: figure.midTorsoAngle) { saveCurrentFigureState() }
            .onChange(of: figure.headAngle) { saveCurrentFigureState() }
            .onChange(of: figure.headRadiusMultiplier) { saveCurrentFigureState() }
    }
    
    var contentWithTorsoOnChanges: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerView
                scrollableContent
            }
            .onAppear {
                availableWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { oldValue, newValue in
                availableWidth = newValue
            }
        }
    }
    
    var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    canvasView
                        .id("canvas")
                    sizeControlView
                    animationControlsView
                    animationPlaybackView
                    jointControlsView
                    colorControlsView
                    objectsControlsView
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: scrollToCanvas) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("canvas", anchor: .top)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToCanvas = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    var headerView: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 50)
            
            HStack {
                Button(action: {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.body)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("2D Stick Figure Editor")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: resetFigure) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea(edges: .top)
    }
    
    var canvasView: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
            
            // Grid overlay
            GridOverlay(canvasSize: canvasSize)
            
            StickFigure2DView(figure: figure, canvasSize: canvasSize, showJoints: true)
            
            // Render animation objects
            ForEach(objects) { object in
                if object.imageName == "line" {
                    // Render line object
                    Line()
                        .stroke(Color.black, lineWidth: 2 + (object.scale * 3))
                        .frame(width: 50 * object.scale, height: 2 + (object.scale * 3))
                        .rotationEffect(.degrees(object.rotation))
                        .position(baseToCanvasPosition(object.position))
                } else if let uiImage = UIImage(named: object.imageName) {
                    // Render image object
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50 * object.scale, height: 50 * object.scale)
                        .rotationEffect(.degrees(object.rotation))
                        .position(baseToCanvasPosition(object.position))
                }
            }
            
            // Object control handles
            ForEach(objects) { object in
                objectControlHandles(for: object)
            }
        
            // Draggable joint handles
            Group {
                jointHandles
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .offset(canvasOffset)
        .contentShape(Rectangle()) // Make entire ZStack tappable/draggable
        .simultaneousGesture(
            // Pan gesture that works alongside other gestures
            DragGesture(minimumDistance: 30) // Higher threshold to avoid conflicts
                .onChanged { value in
                    // Only allow panning when zoomed in AND not dragging a joint AND not moving an object
                    if figure.scale > 1.2 && draggedJoint == nil && selectedObjectId == nil {
                        canvasOffset = CGSize(
                            width: lastCanvasOffset.width + value.translation.width,
                            height: lastCanvasOffset.height + value.translation.height
                        )
                    }
                }
                .onEnded { _ in
                    // Save the final offset for next drag
                    if figure.scale > 1.2 && draggedJoint == nil && selectedObjectId == nil {
                        lastCanvasOffset = canvasOffset
                    }
                }
        )
    }
    
    // Helper function to scale points for drag handles
    private func scalePoint(_ point: CGPoint) -> CGPoint {
        // Base canvas dimensions
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let canvasScale = canvasSize.width / baseCanvasSize.width
        
        let dx = point.x - baseCenter.x
        let dy = point.y - baseCenter.y
        return CGPoint(
            x: canvasCenter.x + dx * canvasScale * figure.scale,
            y: canvasCenter.y + dy * canvasScale * figure.scale
        )
    }
    
    // Helper function to unscale drag positions back to figure coordinates
    private func unscalePoint(_ point: CGPoint) -> CGPoint {
        // Base canvas dimensions
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let canvasScale = canvasSize.width / baseCanvasSize.width
        
        let dx = point.x - canvasCenter.x
        let dy = point.y - canvasCenter.y
        return CGPoint(
            x: baseCenter.x + dx / (canvasScale * figure.scale),
            y: baseCenter.y + dy / (canvasScale * figure.scale)
        )
    }
    
    // Helper function to convert object position from base canvas to display canvas
    private func baseToCanvasPosition(_ basePosition: CGPoint) -> CGPoint {
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let canvasScale = canvasSize.width / baseCanvasSize.width
        
        let dx = basePosition.x - baseCenter.x
        let dy = basePosition.y - baseCenter.y
        return CGPoint(
            x: canvasCenter.x + dx * canvasScale * figure.scale,
            y: canvasCenter.y + dy * canvasScale * figure.scale
        )
    }
    
    // Helper function to convert object position from display canvas to base canvas
    private func canvasToBasePosition(_ canvasPosition: CGPoint) -> CGPoint {
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let canvasScale = canvasSize.width / baseCanvasSize.width
        
        let dx = canvasPosition.x - canvasCenter.x
        let dy = canvasPosition.y - canvasCenter.y
        return CGPoint(
            x: baseCenter.x + dx / (canvasScale * figure.scale),
            y: baseCenter.y + dy / (canvasScale * figure.scale)
        )
    }
    
    // Function to create control handles for animation objects
    @ViewBuilder
    private func objectControlHandles(for object: AnimationObject) -> some View {
        Group {
            // Yellow dot: Move the object
            ZStack {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 10, height: 10)
                
                // Larger invisible hit area
                Circle()
                    .fill(Color.clear)
                    .frame(width: 28, height: 28)
            }
            .position(baseToCanvasPosition(object.position))
            .gesture(DragGesture()
                .onChanged { value in
                    selectedObjectId = object.id
                    if let index = objects.firstIndex(where: { $0.id == object.id }) {
                        // Convert drag position from canvas space to base canvas space
                        objects[index].position = canvasToBasePosition(value.location)
                    }
                }
                .onEnded { _ in }
            )
            
            // Blue dot: Resize the object
            let resizeHandleDistance: CGFloat = 40
            let angle = object.rotation * .pi / 180
            let resizeOffset = CGPoint(
                x: cos(angle + .pi / 4) * resizeHandleDistance,
                y: sin(angle + .pi / 4) * resizeHandleDistance
            )
            let objectCanvasPos = baseToCanvasPosition(object.position)
            let resizePosition = CGPoint(
                x: objectCanvasPos.x + resizeOffset.x,
                y: objectCanvasPos.y + resizeOffset.y
            )
            
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
            }
            .position(resizePosition)
            .gesture(DragGesture()
                .onChanged { value in
                    selectedObjectId = object.id
                    if let index = objects.firstIndex(where: { $0.id == object.id }) {
                        let objectBasePos = objects[index].position
                        let dx = canvasToBasePosition(value.location).x - objectBasePos.x
                        let dy = canvasToBasePosition(value.location).y - objectBasePos.y
                        let newScale = sqrt(dx * dx + dy * dy) / resizeHandleDistance
                        objects[index].scale = max(0.1, newScale)
                    }
                }
                .onEnded { _ in }
            )
            
            // Red dot: Rotate the object
            let rotateHandleDistance: CGFloat = 40
            let rotateOffset = CGPoint(
                x: cos(angle) * rotateHandleDistance,
                y: sin(angle) * rotateHandleDistance
            )
            let rotatePosition = CGPoint(
                x: objectCanvasPos.x + rotateOffset.x,
                y: objectCanvasPos.y + rotateOffset.y
            )
            
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
            }
            .position(rotatePosition)
            .gesture(DragGesture()
                .onChanged { value in
                    selectedObjectId = object.id
                    if let index = objects.firstIndex(where: { $0.id == object.id }) {
                        let objectBasePos = objects[index].position
                        let dragBasePos = canvasToBasePosition(value.location)
                        let dx = dragBasePos.x - objectBasePos.x
                        let dy = dragBasePos.y - objectBasePos.y
                        let newAngle = atan2(dy, dx) * 180 / .pi
                        objects[index].rotation = newAngle
                    }
                }
                .onEnded { _ in }
            )
        }
    }
    
    var jointHandles: some View {
        Group {
            // Waist (root position - draggable for moving entire figure)
            ZStack {
                Circle()
                    .fill(draggedJoint == "waist" ? Color.red : Color.orange)
                    .frame(width: 8, height: 8)
                
                // Larger invisible hit area
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.waistPosition))
            .gesture(DragGesture()
                .onChanged { value in
                    draggedJoint = "waist"
                    figure.waistPosition = unscalePoint(value.location)
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )
            
            // Mid-torso (center of rotation for upper torso and waist hinge)
            ZStack {
                Circle()
                    .fill(draggedJoint == "midTorso" ? Color.red : Color.cyan)
                    .frame(width: 6, height: 6)
                
                // Larger invisible hit area
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.midTorsoPosition))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("midTorso", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                    lastMidTorsoAngle = figure.waistTorsoAngle
                }
            )

            // Neck (controls upper torso rotation)
            ZStack {
                Circle()
                    .fill(draggedJoint == "neck" ? Color.red : Color.purple)
                    .frame(width: 6, height: 6)
                
                // Larger invisible hit area
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.neckPosition))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("neck", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                    lastWaistAngle = figure.waistTorsoAngle
                }
            )

            // Left shoulder (at elbow position)
            ZStack {
                Circle()
                    .fill(draggedJoint == "leftShoulder" ? Color.red : Color.blue)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.leftUpperArmEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("leftShoulder", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Right shoulder (at elbow position)
            ZStack {
                Circle()
                    .fill(draggedJoint == "rightShoulder" ? Color.red : Color.blue)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.rightUpperArmEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("rightShoulder", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Left elbow (at forearm end)
            ZStack {
                Circle()
                    .fill(draggedJoint == "leftElbow" ? Color.red : Color.green)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.leftForearmEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("leftElbow", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Right elbow (at forearm end)
            ZStack {
                Circle()
                    .fill(draggedJoint == "rightElbow" ? Color.red : Color.green)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.rightForearmEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("rightElbow", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Head
            ZStack {
                Circle()
                    .fill(draggedJoint == "head" ? Color.red : Color.purple)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.headPosition))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("head", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Left knee
            ZStack {
                Circle()
                    .fill(draggedJoint == "leftKnee" ? Color.red : Color.yellow)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.leftUpperLegEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("leftKnee", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Right knee
            ZStack {
                Circle()
                    .fill(draggedJoint == "rightKnee" ? Color.red : Color.yellow)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.rightUpperLegEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("rightKnee", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Left foot
            ZStack {
                Circle()
                    .fill(draggedJoint == "leftFoot" ? Color.red : Color.pink)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.leftFootEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("leftFoot", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )

            // Right foot
            ZStack {
                Circle()
                    .fill(draggedJoint == "rightFoot" ? Color.red : Color.pink)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
            }
            .position(scalePoint(figure.rightFootEnd))
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint("rightFoot", with: unscalePoint(value.location))
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )
        }
    }
    
    var jointControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    isControlsCollapsed.toggle()
                }
            }) {
                HStack {
                    Text("Controls")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isControlsCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if !isControlsCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stroke Thickness:")
                        Button(action: { figure.strokeThickness = max(0.5, figure.strokeThickness - 0.5) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.strokeThickness, in: 0.5...20, step: 0.5)
                        Button(action: { figure.strokeThickness = min(20, figure.strokeThickness + 0.5) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(String(format: "%.1f", figure.strokeThickness))")
                            .frame(width: 40)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Waist Rotation:")
                        Button(action: { figure.waistTorsoAngle = adjustAngle(figure.waistTorsoAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.waistTorsoAngle, in: -180...180, step: 1)
                        Button(action: { figure.waistTorsoAngle = adjustAngle(figure.waistTorsoAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.waistTorsoAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Shoulder:")
                        Button(action: { figure.leftShoulderAngle = adjustAngle(figure.leftShoulderAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.leftShoulderAngle, in: -180...180, step: 1)
                        Button(action: { figure.leftShoulderAngle = adjustAngle(figure.leftShoulderAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.leftShoulderAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Shoulder:")
                        Button(action: { figure.rightShoulderAngle = adjustAngle(figure.rightShoulderAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.rightShoulderAngle, in: -180...180, step: 1)
                        Button(action: { figure.rightShoulderAngle = adjustAngle(figure.rightShoulderAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.rightShoulderAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Elbow:")
                        Button(action: { figure.leftElbowAngle = adjustAngle(figure.leftElbowAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.leftElbowAngle, in: -180...180, step: 1)
                        Button(action: { figure.leftElbowAngle = adjustAngle(figure.leftElbowAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.leftElbowAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Elbow:")
                        Button(action: { figure.rightElbowAngle = adjustAngle(figure.rightElbowAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.rightElbowAngle, in: -180...180, step: 1)
                        Button(action: { figure.rightElbowAngle = adjustAngle(figure.rightElbowAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.rightElbowAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Knee:")
                        Button(action: { figure.leftKneeAngle = adjustAngle(figure.leftKneeAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.leftKneeAngle, in: -180...180, step: 1)
                        Button(action: { figure.leftKneeAngle = adjustAngle(figure.leftKneeAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.leftKneeAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Knee:")
                        Button(action: { figure.rightKneeAngle = adjustAngle(figure.rightKneeAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.rightKneeAngle, in: -180...180, step: 1)
                        Button(action: { figure.rightKneeAngle = adjustAngle(figure.rightKneeAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.rightKneeAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Foot:")
                        Button(action: { figure.leftFootAngle = adjustAngle(figure.leftFootAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.leftFootAngle, in: -180...180, step: 1)
                        Button(action: { figure.leftFootAngle = adjustAngle(figure.leftFootAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.leftFootAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Foot:")
                        Button(action: { figure.rightFootAngle = adjustAngle(figure.rightFootAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.rightFootAngle, in: -180...180, step: 1)
                        Button(action: { figure.rightFootAngle = adjustAngle(figure.rightFootAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.rightFootAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Head:")
                        Button(action: { figure.headAngle = adjustAngle(figure.headAngle, by: -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.headAngle, in: -180...180, step: 1)
                        Button(action: { figure.headAngle = adjustAngle(figure.headAngle, by: 1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(Int(wrapAngle(figure.headAngle)))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Head Size:")
                        Button(action: { figure.headRadiusMultiplier = max(0.5, figure.headRadiusMultiplier - 0.1) }) {
                            Image(systemName: "minus.circle")
                        }
                        Slider(value: $figure.headRadiusMultiplier, in: 0.5...2.0, step: 0.1)
                        Button(action: { figure.headRadiusMultiplier = min(2.0, figure.headRadiusMultiplier + 0.1) }) {
                            Image(systemName: "plus.circle")
                        }
                        Text("\(String(format: "%.1f", figure.headRadiusMultiplier))x")
                            .frame(width: 40)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    var animationPlaybackView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    isAnimationPlaybackCollapsed.toggle()
                }
            }) {
                HStack {
                    Text("Animation Playback")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isAnimationPlaybackCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if !isAnimationPlaybackCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Animation Name:")
                        TextField("e.g., Run, Jump", text: $selectedAnimationName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Frame Sequence:")
                        TextField("e.g., 1,2,3,4,3,2,1", text: $frameSequence)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Loop checkbox
                    Toggle("Loop animation", isOn: $loopAnimation)
                        .font(.caption)
                    
                    HStack(spacing: 12) {
                        Button(action: playAnimation) {
                            Label("Play", systemImage: "play.fill")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .disabled(selectedAnimationName.isEmpty || frameSequence.isEmpty)
                        
                        Button(action: stopAnimation) {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .disabled(!isPlayingAnimation)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    var sizeControlView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Display scale: internal 1.2 = 100%, so divide by 1.2 and multiply by 100
                // Use round() to ensure clean percentages (50%, 100%, 150%, 200%)
                Text("Figure Size (\(Int(round(figure.scale / 1.2 * 100)))%)")
                    .fontWeight(.semibold)
                Spacer()
            }

            HStack(spacing: 12) {
                Text("50%")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Internal range: 0.6 to 2.4 (maps to display 50% to 200%)
                // 1.2 internal = 100% display (default)
                Slider(value: $figure.scale, in: 0.6...2.4, step: 0.06)

                Text("200%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func playAnimation() {
        // Parse frame sequence
        let frameStrings = frameSequence.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        let frameNumbers = frameStrings.compactMap { Int($0) }
        
        guard !frameNumbers.isEmpty else { return }
        
        isPlayingAnimation = true
        currentFrameIndex = 0
        
        // Load the first frame immediately
        loadFrameAtIndex(0, from: frameNumbers)
        
        // Start timer to cycle through frames
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            currentFrameIndex = (currentFrameIndex + 1) % frameNumbers.count
            loadFrameAtIndex(currentFrameIndex, from: frameNumbers)
            
            // Stop animation if not looping and reached the end
            if !loopAnimation && currentFrameIndex == frameNumbers.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.stopAnimation()
                }
            }
        }
    }
    
    private func loadFrameAtIndex(_ index: Int, from frameNumbers: [Int]) {
        // Find the saved frame with the matching frame number
        if let savedFrame = savedFrames.first(where: { $0.frameNumber == frameNumbers[index] && $0.name == selectedAnimationName }) {
            figure = savedFrame.pose.toStickFigure2D()
        }
    }
    
    private func stopAnimation() {
        isPlayingAnimation = false
        animationTimer?.invalidate()
        animationTimer = nil
        currentFrameIndex = 0
    }
    
    var colorControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    isColorsCollapsed.toggle()
                }
            }) {
                HStack {
                    Text("Colors")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isColorsCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if !isColorsCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Head:")
                        Spacer()
                        ColorPicker("", selection: $figure.headColor)
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Torso:")
                        Spacer()
                        ColorPicker("", selection: $figure.torsoColor)
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Left Arm:")
                        Spacer()
                        ColorPicker("", selection: $figure.leftArmColor)
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Right Arm:")
                        Spacer()
                        ColorPicker("", selection: $figure.rightArmColor)
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Hands:")
                        Spacer()
                        ColorPicker("", selection: $figure.handColor)
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Left Leg:")
                        Spacer()
                        ColorPicker("", selection: $figure.leftLegColor)
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Right Leg:")
                        Spacer()
                        ColorPicker("", selection: $figure.rightLegColor)
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Feet:")
                        Spacer()
                        ColorPicker("", selection: $figure.footColor)
                            .frame(width: 50)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    var objectsControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                showImagePicker = true
            }) {
                Label("Add Image Object", systemImage: "photo.badge.plus")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            
            if !objects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Objects:").font(.caption2).foregroundColor(.gray)
                    
                    ForEach(objects) { object in
                        HStack {
                            Text(object.imageName)
                                .font(.caption)
                            Spacer()
                            Button(action: {
                                objects.removeAll { $0.id == object.id }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(objects: $objects)
        }
        .sheet(isPresented: $showSaveFrameDialog) {
            SaveFrameDialog(
                frameName: $frameName,
                frameNumber: $frameNumber,
                onSave: savePose,
                onCancel: { showSaveFrameDialog = false }
            )
        }
        .sheet(isPresented: $showFramesManager) {
            FramesManagerView(
                savedFrames: $savedFrames,
                onSelectFrame: { frame in
                    figure = frame.pose.toStickFigure2D()
                    objects = frame.objects  // Load objects saved with the frame
                    scrollToCanvas = true
                    showFramesManager = false
                },
                onSave: { persistFramesToStorage() } // Save deletions and edits to UserDefaults
            )
        }
    }
    
    var animationControlsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            //Text("Animation").font(.subheadline).fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Button(action: {
                    // Smart default: Stand is frameNumber 0, everything else starts at 1
                    frameNumber = "0"
                    showSaveFrameDialog = true
                }) {
                    Label("Save Frame", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Button(action: { showFramesManager = true }) {
                    Label("Open Frame", systemImage: "folder.badge.gearshape")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private func savePose() {
        // Create a new AnimationFrame with the current pose, name, and frame number
        guard let frameNum = Int(frameNumber) else {
            // Invalid frame number, don't save
            return
        }
        
        let frame = AnimationFrame(
            name: frameName.isEmpty ? "Unnamed" : frameName,
            frameNumber: frameNum,
            pose: figure,
            objects: objects  // Save the current objects with this frame
        )
        
        // Debug: print saved object positions
        for (i, obj) in objects.enumerated() {
            print("DEBUG SAVE: object[\(i)] name=\(obj.imageName), position=\(obj.position), scale=\(obj.scale), rotation=\(obj.rotation)")
        }
        
        savedFrames.append(frame)
        
        // Persist frames to UserDefaults
        persistFramesToStorage()
        
        // Reset the dialog
        frameName = ""
        frameNumber = "1"
        showSaveFrameDialog = false
    }
    
    private func persistFramesToStorage() {
        // Save all frames to UserDefaults so they persist between app restarts
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(savedFrames) {
            UserDefaults.standard.set(data, forKey: "saved_animation_frames_2d")
            print("✓ Saved \(savedFrames.count) frames to UserDefaults")
        } else {
            print("✗ Error saving frames to UserDefaults")
        }
    }
    
    private func loadSavedFrames() {
        // First load from Bundle (animations.json)
        savedFrames = AnimationStorage.shared.loadFrames()
        
        // Then load any user-created frames from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "saved_animation_frames_2d") {
            let decoder = JSONDecoder()
            if let userFrames = try? decoder.decode([AnimationFrame].self, from: data) {
                print("✓ Loaded \(userFrames.count) user-created frames from UserDefaults")
                // Append user frames to bundle frames (avoiding duplicates by ID)
                let bundleIds = Set(savedFrames.map { $0.id })
                for userFrame in userFrames {
                    if !bundleIds.contains(userFrame.id) {
                        savedFrames.append(userFrame)
                    }
                }
            }
        }
    }
    
    private func loadLastFigureState() {
        // Try to load the last saved figure state
        if let data = UserDefaults.standard.data(forKey: "last_figure_state_2d"),
           let pose = try? JSONDecoder().decode(StickFigure2DPose.self, from: data) {
            figure = pose.toStickFigure2D()
        } else {
            // If no saved state, load the default Stand pose
            figure = StickFigure2D.defaultStand()
        }
    }
    
    private func saveCurrentFigureState() {
        // Save the current figure state to UserDefaults
        let pose = StickFigure2DPose(from: figure)
        if let data = try? JSONEncoder().encode(pose) {
            UserDefaults.standard.set(data, forKey: "last_figure_state_2d")
        }
    }
    
    private func resetFigure() {
        // Load the default Stand pose
        figure = StickFigure2D.defaultStand()
        // Set scale to 200% (2.4)
        figure.scale = 2.4
        // Reset canvas offset
        canvasOffset = .zero
        lastCanvasOffset = .zero
        // Clear all objects
        objects = []
        // Save this as the current state
        saveCurrentFigureState()
    }
    
    private func updateJoint(_ jointName: String, with position: CGPoint) {
        draggedJoint = jointName

    // Calculate the angle from parent to this position
    let angle = calculateAngle(from: getParentPosition(for: jointName), to: position)

    switch jointName {
    case "waist":
        let midTorsoAngle = 270.0 + figure.midTorsoAngle
        let targetAngle = wrapAngle(angle - midTorsoAngle)
        // Apply very strong damping for waist testing: blend 90% old angle with 10% new angle
        let newAngle = smoothedAngle(last: lastWaistAngle, target: targetAngle, alpha: 0.1)
        figure.waistTorsoAngle = wrapAngle(newAngle)
        lastWaistAngle = wrapAngle(newAngle)
    case "midTorso":
        let midTorsoAngle = 270.0 + figure.midTorsoAngle
        let targetAngle = wrapAngle(angle - midTorsoAngle)
        // Apply damping: blend 70% old angle with 30% new angle for smoother rotation
        let newAngle = smoothedAngle(last: lastMidTorsoAngle, target: targetAngle, alpha: 0.3)
        figure.waistTorsoAngle = wrapAngle(newAngle)
        lastMidTorsoAngle = wrapAngle(newAngle)
    case "neck":
        let midTorsoAngle = 270.0 + figure.waistTorsoAngle
        figure.midTorsoAngle = wrapAngle(angle - midTorsoAngle)
    case "head":
        // Head angle is stored as absolute world angle (0° = up)
        // Convert from atan2 angle (0° = right) to our system (0° = up)
        figure.headAngle = wrapAngle(angle + 90)
    case "leftShoulder":
        let parentAngle = 270.0 + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.leftShoulderAngle = wrapAngle(angle - parentAngle)
    case "rightShoulder":
        let parentAngle = 270.0 + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.rightShoulderAngle = wrapAngle(angle - parentAngle)
    case "leftElbow":
        let parentAngle = 270.0 + figure.leftShoulderAngle + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.leftElbowAngle = wrapAngle(angle - parentAngle)
    case "rightElbow":
        let parentAngle = 270.0 + figure.rightShoulderAngle + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.rightElbowAngle = wrapAngle(angle - parentAngle)
    case "leftKnee":
        // Legs rotate directly from waist center
        let angleFromWaist = calculateAngle(from: figure.waistPosition, to: position)
        let parentAngle = 270.0 // Legs always point down, no waist rotation applied
        figure.leftKneeAngle = wrapAngle(angleFromWaist - parentAngle)
    case "rightKnee":
        // Legs rotate directly from waist center
        let angleFromWaist = calculateAngle(from: figure.waistPosition, to: position)
        let parentAngle = 270.0 // Legs always point down, no waist rotation applied
        figure.rightKneeAngle = wrapAngle(angleFromWaist - parentAngle)
    case "leftFoot":
        // Feet are children of the knee, so calculate from the upper leg end position
        let angleFromKnee = calculateAngle(from: figure.leftUpperLegEnd, to: position)
        let parentAngle = 270.0 + figure.leftKneeAngle
        figure.leftFootAngle = wrapAngle(angleFromKnee - parentAngle)
    case "rightFoot":
        // Feet are children of the knee, so calculate from the upper leg end position
        let angleFromKnee = calculateAngle(from: figure.rightUpperLegEnd, to: position)
        let parentAngle = 270.0 + figure.rightKneeAngle
        figure.rightFootAngle = wrapAngle(angleFromKnee - parentAngle)
    default:
        break
    }

    // Save the current state after any joint update
    // saveCurrentFigureState()  -- Not needed for inline view (uses @Binding)
    }
    
    private func getParentPosition(for jointName: String) -> CGPoint {
        switch jointName {
        case "waist":
            return figure.midTorsoPosition
        case "midTorso":
            return figure.midTorsoPosition
        case "neck":
            return figure.midTorsoPosition
        case "head":
            return figure.neckPosition
        case "leftShoulder":
            return figure.neckPosition
        case "rightShoulder":
            return figure.neckPosition
        case "leftElbow":
            return figure.leftShoulderPosition
        case "rightElbow":
            return figure.rightShoulderPosition
        case "leftKnee":
            return figure.waistPosition
        case "rightKnee":
            return figure.waistPosition
        case "leftFoot":
            return figure.leftUpperLegEnd
        case "rightFoot":
            return figure.rightUpperLegEnd
        default:
            return CGPoint.zero
        }
    }
    
    private func calculateAngle(from: CGPoint, to: CGPoint) -> Double {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let radians = atan2(dy, dx)
        return radians * 180 / .pi
    }
}
