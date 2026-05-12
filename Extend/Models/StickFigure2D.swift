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
        // Decode createdAt as Double (Unix timestamp) and convert to Date
        if let timestamp = try container.decodeIfPresent(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = Date()
        }
    }
    
    // Equatable conformance
    static func == (lhs: AnimationFrame, rhs: AnimationFrame) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.frameNumber == rhs.frameNumber
    }
}

// MARK: - Animation Objects

struct AnimationObject: Codable, Identifiable, Equatable {
    let id: UUID
    var type: ObjectType = .image  // image or box
    var imageName: String = ""  // For image type
    var position: CGPoint
    var rotation: Double // in degrees
    var scale: Double

    // Box-specific properties
    var width: CGFloat = 50   // Box width
    var height: CGFloat = 50  // Box height
    var color: String = "#FF0000"  // Box color as hex string

    /// Width of the SpriteKit editor scene at the time this object was saved.
    /// Used by renderFrameObjects to convert editor scene coordinates back to
    /// figure-relative space at any characterRenderScale.
    /// Defaults to 390 (standard iPhone width) for frames saved before this field existed.
    var editorSceneWidth: CGFloat = 390

    enum ObjectType: String, Codable {
        case image = "image"
        case box = "box"
    }

    init(imageName: String, position: CGPoint, rotation: Double = 0, scale: Double = 1.0, editorSceneWidth: CGFloat = 390) {
        self.id = UUID()
        self.type = .image
        self.imageName = imageName
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.editorSceneWidth = editorSceneWidth
    }

    init(boxAt position: CGPoint, width: CGFloat = 50, height: CGFloat = 50, color: String = "#FF0000", rotation: Double = 0, editorSceneWidth: CGFloat = 390) {
        self.id = UUID()
        self.type = .box
        self.position = position
        self.width = width
        self.height = height
        self.color = color
        self.rotation = rotation
        self.scale = 1.0
        self.editorSceneWidth = editorSceneWidth
    }

    // Custom Codable to handle position as dict with x,y keys
    enum CodingKeys: String, CodingKey {
        case id, type, imageName, position, rotation, scale, width, height, color, editorSceneWidth
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(imageName, forKey: .imageName)
        
        // Encode position as a nested object
        var posContainer = container.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        try posContainer.encode(position.x, forKey: .x)
        try posContainer.encode(position.y, forKey: .y)
        
        try container.encode(rotation, forKey: .rotation)
        try container.encode(scale, forKey: .scale)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(color, forKey: .color)
        try container.encode(editorSceneWidth, forKey: .editorSceneWidth)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ObjectType.self, forKey: .type)
        imageName = try container.decode(String.self, forKey: .imageName)

        let posContainer = try container.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        let x = try posContainer.decode(CGFloat.self, forKey: .x)
        let y = try posContainer.decode(CGFloat.self, forKey: .y)
        position = CGPoint(x: x, y: y)

        rotation = try container.decode(Double.self, forKey: .rotation)
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0

        width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 50
        height = try container.decodeIfPresent(CGFloat.self, forKey: .height) ?? 50
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#FF0000"
        // Default to 390 for frames saved before this field was added
        editorSceneWidth = try container.decodeIfPresent(CGFloat.self, forKey: .editorSceneWidth) ?? 390
    }
    
    enum PositionKeys: String, CodingKey {
        case x, y
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
    let leftHipAngle: Double
    let rightHipAngle: Double
    let leftKneeAngle: Double
    let rightKneeAngle: Double
    let leftFootAngle: Double
    let rightFootAngle: Double
    let headColor: String
    let torsoColor: String
    let leftArmColor: String
    let rightArmColor: String
    let leftUpperArmColor: String
    let rightUpperArmColor: String
    let leftLowerArmColor: String
    let rightLowerArmColor: String
    let leftLegColor: String
    let rightLegColor: String
    let leftUpperLegColor: String
    let rightUpperLegColor: String
    let leftLowerLegColor: String
    let rightLowerLegColor: String
    let handColor: String
    let footColor: String
    let jointColor: String
    let strokeThickness: CGFloat
    let scale: Double
    let headRadiusMultiplier: Double
    
    // Individual stroke thicknesses
    let strokeThicknessBicep: CGFloat
    let strokeThicknessTricep: CGFloat
    let strokeThicknessLowerArms: CGFloat
    let strokeThicknessUpperLegs: CGFloat
    let strokeThicknessLowerLegs: CGFloat
    let strokeThicknessJoints: CGFloat
    let strokeThicknessUpperTorso: CGFloat
    let strokeThicknessLowerTorso: CGFloat
    let strokeThicknessFullTorso: CGFloat
    let strokeThicknessDeltoids: CGFloat
    let strokeThicknessTrapezius: CGFloat
    
    // Fusiform controls
    let fusiformBicep: CGFloat
    let fusiformTricep: CGFloat
    let fusiformLowerArms: CGFloat
    let fusiformUpperLegs: CGFloat
    let fusiformLowerLegs: CGFloat
    let fusiformUpperTorso: CGFloat
    let fusiformLowerTorso: CGFloat
    let fusiformShoulders: CGFloat
    let fusiformDeltoids: CGFloat
    let fusiformFullTorso: CGFloat
    
    // Peak position controls
    let peakPositionBicep: CGFloat
    let peakPositionTricep: CGFloat
    let peakPositionLowerArms: CGFloat
    let peakPositionUpperLegs: CGFloat
    let peakPositionLowerLegs: CGFloat
    let peakPositionUpperTorso: CGFloat
    let peakPositionLowerTorso: CGFloat
    let peakPositionDeltoids: CGFloat
    let peakPositionFullTorsoTop: CGFloat
    let peakPositionFullTorsoMiddle: CGFloat
    let peakPositionFullTorsoBottom: CGFloat
    let armMuscleSide: String
    
    // Figure scale and thickness multipliers
    let figureScale: CGFloat
    let strokeThicknessMultiplier: CGFloat
    let skeletonSizeTorso: CGFloat
    let skeletonSizeArm: CGFloat
    let skeletonSizeLeg: CGFloat
    let jointShapeSize: CGFloat
    let shoulderWidthMultiplier: CGFloat
    let waistWidthMultiplier: CGFloat
    let waistThicknessMultiplier: CGFloat
    let neckLength: CGFloat
    let neckWidth: CGFloat
    let handSize: CGFloat
    let footSize: CGFloat

    // Waist shape control
    // (removed - now using waistThicknessMultiplier for triangle point position)

    // Position offsets
    let figureOffsetX: CGFloat
    let figureOffsetY: CGFloat
    
    init(from figure: StickFigure2D) {
        self.waistPosition = figure.waistPosition  // Save waist position
        self.waistTorsoAngle = figure.waistTorsoAngle
        self.midTorsoAngle = figure.midTorsoAngle
        self.headAngle = figure.headAngle
        self.leftShoulderAngle = figure.leftShoulderAngle
        self.rightShoulderAngle = figure.rightShoulderAngle
        self.leftElbowAngle = figure.leftElbowAngle
        self.rightElbowAngle = figure.rightElbowAngle
        self.leftHipAngle = figure.leftHipAngle
        self.rightHipAngle = figure.rightHipAngle
        self.leftKneeAngle = figure.leftKneeAngle
        self.rightKneeAngle = figure.rightKneeAngle
        self.leftFootAngle = figure.leftFootAngle
        self.rightFootAngle = figure.rightFootAngle
        self.headColor = figure.headColor.toHex()
        self.torsoColor = figure.torsoColor.toHex()
        self.leftArmColor = figure.leftArmColor.toHex()
        self.rightArmColor = figure.rightArmColor.toHex()
        self.leftUpperArmColor = figure.leftUpperArmColor.toHex()
        self.rightUpperArmColor = figure.rightUpperArmColor.toHex()
        self.leftLowerArmColor = figure.leftLowerArmColor.toHex()
        self.rightLowerArmColor = figure.rightLowerArmColor.toHex()
        self.leftLegColor = figure.leftLegColor.toHex()
        self.rightLegColor = figure.rightLegColor.toHex()
        self.leftUpperLegColor = figure.leftUpperLegColor.toHex()
        self.rightUpperLegColor = figure.rightUpperLegColor.toHex()
        self.leftLowerLegColor = figure.leftLowerLegColor.toHex()
        self.rightLowerLegColor = figure.rightLowerLegColor.toHex()
        self.handColor = figure.handColor.toHex()
        self.footColor = figure.footColor.toHex()
        self.jointColor = figure.jointColor.toHex()
        self.strokeThickness = figure.strokeThickness
        self.scale = figure.scale
        self.headRadiusMultiplier = figure.headRadiusMultiplier
        self.strokeThicknessBicep = figure.strokeThicknessBicep
        self.strokeThicknessTricep = figure.strokeThicknessTricep
        self.strokeThicknessLowerArms = figure.strokeThicknessLowerArms
        self.strokeThicknessUpperLegs = figure.strokeThicknessUpperLegs
        self.strokeThicknessLowerLegs = figure.strokeThicknessLowerLegs
        self.strokeThicknessJoints = figure.strokeThicknessJoints
        self.strokeThicknessUpperTorso = figure.strokeThicknessUpperTorso
        self.strokeThicknessLowerTorso = figure.strokeThicknessLowerTorso
        self.strokeThicknessFullTorso = figure.strokeThicknessFullTorso
        self.strokeThicknessDeltoids = figure.strokeThicknessDeltoids
        self.strokeThicknessTrapezius = figure.strokeThicknessTrapezius
        self.fusiformBicep = figure.fusiformBicep
        self.fusiformTricep = figure.fusiformTricep
        self.fusiformLowerArms = figure.fusiformLowerArms
        self.fusiformUpperLegs = figure.fusiformUpperLegs
        self.fusiformLowerLegs = figure.fusiformLowerLegs
        self.fusiformUpperTorso = figure.fusiformUpperTorso
        self.fusiformLowerTorso = figure.fusiformLowerTorso
        self.fusiformShoulders = figure.fusiformShoulders
        self.fusiformDeltoids = figure.fusiformDeltoids
        self.fusiformFullTorso = figure.fusiformFullTorso
        self.peakPositionBicep = figure.peakPositionBicep
        self.peakPositionTricep = figure.peakPositionTricep
        self.peakPositionLowerArms = figure.peakPositionLowerArms
        self.peakPositionUpperLegs = figure.peakPositionUpperLegs
        self.peakPositionLowerLegs = figure.peakPositionLowerLegs
        self.peakPositionUpperTorso = figure.peakPositionUpperTorso
        self.peakPositionLowerTorso = figure.peakPositionLowerTorso
        self.peakPositionDeltoids = figure.peakPositionDeltoids
        self.peakPositionFullTorsoTop = figure.peakPositionFullTorsoTop
        self.peakPositionFullTorsoMiddle = figure.peakPositionFullTorsoMiddle
        self.peakPositionFullTorsoBottom = figure.peakPositionFullTorsoBottom
        self.armMuscleSide = figure.armMuscleSide
        self.figureScale = figure.scale
        self.strokeThicknessMultiplier = 1.0  // This would need to be tracked separately
        self.skeletonSizeTorso = figure.skeletonSizeTorso
        self.skeletonSizeArm = figure.skeletonSizeArm
        self.skeletonSizeLeg = figure.skeletonSizeLeg
        self.jointShapeSize = 1.0  // This would need to be tracked separately
        self.shoulderWidthMultiplier = figure.shoulderWidthMultiplier
        self.waistWidthMultiplier = figure.waistWidthMultiplier
        self.waistThicknessMultiplier = figure.waistThicknessMultiplier
        self.neckLength = figure.neckLength
        self.neckWidth = figure.neckWidth
        self.handSize = figure.handSize
        self.footSize = figure.footSize
        self.figureOffsetX = 0  // This would need to be tracked separately
        self.figureOffsetY = 0  // This would need to be tracked separately
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
        figure.leftHipAngle = leftHipAngle
        figure.rightHipAngle = rightHipAngle
        figure.leftKneeAngle = leftKneeAngle
        figure.rightKneeAngle = rightKneeAngle
        figure.leftFootAngle = leftFootAngle
        figure.rightFootAngle = rightFootAngle
        figure.headColor = Color(hex: headColor) ?? .black
        figure.torsoColor = Color(hex: torsoColor) ?? .black
        figure.leftArmColor = Color(hex: leftArmColor) ?? .black
        figure.rightArmColor = Color(hex: rightArmColor) ?? .black
        figure.leftUpperArmColor = Color(hex: leftUpperArmColor) ?? .black
        figure.rightUpperArmColor = Color(hex: rightUpperArmColor) ?? .black
        figure.leftLowerArmColor = Color(hex: leftLowerArmColor) ?? .black
        figure.rightLowerArmColor = Color(hex: rightLowerArmColor) ?? .black
        figure.leftLegColor = Color(hex: leftLegColor) ?? .black
        figure.rightLegColor = Color(hex: rightLegColor) ?? .black
        figure.leftUpperLegColor = Color(hex: leftUpperLegColor) ?? .black
        figure.rightUpperLegColor = Color(hex: rightUpperLegColor) ?? .black
        figure.leftLowerLegColor = Color(hex: leftLowerLegColor) ?? .black
        figure.rightLowerLegColor = Color(hex: rightLowerLegColor) ?? .black
        figure.handColor = Color(hex: handColor) ?? .black
        figure.footColor = Color(hex: footColor) ?? .black
        figure.jointColor = Color(hex: jointColor) ?? .black
        figure.strokeThickness = strokeThickness
        figure.scale = scale
        figure.headRadiusMultiplier = headRadiusMultiplier
        figure.strokeThicknessBicep = strokeThicknessBicep
        figure.strokeThicknessTricep = strokeThicknessTricep
        figure.strokeThicknessLowerArms = strokeThicknessLowerArms
        figure.strokeThicknessUpperLegs = strokeThicknessUpperLegs
        figure.strokeThicknessLowerLegs = strokeThicknessLowerLegs
        figure.strokeThicknessJoints = strokeThicknessJoints
        figure.strokeThicknessUpperTorso = strokeThicknessUpperTorso
        figure.strokeThicknessLowerTorso = strokeThicknessLowerTorso
        figure.strokeThicknessFullTorso = strokeThicknessFullTorso
        figure.strokeThicknessDeltoids = strokeThicknessDeltoids
        figure.strokeThicknessTrapezius = strokeThicknessTrapezius
        figure.fusiformBicep = fusiformBicep
        figure.fusiformTricep = fusiformTricep
        figure.fusiformLowerArms = fusiformLowerArms
        figure.fusiformUpperLegs = fusiformUpperLegs
        figure.fusiformLowerLegs = fusiformLowerLegs
        figure.fusiformUpperTorso = fusiformUpperTorso
        figure.fusiformLowerTorso = fusiformLowerTorso
        figure.fusiformShoulders = fusiformShoulders
        figure.fusiformDeltoids = fusiformDeltoids
        figure.fusiformFullTorso = fusiformFullTorso
        figure.peakPositionBicep = peakPositionBicep
        figure.peakPositionTricep = peakPositionTricep
        figure.peakPositionLowerArms = peakPositionLowerArms
        figure.peakPositionUpperLegs = peakPositionUpperLegs
        figure.peakPositionLowerLegs = peakPositionLowerLegs
        figure.peakPositionUpperTorso = peakPositionUpperTorso
        figure.peakPositionLowerTorso = peakPositionLowerTorso
        figure.peakPositionDeltoids = peakPositionDeltoids
        figure.peakPositionFullTorsoTop = peakPositionFullTorsoTop
        figure.peakPositionFullTorsoMiddle = peakPositionFullTorsoMiddle
        figure.peakPositionFullTorsoBottom = peakPositionFullTorsoBottom
        figure.armMuscleSide = armMuscleSide
        figure.shoulderWidthMultiplier = shoulderWidthMultiplier
        figure.waistWidthMultiplier = waistWidthMultiplier
        figure.waistThicknessMultiplier = waistThicknessMultiplier
        figure.skeletonSizeTorso = skeletonSizeTorso
        figure.skeletonSizeArm = skeletonSizeArm
        figure.skeletonSizeLeg = skeletonSizeLeg
        figure.jointShapeSize = jointShapeSize
        figure.neckLength = neckLength
        figure.neckWidth = neckWidth
        figure.handSize = handSize
        figure.handSize = handSize
        figure.footSize = footSize
        figure.figureOffsetX = figureOffsetX
        figure.figureOffsetY = figureOffsetY
        return figure
    }
    
    // Custom Codable to handle CGPoint
    enum CodingKeys: String, CodingKey {
        case waistPositionX, waistPositionY
        case waistTorsoAngle, midTorsoAngle, headAngle
        case leftShoulderAngle, rightShoulderAngle
        case leftElbowAngle, rightElbowAngle
        case leftHipAngle, rightHipAngle
        case leftKneeAngle, rightKneeAngle
        case leftFootAngle, rightFootAngle
        case headColor, torsoColor, leftArmColor, rightArmColor
        case leftUpperArmColor, rightUpperArmColor, leftLowerArmColor, rightLowerArmColor
        case leftLegColor, rightLegColor
        case leftUpperLegColor, rightUpperLegColor, leftLowerLegColor, rightLowerLegColor
        case handColor, footColor, jointColor
        case strokeThickness, scale, headRadiusMultiplier
        case strokeThicknessBicep, strokeThicknessTricep, strokeThicknessLowerArms
        case strokeThicknessUpperLegs, strokeThicknessLowerLegs
        case strokeThicknessJoints, strokeThicknessUpperTorso, strokeThicknessLowerTorso, strokeThicknessFullTorso, strokeThicknessDeltoids, strokeThicknessTrapezius
        case fusiformBicep, fusiformTricep, fusiformLowerArms
        case fusiformUpperLegs, fusiformLowerLegs
        case fusiformUpperTorso, fusiformLowerTorso, fusiformShoulders, fusiformDeltoids, fusiformFullTorso
        case peakPositionBicep, peakPositionTricep, peakPositionLowerArms, peakPositionUpperLegs, peakPositionLowerLegs, peakPositionUpperTorso, peakPositionLowerTorso, peakPositionDeltoids, peakPositionFullTorsoTop, peakPositionFullTorsoMiddle, peakPositionFullTorsoBottom, midTorsoYOffset, armMuscleSide
        case figureScale, strokeThicknessMultiplier, skeletonSizeTorso, skeletonSizeArm, skeletonSizeLeg, jointShapeSize
        case shoulderWidthMultiplier, waistWidthMultiplier, waistThicknessMultiplier, neckLength, neckWidth
        case handSize, footSize
        case figureOffsetX, figureOffsetY
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Alphabetically sorted encoding of all properties
        try container.encode(armMuscleSide, forKey: .armMuscleSide)
        try container.encode(round(figureOffsetX), forKey: .figureOffsetX)
        try container.encode(round(figureOffsetY), forKey: .figureOffsetY)
        try container.encode(round(figureScale), forKey: .figureScale)
        try container.encode(round(fusiformLowerArms), forKey: .fusiformLowerArms)
        try container.encode(round(fusiformLowerLegs), forKey: .fusiformLowerLegs)
        try container.encode(round(fusiformShoulders), forKey: .fusiformShoulders)
        try container.encode(round(fusiformDeltoids), forKey: .fusiformDeltoids)
        try container.encode(round(fusiformBicep), forKey: .fusiformBicep)
        try container.encode(round(fusiformTricep), forKey: .fusiformTricep)
        try container.encode(round(fusiformUpperLegs), forKey: .fusiformUpperLegs)
        try container.encode(round(fusiformUpperTorso), forKey: .fusiformUpperTorso)
        try container.encode(round(fusiformFullTorso), forKey: .fusiformFullTorso)
        try container.encode(footColor, forKey: .footColor)
        try container.encode(handColor, forKey: .handColor)
        try container.encode(round(footSize), forKey: .footSize)
        try container.encode(round(handSize), forKey: .handSize)
        try container.encode(round(headAngle), forKey: .headAngle)
        try container.encode(headColor, forKey: .headColor)
        try container.encode(headRadiusMultiplier, forKey: .headRadiusMultiplier)
        try container.encode(round(jointShapeSize), forKey: .jointShapeSize)
        try container.encode(jointColor, forKey: .jointColor)
        try container.encode(round(leftElbowAngle), forKey: .leftElbowAngle)
        try container.encode(round(leftFootAngle), forKey: .leftFootAngle)
        try container.encode(round(leftHipAngle), forKey: .leftHipAngle)
        try container.encode(round(leftKneeAngle), forKey: .leftKneeAngle)
        try container.encode(round(leftShoulderAngle), forKey: .leftShoulderAngle)
        try container.encode(round(midTorsoAngle), forKey: .midTorsoAngle)
        try container.encode(round(neckLength), forKey: .neckLength)
        try container.encode(round(peakPositionLowerArms), forKey: .peakPositionLowerArms)
        try container.encode(round(peakPositionLowerLegs), forKey: .peakPositionLowerLegs)
        try container.encode(round(peakPositionLowerTorso), forKey: .peakPositionLowerTorso)
        try container.encode(round(peakPositionDeltoids), forKey: .peakPositionDeltoids)
        try container.encode(round(peakPositionBicep), forKey: .peakPositionBicep)
        try container.encode(round(peakPositionTricep), forKey: .peakPositionTricep)
        try container.encode(round(peakPositionUpperLegs), forKey: .peakPositionUpperLegs)
        try container.encode(round(peakPositionUpperTorso), forKey: .peakPositionUpperTorso)
        try container.encode(round(peakPositionFullTorsoTop), forKey: .peakPositionFullTorsoTop)
        try container.encode(round(peakPositionFullTorsoMiddle), forKey: .peakPositionFullTorsoMiddle)
        try container.encode(round(peakPositionFullTorsoBottom), forKey: .peakPositionFullTorsoBottom)
        try container.encode(round(rightElbowAngle), forKey: .rightElbowAngle)
        try container.encode(round(rightFootAngle), forKey: .rightFootAngle)
        try container.encode(round(rightHipAngle), forKey: .rightHipAngle)
        try container.encode(round(rightKneeAngle), forKey: .rightKneeAngle)
        try container.encode(round(rightShoulderAngle), forKey: .rightShoulderAngle)
        try container.encode(round(shoulderWidthMultiplier), forKey: .shoulderWidthMultiplier)
        try container.encode(round(waistWidthMultiplier), forKey: .waistWidthMultiplier)
        try container.encode(round(waistThicknessMultiplier), forKey: .waistThicknessMultiplier)
        try container.encode(scale, forKey: .scale)
        try container.encode(round(skeletonSizeTorso), forKey: .skeletonSizeTorso)
        try container.encode(round(skeletonSizeArm), forKey: .skeletonSizeArm)
        try container.encode(round(skeletonSizeLeg), forKey: .skeletonSizeLeg)
        try container.encode(round(strokeThicknessFullTorso), forKey: .strokeThicknessFullTorso)
        try container.encode(round(strokeThicknessDeltoids), forKey: .strokeThicknessDeltoids)
        try container.encode(round(strokeThicknessTrapezius), forKey: .strokeThicknessTrapezius)
        try container.encode(round(strokeThicknessJoints), forKey: .strokeThicknessJoints)
        try container.encode(round(strokeThicknessBicep), forKey: .strokeThicknessBicep)
        try container.encode(round(strokeThicknessTricep), forKey: .strokeThicknessTricep)
        try container.encode(round(strokeThicknessLowerArms), forKey: .strokeThicknessLowerArms)
        try container.encode(round(strokeThicknessLowerLegs), forKey: .strokeThicknessLowerLegs)
        try container.encode(round(strokeThicknessLowerTorso), forKey: .strokeThicknessLowerTorso)
        try container.encode(round(strokeThicknessMultiplier), forKey: .strokeThicknessMultiplier)
        try container.encode(round(strokeThicknessUpperLegs), forKey: .strokeThicknessUpperLegs)
        try container.encode(round(strokeThicknessUpperTorso), forKey: .strokeThicknessUpperTorso)
        try container.encode(torsoColor, forKey: .torsoColor)
        try container.encode(round(waistPosition.x), forKey: .waistPositionX)
        try container.encode(round(waistPosition.y), forKey: .waistPositionY)
        try container.encode(round(waistTorsoAngle), forKey: .waistTorsoAngle)
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
        self.leftHipAngle = try container.decodeIfPresent(Double.self, forKey: .leftHipAngle) ?? 0
        self.rightHipAngle = try container.decodeIfPresent(Double.self, forKey: .rightHipAngle) ?? 0
        self.leftKneeAngle = try container.decode(Double.self, forKey: .leftKneeAngle)
        self.rightKneeAngle = try container.decode(Double.self, forKey: .rightKneeAngle)
        self.leftFootAngle = try container.decode(Double.self, forKey: .leftFootAngle)
        self.rightFootAngle = try container.decode(Double.self, forKey: .rightFootAngle)
        self.headColor = try container.decode(String.self, forKey: .headColor)
        self.torsoColor = try container.decode(String.self, forKey: .torsoColor)
        self.leftArmColor = try container.decodeIfPresent(String.self, forKey: .leftArmColor) ?? "#000000"
        self.rightArmColor = try container.decodeIfPresent(String.self, forKey: .rightArmColor) ?? "#000000"
        self.leftUpperArmColor = try container.decodeIfPresent(String.self, forKey: .leftUpperArmColor) ?? "#000000"
        self.rightUpperArmColor = try container.decodeIfPresent(String.self, forKey: .rightUpperArmColor) ?? "#000000"
        self.leftLowerArmColor = try container.decodeIfPresent(String.self, forKey: .leftLowerArmColor) ?? "#000000"
        self.rightLowerArmColor = try container.decodeIfPresent(String.self, forKey: .rightLowerArmColor) ?? "#000000"
        self.leftLegColor = try container.decodeIfPresent(String.self, forKey: .leftLegColor) ?? "#000000"
        self.rightLegColor = try container.decodeIfPresent(String.self, forKey: .rightLegColor) ?? "#000000"
        self.leftUpperLegColor = try container.decodeIfPresent(String.self, forKey: .leftUpperLegColor) ?? "#000000"
        self.rightUpperLegColor = try container.decodeIfPresent(String.self, forKey: .rightUpperLegColor) ?? "#000000"
        self.leftLowerLegColor = try container.decodeIfPresent(String.self, forKey: .leftLowerLegColor) ?? "#000000"
        self.rightLowerLegColor = try container.decodeIfPresent(String.self, forKey: .rightLowerLegColor) ?? "#000000"
        self.handColor = try container.decode(String.self, forKey: .handColor)
        self.footColor = try container.decode(String.self, forKey: .footColor)
        self.jointColor = try container.decodeIfPresent(String.self, forKey: .jointColor) ?? "#000000"
        // strokeThickness is optional - derive from average of other strokes if missing
        self.strokeThickness = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThickness) ?? 1.0
        self.scale = try container.decode(Double.self, forKey: .scale)
        self.headRadiusMultiplier = try container.decode(Double.self, forKey: .headRadiusMultiplier)
        // New properties with defaults for backward compatibility
        self.strokeThicknessBicep = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessBicep) ?? 4.0
        self.strokeThicknessTricep = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessTricep) ?? 4.0
        self.strokeThicknessLowerArms = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerArms) ?? 3.5
        self.strokeThicknessUpperLegs = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperLegs) ?? 4.5
        self.strokeThicknessLowerLegs = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerLegs) ?? 3.5
        self.strokeThicknessJoints = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessJoints) ?? 2.5
        self.strokeThicknessUpperTorso = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperTorso) ?? 5.0
        self.strokeThicknessLowerTorso = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerTorso) ?? 4.5
        self.strokeThicknessFullTorso = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessFullTorso) ?? 1.0
        self.strokeThicknessDeltoids = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessDeltoids) ?? 4.0
        self.strokeThicknessTrapezius = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessTrapezius) ?? 4.0
        self.fusiformBicep = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformBicep) ?? 0.0
        self.fusiformTricep = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformTricep) ?? 0.0
        self.fusiformLowerArms = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerArms) ?? 0.0
        self.fusiformUpperLegs = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformUpperLegs) ?? 0.0
        self.fusiformLowerLegs = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerLegs) ?? 0.0
        self.fusiformUpperTorso = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformUpperTorso) ?? 0.0
        self.fusiformLowerTorso = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerTorso) ?? 0.0
        self.fusiformShoulders = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformShoulders) ?? 0.0
        self.fusiformDeltoids = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformDeltoids) ?? 0.0
        self.fusiformFullTorso = try container.decodeIfPresent(CGFloat.self, forKey: .fusiformFullTorso) ?? 0.0
        self.peakPositionBicep = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionBicep) ?? 0.5
        self.peakPositionTricep = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionTricep) ?? 0.5
        self.peakPositionLowerArms = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerArms) ?? 0.35
        self.peakPositionUpperLegs = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionUpperLegs) ?? 0.2
        self.peakPositionLowerLegs = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerLegs) ?? 0.2
        self.peakPositionUpperTorso = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionUpperTorso) ?? 0.5
        self.peakPositionLowerTorso = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerTorso) ?? 0.5
        self.peakPositionDeltoids = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionDeltoids) ?? 0.3
        self.peakPositionFullTorsoTop = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionFullTorsoTop) ?? 0.15
        self.peakPositionFullTorsoMiddle = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionFullTorsoMiddle) ?? 0.5
        self.peakPositionFullTorsoBottom = try container.decodeIfPresent(CGFloat.self, forKey: .peakPositionFullTorsoBottom) ?? 0.85
        self.armMuscleSide = try container.decodeIfPresent(String.self, forKey: .armMuscleSide) ?? "normal"
        self.figureScale = try container.decodeIfPresent(CGFloat.self, forKey: .figureScale) ?? 1.0
        self.strokeThicknessMultiplier = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessMultiplier) ?? 1.0
        self.skeletonSizeTorso = try container.decodeIfPresent(CGFloat.self, forKey: .skeletonSizeTorso) ?? 1.0
        self.skeletonSizeArm = try container.decodeIfPresent(CGFloat.self, forKey: .skeletonSizeArm) ?? 1.0
        self.skeletonSizeLeg = try container.decodeIfPresent(CGFloat.self, forKey: .skeletonSizeLeg) ?? 1.0
        self.jointShapeSize = try container.decodeIfPresent(CGFloat.self, forKey: .jointShapeSize) ?? 1.0
        self.shoulderWidthMultiplier = try container.decodeIfPresent(CGFloat.self, forKey: .shoulderWidthMultiplier) ?? 1.0
        self.waistWidthMultiplier = try container.decodeIfPresent(CGFloat.self, forKey: .waistWidthMultiplier) ?? 1.0
        self.waistThicknessMultiplier = try container.decodeIfPresent(CGFloat.self, forKey: .waistThicknessMultiplier) ?? 1.0
        self.neckLength = try container.decodeIfPresent(CGFloat.self, forKey: .neckLength) ?? 1.0
        self.neckWidth = try container.decodeIfPresent(CGFloat.self, forKey: .neckWidth) ?? 1.0
        self.handSize = try container.decodeIfPresent(CGFloat.self, forKey: .handSize) ?? 1.0
        self.footSize = try container.decodeIfPresent(CGFloat.self, forKey: .footSize) ?? 1.0
        self.figureOffsetX = try container.decodeIfPresent(CGFloat.self, forKey: .figureOffsetX) ?? 0.0
        self.figureOffsetY = try container.decodeIfPresent(CGFloat.self, forKey: .figureOffsetY) ?? 0.0
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
    
    // Figure position offsets (for positioning the entire figure within the canvas)
    var figureOffsetX: CGFloat = 0.0
    var figureOffsetY: CGFloat = 0.0
    
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
    var leftHipAngle: Double = 0  // Rotation of upper left leg around waist
    var rightHipAngle: Double = 0  // Rotation of upper right leg around waist
    var leftKneeAngle: Double = 0
    var rightKneeAngle: Double = 0
    var leftFootAngle: Double = 0
    var rightFootAngle: Double = 0
    
    // Scale
    var scale: Double = 2.4 // Size multiplier (2.4 = 200% - default size for editing)
    var headRadiusMultiplier: Double = 1.0 // Head size multiplier (1.0 = normal size)
    var shoulderWidthMultiplier: CGFloat = 1.0 // Shoulder separation multiplier (1.0 = normal, >1.0 = wider)
    var waistWidthMultiplier: CGFloat = 1.0 // Waist width multiplier (1.0 = normal, >1.0 = wider)
    var waistThicknessMultiplier: CGFloat = 1.0 // Waist connector line thickness (1.0 = normal)
    var skeletonSizeTorso: CGFloat = 1.0 // Spine/torso connector thickness multiplier (1.0 = normal)
    var skeletonSizeArm: CGFloat = 1.0 // Arm connector thickness multiplier (1.0 = normal)
    var skeletonSizeLeg: CGFloat = 1.0 // Leg connector thickness multiplier (1.0 = normal)
    var neckLength: CGFloat = 1.0 // Neck length multiplier (1.0 = normal)
    var neckWidth: CGFloat = 1.0 // Neck connector width multiplier (1.0 = normal)
    var handSize: CGFloat = 1.0 // Hand size multiplier (1.0 = normal)
    var footSize: CGFloat = 1.0 // Foot size multiplier (1.0 = normal)
    var jointShapeSize: CGFloat = 1.0 // Joint shape size multiplier (1.0 = normal, 0 = invisible)
    
    // Colors for each body part
    var headColor: Color = .black
    var torsoColor: Color = .black
    var leftArmColor: Color = .black
    var rightArmColor: Color = .black
    var leftUpperArmColor: Color = .black
    var rightUpperArmColor: Color = .black
    var leftLowerArmColor: Color = .black
    var rightLowerArmColor: Color = .black
    var leftLegColor: Color = .black
    var rightLegColor: Color = .black
    var leftUpperLegColor: Color = .black
    var rightUpperLegColor: Color = .black
    var leftLowerLegColor: Color = .black
    var rightLowerLegColor: Color = .black
    var handColor: Color = .black
    var footColor: Color = .black
    var jointColor: Color = .black  // Color for visual joints/dots
    var eyeColor: Color = .black
    
    // Eye settings
    var eyesEnabled: Bool = false
    var irisColor: Color = .black
    var irisEnabled: Bool = false
    var isSideView: Bool = false  // When true, show only one eye (side view mode)
    
    // Stroke thickness (overall - kept for backward compatibility)
    var strokeThickness: CGFloat = 4.0
    
    // Individual stroke thicknesses for each body part
    var strokeThicknessBicep: CGFloat = 4.0
    var strokeThicknessTricep: CGFloat = 4.0
    var strokeThicknessLowerArms: CGFloat = 3.5
    var strokeThicknessUpperLegs: CGFloat = 4.5
    var strokeThicknessLowerLegs: CGFloat = 3.5
    var strokeThicknessJoints: CGFloat = 2.5  // For connection points/joints
    var strokeThicknessUpperTorso: CGFloat = 5.0
    var strokeThicknessLowerTorso: CGFloat = 4.5
    var strokeThicknessFullTorso: CGFloat = 1.0  // Overall torso thickness multiplier
    var strokeThicknessDeltoids: CGFloat = 4.0  // Deltoid (shoulder cap) thickness
    var strokeThicknessTrapezius: CGFloat = 4.0  // Trapezius (shoulder/neck muscle) thickness
    
    // Fusiform (tapered) controls for each body part (0.0 = no taper, 1.0 = full taper)
    var fusiformBicep: CGFloat = 0.0  // Inner arm taper (bicep)
    var fusiformTricep: CGFloat = 0.0  // Outer arm taper (tricep) - 50% of bicep width
    var fusiformLowerArms: CGFloat = 0.0  // Taper from elbow to wrist
    var fusiformShoulders: CGFloat = 0.0  // Shoulder joint taper (width variation at shoulders)
    var fusiformDeltoids: CGFloat = 0.0  // Shoulder cap (deltoid muscle taper) - 0 by default (not visible unless explicitly set)
    var fusiformUpperLegs: CGFloat = 0.0  // Taper from hip to knee
    var fusiformLowerLegs: CGFloat = 0.0  // Taper from knee to ankle (inverted - larger at top)
    var fusiformUpperTorso: CGFloat = 0.0 // Taper from shoulders to mid-torso (inverted - larger at top)
    var fusiformLowerTorso: CGFloat = 0.0 // Taper from mid-torso to waist
    
    // Peak position controls (where the widest part of tapered segments occurs)
    var peakPositionBicep: CGFloat = 0.5  // Default: middle of bicep
    var peakPositionTricep: CGFloat = 0.5  // Default: middle of tricep
    var peakPositionLowerArms: CGFloat = 0.35  // Default: closer to elbow
    var peakPositionUpperLegs: CGFloat = 0.2  // Default: near hip
    var peakPositionLowerLegs: CGFloat = 0.2  // Default: near knee
    var peakPositionUpperTorso: CGFloat = 0.5  // Default: middle of upper torso
    var peakPositionLowerTorso: CGFloat = 0.5  // Default: middle of lower torso
    var peakPositionDeltoids: CGFloat = 0.3  // Default: closer to shoulder joint for cap effect
    
    // Full torso hourglass control (smooth curved hourglass shape with 3 peaks)
    var fusiformFullTorso: CGFloat = 0.0  // Intensity of hourglass curve (0 = straight, 10 = pronounced)
    var peakPositionFullTorsoTop: CGFloat = 0.15  // Where shoulder/chest bulge reaches maximum (0-1)
    var peakPositionFullTorsoMiddle: CGFloat = 0.5  // Where waist pinch occurs (0-1)
    var peakPositionFullTorsoBottom: CGFloat = 0.85  // Where hip/gluteal bulge reaches maximum (0-1)
    
    // Arm muscle side control - determines which side bicep/tricep appear on based on pose
    // "normal" = bicep on bottom/inner, tricep on top/outer (default)
    // "flipped" = bicep on top/outer, tricep on bottom/inner
    // "both" = both muscles visible on both sides
    var armMuscleSide: String = "normal"  // "normal", "flipped", or "both"
    
    // ...existing code...
    
    // Static default Stand pose
    static func defaultStand() -> StickFigure2D {
        // ALWAYS load from Bundle's animations.json (the authoritative default)
        // Ignore Documents folder - that's for user edits, not defaults
        
        if let bundleURL = Bundle.main.url(forResource: "animations", withExtension: "json") {
            do {
                let data = try Data(contentsOf: bundleURL)
                let decoder = JSONDecoder()
                let frames = try decoder.decode([AnimationFrame].self, from: data)
                //print("DEBUG defaultStand: Loaded \(frames.count) frames from Bundle")
                
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
    let torsoLength: CGFloat = 46
    let neckBaseLength: CGFloat = 15  // Base neck length (actual length is neckLength property * this value)
    let headRadius: CGFloat = 12
    let upperArmLength: CGFloat = 25
    let forearmLength: CGFloat = 26
    let handLength: CGFloat = 8
    let upperLegLength: CGFloat = 34
    let lowerLegLength: CGFloat = 30
    let footLength: CGFloat = 10
    let shoulderWidth: CGFloat = 30
    let waistWidth: CGFloat = 20  // Width of waist/hips (similar to shoulderWidth)
    
    // Calculated positions
    var hipPosition: CGPoint { waistPosition }
    
    var leftHipPosition: CGPoint {
        // Hips are offset from the waist position based on waistWidthMultiplier
        let offsetAmount = waistWidth * waistWidthMultiplier
        return CGPoint(x: waistPosition.x - offsetAmount, y: waistPosition.y)
    }
    
    var rightHipPosition: CGPoint {
        // Hips are offset from the waist position based on waistWidthMultiplier
        let offsetAmount = waistWidth * waistWidthMultiplier
        return CGPoint(x: waistPosition.x + offsetAmount, y: waistPosition.y)
    }
    
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
        // Shoulders are offset from the neck position based on shoulderWidthMultiplier
        // When the waist rotates, shoulders rotate with it (they're part of the upper body)
        let offsetAmount = shoulderWidth * shoulderWidthMultiplier
        
        // Base offset (pointing left relative to neck)
        let baseX = -offsetAmount
        let baseY = 0.0
        
        // Rotate by torso angle so shoulders rotate with the body
        let totalTorsoRotation = waistTorsoAngle + midTorsoAngle
        let radians = totalTorsoRotation * .pi / 180
        let rotatedX = baseX * cos(radians) - baseY * sin(radians)
        let rotatedY = baseX * sin(radians) + baseY * cos(radians)
        
        return CGPoint(x: neckPosition.x + rotatedX, y: neckPosition.y + rotatedY)
    }
    
    var rightShoulderPosition: CGPoint {
        // Shoulders are offset from the neck position based on shoulderWidthMultiplier
        // When the waist rotates, shoulders rotate with it (they're part of the upper body)
        let offsetAmount = shoulderWidth * shoulderWidthMultiplier
        
        // Base offset (pointing right relative to neck)
        let baseX = offsetAmount
        let baseY = 0.0
        
        // Rotate by torso angle so shoulders rotate with the body
        let totalTorsoRotation = waistTorsoAngle + midTorsoAngle
        let radians = totalTorsoRotation * .pi / 180
        let rotatedX = baseX * cos(radians) - baseY * sin(radians)
        let rotatedY = baseX * sin(radians) + baseY * cos(radians)
        
        return CGPoint(x: neckPosition.x + rotatedX, y: neckPosition.y + rotatedY)
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
        let angle = 270.0 + leftHipAngle + leftKneeAngle // Hip rotation + knee rotation
        let radians = angle * .pi / 180
        let x = leftHipPosition.x + upperLegLength * cos(radians)
        let y = leftHipPosition.y + upperLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var leftLowerLegEnd: CGPoint {
        let angle = 270.0 + leftHipAngle + leftKneeAngle + leftFootAngle
        let radians = angle * .pi / 180
        let x = leftUpperLegEnd.x + lowerLegLength * cos(radians)
        let y = leftUpperLegEnd.y + lowerLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var leftFootEnd: CGPoint {
        // Foot end is the same as lower leg end
        leftLowerLegEnd
    }
    
    // Right leg positions
    // Legs rotate directly from waist center - no fixed X offset
    var rightUpperLegEnd: CGPoint {
        let angle = 270.0 + rightHipAngle + rightKneeAngle
        let radians = angle * .pi / 180
        let x = rightHipPosition.x + upperLegLength * cos(radians)
        let y = rightHipPosition.y + upperLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var rightLowerLegEnd: CGPoint {
        let angle = 270.0 + rightHipAngle + rightKneeAngle + rightFootAngle
        let radians = angle * .pi / 180
        let x = rightUpperLegEnd.x + lowerLegLength * cos(radians)
        let y = rightUpperLegEnd.y + lowerLegLength * sin(radians)
        return CGPoint(x: x, y: y)
    }
    
    var rightFootEnd: CGPoint {
        // Foot end is the same as lower leg end
        rightLowerLegEnd
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
        var regularPath = Path()
        var crosshairPath = Path()
        
        // Calculate center of canvas
        let canvasCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Calculate offset so grid lines align with center crosshairs
        // We want the center lines to be ON grid lines, not between them
        let offsetX = canvasCenter.x.truncatingRemainder(dividingBy: gridSpacing)
        let offsetY = canvasCenter.y.truncatingRemainder(dividingBy: gridSpacing)
        
        // Draw vertical lines - aligned with center
        var x: CGFloat = offsetX - gridSpacing * CGFloat(Int(canvasCenter.x / gridSpacing))
        while x <= size.width {
            if x >= 0 {
                // Skip if this would be the center line (we'll draw it separately)
                if abs(x - canvasCenter.x) >= gridSpacing * 0.1 {
                    regularPath.move(to: CGPoint(x: x, y: 0))
                    regularPath.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
            x += gridSpacing
        }
        
        // Draw horizontal lines - aligned with center
        var y: CGFloat = offsetY - gridSpacing * CGFloat(Int(canvasCenter.y / gridSpacing))
        while y <= size.height {
            if y >= 0 {
                // Skip if this would be the center line
                if abs(y - canvasCenter.y) >= gridSpacing * 0.1 {
                    regularPath.move(to: CGPoint(x: 0, y: y))
                    regularPath.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            y += gridSpacing
        }
        
        // Explicitly draw center crosshair lines
        // Vertical center line
        crosshairPath.move(to: CGPoint(x: canvasCenter.x, y: 0))
        crosshairPath.addLine(to: CGPoint(x: canvasCenter.x, y: size.height))
        
        // Horizontal center line
        crosshairPath.move(to: CGPoint(x: 0, y: canvasCenter.y))
        crosshairPath.addLine(to: CGPoint(x: size.width, y: canvasCenter.y))
        
        // Stroke regular grid with lighter color
        context.stroke(
            regularPath,
            with: .color(Color.gray.opacity(0.3)),
            lineWidth: 0.5
        )
        
        // Stroke crosshair (center lines) with darker color and thicker width
        context.stroke(
            crosshairPath,
            with: .color(Color.gray.opacity(0.6)),
            lineWidth: 1.5
        )
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
                                HStack(spacing: 6) {
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
                                            .imageScale(.small)
                                    }
                                    .buttonStyle(.plain)
                                    .scaleEffect(0.7)
                                    
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
                                                .imageScale(.small)
                                        }
                                        .buttonStyle(.plain)
                                        .scaleEffect(0.7)
                                        
                                        // Delete button
                                        Button(action: {
                                            frameToDelete = frame
                                            showDeleteConfirmation = true
                                        }) {
                                            Image(systemName: "trash.circle")
                                                .foregroundColor(.red)
                                                .imageScale(.small)
                                        }
                                        .buttonStyle(.plain)
                                        .scaleEffect(0.7)
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
                Button("Cancel", role: .cancel) {
                    frameToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let frame = frameToDelete {
                        savedFrames.removeAll { $0.id == frame.id }
                        frameToDelete = nil
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
        AnimationPersistence.exportFramesAsJSON([frame]) { jsonString, _ in
            if let jsonString = jsonString {
                UIPasteboard.general.string = jsonString
            }
        }
    }
}

// MARK: - Save Frame Dialog

struct SaveFrameDialog2D: View {
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

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Returns a normalized direction vector with magnitude 1.0
    func normalized() -> CGPoint {
        let length = sqrt(x * x + y * y)
        guard length > 0 else { return CGPoint.zero }
        return CGPoint(x: x / length, y: y / length)
    }
    
    /// Subtracts one point from another to create a direction vector
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    /// Multiplies a point by a scalar
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    /// Multiplies a scalar by a point
    static func * (lhs: CGFloat, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs * rhs.x, y: lhs * rhs.y)
    }
    
    /// Adds two points together
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
