import SwiftUI
import Combine
import PhotosUI

// MARK: - Saveable Animation Frame

struct AnimationFrame: Codable, Identifiable {
    let id: UUID
    let name: String
    let frameNumber: Int
    let pose: StickFigure2DPose
    let createdAt: Date
    
    init(name: String, frameNumber: Int, pose: StickFigure2D) {
        self.id = UUID()
        self.name = name
        self.frameNumber = frameNumber
        self.pose = StickFigure2DPose(from: pose)
        self.createdAt = Date()
    }
    
    init(id: UUID, name: String, frameNumber: Int, pose: StickFigure2D) {
        self.id = id
        self.name = name
        self.frameNumber = frameNumber
        self.pose = StickFigure2DPose(from: pose)
        self.createdAt = Date()
    }
}

// MARK: - Animation Objects

struct AnimationObject: Codable, Identifiable {
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
    // Root position
    var waistPosition: CGPoint = CGPoint(x: 200, y: 225)
    
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
    var scale: Double = 1.0 // Size multiplier (1.0 = 100%)
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
        // Load from saved Stand frame if available
        if let data = UserDefaults.standard.data(forKey: "default_stand_pose_2d"),
           let pose = try? JSONDecoder().decode(StickFigure2DPose.self, from: data) {
            return pose.toStickFigure2D()
        }
        // Otherwise return default constructor values
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
    var leftUpperLegEnd: CGPoint {
        let angle = 270.0 + leftKneeAngle // 270° = pointing down
        let radians = angle * .pi / 180
        let x = waistPosition.x - shoulderWidth / 4 + upperLegLength * cos(radians)
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
    var rightUpperLegEnd: CGPoint {
        let angle = 270.0 + rightKneeAngle
        let radians = angle * .pi / 180
        let x = waistPosition.x + shoulderWidth / 4 + upperLegLength * cos(radians)
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

// MARK: - Drawing View

struct StickFigure2DView: View {
    let figure: StickFigure2D
    let jointRadius: CGFloat = 5
    let jointColor: Color = .blue
    
    var body: some View {
        Canvas { context, size in
            drawFigure(in: context)
        }
    }
    
    private func drawFigure(in context: GraphicsContext) {
        // Get canvas center for scaling
        let canvasSize = CGSize(width: 400, height: 450)
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        
        // Helper function to scale a point around the canvas center
        func scalePoint(_ point: CGPoint) -> CGPoint {
            let dx = point.x - canvasCenter.x
            let dy = point.y - canvasCenter.y
            return CGPoint(
                x: canvasCenter.x + dx * figure.scale,
                y: canvasCenter.y + dy * figure.scale
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
        let scaledHeadRadius = figure.headRadius * figure.scale * figure.headRadiusMultiplier
        let headCircle = Circle().path(in: CGRect(
            x: headPos.x - scaledHeadRadius,
            y: headPos.y - scaledHeadRadius,
            width: scaledHeadRadius * 2,
            height: scaledHeadRadius * 2
        ))
        context.fill(headCircle, with: .color(figure.headColor))
        context.stroke(headCircle, with: .color(figure.headColor.opacity(0.8)), lineWidth: figure.strokeThickness)
        
        // Draw joints
        drawJoint(at: waistPos, in: context)
        drawJoint(at: midTorsoPos, in: context)
        drawJoint(at: neckPos, in: context)
        drawJoint(at: leftUpperArmEnd, in: context)
        drawJoint(at: rightUpperArmEnd, in: context)
        drawJoint(at: leftUpperLegEnd, in: context)
        drawJoint(at: rightUpperLegEnd, in: context)
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
        "guy_stand", "guy_move1", "guy_move2", "guy_move3", "guy_move4",
        "guy_wave1", "guy_wave2", "guy_jump1", "guy_jump2", "guy_jump3",
        "pushup1", "pushup2", "pushup3", "pushup4",
        "pullup1", "pullup2", "pullup3", "pullup4",
        "jumpingjack1", "jumpingjack2", "jumpingjack3", "jumpingjack4",
        "yoga1", "yoga2", "yoga3", "yoga4", "yoga5", "yoga6", "yoga7", "yoga8",
        "meditate1", "meditate2", "meditate3",
        "rest1", "rest2",
        "kb1", "kb2", "kb3", "kb4", "kb5", "kb6", "kb7", "kb8",
        "curls1", "curls2", "curls3", "curls4",
        "shaker1", "shaker2", "Shaker",
        "topview1", "topview2", "topview3",
        "leaf", "Apple", "BlueDrink", "RedDrink"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
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
                                    position: CGPoint(x: 200, y: 225),
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
                }
                .padding()
            }
            .navigationTitle("Select Image")
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

// MARK: - Save Frame Dialog

struct SaveFrameDialog: View {
    @Binding var frameName: String
    @Binding var frameNumber: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
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
    @State private var scrollToCanvas = false
    @State private var objects: [AnimationObject] = []
    @State private var showImagePicker = false
    @State private var selectedObjectId: UUID? = nil
    @State private var selectedAnimationName = ""
    @State private var frameSequence = "1,2,3,4,3,2,1"
    @State private var isPlayingAnimation = false
    @State private var currentFrameIndex = 0
    @State private var animationTimer: Timer? = nil
    
    let canvasSize = CGSize(width: 400, height: 450)

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
    
    var body: some View {
        baseView
            .onAppear {
                loadSavedFrames()
                // Load the last saved figure state, or default Stand pose if none exists
                loadLastFigureState()
            }
            .onDisappear {
                // Save the current figure state when leaving the editor
                saveCurrentFigureState()
            }
            .onChange(of: figure.waistTorsoAngle) { saveCurrentFigureState() }
            .onChange(of: figure.midTorsoAngle) { saveCurrentFigureState() }
            .onChange(of: figure.headAngle) { saveCurrentFigureState() }
            .onChange(of: figure.headRadiusMultiplier) { saveCurrentFigureState() }
            .onChange(of: figure.leftShoulderAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightShoulderAngle) { saveCurrentFigureState() }
            .onChange(of: figure.leftElbowAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightElbowAngle) { saveCurrentFigureState() }
            .onChange(of: figure.leftKneeAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightKneeAngle) { saveCurrentFigureState() }
            .onChange(of: figure.leftFootAngle) { saveCurrentFigureState() }
            .onChange(of: figure.rightFootAngle) { saveCurrentFigureState() }
            .onChange(of: figure.scale) { saveCurrentFigureState() }
            .onChange(of: figure.strokeThickness) { saveCurrentFigureState() }
    }
    
    var baseView: some View {
        contentWithBodyOnChanges
    }
    
    var contentWithBodyOnChanges: some View {
        contentWithArmOnChanges
    }
    
    var contentWithArmOnChanges: some View {
        contentWithJointOnChanges
    }
    
    var contentWithJointOnChanges: some View {
        contentWithTorsoOnChanges
    }
    
    var contentWithTorsoOnChanges: some View {
        VStack(spacing: 0) {
            headerView
            scrollableContent
        }
    }
    
    var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    canvasView
                        .id("canvas")
                    animationPlaybackView
                    sizeControlView
                    jointControlsView
                    colorControlsView
                    objectsControlsView
                    animationControlsView
                }
                .padding(4)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
            
            StickFigure2DView(figure: figure)
            
            // Render animation objects
            ForEach(objects) { object in
                if let uiImage = UIImage(named: object.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50 * object.scale, height: 50 * object.scale)
                        .rotationEffect(.degrees(object.rotation))
                        .position(object.position)
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
        .padding(4)
    }
    
    // Helper function to scale points for drag handles
    private func scalePoint(_ point: CGPoint) -> CGPoint {
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = point.x - canvasCenter.x
        let dy = point.y - canvasCenter.y
        return CGPoint(
            x: canvasCenter.x + dx * figure.scale,
            y: canvasCenter.y + dy * figure.scale
        )
    }
    
    // Helper function to unscale drag positions back to figure coordinates
    private func unscalePoint(_ point: CGPoint) -> CGPoint {
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = point.x - canvasCenter.x
        let dy = point.y - canvasCenter.y
        return CGPoint(
            x: canvasCenter.x + dx / figure.scale,
            y: canvasCenter.y + dy / figure.scale
        )
    }
    
    // Function to create control handles for animation objects
    @ViewBuilder
    private func objectControlHandles(for object: AnimationObject) -> some View {
        Group {
            // Center handle (for position adjustment)
            ZStack {
                Circle()
                    .fill(selectedObjectId == object.id ? Color.yellow : Color.green)
                    .frame(width: 8, height: 8)
                
                // Larger invisible hit area
                Circle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
            }
            .position(object.position)
            .gesture(DragGesture()
                .onChanged { value in
                    selectedObjectId = object.id
                    if let index = objects.firstIndex(where: { $0.id == object.id }) {
                        objects[index].position = value.location
                    }
                }
                .onEnded { _ in }
            )
            
            // Corner handle for rotation and scale
            let handleDistance: CGFloat = 30
            let angle = object.rotation * .pi / 180
            let cornerOffset = CGPoint(
                x: cos(angle) * handleDistance,
                y: sin(angle) * handleDistance
            )
            let cornerPosition = CGPoint(
                x: object.position.x + cornerOffset.x,
                y: object.position.y + cornerOffset.y
            )
            
            ZStack {
                Circle()
                    .fill(selectedObjectId == object.id ? Color.orange : Color.red)
                    .frame(width: 6, height: 6)
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 20, height: 20)
            }
            .position(cornerPosition)
            .gesture(DragGesture()
                .onChanged { value in
                    selectedObjectId = object.id
                    if let index = objects.firstIndex(where: { $0.id == object.id }) {
                        let dx = value.location.x - objects[index].position.x
                        let dy = value.location.y - objects[index].position.y
                        let newAngle = atan2(dy, dx) * 180 / .pi
                        let newScale = sqrt(dx * dx + dy * dy) / handleDistance
                        objects[index].rotation = newAngle
                        objects[index].scale = max(0.1, newScale)
                    }
                }
                .onEnded { _ in }
            )
        }
    }
    
    var jointHandles: some View {
        Group {
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
            Text("Joint Controls").font(.subheadline).fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Waist Rotation:")
                    Slider(value: $figure.waistTorsoAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.waistTorsoAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Left Shoulder:")
                    Slider(value: $figure.leftShoulderAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.leftShoulderAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Right Shoulder:")
                    Slider(value: $figure.rightShoulderAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.rightShoulderAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Left Elbow:")
                    Slider(value: $figure.leftElbowAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.leftElbowAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Right Elbow:")
                    Slider(value: $figure.rightElbowAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.rightElbowAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Left Knee:")
                    Slider(value: $figure.leftKneeAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.leftKneeAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Right Knee:")
                    Slider(value: $figure.rightKneeAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.rightKneeAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Left Foot:")
                    Slider(value: $figure.leftFootAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.leftFootAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Right Foot:")
                    Slider(value: $figure.rightFootAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.rightFootAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Head:")
                    Slider(value: $figure.headAngle, in: -180...180, step: 1)
                    Text("\(Int(figure.headAngle))°")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Head Size:")
                    Slider(value: $figure.headRadiusMultiplier, in: 0.5...2.0, step: 0.1)
                    Text("\(String(format: "%.1f", figure.headRadiusMultiplier))x")
                        .frame(width: 40)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
    
    var animationPlaybackView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation Playback").font(.subheadline).fontWeight(.semibold)
            
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
        .padding()
    }
    
    var sizeControlView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Figure Size:")
                Spacer()
                Text("\(Int(figure.scale * 100))%")
                    .frame(width: 40)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 12) {
                Text("50%")
                    .font(.caption)
                    .foregroundColor(.gray)

                Slider(value: $figure.scale, in: 0.5...2.0, step: 0.05)

                Text("200%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding()
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
            
            if currentFrameIndex == frameNumbers.count - 1 {
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
            Text("Colors").font(.subheadline).fontWeight(.semibold)
            
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
                
                Divider()
                
                HStack {
                    Text("Stroke Thickness:")
                    Slider(value: $figure.strokeThickness, in: 0.5...20, step: 0.5)
                    Text("\(String(format: "%.1f", figure.strokeThickness))")
                        .frame(width: 40)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
    
    var objectsControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objects").font(.subheadline).fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
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
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(objects: $objects)
        }
    }
    
    var animationControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation").font(.subheadline).fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Button(action: { showSaveFrameDialog = true }) {
                    Label("Save Frame", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Saved frames list
            if !savedFrames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Saved Frames").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Button(action: {
                            isEditingFrames.toggle()
                        }) {
                            Text(isEditingFrames ? "Done" : "Edit")
                                .font(.caption)
                        }
                    }
                    
                    List {
                        ForEach(savedFrames) { frame in
                            HStack(spacing: 12) {
                                if isEditingFrames {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                
                                Button(action: {
                                    if !isEditingFrames {
                                        figure = frame.pose.toStickFigure2D()
                                        scrollToCanvas = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(frame.name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .lineLimit(1)
                                            Text("Frame #\(frame.frameNumber)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isEditingFrames)
                                
                                if isEditingFrames {
                                    Button(action: {
                                        frameToDelete = frame
                                        showDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .onMove { indices, newOffset in
                            savedFrames.move(fromOffsets: indices, toOffset: newOffset)
                            saveSavedFrames()
                        }
                    }
                    .frame(height: 200)
                    .listStyle(.plain)
                    .environment(\.editMode, isEditingFrames ? .constant(.active) : .constant(.inactive))
                }
                .padding(.horizontal)
            } else {
                Text("No saved frames yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
        .sheet(isPresented: $showSaveFrameDialog) {
            SaveFrameDialog(
                frameName: $frameName,
                frameNumber: $frameNumber,
                onSave: savePose,
                onCancel: { showSaveFrameDialog = false }
            )
        }
        .alert("Delete Frame?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let frameToDelete = frameToDelete {
                    savedFrames.removeAll { $0.id == frameToDelete.id }
                    saveSavedFrames()
                }
            }
        } message: {
            if let frame = frameToDelete {
                Text("Are you sure you want to delete '\(frame.name)'?")
            }
        }
    }
    
    private func savePose() {
        let frameNum = Int(frameNumber) ?? 1
        let name = frameName.trimmingCharacters(in: .whitespaces).isEmpty ? "Frame \(frameNum)" : frameName
        let frame = AnimationFrame(name: name, frameNumber: frameNum, pose: figure)
        
        // Add to savedFrames list
        savedFrames.append(frame)
        saveSavedFrames()
        
        // If this is the "Stand" pose, save it as the default
        if name == "Stand" {
            saveDefaultStandPose(figure)
        }
        
        // Reset the dialog
        frameName = ""
        frameNumber = "1"
        showSaveFrameDialog = false
    }
    
    private func saveSavedFrames() {
        if let encoded = try? JSONEncoder().encode(savedFrames) {
            UserDefaults.standard.set(encoded, forKey: "saved_animation_frames")
        }
    }
    
    private func loadSavedFrames() {
        if let data = UserDefaults.standard.data(forKey: "saved_animation_frames"),
           let decoded = try? JSONDecoder().decode([AnimationFrame].self, from: data) {
            savedFrames = decoded
        }
        
        // If no Stand pose exists, create default one
        if !savedFrames.contains(where: { $0.name == "Stand" }) {
            let defaultStand = StickFigure2D()
            let standFrame = AnimationFrame(name: "Stand", frameNumber: 0, pose: defaultStand)
            savedFrames.insert(standFrame, at: 0)
            saveSavedFrames()
            saveDefaultStandPose(defaultStand)
        }
    }
    
    private func saveDefaultStandPose(_ figure: StickFigure2D) {
        let pose = StickFigure2DPose(from: figure)
        if let encoded = try? JSONEncoder().encode(pose) {
            UserDefaults.standard.set(encoded, forKey: "default_stand_pose_2d")
        }
    }
    
    private func loadDefaultStandPose() -> StickFigure2D? {
        if let data = UserDefaults.standard.data(forKey: "default_stand_pose_2d"),
           let pose = try? JSONDecoder().decode(StickFigure2DPose.self, from: data) {
            return pose.toStickFigure2D()
        }
        return nil
    }
    
    private func loadPose() {
        if let data = UserDefaults.standard.data(forKey: "last_saved_frame"),
           let frame = try? JSONDecoder().decode(AnimationFrame.self, from: data) {
            figure = frame.pose.toStickFigure2D()
        }
    }
    
    private func saveCurrentFigureState() {
        // Save the current figure state for persistence
        let pose = StickFigure2DPose(from: figure)
        if let encoded = try? JSONEncoder().encode(pose) {
            UserDefaults.standard.set(encoded, forKey: "last_figure_state_2d")
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
    
    private func resetFigure() {
        // Load the default Stand pose
        figure = StickFigure2D.defaultStand()
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
        figure.waistTorsoAngle = newAngle
        lastWaistAngle = newAngle
    case "midTorso":
        let midTorsoAngle = 270.0 + figure.midTorsoAngle
        let targetAngle = wrapAngle(angle - midTorsoAngle)
        // Apply damping: blend 70% old angle with 30% new angle for smoother rotation
        let newAngle = smoothedAngle(last: lastMidTorsoAngle, target: targetAngle, alpha: 0.3)
        figure.waistTorsoAngle = newAngle
        lastMidTorsoAngle = newAngle
    case "neck":
        let midTorsoAngle = 270.0 + figure.waistTorsoAngle
        figure.midTorsoAngle = angle - midTorsoAngle
    case "head":
        // Head angle is stored as absolute world angle (0° = up)
        // Convert from atan2 angle (0° = right) to our system (0° = up)
        figure.headAngle = angle + 90
    case "leftShoulder":
        let parentAngle = 270.0 + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.leftShoulderAngle = angle - parentAngle
    case "rightShoulder":
        let parentAngle = 270.0 + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.rightShoulderAngle = angle - parentAngle
    case "leftElbow":
        let parentAngle = 270.0 + figure.leftShoulderAngle + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.leftElbowAngle = angle - parentAngle
    case "rightElbow":
        let parentAngle = 270.0 + figure.rightShoulderAngle + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.rightElbowAngle = angle - parentAngle
    case "leftKnee":
        let parentAngle = 270.0 + figure.waistTorsoAngle
        figure.leftKneeAngle = angle - parentAngle
    case "rightKnee":
        let parentAngle = 270.0 + figure.waistTorsoAngle
        figure.rightKneeAngle = angle - parentAngle
    case "leftFoot":
        let parentAngle = 270.0 + figure.leftKneeAngle + figure.waistTorsoAngle
        figure.leftFootAngle = angle - parentAngle
    case "rightFoot":
        let parentAngle = 270.0 + figure.rightKneeAngle + figure.waistTorsoAngle
        figure.rightFootAngle = angle - parentAngle
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

// MARK: - Inline Editor Component

struct StickFigure2DEditorInlineView: View {
    @Binding var figure: StickFigure2D
    @State private var draggedJoint: String? = nil
    @State private var lastWaistAngle: Double = 0
    @State private var lastMidTorsoAngle: Double = 0
    
    let canvasSize = CGSize(width: 400, height: 500)

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
    
    // Helper function to scale points for drag handles
    private func scalePoint(_ point: CGPoint) -> CGPoint {
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = point.x - canvasCenter.x
        let dy = point.y - canvasCenter.y
        return CGPoint(
            x: canvasCenter.x + dx * figure.scale,
            y: canvasCenter.y + dy * figure.scale
        )
    }
    
    // Helper function to unscale drag positions back to figure coordinates
    private func unscalePoint(_ point: CGPoint) -> CGPoint {
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = point.x - canvasCenter.x
        let dy = point.y - canvasCenter.y
        return CGPoint(
            x: canvasCenter.x + dx / figure.scale,
            y: canvasCenter.y + dy / figure.scale
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                
                StickFigure2DView(figure: figure)
                
                // Draggable joint handles
                Group {
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
            .frame(width: canvasSize.width, height: canvasSize.height)
            .padding(4)
            
            // Controls
            VStack(alignment: .leading, spacing: 12) {
                Text("Joint Controls").font(.subheadline).fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Waist Rotation:")
                        Slider(value: $figure.waistTorsoAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.waistTorsoAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Shoulder:")
                        Slider(value: $figure.leftShoulderAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.leftShoulderAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Shoulder:")
                        Slider(value: $figure.rightShoulderAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.rightShoulderAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Elbow:")
                        Slider(value: $figure.leftElbowAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.leftElbowAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Elbow:")
                        Slider(value: $figure.rightElbowAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.rightElbowAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Knee:")
                        Slider(value: $figure.leftKneeAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.leftKneeAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Knee:")
                        Slider(value: $figure.rightKneeAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.rightKneeAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Left Foot:")
                        Slider(value: $figure.leftFootAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.leftFootAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Right Foot:")
                        Slider(value: $figure.rightFootAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.rightFootAngle))°")
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Head:")
                        Slider(value: $figure.headAngle, in: -180...180, step: 1)
                        Text("\(Int(figure.headAngle))°")
                            .frame(width: 40)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
            
            // Colors
            VStack(alignment: .leading, spacing: 12) {
                Text("Colors").font(.subheadline).fontWeight(.semibold)
                
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
                    
                    Divider()
                    
                    HStack {
                        Text("Stroke Thickness:")
                        Slider(value: $figure.strokeThickness, in: 0.5...20, step: 0.5)
                        Text("\(String(format: "%.1f", figure.strokeThickness))")
                            .frame(width: 40)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func jointDragHandle(_ name: String, position: CGPoint, color: Color) -> some View {
        Circle()
            .fill(draggedJoint == name ? Color.red : color)
            .frame(width: name.contains("Foot") || name.contains("Hand") ? 8 : 10, height: name.contains("Foot") || name.contains("Hand") ? 8 : 10)
            .position(position)
            .gesture(DragGesture()
                .onChanged { value in
                    updateJoint(name, with: value.location)
                }
                .onEnded { _ in
                    draggedJoint = nil
                }
            )
    }
    
    @ViewBuilder
    private func sliderControl(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: -180...180, step: 1)
            Text("\(Int(value.wrappedValue))°")
                .frame(width: 40)
        }
    }
    
    @ViewBuilder
    private func colorControl(_ label: String, color: Binding<Color>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: color)
                .frame(width: 50)
        }
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
        figure.waistTorsoAngle = newAngle
        lastWaistAngle = newAngle
    case "midTorso":
        let midTorsoAngle = 270.0 + figure.midTorsoAngle
        let targetAngle = wrapAngle(angle - midTorsoAngle)
        // Apply damping: blend 70% old angle with 30% new angle for smoother rotation
        let newAngle = smoothedAngle(last: lastMidTorsoAngle, target: targetAngle, alpha: 0.3)
        figure.waistTorsoAngle = newAngle
        lastMidTorsoAngle = newAngle
    case "neck":
        let midTorsoAngle = 270.0 + figure.waistTorsoAngle
        figure.midTorsoAngle = angle - midTorsoAngle
    case "head":
        // Head angle is stored as absolute world angle (0° = up)
        // Convert from atan2 angle (0° = right) to our system (0° = up)
        figure.headAngle = angle + 90
    case "leftShoulder":
        let parentAngle = 270.0 + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.leftShoulderAngle = angle - parentAngle
    case "rightShoulder":
        let parentAngle = 270.0 + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.rightShoulderAngle = angle - parentAngle
    case "leftElbow":
        let parentAngle = 270.0 + figure.leftShoulderAngle + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.leftElbowAngle = angle - parentAngle
    case "rightElbow":
        let parentAngle = 270.0 + figure.rightShoulderAngle + figure.midTorsoAngle + figure.waistTorsoAngle
        figure.rightElbowAngle = angle - parentAngle
    case "leftKnee":
        let parentAngle = 270.0 + figure.waistTorsoAngle
        figure.leftKneeAngle = angle - parentAngle
    case "rightKnee":
        let parentAngle = 270.0 + figure.waistTorsoAngle
        figure.rightKneeAngle = angle - parentAngle
    case "leftFoot":
        let parentAngle = 270.0 + figure.leftKneeAngle + figure.waistTorsoAngle
        figure.leftFootAngle = angle - parentAngle
    case "rightFoot":
        let parentAngle = 270.0 + figure.rightKneeAngle + figure.waistTorsoAngle
        figure.rightFootAngle = angle - parentAngle
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
