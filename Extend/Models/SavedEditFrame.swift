import Foundation

/// Represents an object placed in the editor
struct EditorObject: Codable, Identifiable {
    let id: UUID
    let assetName: String  // "Apple", "Dumbbell", etc.
    var position: CGPoint
    var rotation: CGFloat  // in radians
    var scaleX: CGFloat
    var scaleY: CGFloat
    
    enum CodingKeys: String, CodingKey {
        case id
        case assetName = "imageName"  // JSON uses "imageName", property is "assetName"
        case position
        case rotation
        case scale  // JSON uses "scale" for both scaleX and scaleY
    }
    
    enum PositionKeys: String, CodingKey {
        case x, y
    }
    
    init(assetName: String, position: CGPoint, rotation: CGFloat = 0, scaleX: CGFloat = 1.0, scaleY: CGFloat = 1.0) {
        self.id = UUID()
        self.assetName = assetName
        self.position = position
        self.rotation = rotation
        self.scaleX = scaleX
        self.scaleY = scaleY
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        assetName = try container.decode(String.self, forKey: .assetName)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        
        // Decode position as a dictionary with x and y
        let posContainer = try container.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        let x = try posContainer.decode(CGFloat.self, forKey: .x)
        let y = try posContainer.decode(CGFloat.self, forKey: .y)
        position = CGPoint(x: x, y: y)
        
        // JSON stores scale as a single value, use it for both scaleX and scaleY
        let scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1.0
        scaleX = scale
        scaleY = scale
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(assetName, forKey: .assetName)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(scaleX, forKey: .scale)
        
        // Encode position as a nested dictionary with x and y
        var posContainer = container.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        try posContainer.encode(position.x, forKey: .x)
        try posContainer.encode(position.y, forKey: .y)
    }
}

/// Represents a frame saved in the gameplay editor
struct SavedEditFrame: Codable, Identifiable {
    var id: UUID
    var name: String
    var frameNumber: Int = 0  // Frame number for animation playback
    let timestamp: Date
    let figureScale: CGFloat
    let fusiformUpperTorso: CGFloat
    let fusiformLowerTorso: CGFloat
    let fusiformUpperArms: CGFloat
    let fusiformLowerArms: CGFloat
    let fusiformUpperLegs: CGFloat
    let fusiformLowerLegs: CGFloat
    let fusiformShoulders: CGFloat
    let peakPositionUpperArms: CGFloat
    let peakPositionLowerArms: CGFloat
    let peakPositionUpperLegs: CGFloat
    let peakPositionLowerLegs: CGFloat
    let peakPositionUpperTorso: CGFloat
    let peakPositionLowerTorso: CGFloat
    let positionX: CGFloat
    let positionY: CGFloat
    let shoulderWidthMultiplier: CGFloat
    let waistWidthMultiplier: CGFloat
    let waistThicknessMultiplier: CGFloat
    let skeletonSizeTorso: CGFloat
    let skeletonSizeArm: CGFloat
    let skeletonSizeLeg: CGFloat
    let jointShapeSize: CGFloat
    let neckLength: CGFloat
    let neckWidth: CGFloat
    let handSize: CGFloat
    let footSize: CGFloat
    
    // Stroke thickness properties for each body part
    let strokeThicknessJoints: CGFloat
    let strokeThicknessLowerArms: CGFloat
    let strokeThicknessLowerLegs: CGFloat
    let strokeThicknessLowerTorso: CGFloat
    let strokeThicknessUpperArms: CGFloat
    let strokeThicknessUpperLegs: CGFloat
    let strokeThicknessUpperTorso: CGFloat
    let strokeThicknessFullTorso: CGFloat
    
    // Pose data (angles) - stored as simple properties
    let waistTorsoAngle: CGFloat
    let midTorsoAngle: CGFloat
    let torsoRotationAngle: CGFloat
    let headAngle: CGFloat
    let leftShoulderAngle: CGFloat
    let rightShoulderAngle: CGFloat
    let leftElbowAngle: CGFloat
    let rightElbowAngle: CGFloat
    let leftHandAngle: CGFloat
    let rightHandAngle: CGFloat
    let leftHipAngle: CGFloat
    let rightHipAngle: CGFloat
    let leftKneeAngle: CGFloat
    let rightKneeAngle: CGFloat
    let leftFootAngle: CGFloat
    let rightFootAngle: CGFloat
    let midTorsoYOffset: CGFloat  // Y-axis offset for upper torso bottom pin position
    
    // Objects in the frame
    var objects: [EditorObject] = []
    
    /// Initialize from EditModeValues with optional pose data
    init(name: String, frameNumber: Int = 0, from values: EditModeValues, pose: StickFigure2D? = nil, objects: [EditorObject] = []) {
        self.init(id: UUID(), name: name, frameNumber: frameNumber, from: values, pose: pose, objects: objects)
    }
    
    /// Initialize from EditModeValues with optional pose data and custom id
    init(id: UUID, name: String, frameNumber: Int = 0, from values: EditModeValues, pose: StickFigure2D? = nil, objects: [EditorObject] = []) {
        self.id = id
        self.name = name
        self.frameNumber = frameNumber
        self.timestamp = Date()
        self.figureScale = values.figureScale
        self.fusiformUpperTorso = values.fusiformUpperTorso
        self.fusiformLowerTorso = values.fusiformLowerTorso
        self.fusiformUpperArms = values.fusiformUpperArms
        self.fusiformLowerArms = values.fusiformLowerArms
        self.fusiformUpperLegs = values.fusiformUpperLegs
        self.fusiformLowerLegs = values.fusiformLowerLegs
        self.positionX = values.positionX
        self.positionY = values.positionY
        
        // Save structure/layout multipliers from pose
        if let pose = pose {
            self.shoulderWidthMultiplier = pose.shoulderWidthMultiplier
            self.waistWidthMultiplier = pose.waistWidthMultiplier
            self.waistThicknessMultiplier = pose.waistThicknessMultiplier
            self.skeletonSizeTorso = pose.skeletonSizeTorso
            self.skeletonSizeArm = pose.skeletonSizeArm
            self.skeletonSizeLeg = pose.skeletonSizeLeg
            self.jointShapeSize = 1.0  // Editor-only property, not part of pose
            self.neckLength = pose.neckLength
            self.neckWidth = pose.neckWidth
            self.handSize = pose.handSize
            self.footSize = pose.footSize
            // Set peak positions from pose
            self.fusiformShoulders = pose.fusiformShoulders
            self.peakPositionUpperArms = pose.peakPositionUpperArms
            self.peakPositionLowerArms = pose.peakPositionLowerArms
            self.peakPositionUpperLegs = pose.peakPositionUpperLegs
            self.peakPositionLowerLegs = pose.peakPositionLowerLegs
            self.peakPositionUpperTorso = pose.peakPositionUpperTorso
            self.peakPositionLowerTorso = pose.peakPositionLowerTorso
        } else {
            self.shoulderWidthMultiplier = 1.0
            self.waistWidthMultiplier = 1.0
            self.waistThicknessMultiplier = 0.5
            self.skeletonSizeTorso = 1.0
            self.skeletonSizeArm = 1.0
            self.skeletonSizeLeg = 1.0
            self.jointShapeSize = 1.0
            self.neckLength = 1.0
            self.neckWidth = 1.0
            self.handSize = 1.0
            self.footSize = 1.0
            // Default peak positions
            self.fusiformShoulders = 0.0
            self.peakPositionUpperArms = 0.5
            self.peakPositionLowerArms = 0.35
            self.peakPositionUpperLegs = 0.2
            self.peakPositionLowerLegs = 0.2
            self.peakPositionUpperTorso = 0.5
            self.peakPositionLowerTorso = 0.5
        }
        
        // Store pose angles if provided, otherwise use defaults
        if let pose = pose {
            self.waistTorsoAngle = pose.waistTorsoAngle
            self.midTorsoAngle = pose.midTorsoAngle
            self.torsoRotationAngle = pose.torsoRotationAngle
            self.headAngle = pose.headAngle
            self.leftShoulderAngle = pose.leftShoulderAngle
            self.rightShoulderAngle = pose.rightShoulderAngle
            self.leftElbowAngle = pose.leftElbowAngle
            self.rightElbowAngle = pose.rightElbowAngle
            self.leftHandAngle = pose.leftHandAngle
            self.rightHandAngle = pose.rightHandAngle
            self.leftHipAngle = pose.leftHipAngle
            self.rightHipAngle = pose.rightHipAngle
            self.leftKneeAngle = pose.leftKneeAngle
            self.rightKneeAngle = pose.rightKneeAngle
            self.leftFootAngle = pose.leftFootAngle
            self.rightFootAngle = pose.rightFootAngle
            self.midTorsoYOffset = pose.midTorsoYOffset
        } else {
            // Default angles (standing position)
            self.waistTorsoAngle = 0
            self.midTorsoAngle = 0
            self.torsoRotationAngle = 0
            self.headAngle = 0
            self.leftShoulderAngle = 0
            self.rightShoulderAngle = 0
            self.leftElbowAngle = 45
            self.rightElbowAngle = 45
            self.leftHandAngle = -45
            self.rightHandAngle = -45
            self.leftHipAngle = 0
            self.rightHipAngle = 0
            self.leftKneeAngle = 0
            self.rightKneeAngle = 0
            self.leftFootAngle = 0
            self.rightFootAngle = 0
            self.midTorsoYOffset = 0.0
        }
        
        // Store stroke thickness properties from pose
        if let pose = pose {
            self.strokeThicknessJoints = pose.strokeThicknessJoints
            self.strokeThicknessLowerArms = pose.strokeThicknessLowerArms
            self.strokeThicknessLowerLegs = pose.strokeThicknessLowerLegs
            self.strokeThicknessLowerTorso = pose.strokeThicknessLowerTorso
            self.strokeThicknessUpperArms = pose.strokeThicknessUpperArms
            self.strokeThicknessUpperLegs = pose.strokeThicknessUpperLegs
            self.strokeThicknessUpperTorso = pose.strokeThicknessUpperTorso
            self.strokeThicknessFullTorso = pose.strokeThicknessFullTorso
        } else {
            // Use defaults that match the Stand frame
            self.strokeThicknessJoints = 2.5
            self.strokeThicknessLowerArms = 3.5
            self.strokeThicknessLowerLegs = 3.5
            self.strokeThicknessLowerTorso = 4.5
            self.strokeThicknessUpperArms = 4.0
            self.strokeThicknessUpperLegs = 4.5
            self.strokeThicknessUpperTorso = 5.0
            self.strokeThicknessFullTorso = 1.0
        }
        
        // Store objects
        self.objects = objects
    }
    
    // MARK: - Codable Support for Backward Compatibility
    
    enum CodingKeys: String, CodingKey {
        case id, name, frameNumber, createdAt, objects, pose
        case figureScale
        case fusiformUpperTorso, fusiformLowerTorso, fusiformUpperArms, fusiformLowerArms
        case fusiformUpperLegs, fusiformLowerLegs, fusiformShoulders
        case peakPositionUpperArms, peakPositionLowerArms, peakPositionUpperLegs
        case peakPositionLowerLegs, peakPositionUpperTorso, peakPositionLowerTorso
        case figureOffsetX, figureOffsetY, waistPositionX, waistPositionY
        case shoulderWidthMultiplier, waistWidthMultiplier
        case waistThicknessMultiplier, skeletonSizeTorso, skeletonSizeArm, skeletonSizeLeg, jointShapeSize, neckLength, neckWidth
        case handSize, footSize, waistTorsoAngle, midTorsoAngle, torsoRotationAngle, headAngle
        case leftShoulderAngle, rightShoulderAngle, leftElbowAngle, rightElbowAngle
        case leftHandAngle, rightHandAngle, leftHipAngle, rightHipAngle
        case leftKneeAngle, rightKneeAngle, leftFootAngle, rightFootAngle, midTorsoYOffset
        case strokeThicknessJoints, strokeThicknessLowerArms, strokeThicknessLowerLegs
        case strokeThicknessLowerTorso, strokeThicknessUpperArms, strokeThicknessUpperLegs, strokeThicknessUpperTorso, strokeThicknessFullTorso
        case headRadiusMultiplier, shoulderWidthMultiplier_
        case footColor, handColor, headColor, torsoColor, leftArmColor, rightArmColor
        case leftLegColor, rightLegColor, leftUpperArmColor, leftLowerArmColor
        case rightUpperArmColor, rightLowerArmColor, leftUpperLegColor, leftLowerLegColor
        case rightUpperLegColor, rightLowerLegColor, jointColor, scale
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode top-level id, name, frameNumber first
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        frameNumber = try container.decodeIfPresent(Int.self, forKey: .frameNumber) ?? 0
        
        // Handle timestamp - try both createdAt (from JSON) and timestamp (for compatibility)
        let createdAt = try container.decodeIfPresent(Double.self, forKey: .createdAt) ?? Date().timeIntervalSince1970
        timestamp = Date(timeIntervalSince1970: createdAt)
        
        // Now decode from the "pose" container (nested in JSON)
        let poseContainer: KeyedDecodingContainer<CodingKeys>
        if container.contains(.pose) {
            poseContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .pose)
        } else {
            // Fallback to root container if no pose object exists
            poseContainer = container
        }
        
        // Decode all CGFloat properties from pose container
        figureScale = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .figureScale) ?? 1.0
        fusiformUpperTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformUpperTorso) ?? 0.0
        fusiformLowerTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerTorso) ?? 0.0
        fusiformUpperArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformUpperArms) ?? 0.0
        fusiformLowerArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerArms) ?? 0.0
        fusiformUpperLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformUpperLegs) ?? 0.0
        fusiformLowerLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerLegs) ?? 0.0
        fusiformShoulders = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformShoulders) ?? 0.0
        peakPositionUpperArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionUpperArms) ?? 0.0
        peakPositionLowerArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerArms) ?? 0.0
        peakPositionUpperLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionUpperLegs) ?? 0.0
        peakPositionLowerLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerLegs) ?? 0.0
        peakPositionUpperTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionUpperTorso) ?? 0.0
        peakPositionLowerTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerTorso) ?? 0.0
        positionX = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .figureOffsetX) ?? 0.0
        positionY = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .figureOffsetY) ?? 0.0
        shoulderWidthMultiplier = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .shoulderWidthMultiplier) ?? 0.5
        waistWidthMultiplier = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .waistWidthMultiplier) ?? 0.5
        waistThicknessMultiplier = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .waistThicknessMultiplier) ?? 0.5
        skeletonSizeTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .skeletonSizeTorso) ?? 1.0
        skeletonSizeArm = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .skeletonSizeArm) ?? 1.0
        skeletonSizeLeg = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .skeletonSizeLeg) ?? 1.0
        jointShapeSize = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .jointShapeSize) ?? 1.0
        neckLength = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .neckLength) ?? 20.0
        neckWidth = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .neckWidth) ?? 8.0
        handSize = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .handSize) ?? 1.0
        footSize = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .footSize) ?? 1.0
        
        // Decode angles from pose container
        waistTorsoAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .waistTorsoAngle) ?? 0.0
        midTorsoAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .midTorsoAngle) ?? 0.0
        torsoRotationAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .torsoRotationAngle) ?? 0.0
        headAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .headAngle) ?? 0.0
        leftShoulderAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftShoulderAngle) ?? 0.0
        rightShoulderAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightShoulderAngle) ?? 0.0
        leftElbowAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftElbowAngle) ?? 0.0
        rightElbowAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightElbowAngle) ?? 0.0
        leftHandAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftHandAngle) ?? 0.0
        rightHandAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightHandAngle) ?? 0.0
        leftHipAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftHipAngle) ?? 0.0
        rightHipAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightHipAngle) ?? 0.0
        leftKneeAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftKneeAngle) ?? 0.0
        rightKneeAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightKneeAngle) ?? 0.0
        leftFootAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftFootAngle) ?? 0.0
        rightFootAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightFootAngle) ?? 0.0
        midTorsoYOffset = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .midTorsoYOffset) ?? 0.0
        
        // Decode stroke thickness properties from pose container - optional for backward compatibility
        strokeThicknessJoints = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessJoints) ?? 2.5
        strokeThicknessLowerArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerArms) ?? 3.5
        strokeThicknessLowerLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerLegs) ?? 3.5
        strokeThicknessLowerTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerTorso) ?? 4.5
        strokeThicknessUpperArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperArms) ?? 4.0
        strokeThicknessUpperLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperLegs) ?? 4.5
        strokeThicknessUpperTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperTorso) ?? 5.0
        strokeThicknessFullTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessFullTorso) ?? 1.0
        
        // Decode objects - optional for backward compatibility with old saved frames
        objects = try container.decodeIfPresent([EditorObject].self, forKey: .objects) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode top-level properties
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(frameNumber, forKey: .frameNumber)
        try container.encode(timestamp.timeIntervalSince1970, forKey: .createdAt)
        
        // Encode objects
        try container.encode(objects, forKey: .objects)
        
        // Create nested pose container for all pose data
        var poseContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .pose)
        
        // Encode all properties into pose container
        try poseContainer.encode(figureScale, forKey: .figureScale)
        try poseContainer.encode(fusiformUpperTorso, forKey: .fusiformUpperTorso)
        try poseContainer.encode(fusiformLowerTorso, forKey: .fusiformLowerTorso)
        try poseContainer.encode(fusiformUpperArms, forKey: .fusiformUpperArms)
        try poseContainer.encode(fusiformLowerArms, forKey: .fusiformLowerArms)
        try poseContainer.encode(fusiformUpperLegs, forKey: .fusiformUpperLegs)
        try poseContainer.encode(fusiformLowerLegs, forKey: .fusiformLowerLegs)
        try poseContainer.encode(fusiformShoulders, forKey: .fusiformShoulders)
        try poseContainer.encode(peakPositionUpperArms, forKey: .peakPositionUpperArms)
        try poseContainer.encode(peakPositionLowerArms, forKey: .peakPositionLowerArms)
        try poseContainer.encode(peakPositionUpperLegs, forKey: .peakPositionUpperLegs)
        try poseContainer.encode(peakPositionLowerLegs, forKey: .peakPositionLowerLegs)
        try poseContainer.encode(peakPositionUpperTorso, forKey: .peakPositionUpperTorso)
        try poseContainer.encode(peakPositionLowerTorso, forKey: .peakPositionLowerTorso)
        try poseContainer.encode(positionX, forKey: .figureOffsetX)
        try poseContainer.encode(positionY, forKey: .figureOffsetY)
        try poseContainer.encode(shoulderWidthMultiplier, forKey: .shoulderWidthMultiplier)
        try poseContainer.encode(waistWidthMultiplier, forKey: .waistWidthMultiplier)
        try poseContainer.encode(waistThicknessMultiplier, forKey: .waistThicknessMultiplier)
        try poseContainer.encode(skeletonSizeTorso, forKey: .skeletonSizeTorso)
        try poseContainer.encode(skeletonSizeArm, forKey: .skeletonSizeArm)
        try poseContainer.encode(skeletonSizeLeg, forKey: .skeletonSizeLeg)
        try poseContainer.encode(jointShapeSize, forKey: .jointShapeSize)
        try poseContainer.encode(neckLength, forKey: .neckLength)
        try poseContainer.encode(neckWidth, forKey: .neckWidth)
        try poseContainer.encode(handSize, forKey: .handSize)
        try poseContainer.encode(footSize, forKey: .footSize)
        try poseContainer.encode(waistTorsoAngle, forKey: .waistTorsoAngle)
        try poseContainer.encode(midTorsoAngle, forKey: .midTorsoAngle)
        try poseContainer.encode(torsoRotationAngle, forKey: .torsoRotationAngle)
        try poseContainer.encode(headAngle, forKey: .headAngle)
        try poseContainer.encode(leftShoulderAngle, forKey: .leftShoulderAngle)
        try poseContainer.encode(rightShoulderAngle, forKey: .rightShoulderAngle)
        try poseContainer.encode(leftElbowAngle, forKey: .leftElbowAngle)
        try poseContainer.encode(rightElbowAngle, forKey: .rightElbowAngle)
        try poseContainer.encode(leftHandAngle, forKey: .leftHandAngle)
        try poseContainer.encode(rightHandAngle, forKey: .rightHandAngle)
        try poseContainer.encode(leftHipAngle, forKey: .leftHipAngle)
        try poseContainer.encode(rightHipAngle, forKey: .rightHipAngle)
        try poseContainer.encode(leftKneeAngle, forKey: .leftKneeAngle)
        try poseContainer.encode(rightKneeAngle, forKey: .rightKneeAngle)
        try poseContainer.encode(leftFootAngle, forKey: .leftFootAngle)
        try poseContainer.encode(rightFootAngle, forKey: .rightFootAngle)
        try poseContainer.encode(midTorsoYOffset, forKey: .midTorsoYOffset)
        try poseContainer.encode(strokeThicknessJoints, forKey: .strokeThicknessJoints)
        try poseContainer.encode(strokeThicknessLowerArms, forKey: .strokeThicknessLowerArms)
        try poseContainer.encode(strokeThicknessLowerLegs, forKey: .strokeThicknessLowerLegs)
        try poseContainer.encode(strokeThicknessLowerTorso, forKey: .strokeThicknessLowerTorso)
        try poseContainer.encode(strokeThicknessUpperArms, forKey: .strokeThicknessUpperArms)
        try poseContainer.encode(strokeThicknessUpperLegs, forKey: .strokeThicknessUpperLegs)
        try poseContainer.encode(strokeThicknessUpperTorso, forKey: .strokeThicknessUpperTorso)
        try poseContainer.encode(strokeThicknessFullTorso, forKey: .strokeThicknessFullTorso)
    }
}

/// Manager for saved frames in UserDefaults
class SavedFramesManager {
    static let shared = SavedFramesManager()
    private let userDefaultsKey = "savedEditFrames"
    
    /// Save a new frame
    func saveFrame(_ frame: SavedEditFrame) {
        var frames = getAllFrames()
        frames.append(frame)
        saveAll(frames)
        print("✅ Frame saved: \(frame.name)")
    }
    
    /// Get all saved frames
    func getAllFrames() -> [SavedEditFrame] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let frames = try? JSONDecoder().decode([SavedEditFrame].self, from: data) else {
            return []
        }
        return frames.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get a specific frame by ID
    func getFrame(id: UUID) -> SavedEditFrame? {
        getAllFrames().first { $0.id == id }
    }
    
    /// Delete a frame
    func deleteFrame(id: UUID) {
        let frames = getAllFrames().filter { $0.id != id }
        saveAll(frames)
        print("✅ Frame deleted")
    }
    
    /// Rename a frame
    func renameFrame(id: UUID, newName: String) {
        var frames = getAllFrames()
        if let index = frames.firstIndex(where: { $0.id == id }) {
            frames[index].name = newName
            saveAll(frames)
            print("✅ Frame renamed to: \(newName)")
        }
    }
    
    /// Export frame as JSON string
    /// Export frame as JSON string (by ID - for backwards compatibility)
    func exportFrameAsJSON(id: UUID) -> String? {
        guard let frame = getFrame(id: id) else {
            print("❌ exportFrameAsJSON: Could not find frame with id \(id)")
            return nil
        }
        return exportFrameAsJSON(frame: frame)
    }
    
    /// Export frame as JSON string (direct frame object)
    func exportFrameAsJSON(frame: SavedEditFrame) -> String? {
        print("✅ exportFrameAsJSON: Exporting frame '\(frame.name)'")
        
        // Helper to format number with specific decimal places
        func formatNumber(_ value: Double, decimals: Int) -> String {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = decimals
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false  // Disable thousands separators
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        
        // Helper to round and format
        func roundAndFormat(_ value: CGFloat, decimals: Int) -> String {
            let divisor = pow(10.0, Double(decimals))
            let rounded = (Double(value) * divisor).rounded() / divisor
            return formatNumber(rounded, decimals: decimals)
        }
        
        // Helper to round to N decimal places (converts CGFloat to Double)
        func roundValue(_ value: CGFloat, decimals: Int) -> Double {
            let divisor = pow(10.0, Double(decimals))
            let rounded = (Double(value) * divisor).rounded() / divisor
            return rounded
        }
        
        // Build JSON string manually to ensure proper formatting
        var jsonString = "[\n"
        jsonString += "  {\n"
        jsonString += "    \"createdAt\" : \(formatNumber(frame.timestamp.timeIntervalSince1970, decimals: 4)),\n"
        jsonString += "    \"frameNumber\" : \(frame.frameNumber),\n"
        jsonString += "    \"id\" : \"\(frame.id.uuidString)\",\n"
        jsonString += "    \"name\" : \"\(frame.name)\",\n"
        
        // Build objects array
        jsonString += "    \"objects\" : [\n"
        for (index, object) in frame.objects.enumerated() {
            jsonString += "      {\n"
            jsonString += "        \"id\" : \"\(object.id.uuidString)\",\n"
            jsonString += "        \"imageName\" : \"\(object.assetName)\",\n"
            jsonString += "        \"position\" : {\n"
            jsonString += "          \"x\" : \(roundAndFormat(object.position.x, decimals: 1)),\n"
            jsonString += "          \"y\" : \(roundAndFormat(object.position.y, decimals: 1))\n"
            jsonString += "        },\n"
            jsonString += "        \"rotation\" : \(roundAndFormat(object.rotation, decimals: 4)),\n"
            jsonString += "        \"scale\" : \(roundAndFormat(object.scaleX, decimals: 4))\n"
            jsonString += "      }"
            if index < frame.objects.count - 1 {
                jsonString += ","
            }
            jsonString += "\n"
        }
        jsonString += "    ],\n"
        jsonString += "    \"pose\" : {\n"
        
        // Build pose dictionary - sort alphabetically
        let poseEntries: [(String, String)] = [
            ("figureOffsetX", roundAndFormat(frame.positionX, decimals: 1)),
            ("figureOffsetY", roundAndFormat(frame.positionY, decimals: 1)),
            ("figureScale", roundAndFormat(frame.figureScale, decimals: 1)),
            ("footColor", "\"#000000\""),
            ("footSize", roundAndFormat(frame.footSize, decimals: 1)),
            ("fusiformLowerArms", roundAndFormat(frame.fusiformLowerArms, decimals: 2)),
            ("fusiformLowerLegs", roundAndFormat(frame.fusiformLowerLegs, decimals: 2)),
            ("fusiformLowerTorso", roundAndFormat(frame.fusiformLowerTorso, decimals: 2)),
            ("fusiformShoulders", roundAndFormat(frame.fusiformShoulders, decimals: 2)),
            ("fusiformUpperArms", roundAndFormat(frame.fusiformUpperArms, decimals: 2)),
            ("fusiformUpperLegs", roundAndFormat(frame.fusiformUpperLegs, decimals: 2)),
            ("fusiformUpperTorso", roundAndFormat(frame.fusiformUpperTorso, decimals: 2)),
            ("handColor", "\"#000000\""),
            ("handSize", roundAndFormat(frame.handSize, decimals: 1)),
            ("headAngle", "\(Int(frame.headAngle))"),
            ("headColor", "\"#000000\""),
            ("headRadiusMultiplier", "1"),
            ("jointColor", "\"#000000\""),
            ("jointShapeSize", roundAndFormat(frame.jointShapeSize, decimals: 1)),
            ("leftArmColor", "\"#000000\""),
            ("leftElbowAngle", "\(Int(frame.leftElbowAngle))"),
            ("leftFootAngle", "\(Int(frame.leftFootAngle))"),
            ("leftHandAngle", "\(Int(frame.leftHandAngle))"),
            ("leftHipAngle", "\(Int(frame.leftHipAngle))"),
            ("leftKneeAngle", "\(Int(frame.leftKneeAngle))"),
            ("leftLegColor", "\"#000000\""),
            ("leftLowerArmColor", "\"#000000\""),
            ("leftLowerLegColor", "\"#000000\""),
            ("leftShoulderAngle", "\(Int(frame.leftShoulderAngle))"),
            ("leftUpperArmColor", "\"#000000\""),
            ("leftUpperLegColor", "\"#000000\""),
            ("midTorsoAngle", "\(Int(frame.midTorsoAngle))"),
            ("neckLength", roundAndFormat(frame.neckLength, decimals: 1)),
            ("neckWidth", roundAndFormat(frame.neckWidth, decimals: 1)),
            ("peakPositionLowerArms", roundAndFormat(frame.peakPositionLowerArms, decimals: 2)),
            ("peakPositionLowerLegs", roundAndFormat(frame.peakPositionLowerLegs, decimals: 2)),
            ("peakPositionLowerTorso", roundAndFormat(frame.peakPositionLowerTorso, decimals: 2)),
            ("peakPositionUpperArms", roundAndFormat(frame.peakPositionUpperArms, decimals: 2)),
            ("peakPositionUpperLegs", roundAndFormat(frame.peakPositionUpperLegs, decimals: 2)),
            ("peakPositionUpperTorso", roundAndFormat(frame.peakPositionUpperTorso, decimals: 2)),
            ("rightArmColor", "\"#000000\""),
            ("rightElbowAngle", "\(Int(frame.rightElbowAngle))"),
            ("rightFootAngle", "\(Int(frame.rightFootAngle))"),
            ("rightHandAngle", "\(Int(frame.rightHandAngle))"),
            ("rightHipAngle", "\(Int(frame.rightHipAngle))"),
            ("rightKneeAngle", "\(Int(frame.rightKneeAngle))"),
            ("rightLegColor", "\"#000000\""),
            ("rightLowerArmColor", "\"#000000\""),
            ("rightLowerLegColor", "\"#000000\""),
            ("rightShoulderAngle", "\(Int(frame.rightShoulderAngle))"),
            ("rightUpperArmColor", "\"#000000\""),
            ("rightUpperLegColor", "\"#000000\""),
            ("scale", roundAndFormat(frame.figureScale, decimals: 1)),
            ("shoulderWidthMultiplier", roundAndFormat(frame.shoulderWidthMultiplier, decimals: 2)),
            ("skeletonSizeArm", roundAndFormat(frame.skeletonSizeArm, decimals: 2)),
            ("skeletonSizeLeg", roundAndFormat(frame.skeletonSizeLeg, decimals: 2)),
            ("skeletonSizeTorso", roundAndFormat(frame.skeletonSizeTorso, decimals: 2)),
            ("strokeThicknessFullTorso", roundAndFormat(frame.strokeThicknessFullTorso, decimals: 1)),
            ("strokeThicknessJoints", roundAndFormat(frame.strokeThicknessJoints, decimals: 1)),
            ("strokeThicknessLowerArms", roundAndFormat(frame.strokeThicknessLowerArms, decimals: 1)),
            ("strokeThicknessLowerLegs", roundAndFormat(frame.strokeThicknessLowerLegs, decimals: 1)),
            ("strokeThicknessLowerTorso", roundAndFormat(frame.strokeThicknessLowerTorso, decimals: 1)),
            ("strokeThicknessUpperArms", roundAndFormat(frame.strokeThicknessUpperArms, decimals: 1)),
            ("strokeThicknessUpperLegs", roundAndFormat(frame.strokeThicknessUpperLegs, decimals: 1)),
            ("strokeThicknessUpperTorso", roundAndFormat(frame.strokeThicknessUpperTorso, decimals: 1)),
            ("torsoColor", "\"#000000\""),
            ("torsoRotationAngle", "\(Int(frame.torsoRotationAngle))"),
            ("waistPositionX", "300"),
            ("waistPositionY", "360"),
            ("waistThicknessMultiplier", roundAndFormat(frame.waistThicknessMultiplier, decimals: 1)),
            ("waistTorsoAngle", "\(Int(frame.waistTorsoAngle))"),
            ("waistWidthMultiplier", roundAndFormat(frame.waistWidthMultiplier, decimals: 2))
        ]
        
        // Add pose entries
        for (index, (key, value)) in poseEntries.enumerated() {
            jsonString += "      \"\(key)\" : \(value)"
            if index < poseEntries.count - 1 {
                jsonString += ","
            }
            jsonString += "\n"
        }
        
        jsonString += "    }\n"
        jsonString += "  }\n"
        jsonString += "]\n"
        
        return jsonString
    }
    
    /// Save all frames to UserDefaults
    private func saveAll(_ frames: [SavedEditFrame]) {
        if let data = try? JSONEncoder().encode(frames) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    /// Sync frames from Bundle (animations.json) to UserDefaults
    /// This is a safe operation that replaces local storage with bundle versions
    func syncFromBundle() -> (success: Bool, message: String) {
        let bundleFrames = AnimationStorage.shared.loadFrames()
        
        guard !bundleFrames.isEmpty else {
            return (false, "No frames found in animations.json")
        }
        
        // Convert AnimationFrames to SavedEditFrames
        var savedFrames: [SavedEditFrame] = []
        
        for animFrame in bundleFrames {
            let pose = animFrame.pose.toStickFigure2D()
            let editValues = EditModeValues(
                figureScale: pose.scale,
                fusiformUpperTorso: pose.fusiformUpperTorso,
                fusiformLowerTorso: pose.fusiformLowerTorso,
                fusiformUpperArms: pose.fusiformUpperArms,
                fusiformLowerArms: pose.fusiformLowerArms,
                fusiformUpperLegs: pose.fusiformUpperLegs,
                fusiformLowerLegs: pose.fusiformLowerLegs,
                showGrid: true,
                showJoints: true,
                positionX: 0,
                positionY: 0
            )
            
            let editorObjects = animFrame.objects.map { animObj in
                EditorObject(
                    assetName: animObj.imageName,
                    position: animObj.position,
                    rotation: animObj.rotation,
                    scaleX: animObj.scale,
                    scaleY: animObj.scale
                )
            }
            
            let savedFrame = SavedEditFrame(
                id: animFrame.id,
                name: animFrame.name,
                frameNumber: animFrame.frameNumber,
                from: editValues,
                pose: pose,
                objects: editorObjects
            )
            savedFrames.append(savedFrame)
        }
        
        // Save to UserDefaults
        saveAll(savedFrames)
        
        let message = "✅ Synced \(savedFrames.count) frame(s) from Bundle"
        print(message)
        return (true, message)
    }
    
    /// Clear all saved frames (for testing)
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("⚠️ All saved frames cleared")
    }
}
