////
////  ProgrammableStickFigure.swift
////  Extend
////
////  Created by AI Assistant on 2/20/26.
////
// Proof of concept: Programmable stick figure with customizable clothing

import SwiftUI
import Combine

// MARK: - Saved Pose Model

struct SavedPose: Codable, Identifiable {
    let id: UUID
    let name: String
    let positionNumber: Int
    let pose: SavedStickFigurePose
    let createdAt: Date
    
    init(name: String, positionNumber: Int, pose: StickFigurePose) {
        self.id = UUID()
        self.name = name
        self.positionNumber = positionNumber
        self.pose = SavedStickFigurePose(from: pose)
        self.createdAt = Date()
    }
}

struct SavedStickFigurePose: Codable {
    let headPositionX: CGFloat
    let headPositionY: CGFloat
    let neckPositionX: CGFloat
    let neckPositionY: CGFloat
    let shoulderLeftX: CGFloat
    let shoulderLeftY: CGFloat
    let shoulderRightX: CGFloat
    let shoulderRightY: CGFloat
    let elbowLeftX: CGFloat
    let elbowLeftY: CGFloat
    let elbowRightX: CGFloat
    let elbowRightY: CGFloat
    let handLeftX: CGFloat
    let handLeftY: CGFloat
    let handRightX: CGFloat
    let handRightY: CGFloat
    let hipLeftX: CGFloat
    let hipLeftY: CGFloat
    let hipRightX: CGFloat
    let hipRightY: CGFloat
    let kneeLeftX: CGFloat
    let kneeLeftY: CGFloat
    let kneeRightX: CGFloat
    let kneeRightY: CGFloat
    let footLeftX: CGFloat
    let footLeftY: CGFloat
    let footRightX: CGFloat
    let footRightY: CGFloat
    let frontArmIsLeft: Bool
    let frontLegIsLeft: Bool
    
    init(from pose: StickFigurePose) {
        self.headPositionX = pose.headPosition.x
        self.headPositionY = pose.headPosition.y
        self.neckPositionX = pose.neckPosition.x
        self.neckPositionY = pose.neckPosition.y
        self.shoulderLeftX = pose.shoulderLeft.x
        self.shoulderLeftY = pose.shoulderLeft.y
        self.shoulderRightX = pose.shoulderRight.x
        self.shoulderRightY = pose.shoulderRight.y
        self.elbowLeftX = pose.elbowLeft.x
        self.elbowLeftY = pose.elbowLeft.y
        self.elbowRightX = pose.elbowRight.x
        self.elbowRightY = pose.elbowRight.y
        self.handLeftX = pose.handLeft.x
        self.handLeftY = pose.handLeft.y
        self.handRightX = pose.handRight.x
        self.handRightY = pose.handRight.y
        self.hipLeftX = pose.hipLeft.x
        self.hipLeftY = pose.hipLeft.y
        self.hipRightX = pose.hipRight.x
        self.hipRightY = pose.hipRight.y
        self.kneeLeftX = pose.kneeLeft.x
        self.kneeLeftY = pose.kneeLeft.y
        self.kneeRightX = pose.kneeRight.x
        self.kneeRightY = pose.kneeRight.y
        self.footLeftX = pose.footLeft.x
        self.footLeftY = pose.footLeft.y
        self.footRightX = pose.footRight.x
        self.footRightY = pose.footRight.y
        self.frontArmIsLeft = pose.frontArmIsLeft
        self.frontLegIsLeft = pose.frontLegIsLeft
    }
    
    func toStickFigurePose() -> StickFigurePose {
        StickFigurePose(
            bodyPosition: CGPoint(x: 200, y: 225),
            headPosition: CGPoint(x: headPositionX, y: headPositionY),
            neckPosition: CGPoint(x: neckPositionX, y: neckPositionY),
            shoulderLeft: CGPoint(x: shoulderLeftX, y: shoulderLeftY),
            shoulderRight: CGPoint(x: shoulderRightX, y: shoulderRightY),
            waistPosition: CGPoint(x: (shoulderLeftX + shoulderRightX) / 2, y: (hipLeftY + hipRightY) / 2 - 20),
            elbowLeft: CGPoint(x: elbowLeftX, y: elbowLeftY),
            elbowRight: CGPoint(x: elbowRightX, y: elbowRightY),
            handLeft: CGPoint(x: handLeftX, y: handLeftY),
            handRight: CGPoint(x: handRightX, y: handRightY),
            hipLeft: CGPoint(x: hipLeftX, y: hipLeftY),
            hipRight: CGPoint(x: hipRightX, y: hipRightY),
            kneeLeft: CGPoint(x: kneeLeftX, y: kneeLeftY),
            kneeRight: CGPoint(x: kneeRightX, y: kneeRightY),
            footLeft: CGPoint(x: footLeftX, y: footLeftY),
            footRight: CGPoint(x: footRightX, y: footRightY),
            frontArmIsLeft: frontArmIsLeft,
            frontLegIsLeft: frontLegIsLeft
        )
    }
}

// MARK: - Pose Manager

class PoseManager: ObservableObject {
    @Published var savedPoses: [SavedPose] = []
    
    init() {
        loadPoses()
    }
    
    func savePose(_ pose: StickFigurePose, name: String, positionNumber: Int) {
        let newPose = SavedPose(name: name, positionNumber: positionNumber, pose: pose)
        savedPoses.append(newPose)
        persistPoses()
    }
    
    func deletePose(_ pose: SavedPose) {
        savedPoses.removeAll { $0.id == pose.id }
        persistPoses()
    }
    
    func getPosesForAnimation(named name: String) -> [SavedPose] {
        return savedPoses.filter { $0.name == name }.sorted { $0.positionNumber < $1.positionNumber }
    }
    
    private func persistPoses() {
        if let encoded = try? JSONEncoder().encode(savedPoses) {
            UserDefaults.standard.set(encoded, forKey: "saved_stick_figure_poses")
        }
    }
    
    private func loadPoses() {
        if let data = UserDefaults.standard.data(forKey: "saved_stick_figure_poses"),
           let decoded = try? JSONDecoder().decode([SavedPose].self, from: data) {
            savedPoses = decoded
        }
    }
}

fileprivate func drawMuscleSegment(from start: CGPoint, to end: CGPoint, thickness: CGFloat, color: Color, in context: GraphicsContext) {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let angle = atan2(dy, dx)
    let perpAngle = angle + .pi / 2
    let halfThickness = thickness / 2
    
    var musclePath = Path()
    let tl = CGPoint(x: start.x + cos(perpAngle) * halfThickness, y: start.y + sin(perpAngle) * halfThickness)
    let tr = CGPoint(x: end.x + cos(perpAngle) * halfThickness, y: end.y + sin(perpAngle) * halfThickness)
    let bl = CGPoint(x: start.x - cos(perpAngle) * halfThickness, y: start.y - sin(perpAngle) * halfThickness)
    
    musclePath.move(to: tl)
    musclePath.addLine(to: tr)
    musclePath.addArc(center: end, radius: halfThickness, startAngle: Angle(radians: perpAngle), endAngle: Angle(radians: perpAngle + .pi), clockwise: false)
    musclePath.addLine(to: bl)
    musclePath.addArc(center: start, radius: halfThickness, startAngle: Angle(radians: perpAngle + .pi), endAngle: Angle(radians: perpAngle), clockwise: false)
    musclePath.closeSubpath()
    
    context.fill(musclePath, with: .color(color))
    context.stroke(musclePath, with: .color(color.opacity(0.6)), lineWidth: 1)
}

// MARK: - Clothing Options

struct ClothingStyle {
    var shirtColor: Color
    var pantsColor: Color
    var shoeColor: Color
    var skinColor: Color
    var hasShirt: Bool
    var hasPants: Bool
    var hasShoes: Bool
    var shoulderWidth: CGFloat
    var bodyThickness: CGFloat
    var shoulderJointSize: CGFloat
    
    // Individual body part colors
    var headNeckColor: Color
    var torsoShoulderColor: Color
    var upperArmColor: Color
    var lowerArmColor: Color
    var handColor: Color
    var feetColor: Color
    var upperLegColor: Color
    var lowerLegColor: Color
    
    static let `default` = ClothingStyle(
        shirtColor: .blue,
        pantsColor: .gray,
        shoeColor: .black,
        skinColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        hasShirt: true,
        hasPants: true,
        hasShoes: true,
        shoulderWidth: 20,
        bodyThickness: 6,
        shoulderJointSize: 6,
        headNeckColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        torsoShoulderColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        upperArmColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        lowerArmColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        handColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        feetColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        upperLegColor: Color(red: 0.9, green: 0.7, blue: 0.6),
        lowerLegColor: Color(red: 0.9, green: 0.7, blue: 0.6)
    )
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(shirtColor.toHex(), forKey: "prog_stick_shirt_color")
        defaults.set(pantsColor.toHex(), forKey: "prog_stick_pants_color")
        defaults.set(shoeColor.toHex(), forKey: "prog_stick_shoe_color")
        defaults.set(skinColor.toHex(), forKey: "prog_stick_skin_color")
        defaults.set(hasShirt, forKey: "prog_stick_has_shirt")
        defaults.set(hasPants, forKey: "prog_stick_has_pants")
        defaults.set(hasShoes, forKey: "prog_stick_has_shoes")
        defaults.set(Double(shoulderWidth), forKey: "prog_stick_shoulder_width")
        defaults.set(Double(bodyThickness), forKey: "prog_stick_body_thickness")
        defaults.set(Double(shoulderJointSize), forKey: "prog_stick_shoulder_joint_size")
        defaults.set(headNeckColor.toHex(), forKey: "prog_stick_head_neck_color")
        defaults.set(torsoShoulderColor.toHex(), forKey: "prog_stick_torso_shoulder_color")
        defaults.set(upperArmColor.toHex(), forKey: "prog_stick_upper_arm_color")
        defaults.set(lowerArmColor.toHex(), forKey: "prog_stick_lower_arm_color")
        defaults.set(handColor.toHex(), forKey: "prog_stick_hand_color")
        defaults.set(feetColor.toHex(), forKey: "prog_stick_feet_color")
        defaults.set(upperLegColor.toHex(), forKey: "prog_stick_upper_leg_color")
        defaults.set(lowerLegColor.toHex(), forKey: "prog_stick_lower_leg_color")
    }
    
    static func load() -> ClothingStyle {
        let defaults = UserDefaults.standard
        let skinDefault = Color(red: 0.9, green: 0.7, blue: 0.6)
        
        return ClothingStyle(
            shirtColor: Color(hex: defaults.string(forKey: "prog_stick_shirt_color") ?? "#0000FF") ?? .blue,
            pantsColor: Color(hex: defaults.string(forKey: "prog_stick_pants_color") ?? "#808080") ?? .gray,
            shoeColor: Color(hex: defaults.string(forKey: "prog_stick_shoe_color") ?? "#000000") ?? .black,
            skinColor: Color(hex: defaults.string(forKey: "prog_stick_skin_color") ?? "#E6B399") ?? skinDefault,
            hasShirt: defaults.object(forKey: "prog_stick_has_shirt") as? Bool ?? true,
            hasPants: defaults.object(forKey: "prog_stick_has_pants") as? Bool ?? true,
            hasShoes: defaults.object(forKey: "prog_stick_has_shoes") as? Bool ?? true,
            shoulderWidth: 20,
            bodyThickness: 6,
            shoulderJointSize: CGFloat(defaults.object(forKey: "prog_stick_shoulder_joint_size") as? Double ?? 6),
            headNeckColor: Color(hex: defaults.string(forKey: "prog_stick_head_neck_color") ?? "#E6B399") ?? skinDefault,
            torsoShoulderColor: Color(hex: defaults.string(forKey: "prog_stick_torso_shoulder_color") ?? "#E6B399") ?? skinDefault,
            upperArmColor: Color(hex: defaults.string(forKey: "prog_stick_upper_arm_color") ?? "#E6B399") ?? skinDefault,
            lowerArmColor: Color(hex: defaults.string(forKey: "prog_stick_lower_arm_color") ?? "#E6B399") ?? skinDefault,
            handColor: Color(hex: defaults.string(forKey: "prog_stick_hand_color") ?? "#E6B399") ?? skinDefault,
            feetColor: Color(hex: defaults.string(forKey: "prog_stick_feet_color") ?? "#E6B399") ?? skinDefault,
            upperLegColor: Color(hex: defaults.string(forKey: "prog_stick_upper_leg_color") ?? "#E6B399") ?? skinDefault,
            lowerLegColor: Color(hex: defaults.string(forKey: "prog_stick_lower_leg_color") ?? "#E6B399") ?? skinDefault
        )
    }
}

extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
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

struct StickFigurePose {
    var bodyPosition: CGPoint = CGPoint(x: 200, y: 225) // center position of whole body
    var headPosition: CGPoint
    var headTilt: Double = 0 // rotation in degrees
    var neckPosition: CGPoint
    var shoulderLeft: CGPoint
    var shoulderRight: CGPoint
    var waistPosition: CGPoint // for bending at waist
    var elbowLeft: CGPoint
    var elbowRight: CGPoint
    var handLeft: CGPoint
    var handRight: CGPoint
    var hipLeft: CGPoint
    var hipRight: CGPoint
    var kneeLeft: CGPoint
    var kneeRight: CGPoint
    var footLeft: CGPoint
    var footRight: CGPoint
    var frontArmIsLeft: Bool
    var frontLegIsLeft: Bool
    
    static func standing(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 60
        let neckY = origin.y - 50
        let shoulderY = origin.y - 45
        let elbowY = origin.y - 15
        let handY = origin.y + 5
        let hipY = origin.y
        let kneeY = origin.y + 25
        let footY = origin.y + 50
        let halfShoulder = shoulderWidth / 2
        let hipWidth = shoulderWidth * 0.8
        let halfHip = hipWidth / 2
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: origin.x, y: headY),
            neckPosition: CGPoint(x: origin.x, y: neckY),
            shoulderLeft: CGPoint(x: origin.x - halfShoulder, y: shoulderY),
            shoulderRight: CGPoint(x: origin.x + halfShoulder, y: shoulderY),
            waistPosition: CGPoint(x: origin.x, y: origin.y - 10),
            elbowLeft: CGPoint(x: origin.x - halfShoulder - 1, y: elbowY),
            elbowRight: CGPoint(x: origin.x + halfShoulder + 1, y: elbowY),
            handLeft: CGPoint(x: origin.x - halfShoulder - 2, y: handY),
            handRight: CGPoint(x: origin.x + halfShoulder + 2, y: handY),
            hipLeft: CGPoint(x: origin.x - halfHip, y: hipY),
            hipRight: CGPoint(x: origin.x + halfHip, y: hipY),
            kneeLeft: CGPoint(x: origin.x - halfShoulder, y: kneeY),
            kneeRight: CGPoint(x: origin.x + halfShoulder, y: kneeY),
            footLeft: CGPoint(x: origin.x - halfShoulder - 2, y: footY),
            footRight: CGPoint(x: origin.x + halfShoulder + 2, y: footY),
            frontArmIsLeft: true,
            frontLegIsLeft: true
        )
    }
    
    static func running1(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 58
        let neckY = origin.y - 48
        let shoulderY = origin.y - 43
        let elbowYL = origin.y - 30
        let elbowYR = origin.y - 20
        let handYL = origin.y - 15
        let handYR = origin.y - 5
        let hipY = origin.y
        let kneeYL = origin.y + 15
        let kneeYR = origin.y + 30
        let footYL = origin.y + 35
        let footYR = origin.y + 50
        let halfShoulder = shoulderWidth / 2
        let armSwing = shoulderWidth * 0.8
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: origin.x, y: headY),
            neckPosition: CGPoint(x: origin.x, y: neckY),
            shoulderLeft: CGPoint(x: origin.x - halfShoulder, y: shoulderY),
            shoulderRight: CGPoint(x: origin.x + halfShoulder, y: shoulderY),
            waistPosition: CGPoint(x: origin.x, y: origin.y - 10),
            elbowLeft: CGPoint(x: origin.x - armSwing, y: elbowYL),
            elbowRight: CGPoint(x: origin.x + armSwing + 5, y: elbowYR),
            handLeft: CGPoint(x: origin.x - halfShoulder, y: handYL),
            handRight: CGPoint(x: origin.x + armSwing + 8, y: handYR),
            hipLeft: CGPoint(x: origin.x - halfShoulder, y: hipY),
            hipRight: CGPoint(x: origin.x + halfShoulder, y: hipY),
            kneeLeft: CGPoint(x: origin.x - halfShoulder + 3, y: kneeYL),
            kneeRight: CGPoint(x: origin.x + halfShoulder + 4, y: kneeYR),
            footLeft: CGPoint(x: origin.x - halfShoulder, y: footYL),
            footRight: CGPoint(x: origin.x + halfShoulder + 7, y: footYR),
            frontArmIsLeft: true,
            frontLegIsLeft: true
        )
    }
    
    static func running2(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 58
        let neckY = origin.y - 48
        let shoulderY = origin.y - 43
        let elbowYL = origin.y - 20
        let elbowYR = origin.y - 30
        let handYL = origin.y - 5
        let handYR = origin.y - 15
        let hipY = origin.y
        let kneeYL = origin.y + 30
        let kneeYR = origin.y + 15
        let footYL = origin.y + 50
        let footYR = origin.y + 35
        let halfShoulder = shoulderWidth / 2
        let armSwing = shoulderWidth * 0.8
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: origin.x, y: headY),
            neckPosition: CGPoint(x: origin.x, y: neckY),
            shoulderLeft: CGPoint(x: origin.x - halfShoulder, y: shoulderY),
            shoulderRight: CGPoint(x: origin.x + halfShoulder, y: shoulderY),
            waistPosition: CGPoint(x: origin.x, y: origin.y - 10),
            elbowLeft: CGPoint(x: origin.x - armSwing - 5, y: elbowYL),
            elbowRight: CGPoint(x: origin.x + armSwing, y: elbowYR),
            handLeft: CGPoint(x: origin.x - armSwing - 8, y: handYL),
            handRight: CGPoint(x: origin.x + halfShoulder, y: handYR),
            hipLeft: CGPoint(x: origin.x - halfShoulder, y: hipY),
            hipRight: CGPoint(x: origin.x + halfShoulder, y: hipY),
            kneeLeft: CGPoint(x: origin.x - halfShoulder - 4, y: kneeYL),
            kneeRight: CGPoint(x: origin.x + halfShoulder + 3, y: kneeYR),
            footLeft: CGPoint(x: origin.x - halfShoulder - 7, y: footYL),
            footRight: CGPoint(x: origin.x + halfShoulder, y: footYR),
            frontArmIsLeft: true,
            frontLegIsLeft: true
        )
    }
    
    static func standingSide(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 60
        let neckY = origin.y - 50
        let shoulderY = origin.y - 45
        let elbowY = origin.y - 12
        let handY = origin.y + 5
        let hipY = origin.y
        let kneeY = origin.y + 25
        let footY = origin.y + 50
        let centerX = origin.x
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: centerX, y: headY),
            neckPosition: CGPoint(x: centerX, y: neckY),
            shoulderLeft: CGPoint(x: centerX, y: shoulderY),
            shoulderRight: CGPoint(x: centerX, y: shoulderY),
            waistPosition: CGPoint(x: centerX, y: origin.y - 10),
            elbowLeft: CGPoint(x: centerX + 3, y: elbowY),
            elbowRight: CGPoint(x: centerX + 3, y: elbowY),
            handLeft: CGPoint(x: centerX + 4, y: handY),
            handRight: CGPoint(x: centerX + 4, y: handY),
            hipLeft: CGPoint(x: centerX, y: hipY),
            hipRight: CGPoint(x: centerX, y: hipY),
            kneeLeft: CGPoint(x: centerX, y: kneeY),
            kneeRight: CGPoint(x: centerX, y: kneeY),
            footLeft: CGPoint(x: centerX + 8, y: footY),
            footRight: CGPoint(x: centerX + 8, y: footY),
            frontArmIsLeft: true,
            frontLegIsLeft: true
        )
    }
    
    static func runningSide1(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 58
        let neckY = origin.y - 48
        let shoulderY = origin.y - 43
        let hipY = origin.y
        let centerX = origin.x
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: centerX, y: headY),
            neckPosition: CGPoint(x: centerX, y: neckY),
            shoulderLeft: CGPoint(x: centerX, y: shoulderY),
            shoulderRight: CGPoint(x: centerX, y: shoulderY),
            waistPosition: CGPoint(x: centerX, y: origin.y - 10),
            // Left arm forward: elbow up, pointing toward face
            elbowLeft: CGPoint(x: centerX + 14, y: origin.y - 28),
            // Right arm back: elbow down, pointing toward ground
            elbowRight: CGPoint(x: centerX - 12, y: origin.y + 15),
            handLeft: CGPoint(x: centerX + 20, y: origin.y - 45),
            handRight: CGPoint(x: centerX - 16, y: origin.y + 30),
            hipLeft: CGPoint(x: centerX, y: hipY),
            hipRight: CGPoint(x: centerX, y: hipY),
            // Left leg forward and extended
            kneeLeft: CGPoint(x: centerX + 24, y: origin.y + 16),
            // Right leg back and extended
            kneeRight: CGPoint(x: centerX - 28, y: origin.y + 20),
            footLeft: CGPoint(x: centerX + 38, y: origin.y + 50),
            footRight: CGPoint(x: centerX - 42, y: origin.y + 48),
            frontArmIsLeft: true,
            frontLegIsLeft: true
        )
    }
    
    static func runningSide2(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 58
        let neckY = origin.y - 48
        let shoulderY = origin.y - 43
        let hipY = origin.y
        let centerX = origin.x
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: centerX, y: headY),
            neckPosition: CGPoint(x: centerX, y: neckY),
            shoulderLeft: CGPoint(x: centerX, y: shoulderY),
            shoulderRight: CGPoint(x: centerX, y: shoulderY),
            waistPosition: CGPoint(x: centerX, y: origin.y - 10),
            // Both arms mid-swing - transitioning
            elbowLeft: CGPoint(x: centerX + 6, y: origin.y - 20),
            elbowRight: CGPoint(x: centerX - 6, y: origin.y - 18),
            handLeft: CGPoint(x: centerX + 10, y: origin.y - 35),
            handRight: CGPoint(x: centerX - 10, y: origin.y - 30),
            hipLeft: CGPoint(x: centerX, y: hipY),
            hipRight: CGPoint(x: centerX, y: hipY),
            // Legs switching - left moving back, right moving forward
            kneeLeft: CGPoint(x: centerX + 8, y: origin.y + 22),
            kneeRight: CGPoint(x: centerX - 8, y: origin.y + 24),
            footLeft: CGPoint(x: centerX + 14, y: origin.y + 48),
            footRight: CGPoint(x: centerX - 14, y: origin.y + 50),
            frontArmIsLeft: true,
            frontLegIsLeft: false
        )
    }
    
    static func runningSide3(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 58
        let neckY = origin.y - 48
        let shoulderY = origin.y - 43
        let hipY = origin.y
        let centerX = origin.x
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: centerX, y: headY),
            neckPosition: CGPoint(x: centerX, y: neckY),
            shoulderLeft: CGPoint(x: centerX, y: shoulderY),
            shoulderRight: CGPoint(x: centerX, y: shoulderY),
            waistPosition: CGPoint(x: centerX, y: origin.y - 10),
            // Right arm forward: elbow up, pointing toward face
            elbowLeft: CGPoint(x: centerX - 12, y: origin.y + 15),
            elbowRight: CGPoint(x: centerX + 14, y: origin.y - 28),
            // Left arm back: elbow down, pointing toward ground
            handLeft: CGPoint(x: centerX - 16, y: origin.y + 30),
            handRight: CGPoint(x: centerX + 20, y: origin.y - 45),
            hipLeft: CGPoint(x: centerX, y: hipY),
            hipRight: CGPoint(x: centerX, y: hipY),
            // Right leg forward and extended
            kneeLeft: CGPoint(x: centerX - 28, y: origin.y + 20),
            kneeRight: CGPoint(x: centerX + 24, y: origin.y + 16),
            // Left leg back and extended
            footLeft: CGPoint(x: centerX - 42, y: origin.y + 48),
            footRight: CGPoint(x: centerX + 38, y: origin.y + 50),
            frontArmIsLeft: false,
            frontLegIsLeft: false
        )
    }
    
    static func runningSide4(at origin: CGPoint, shoulderWidth: CGFloat = 10) -> StickFigurePose {
        let headY = origin.y - 58
        let neckY = origin.y - 48
        let shoulderY = origin.y - 43
        let hipY = origin.y
        let centerX = origin.x
        
        return StickFigurePose(
            bodyPosition: origin,
            headPosition: CGPoint(x: centerX, y: headY),
            neckPosition: CGPoint(x: centerX, y: neckY),
            shoulderLeft: CGPoint(x: centerX, y: shoulderY),
            shoulderRight: CGPoint(x: centerX, y: shoulderY),
            waistPosition: CGPoint(x: centerX, y: origin.y - 10),
            // Both arms mid-swing - transitioning
            elbowLeft: CGPoint(x: centerX - 6, y: origin.y - 18),
            elbowRight: CGPoint(x: centerX + 6, y: origin.y - 20),
            handLeft: CGPoint(x: centerX - 10, y: origin.y - 30),
            handRight: CGPoint(x: centerX + 10, y: origin.y - 35),
            hipLeft: CGPoint(x: centerX, y: hipY),
            hipRight: CGPoint(x: centerX, y: hipY),
            // Legs switching - right moving back, left moving forward
            kneeLeft: CGPoint(x: centerX - 8, y: origin.y + 24),
            kneeRight: CGPoint(x: centerX + 8, y: origin.y + 22),
            footLeft: CGPoint(x: centerX - 14, y: origin.y + 50),
            footRight: CGPoint(x: centerX + 14, y: origin.y + 48),
            frontArmIsLeft: false,
            frontLegIsLeft: true
        )
    }
}

struct ProgrammableStickFigure: View {
    let pose: StickFigurePose
    let clothing: ClothingStyle
    let scale: CGFloat
    
    init(pose: StickFigurePose, clothing: ClothingStyle = .default, scale: CGFloat = 1.0) {
        self.pose = pose
        self.clothing = clothing
        self.scale = scale
    }
    
    var body: some View {
        Canvas { context, size in
            drawLimbs(in: context)
            drawJoints(in: context)
            drawHead(in: context)
            if clothing.hasShirt { drawShirt(in: context) }
            if clothing.hasPants { drawPants(in: context) }
            if clothing.hasShoes { drawShoes(in: context) }
        }
        .scaleEffect(scale)
    }
    
    private func drawLimbs(in context: GraphicsContext) {
        let torsoMid = CGPoint(x: (pose.hipLeft.x + pose.hipRight.x) / 2, y: pose.hipLeft.y)
        
        // Draw torso with waist bend
        // Upper torso: from neck to waist
        drawMuscleSegment(from: pose.neckPosition, to: pose.waistPosition, thickness: clothing.bodyThickness * 2, color: clothing.torsoShoulderColor, in: context)
        // Lower torso: from waist to hips
        drawMuscleSegment(from: pose.waistPosition, to: torsoMid, thickness: clothing.bodyThickness * 2, color: clothing.torsoShoulderColor, in: context)
        
        let frontArmLeft = pose.frontArmIsLeft
        let frontLegLeft = pose.frontLegIsLeft
        
        drawArm(isLeft: !frontArmLeft, in: context)
        drawLeg(isLeft: !frontLegLeft, in: context)
        drawLeg(isLeft: frontLegLeft, in: context)
        drawArm(isLeft: frontArmLeft, in: context)
    }
    
    private func drawArm(isLeft: Bool, in context: GraphicsContext) {
        let shoulder = isLeft ? pose.shoulderLeft : pose.shoulderRight
        let elbow = isLeft ? pose.elbowLeft : pose.elbowRight
        let hand = isLeft ? pose.handLeft : pose.handRight
        drawMuscleSegment(from: shoulder, to: elbow, thickness: clothing.bodyThickness * 1.2, color: clothing.upperArmColor, in: context)
        drawMuscleSegment(from: elbow, to: hand, thickness: clothing.bodyThickness * 0.9, color: clothing.lowerArmColor, in: context)
    }
    
    private func drawLeg(isLeft: Bool, in context: GraphicsContext) {
        let hip = isLeft ? pose.hipLeft : pose.hipRight
        let knee = isLeft ? pose.kneeLeft : pose.kneeRight
        let foot = isLeft ? pose.footLeft : pose.footRight
        drawMuscleSegment(from: hip, to: knee, thickness: clothing.bodyThickness * 1.5, color: clothing.upperLegColor, in: context)
        drawMuscleSegment(from: knee, to: foot, thickness: clothing.bodyThickness * 1.1, color: clothing.lowerLegColor, in: context)
    }
    
    private func drawMuscle(from start: CGPoint, to end: CGPoint, thickness: CGFloat, in context: GraphicsContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let perpAngle = angle + .pi / 2
        let halfThickness = thickness / 2
        
        var musclePath = Path()
        let tl = CGPoint(x: start.x + cos(perpAngle) * halfThickness, y: start.y + sin(perpAngle) * halfThickness)
        let tr = CGPoint(x: end.x + cos(perpAngle) * halfThickness, y: end.y + sin(perpAngle) * halfThickness)
        let bl = CGPoint(x: start.x - cos(perpAngle) * halfThickness, y: start.y - sin(perpAngle) * halfThickness)
        
        musclePath.move(to: tl)
        musclePath.addLine(to: tr)
        musclePath.addArc(center: end, radius: halfThickness, startAngle: Angle(radians: perpAngle), endAngle: Angle(radians: perpAngle + .pi), clockwise: false)
        musclePath.addLine(to: bl)
        musclePath.addArc(center: start, radius: halfThickness, startAngle: Angle(radians: perpAngle + .pi), endAngle: Angle(radians: perpAngle), clockwise: false)
        musclePath.closeSubpath()
        
        context.fill(musclePath, with: .color(clothing.skinColor))
        context.stroke(musclePath, with: .color(clothing.skinColor.opacity(0.6)), lineWidth: 1)
    }

    private func drawJoints(in context: GraphicsContext) {
        let largeJoints = [pose.neckPosition, pose.shoulderLeft, pose.shoulderRight]
        for joint in largeJoints {
            let radius = clothing.shoulderJointSize
            let circle = Circle().path(in: CGRect(x: joint.x - radius, y: joint.y - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(clothing.headNeckColor))
            context.stroke(circle, with: .color(clothing.headNeckColor.opacity(0.7)), lineWidth: 0.5)
        }
        
        let legThickness = clothing.bodyThickness * 1.5
        let hipRadius = (legThickness / 2) * 0.6
        let hipJoints = [pose.hipLeft, pose.hipRight]
        for joint in hipJoints {
            let radius = hipRadius
            let circle = Circle().path(in: CGRect(x: joint.x - radius, y: joint.y - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(clothing.torsoShoulderColor))
            context.stroke(circle, with: .color(clothing.torsoShoulderColor.opacity(0.7)), lineWidth: 0.5)
        }
        
        let smallJoints = [pose.elbowLeft, pose.elbowRight, pose.kneeLeft, pose.kneeRight]
        for joint in smallJoints {
            let radius: CGFloat = 2.5
            let circle = Circle().path(in: CGRect(x: joint.x - radius, y: joint.y - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(clothing.skinColor))
            context.stroke(circle, with: .color(clothing.skinColor.opacity(0.7)), lineWidth: 0.5)
        }
        
        let frontArmLeft = pose.frontArmIsLeft
        let frontLegLeft = pose.frontLegIsLeft
        let backHandsFeet = [
            frontArmLeft ? pose.handRight : pose.handLeft,
            frontLegLeft ? pose.footRight : pose.footLeft
        ]
        for joint in backHandsFeet {
            let radius: CGFloat = 3.5
            let circle = Circle().path(in: CGRect(x: joint.x - radius, y: joint.y - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(clothing.handColor))
            context.stroke(circle, with: .color(clothing.handColor.opacity(0.7)), lineWidth: 0.5)
        }
        
        let frontHandsFeet = [
            frontArmLeft ? pose.handLeft : pose.handRight,
            frontLegLeft ? pose.footLeft : pose.footRight
        ]
        for joint in frontHandsFeet {
            let radius: CGFloat = 3.5
            let circle = Circle().path(in: CGRect(x: joint.x - radius, y: joint.y - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(clothing.skinColor))
            context.stroke(circle, with: .color(clothing.skinColor.opacity(0.7)), lineWidth: 0.5)
        }
    }
    
    private func drawHead(in context: GraphicsContext) {
        var headContext = context
        headContext.translateBy(x: pose.headPosition.x, y: pose.headPosition.y)
        headContext.rotate(by: .degrees(pose.headTilt))
        headContext.translateBy(x: -pose.headPosition.x, y: -pose.headPosition.y)
        
        let headCircle = Circle().path(in: CGRect(x: pose.headPosition.x - 8, y: pose.headPosition.y - 8, width: 16, height: 16))
        headContext.fill(headCircle, with: .color(clothing.headNeckColor))
        headContext.stroke(headCircle, with: .color(.black), lineWidth: 0.5)
    }
    
    private func drawShirt(in context: GraphicsContext) {
        var shirtPath = Path()
        shirtPath.move(to: pose.shoulderLeft)
        shirtPath.addLine(to: pose.shoulderRight)
        shirtPath.addLine(to: CGPoint(x: pose.hipRight.x + 5, y: pose.hipRight.y))
        shirtPath.addLine(to: CGPoint(x: pose.hipLeft.x - 5, y: pose.hipLeft.y))
        shirtPath.addLine(to: pose.shoulderLeft)
        
        context.fill(shirtPath, with: .color(clothing.shirtColor.opacity(0.7)))
        context.stroke(shirtPath, with: .color(clothing.shirtColor), lineWidth: 2)
        
        var leftSleeve = Path()
        leftSleeve.move(to: pose.shoulderLeft)
        leftSleeve.addLine(to: CGPoint(x: pose.elbowLeft.x - 3, y: pose.elbowLeft.y))
        leftSleeve.addLine(to: CGPoint(x: pose.elbowLeft.x + 3, y: pose.elbowLeft.y))
        leftSleeve.addLine(to: CGPoint(x: pose.shoulderLeft.x + 3, y: pose.shoulderLeft.y))
        leftSleeve.closeSubpath()
        
        var rightSleeve = Path()
        rightSleeve.move(to: pose.shoulderRight)
        rightSleeve.addLine(to: CGPoint(x: pose.elbowRight.x - 3, y: pose.elbowRight.y))
        rightSleeve.addLine(to: CGPoint(x: pose.elbowRight.x + 3, y: pose.elbowRight.y))
        rightSleeve.addLine(to: CGPoint(x: pose.shoulderRight.x - 3, y: pose.shoulderRight.y))
        rightSleeve.closeSubpath()
        
        context.fill(leftSleeve, with: .color(clothing.shirtColor.opacity(0.7)))
        context.fill(rightSleeve, with: .color(clothing.shirtColor.opacity(0.7)))
    }
    
    private func drawPants(in context: GraphicsContext) {
        let frontLegLeft = pose.frontLegIsLeft
        drawPant(isLeft: !frontLegLeft, in: context)
        drawPant(isLeft: frontLegLeft, in: context)
    }
    
    private func drawPant(isLeft: Bool, in context: GraphicsContext) {
        let hip = isLeft ? pose.hipLeft : pose.hipRight
        let knee = isLeft ? pose.kneeLeft : pose.kneeRight
        var pantPath = Path()
        pantPath.move(to: hip)
        pantPath.addLine(to: CGPoint(x: knee.x - 4, y: knee.y))
        pantPath.addLine(to: CGPoint(x: knee.x + 4, y: knee.y))
        pantPath.addLine(to: CGPoint(x: hip.x + (isLeft ? 4 : -4), y: hip.y))
        pantPath.closeSubpath()
        context.fill(pantPath, with: .color(clothing.pantsColor.opacity(0.7)))
    }
    
    private func drawShoes(in context: GraphicsContext) {
        let frontLegLeft = pose.frontLegIsLeft
        drawShoe(at: frontLegLeft ? pose.footRight : pose.footLeft, in: context)
        drawShoe(at: frontLegLeft ? pose.footLeft : pose.footRight, in: context)
    }
    
    private func drawShoe(at point: CGPoint, in context: GraphicsContext) {
        let shoe = Ellipse().path(in: CGRect(x: point.x - 6, y: point.y - 3, width: 12, height: 6))
        context.fill(shoe, with: .color(clothing.shoeColor))
    }
}

struct ProgrammableStickFigureDemo: View {
    @State private var isRunning = false
    @State private var runFrame = 0
    @State private var clothing = ClothingStyle.load()
    @State private var showEditor = false
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with buttons
            HStack {
                Button(action: {
                    print("Back button tapped - isPresented = \(isPresented)")
                    isPresented = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()

                Text("Programmable Stick Figure")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    print("🖊️  Edit button tapped!")
                    showEditor = true
                }) {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .padding(.top, 50)
            .background(Color(red: 0.95, green: 0.95, blue: 0.98))
                
                // Figure display with extended background
                GeometryReader { geometry in
                    let centerX = geometry.size.width / 2
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                            
                            if isRunning {
                                if runFrame % 2 == 0 {
                                    ProgrammableStickFigure(pose: .running1(at: CGPoint(x: centerX, y: 100), shoulderWidth: clothing.shoulderWidth), clothing: clothing, scale: 1.5)
                                } else {
                                    ProgrammableStickFigure(pose: .running2(at: CGPoint(x: centerX, y: 100), shoulderWidth: clothing.shoulderWidth), clothing: clothing, scale: 1.5)
                                }
                            } else {
                                ProgrammableStickFigure(pose: .standing(at: CGPoint(x: centerX, y: 100), shoulderWidth: clothing.shoulderWidth), clothing: clothing, scale: 1.5)
                            }
                        }
                        .frame(height: 200)
                    }
                }
                .frame(height: 240)
            
                // Buttons
                HStack(spacing: 16) {
                    Button(action: { isRunning = false }) {
                        Text("Stand")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isRunning ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    
                    Button(action: { isRunning = true }) {
                        Text("Run")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isRunning ? Color.blue : Color.gray)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                
                // Scrollable customization content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customize Clothing")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Body:")
                            ColorPicker("", selection: $clothing.skinColor)
                                .labelsHidden()
                                .onChange(of: clothing.skinColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Shirt:")
                            ColorPicker("", selection: $clothing.shirtColor)
                                .labelsHidden()
                                .onChange(of: clothing.shirtColor) { _, _ in clothing.save() }
                            Toggle("", isOn: $clothing.hasShirt)
                                .labelsHidden()
                                .onChange(of: clothing.hasShirt) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Pants:")
                            ColorPicker("", selection: $clothing.pantsColor)
                                .labelsHidden()
                                .onChange(of: clothing.pantsColor) { _, _ in clothing.save() }
                            Toggle("", isOn: $clothing.hasPants)
                                .labelsHidden()
                                .onChange(of: clothing.hasPants) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Shoes:")
                            ColorPicker("", selection: $clothing.shoeColor)
                                .labelsHidden()
                                .onChange(of: clothing.shoeColor) { _, _ in clothing.save() }
                            Toggle("", isOn: $clothing.hasShoes)
                                .labelsHidden()
                                .onChange(of: clothing.hasShoes) { _, _ in clothing.save() }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("Body Part Colors")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Head/Neck:")
                            ColorPicker("", selection: $clothing.headNeckColor)
                                .labelsHidden()
                                .onChange(of: clothing.headNeckColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Torso/Shoulders:")
                            ColorPicker("", selection: $clothing.torsoShoulderColor)
                                .labelsHidden()
                                .onChange(of: clothing.torsoShoulderColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Upper Arm:")
                            ColorPicker("", selection: $clothing.upperArmColor)
                                .labelsHidden()
                                .onChange(of: clothing.upperArmColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Lower Arm:")
                            ColorPicker("", selection: $clothing.lowerArmColor)
                                .labelsHidden()
                                .onChange(of: clothing.lowerArmColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Hands:")
                            ColorPicker("", selection: $clothing.handColor)
                                .labelsHidden()
                                .onChange(of: clothing.handColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Upper Leg:")
                            ColorPicker("", selection: $clothing.upperLegColor)
                                .labelsHidden()
                                .onChange(of: clothing.upperLegColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Lower Leg:")
                            ColorPicker("", selection: $clothing.lowerLegColor)
                                .labelsHidden()
                                .onChange(of: clothing.lowerLegColor) { _, _ in clothing.save() }
                        }
                        
                        HStack {
                            Text("Feet:")
                            ColorPicker("", selection: $clothing.feetColor)
                                .labelsHidden()
                                .onChange(of: clothing.feetColor) { _, _ in clothing.save() }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("Body Proportions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shoulder Joint Size: \(Int(clothing.shoulderJointSize))")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Slider(value: $clothing.shoulderJointSize, in: 3...12, step: 1)
                                .onChange(of: clothing.shoulderJointSize) { _, _ in clothing.save() }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
                    if isRunning {
                        runFrame = (runFrame + 1) % 4
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                DraggableJointEditorView(clothing: $clothing)
            }
        }
    }
#Preview {
    @Previewable @State var isPresented = true
    ProgrammableStickFigureDemo(isPresented: $isPresented)
}

#Preview {
    DraggableJointEditorView(clothing: .constant(ClothingStyle.load()))
}

struct JointInfo {
    let name: String
    let position: CGPoint
}

// MARK: - Resizeable Directional Object

struct DirectionalObject: Codable, Identifiable, Equatable {
    let id: UUID
    var position: CGPoint
    var width: CGFloat
    var height: CGFloat
    var rotation: Double // in degrees
    var objectType: String // "image", "ball", "stick", "box", etc.
    var color: String // hex color (for non-image objects)
    var imageData: Data? // stored image data
    var imageName: String? // for display purposes
    
    init(position: CGPoint, width: CGFloat = 30, height: CGFloat = 30, rotation: Double = 0, objectType: String = "ball", color: String = "#FF0000", imageData: Data? = nil, imageName: String? = nil) {
        self.id = UUID()
        self.position = position
        self.width = width
        self.height = height
        self.rotation = rotation
        self.objectType = objectType
        self.color = color
        self.imageData = imageData
        self.imageName = imageName
    }
    
    static func == (lhs: DirectionalObject, rhs: DirectionalObject) -> Bool {
        lhs.id == rhs.id
    }
}

struct AnimationFrameWithObjects: Codable, Identifiable {
    let id: UUID
    let name: String
    let positionNumber: Int
    let pose: SavedStickFigurePose
    var objects: [DirectionalObject]
    let createdAt: Date
    
    init(from savedPose: SavedPose) {
        self.id = savedPose.id
        self.name = savedPose.name
        self.positionNumber = savedPose.positionNumber
        self.pose = savedPose.pose
        self.objects = []
        self.createdAt = savedPose.createdAt
    }
}

// MARK: - Draggable Pose Editor

struct DraggableJointEditorView: View {
    @StateObject private var poseManager = PoseManager()
    @State private var currentPose: StickFigurePose
    @State private var currentObjects: [DirectionalObject] = []
    @State private var poseName: String = ""
    @State private var positionNumber: String = "1"
    @State private var draggedJoint: String?
    @State private var lastWaistDragLocation: CGPoint = .zero
    @State private var initialUpperBodyPositions: [String: CGPoint] = [:]
    @State private var draggedObjectId: UUID?
    @State private var draggedObjectHandle: String?
    @Binding var clothing: ClothingStyle
    @State private var showSaveAlert = false
    @State private var selectedObjectType: String = "ball"
    @State private var selectedColor: Color = .red
    @State private var showImagePicker = false
    @State private var selectedImageData: Data?
    @State private var selectedImageName: String = ""
    @State private var constrainLegs = true
    @State private var constrainArms = true
    @State private var constrainHead = true
    @Environment(\.dismiss) var dismiss
    
    let canvasSize = CGSize(width: 400, height: 450)
    
    init(clothing: Binding<ClothingStyle>) {
        self._clothing = clothing
        let origin = CGPoint(x: 200, y: 225)
        _currentPose = State(initialValue: .standing(at: origin, shoulderWidth: 20))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                    
                    Spacer()
                    
                    Text("Pose Editor")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        print("🔄 Reset pose to default")
                        let origin = CGPoint(x: 200, y: 225)
                        currentPose = .standing(at: origin, shoulderWidth: 20)
                        draggedJoint = nil
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Top padding for vertical centering
                        Spacer()
                            .frame(height: 20)
                        
                        // Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                
                ProgrammableStickFigure(pose: currentPose, clothing: clothing, scale: 1.5)
                
                // Draggable objects
                ForEach(currentObjects) { obj in
                    DraggableObjectView(
                        object: obj,
                        isDragged: draggedObjectId == obj.id,
                        draggedHandle: draggedObjectId == obj.id ? draggedObjectHandle : nil,
                        onMove: { newPosition in
                            if let index = currentObjects.firstIndex(where: { $0.id == obj.id }) {
                                currentObjects[index].position = newPosition
                            }
                        },
                        onResize: { width, height in
                            if let index = currentObjects.firstIndex(where: { $0.id == obj.id }) {
                                currentObjects[index].width = width
                                currentObjects[index].height = height
                            }
                        },
                        onRotate: { rotation in
                            if let index = currentObjects.firstIndex(where: { $0.id == obj.id }) {
                                currentObjects[index].rotation = rotation
                            }
                        },
                        onDragStart: { handle in
                            draggedObjectId = obj.id
                            draggedObjectHandle = handle
                        },
                        onDragEnd: {
                            draggedObjectId = nil
                            draggedObjectHandle = nil
                        }
                    )
                }
                
                // Draggable joints
                ForEach(getAllJoints(), id: \.name) { joint in
                    Circle()
                        .fill(draggedJoint == joint.name ? Color.red : Color.blue)
                        .frame(width: 12, height: 12)
                        .position(joint.position)
                        .scaleEffect(1.5)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggedJoint = joint.name
                                    updateJointPosition(joint.name, to: value.location)
                                }
                                .onEnded { _ in
                                    draggedJoint = nil
                                }
                        )
                        .zIndex(draggedJoint == joint.name ? 100 : 0)
                }
                
                // Head swivel dot (green)
                ZStack {
                    Circle().fill(Color.clear).frame(width: 20, height: 20)
                    Circle().fill(draggedJoint == "headSwivel" ? Color.orange : Color.green)
                        .frame(width: 10, height: 10)
                }
                .position(currentPose.headPosition)
                .scaleEffect(1.5)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            draggedJoint = "headSwivel"
                            // Keep head at fixed distance from neck, but allow rotation
                            let dx = value.location.x - currentPose.neckPosition.x
                            let dy = value.location.y - currentPose.neckPosition.y
                            let distance = sqrt(dx * dx + dy * dy)
                            if distance > 0 {
                                let headDist: CGFloat = 10
                                let ratio = headDist / distance
                                currentPose.headPosition = CGPoint(
                                    x: currentPose.neckPosition.x + dx * ratio,
                                    y: currentPose.neckPosition.y + dy * ratio
                                )
                                let angle = atan2(dx, -dy) * 180 / .pi
                                currentPose.headTilt = angle
                            }
                        }
                        .onEnded { _ in
                            draggedJoint = nil
                        }
                )
                .zIndex(draggedJoint == "headSwivel" ? 100 : 0)
                
                // Waist bend dot (purple)
                ZStack {
                    Circle().fill(Color.clear).frame(width: 20, height: 20)
                    Circle().fill(draggedJoint == "waist" ? Color.orange : Color.purple)
                        .frame(width: 10, height: 10)
                }
                .position(currentPose.waistPosition)
                .scaleEffect(1.5)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if draggedJoint != "waist" {
                                draggedJoint = "waist"
                                lastWaistDragLocation = value.location
                                
                                // Store the initial positions of upper body at start of drag
                                initialUpperBodyPositions = [
                                    "head": currentPose.headPosition,
                                    "neck": currentPose.neckPosition,
                                    "shoulderLeft": currentPose.shoulderLeft,
                                    "shoulderRight": currentPose.shoulderRight,
                                    "elbowLeft": currentPose.elbowLeft,
                                    "elbowRight": currentPose.elbowRight,
                                    "handLeft": currentPose.handLeft,
                                    "handRight": currentPose.handRight,
                                ]
                            }
                            
                            // Calculate incremental angle from last position to current position
                            let dx = value.location.x - lastWaistDragLocation.x
                            let dy = value.location.y - lastWaistDragLocation.y
                            let incrementalAngle = atan2(dx, -dy) * 180 / .pi
                            
                            // Reduce sensitivity by scaling down the angle
                            let scaledAngle = incrementalAngle * 0.5
                            
                            lastWaistDragLocation = value.location
                            
                            let waistX = currentPose.waistPosition.x
                            let waistY = currentPose.waistPosition.y
                            
                            // Helper function to rotate a point around the waist
                            func rotateAroundWaist(_ point: CGPoint, angle: Double) -> CGPoint {
                                let rad = angle * .pi / 180
                                let cos = cos(rad)
                                let sin = sin(rad)
                                let dx = point.x - waistX
                                let dy = point.y - waistY
                                return CGPoint(
                                    x: waistX + dx * cos - dy * sin,
                                    y: waistY + dx * sin + dy * cos
                                )
                            }
                            
                            // Apply incremental rotation to current positions
                            currentPose.headPosition = rotateAroundWaist(currentPose.headPosition, angle: scaledAngle)
                            currentPose.neckPosition = rotateAroundWaist(currentPose.neckPosition, angle: scaledAngle)
                            currentPose.shoulderLeft = rotateAroundWaist(currentPose.shoulderLeft, angle: scaledAngle)
                            currentPose.shoulderRight = rotateAroundWaist(currentPose.shoulderRight, angle: scaledAngle)
                            currentPose.elbowLeft = rotateAroundWaist(currentPose.elbowLeft, angle: scaledAngle)
                            currentPose.elbowRight = rotateAroundWaist(currentPose.elbowRight, angle: scaledAngle)
                            currentPose.handLeft = rotateAroundWaist(currentPose.handLeft, angle: scaledAngle)
                            currentPose.handRight = rotateAroundWaist(currentPose.handRight, angle: scaledAngle)
                        }
                        .onEnded { _ in
                            draggedJoint = nil
                            lastWaistDragLocation = .zero
                            initialUpperBodyPositions = [:]
                        }
                )
                .zIndex(draggedJoint == "waist" ? 100 : 0)
                
                // Body position dot (yellow)
                ZStack {
                    Circle().fill(Color.clear).frame(width: 20, height: 20)
                    Circle().fill(draggedJoint == "body" ? Color.orange : Color.yellow)
                        .frame(width: 10, height: 10)
                }
                .position(currentPose.bodyPosition)
                .scaleEffect(1.5)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            draggedJoint = "body"
                            let delta = CGPoint(x: value.location.x - currentPose.bodyPosition.x,
                                              y: value.location.y - currentPose.bodyPosition.y)
                            currentPose.bodyPosition = value.location
                            // Move entire body by delta
                            currentPose.headPosition.x += delta.x
                            currentPose.headPosition.y += delta.y
                            currentPose.neckPosition.x += delta.x
                            currentPose.neckPosition.y += delta.y
                            currentPose.shoulderLeft.x += delta.x
                            currentPose.shoulderLeft.y += delta.y
                            currentPose.shoulderRight.x += delta.x
                            currentPose.shoulderRight.y += delta.y
                            currentPose.waistPosition.x += delta.x
                            currentPose.waistPosition.y += delta.y
                            currentPose.elbowLeft.x += delta.x
                            currentPose.elbowLeft.y += delta.y
                            currentPose.elbowRight.x += delta.x
                            currentPose.elbowRight.y += delta.y
                            currentPose.handLeft.x += delta.x
                            currentPose.handLeft.y += delta.y
                            currentPose.handRight.x += delta.x
                            currentPose.handRight.y += delta.y
                            currentPose.hipLeft.x += delta.x
                            currentPose.hipLeft.y += delta.y
                            currentPose.hipRight.x += delta.x
                            currentPose.hipRight.y += delta.y
                            currentPose.kneeLeft.x += delta.x
                            currentPose.kneeLeft.y += delta.y
                            currentPose.kneeRight.x += delta.x
                            currentPose.kneeRight.y += delta.y
                            currentPose.footLeft.x += delta.x
                            currentPose.footLeft.y += delta.y
                            currentPose.footRight.x += delta.x
                            currentPose.footRight.y += delta.y
                        }
                        .onEnded { _ in
                            draggedJoint = nil
                        }
                )
                .zIndex(draggedJoint == "body" ? 100 : 0)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .padding()
            
            // Save Controls
            VStack(spacing: 10) {
                HStack {
                    Text("Animation Name:")
                    TextField("e.g., Running", text: $poseName)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Position #:")
                    TextField("1", text: $positionNumber)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    
                    Spacer()
                    
                    Button(action: savePose) {
                        Text("Save Pose")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(poseName.trimmingCharacters(in: .whitespaces).isEmpty || positionNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            .cornerRadius(12)
            .padding()
            
            // Object Controls
            VStack(spacing: 10) {
                Text("Add Objects to Frame")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Picker("Object Type", selection: $selectedObjectType) {
                    Text("Image").tag("image")
                    Text("Ball").tag("ball")
                    Text("Box").tag("box")
                    Text("Stick").tag("stick")
                }
                .pickerStyle(.segmented)
                
                if selectedObjectType == "image" {
                    HStack {
                        Button(action: { showImagePicker = true }) {
                            Image(systemName: "photo.on.rectangle")
                            Text(selectedImageName.isEmpty ? "Choose Image" : selectedImageName)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(6)
                        
                        if !selectedImageName.isEmpty {
                            Button(action: {
                                selectedImageData = nil
                                selectedImageName = ""
                            }) {
                                Image(systemName: "xmark.circle")
                            }
                            .foregroundColor(.gray)
                        }
                    }
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(imageData: $selectedImageData, imageName: $selectedImageName)
                    }
                } else {
                    HStack {
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                            .frame(width: 40)
                        Text("Color")
                            .font(.subheadline)
                    }
                }
                
                HStack {
                    Button(action: addObject) {
                        Image(systemName: "plus.circle")
                        Text("Add Object")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(8)
                    
                    if !currentObjects.isEmpty {
                        Button(action: { currentObjects.removeAll() }) {
                            Image(systemName: "trash")
                            Text("Clear All")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Text("Objects: \(currentObjects.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            .cornerRadius(12)
            .padding()
            
            // Joint Constraints removed - using draggable dots instead
            
            // Saved Poses
            if !poseManager.savedPoses.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Saved Poses: \(poseManager.savedPoses.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(poseManager.savedPoses) { pose in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(pose.name) - Position \(pose.positionNumber)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Text(pose.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: { poseManager.deletePose(pose) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(8)
                                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                .padding()
                .background(Color(red: 0.92, green: 0.95, blue: 0.98))
                .cornerRadius(12)
                .padding()
            }
            
                    Spacer()
                }
        }
    }
    
    private func getAllJoints() -> [JointInfo] {
        [
            JointInfo(name: "elbowLeft", position: currentPose.elbowLeft),
            JointInfo(name: "elbowRight", position: currentPose.elbowRight),
            JointInfo(name: "handLeft", position: currentPose.handLeft),
            JointInfo(name: "handRight", position: currentPose.handRight),
            JointInfo(name: "kneeLeft", position: currentPose.kneeLeft),
            JointInfo(name: "kneeRight", position: currentPose.kneeRight),
            JointInfo(name: "footLeft", position: currentPose.footLeft),
            JointInfo(name: "footRight", position: currentPose.footRight),
        ]
    }
    
    private func updateJointPosition(_ jointName: String, to position: CGPoint) {
        var newPosition = position
        
        // Define fixed limb lengths (distances between connected joints)
        let headToNeck: CGFloat = 10
        let neckToShoulder: CGFloat = 5
        let shoulderToElbow: CGFloat = 20
        let elbowToHand: CGFloat = 18
        let hipToKnee: CGFloat = 25
        let kneeToFoot: CGFloat = 25
        let shoulderToHip: CGFloat = 45 // torso length
        
        switch jointName {
        case "head":
            if constrainHead {
                // Head stays directly above neck at fixed distance, can tilt
                newPosition.x = currentPose.neckPosition.x
                newPosition.y = currentPose.neckPosition.y - headToNeck
                // Allow head tilt by calculating angle
                let dx = position.x - currentPose.neckPosition.x
                let dy = position.y - currentPose.neckPosition.y
                let angle = atan2(dx, -dy) * 180 / .pi
                currentPose.headTilt = angle
            }
            currentPose.headPosition = newPosition
            
        case "neck":
            if constrainHead {
                // Neck stays directly below head at fixed distance
                newPosition.x = currentPose.headPosition.x
                newPosition.y = currentPose.headPosition.y + headToNeck
            }
            currentPose.neckPosition = newPosition
            
        case "shoulderLeft":
            if constrainHead {
                // Left shoulder at fixed distance below and to the left of neck
                newPosition.x = currentPose.neckPosition.x - 10
                newPosition.y = currentPose.neckPosition.y + neckToShoulder
            }
            currentPose.shoulderLeft = newPosition
            // Update elbow and hand to maintain their distances
            updateChildLimbsLeft(from: newPosition, distA: shoulderToElbow, distB: elbowToHand)
            
        case "shoulderRight":
            if constrainHead {
                // Right shoulder at fixed distance below and to the right of neck
                newPosition.x = currentPose.neckPosition.x + 10
                newPosition.y = currentPose.neckPosition.y + neckToShoulder
            }
            currentPose.shoulderRight = newPosition
            // Update elbow and hand to maintain their distances
            updateChildLimbsRight(from: newPosition, distA: shoulderToElbow, distB: elbowToHand)
            
        case "elbowLeft":
            if constrainArms {
                let dx = newPosition.x - currentPose.shoulderLeft.x
                let dy = newPosition.y - currentPose.shoulderLeft.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = shoulderToElbow / distance
                    newPosition.x = currentPose.shoulderLeft.x + dx * ratio
                    newPosition.y = currentPose.shoulderLeft.y + dy * ratio
                }
            }
            currentPose.elbowLeft = newPosition
            // Update hand to maintain distance from elbow
            if constrainArms {
                let dx = currentPose.handLeft.x - currentPose.elbowLeft.x
                let dy = currentPose.handLeft.y - currentPose.elbowLeft.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = elbowToHand / distance
                    currentPose.handLeft.x = currentPose.elbowLeft.x + dx * ratio
                    currentPose.handLeft.y = currentPose.elbowLeft.y + dy * ratio
                }
            }
            
        case "handLeft":
            if constrainArms {
                let dx = newPosition.x - currentPose.elbowLeft.x
                let dy = newPosition.y - currentPose.elbowLeft.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = elbowToHand / distance
                    newPosition.x = currentPose.elbowLeft.x + dx * ratio
                    newPosition.y = currentPose.elbowLeft.y + dy * ratio
                }
            }
            currentPose.handLeft = newPosition
            
        case "elbowRight":
            if constrainArms {
                let dx = newPosition.x - currentPose.shoulderRight.x
                let dy = newPosition.y - currentPose.shoulderRight.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = shoulderToElbow / distance
                    newPosition.x = currentPose.shoulderRight.x + dx * ratio
                    newPosition.y = currentPose.shoulderRight.y + dy * ratio
                }
            }
            currentPose.elbowRight = newPosition
            // Update hand to maintain distance from elbow
            if constrainArms {
                let dx = currentPose.handRight.x - currentPose.elbowRight.x
                let dy = currentPose.handRight.y - currentPose.elbowRight.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = elbowToHand / distance
                    currentPose.handRight.x = currentPose.elbowRight.x + dx * ratio
                    currentPose.handRight.y = currentPose.elbowRight.y + dy * ratio
                }
            }
            
        case "handRight":
            if constrainArms {
                let dx = newPosition.x - currentPose.elbowRight.x
                let dy = newPosition.y - currentPose.elbowRight.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = elbowToHand / distance
                    newPosition.x = currentPose.elbowRight.x + dx * ratio
                    newPosition.y = currentPose.elbowRight.y + dy * ratio
                }
            }
            currentPose.handRight = newPosition
            
        case "hipLeft":
            if constrainHead {
                // Hip stays directly below corresponding shoulder at fixed torso distance
                let shoulderMidX = (currentPose.shoulderLeft.x + currentPose.shoulderRight.x) / 2
                let shoulderMidY = (currentPose.shoulderLeft.y + currentPose.shoulderRight.y) / 2
                // Offset from midpoint based on shoulder width
                let shoulderOffsetX = currentPose.shoulderLeft.x - shoulderMidX
                newPosition.x = shoulderMidX + shoulderOffsetX
                newPosition.y = shoulderMidY + shoulderToHip
            }
            currentPose.hipLeft = newPosition
            // Update knee and foot to maintain their distances
            if constrainLegs {
                let dx = currentPose.kneeLeft.x - currentPose.hipLeft.x
                let dy = currentPose.kneeLeft.y - currentPose.hipLeft.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = hipToKnee / distance
                    currentPose.kneeLeft.x = currentPose.hipLeft.x + dx * ratio
                    currentPose.kneeLeft.y = currentPose.hipLeft.y + dy * ratio
                }
                // Update foot to maintain distance from knee
                let dx2 = currentPose.footLeft.x - currentPose.kneeLeft.x
                let dy2 = currentPose.footLeft.y - currentPose.kneeLeft.y
                let distance2 = sqrt(dx2 * dx2 + dy2 * dy2)
                if distance2 > 0 {
                    let ratio2 = kneeToFoot / distance2
                    currentPose.footLeft.x = currentPose.kneeLeft.x + dx2 * ratio2
                    currentPose.footLeft.y = currentPose.kneeLeft.y + dy2 * ratio2
                }
            }
            
        case "hipRight":
            if constrainHead {
                // Hip stays directly below corresponding shoulder at fixed torso distance
                let shoulderMidX = (currentPose.shoulderLeft.x + currentPose.shoulderRight.x) / 2
                let shoulderMidY = (currentPose.shoulderLeft.y + currentPose.shoulderRight.y) / 2
                // Offset from midpoint based on shoulder width
                let shoulderOffsetX = currentPose.shoulderRight.x - shoulderMidX
                newPosition.x = shoulderMidX + shoulderOffsetX
                newPosition.y = shoulderMidY + shoulderToHip
            }
            currentPose.hipRight = newPosition
            // Update knee and foot to maintain their distances
            if constrainLegs {
                let dx = currentPose.kneeRight.x - currentPose.hipRight.x
                let dy = currentPose.kneeRight.y - currentPose.hipRight.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = hipToKnee / distance
                    currentPose.kneeRight.x = currentPose.hipRight.x + dx * ratio
                    currentPose.kneeRight.y = currentPose.hipRight.y + dy * ratio
                }
                // Update foot to maintain distance from knee
                let dx2 = currentPose.footRight.x - currentPose.kneeRight.x
                let dy2 = currentPose.footRight.y - currentPose.kneeRight.y
                let distance2 = sqrt(dx2 * dx2 + dy2 * dy2)
                if distance2 > 0 {
                    let ratio2 = kneeToFoot / distance2
                    currentPose.footRight.x = currentPose.kneeRight.x + dx2 * ratio2
                    currentPose.footRight.y = currentPose.kneeRight.y + dy2 * ratio2
                }
            }
            
        case "kneeLeft":
            if constrainLegs {
                let dx = newPosition.x - currentPose.hipLeft.x
                let dy = newPosition.y - currentPose.hipLeft.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = hipToKnee / distance
                    newPosition.x = currentPose.hipLeft.x + dx * ratio
                    newPosition.y = currentPose.hipLeft.y + dy * ratio
                }
            }
            currentPose.kneeLeft = newPosition
            // Update foot to maintain distance from knee
            if constrainLegs {
                let dx = currentPose.footLeft.x - currentPose.kneeLeft.x
                let dy = currentPose.footLeft.y - currentPose.kneeLeft.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = kneeToFoot / distance
                    currentPose.footLeft.x = currentPose.kneeLeft.x + dx * ratio
                    currentPose.footLeft.y = currentPose.kneeLeft.y + dy * ratio
                }
            }
            
        case "footLeft":
            if constrainLegs {
                let dx = newPosition.x - currentPose.kneeLeft.x
                let dy = newPosition.y - currentPose.kneeLeft.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = kneeToFoot / distance
                    newPosition.x = currentPose.kneeLeft.x + dx * ratio
                    newPosition.y = currentPose.kneeLeft.y + dy * ratio
                }
            }
            currentPose.footLeft = newPosition
            
        case "kneeRight":
            if constrainLegs {
                let dx = newPosition.x - currentPose.hipRight.x
                let dy = newPosition.y - currentPose.hipRight.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = hipToKnee / distance
                    newPosition.x = currentPose.hipRight.x + dx * ratio
                    newPosition.y = currentPose.hipRight.y + dy * ratio
                }
            }
            currentPose.kneeRight = newPosition
            // Update foot to maintain distance from knee
            if constrainLegs {
                let dx = currentPose.footRight.x - currentPose.kneeRight.x
                let dy = currentPose.footRight.y - currentPose.kneeRight.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = kneeToFoot / distance
                    currentPose.footRight.x = currentPose.kneeRight.x + dx * ratio
                    currentPose.footRight.y = currentPose.kneeRight.y + dy * ratio
                }
            }
            
        case "footRight":
            if constrainLegs {
                let dx = newPosition.x - currentPose.kneeRight.x
                let dy = newPosition.y - currentPose.kneeRight.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 0 {
                    let ratio = kneeToFoot / distance
                    newPosition.x = currentPose.kneeRight.x + dx * ratio
                    newPosition.y = currentPose.kneeRight.y + dy * ratio
                }
            }
            currentPose.footRight = newPosition
            
        default:
            break
        }
    }
    
    private func updateChildLimbsLeft(from parentPos: CGPoint, distA: CGFloat, distB: CGFloat) {
        if constrainArms {
            // Maintain distance from parent to elbow
            let dx = currentPose.elbowLeft.x - parentPos.x
            let dy = currentPose.elbowLeft.y - parentPos.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance > 0 {
                let ratio = distA / distance
                currentPose.elbowLeft.x = parentPos.x + dx * ratio
                currentPose.elbowLeft.y = parentPos.y + dy * ratio
            }
            // Maintain distance from elbow to hand
            let dx2 = currentPose.handLeft.x - currentPose.elbowLeft.x
            let dy2 = currentPose.handLeft.y - currentPose.elbowLeft.y
            let distance2 = sqrt(dx2 * dx2 + dy2 * dy2)
            if distance2 > 0 {
                let ratio2 = distB / distance2
                currentPose.handLeft.x = currentPose.elbowLeft.x + dx2 * ratio2
                currentPose.handLeft.y = currentPose.elbowLeft.y + dy2 * ratio2
            }
        }
    }
    
    private func updateChildLimbsRight(from parentPos: CGPoint, distA: CGFloat, distB: CGFloat) {
        if constrainArms {
            // Maintain distance from parent to elbow
            let dx = currentPose.elbowRight.x - parentPos.x
            let dy = currentPose.elbowRight.y - parentPos.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance > 0 {
                let ratio = distA / distance
                currentPose.elbowRight.x = parentPos.x + dx * ratio
                currentPose.elbowRight.y = parentPos.y + dy * ratio
            }
            // Maintain distance from elbow to hand
            let dx2 = currentPose.handRight.x - currentPose.elbowRight.x
            let dy2 = currentPose.handRight.y - currentPose.elbowRight.y
            let distance2 = sqrt(dx2 * dx2 + dy2 * dy2)
            if distance2 > 0 {
                let ratio2 = distB / distance2
                currentPose.handRight.x = currentPose.elbowRight.x + dx2 * ratio2
                currentPose.handRight.y = currentPose.elbowRight.y + dy2 * ratio2
            }
        }
    }
    
    private func savePose() {
        let trimmedName = poseName.trimmingCharacters(in: .whitespaces)
        guard let position = Int(positionNumber.trimmingCharacters(in: .whitespaces)), !trimmedName.isEmpty else {
            return
        }
        
        poseManager.savePose(currentPose, name: trimmedName, positionNumber: position)
        showSaveAlert = true
        poseName = ""
        positionNumber = "1"
        currentObjects.removeAll()
    }
    
    private func addObject() {
        let newObject = DirectionalObject(
            position: CGPoint(x: 200 + CGFloat.random(in: -30...30), y: 225 + CGFloat.random(in: -30...30)),
            width: 30,
            height: 30,
            rotation: 0,
            objectType: selectedObjectType,
            color: selectedObjectType == "image" ? "#FFFFFF" : selectedColor.toHex(),
            imageData: selectedObjectType == "image" ? selectedImageData : nil,
            imageName: selectedObjectType == "image" ? selectedImageName : nil
        )
        currentObjects.append(newObject)
    }
}

// MARK: - Draggable Object View Component

struct DraggableObjectView: View {
    let object: DirectionalObject
    let isDragged: Bool
    let draggedHandle: String?
    let onMove: (CGPoint) -> Void
    let onResize: (CGFloat, CGFloat) -> Void
    let onRotate: (Double) -> Void
    let onDragStart: (String) -> Void
    let onDragEnd: () -> Void
    
    var body: some View {
        ZStack(alignment: .center) {
            // Main object
            Group {
                if object.objectType == "image" {
                    if let imageData = object.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: object.width, height: object.height)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: object.width, height: object.height)
                            .overlay(Text("No Image").font(.caption))
                    }
                } else if object.objectType == "ball" {
                    Circle()
                        .fill(Color(hex: object.color) ?? .red)
                        .frame(width: object.width, height: object.height)
                } else if object.objectType == "box" {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: object.color) ?? .red)
                        .frame(width: object.width, height: object.height)
                } else {
                    Capsule()
                        .fill(Color(hex: object.color) ?? .red)
                        .frame(width: object.width, height: object.height)
                }
            }
            .rotationEffect(.degrees(object.rotation))
            
            // Resize handle (bottom-right corner)
            Circle()
                .fill(isDragged && draggedHandle == "resize" ? Color.orange : Color.yellow)
                .frame(width: 8, height: 8)
                .position(CGPoint(x: object.position.x + object.width/2 + 4, y: object.position.y + object.height/2 + 4))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDragStart("resize")
                            let newWidth = max(10, value.location.x - object.position.x)
                            let newHeight = max(10, value.location.y - object.position.y)
                            onResize(newWidth, newHeight)
                        }
                        .onEnded { _ in
                            onDragEnd()
                        }
                )
            
            // Rotation handle (top-right corner)
            Circle()
                .fill(isDragged && draggedHandle == "rotate" ? Color.green : Color.cyan)
                .frame(width: 8, height: 8)
                .position(CGPoint(x: object.position.x + object.width/2 + 4, y: object.position.y - object.height/2 - 4))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDragStart("rotate")
                            let dx = value.location.x - object.position.x
                            let dy = value.location.y - object.position.y
                            let angle = atan2(dy, dx) * 180 / .pi
                            onRotate(angle)
                        }
                        .onEnded { _ in
                            onDragEnd()
                        }
                )
        }
        .position(object.position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    onDragStart("move")
                    onMove(value.location)
                }
                .onEnded { _ in
                    onDragEnd()
                }
        )
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Binding var imageName: String
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                if let jpegData = image.jpegData(compressionQuality: 0.8) {
                    parent.imageData = jpegData
                }
                
                if let url = info[.imageURL] as? URL {
                    parent.imageName = url.lastPathComponent
                } else if info[.phAsset] != nil {
                    parent.imageName = "photo"
                } else {
                    parent.imageName = "selected_image"
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
