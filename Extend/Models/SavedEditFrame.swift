import Foundation

/// Represents an object placed in the editor
struct EditorObject: Codable, Identifiable {
    let id: UUID
    let assetName: String  // "Apple", "Dumbbell", etc.
    var position: CGPoint
    var rotation: CGFloat  // in radians
    var scaleX: CGFloat
    var scaleY: CGFloat
    var baseWidth: CGFloat?
    var baseHeight: CGFloat?
    /// Width of the editor SpriteKit scene at save time — used for coordinate conversion in gameplay.
    var editorSceneWidth: CGFloat = 390

    enum CodingKeys: String, CodingKey {
        case id
        case assetName = "imageName"
        case position
        case rotation
        case scale
        case baseWidth
        case baseHeight
        case editorSceneWidth
    }
    
    enum PositionKeys: String, CodingKey {
        case x, y
    }
    
    init(assetName: String, position: CGPoint, rotation: CGFloat = 0, scaleX: CGFloat = 1.0, scaleY: CGFloat = 1.0, baseWidth: CGFloat? = nil, baseHeight: CGFloat? = nil, editorSceneWidth: CGFloat = 390) {
        self.id = UUID()
        self.assetName = assetName
        self.position = position
        self.rotation = rotation
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.baseWidth = baseWidth
        self.baseHeight = baseHeight
        self.editorSceneWidth = editorSceneWidth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        assetName = try container.decode(String.self, forKey: .assetName)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0

        let posContainer = try container.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        let x = try posContainer.decode(CGFloat.self, forKey: .x)
        let y = try posContainer.decode(CGFloat.self, forKey: .y)
        position = CGPoint(x: x, y: y)

        let scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1.0
        scaleX = scale
        scaleY = scale

        baseWidth = try container.decodeIfPresent(CGFloat.self, forKey: .baseWidth)
        baseHeight = try container.decodeIfPresent(CGFloat.self, forKey: .baseHeight)
        editorSceneWidth = try container.decodeIfPresent(CGFloat.self, forKey: .editorSceneWidth) ?? 390
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(assetName, forKey: .assetName)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(scaleX, forKey: .scale)
        try container.encode(editorSceneWidth, forKey: .editorSceneWidth)

        var posContainer = container.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        try posContainer.encode(position.x, forKey: .x)
        try posContainer.encode(position.y, forKey: .y)

        if let baseWidth = baseWidth { try container.encode(baseWidth, forKey: .baseWidth) }
        if let baseHeight = baseHeight { try container.encode(baseHeight, forKey: .baseHeight) }
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
    let fusiformBicep: CGFloat
    let fusiformTricep: CGFloat
    let fusiformLowerArms: CGFloat
    let fusiformUpperLegs: CGFloat
    let fusiformLowerLegs: CGFloat
    let fusiformShoulders: CGFloat
    let fusiformDeltoids: CGFloat
    let peakPositionBicep: CGFloat
    let peakPositionTricep: CGFloat
    let peakPositionLowerArms: CGFloat
    let peakPositionUpperLegs: CGFloat
    let peakPositionLowerLegs: CGFloat
    let peakPositionUpperTorso: CGFloat
    let peakPositionLowerTorso: CGFloat
    let peakPositionDeltoids: CGFloat
    let fusiformFullTorso: CGFloat
    let peakPositionFullTorsoTop: CGFloat
    let peakPositionFullTorsoMiddle: CGFloat
    let peakPositionFullTorsoBottom: CGFloat
    let armMuscleSide: String  // "normal", "flipped", or "both"
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
    let strokeThickness: CGFloat  // Torso width (V2 renderer)
    let strokeThicknessJoints: CGFloat
    let strokeThicknessLowerArms: CGFloat
    let strokeThicknessLowerLegs: CGFloat
    let strokeThicknessLowerTorso: CGFloat
    let strokeThicknessBicep: CGFloat
    let strokeThicknessTricep: CGFloat
    let strokeThicknessUpperLegs: CGFloat
    let strokeThicknessUpperTorso: CGFloat
    let strokeThicknessFullTorso: CGFloat
    let strokeThicknessDeltoids: CGFloat
    let strokeThicknessTrapezius: CGFloat
    
    // Pose data (angles) - stored as simple properties
    let waistTorsoAngle: CGFloat
    let midTorsoAngle: CGFloat
    let torsoRotationAngle: CGFloat
    let headAngle: CGFloat
    let leftShoulderAngle: CGFloat
    let rightShoulderAngle: CGFloat
    let leftElbowAngle: CGFloat
    let rightElbowAngle: CGFloat
    let leftHipAngle: CGFloat
    let rightHipAngle: CGFloat
    let leftKneeAngle: CGFloat
    let rightKneeAngle: CGFloat
    let leftFootAngle: CGFloat
    let rightFootAngle: CGFloat
    
    // Objects in the frame
    var objects: [EditorObject] = []
    
    /// Initialize from EditModeValues with optional pose data
    init(name: String, frameNumber: Int = 0, from values: EditModeValues, pose: StickFigure2D? = nil, objects: [EditorObject] = []) {
        self.init(id: UUID(), name: name, frameNumber: frameNumber, from: values, pose: pose, objects: objects, timestamp: Date())
    }
    
    /// Initialize from EditModeValues with optional pose data and custom id
    init(id: UUID, name: String, frameNumber: Int = 0, from values: EditModeValues, pose: StickFigure2D? = nil, objects: [EditorObject] = [], timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.frameNumber = frameNumber
        self.timestamp = timestamp
        self.figureScale = values.figureScale
        self.fusiformUpperTorso = values.fusiformUpperTorso
        self.fusiformLowerTorso = values.fusiformLowerTorso
        self.fusiformBicep = values.fusiformBicep
        self.fusiformTricep = values.fusiformTricep
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
            self.fusiformDeltoids = pose.fusiformDeltoids
            self.peakPositionBicep = pose.peakPositionBicep
            self.peakPositionTricep = pose.peakPositionTricep
            self.peakPositionLowerArms = pose.peakPositionLowerArms
            self.peakPositionUpperLegs = pose.peakPositionUpperLegs
            self.peakPositionLowerLegs = pose.peakPositionLowerLegs
            self.peakPositionUpperTorso = pose.peakPositionUpperTorso
            self.peakPositionLowerTorso = pose.peakPositionLowerTorso
            self.peakPositionDeltoids = pose.peakPositionDeltoids
            self.fusiformFullTorso = pose.fusiformFullTorso
            self.peakPositionFullTorsoTop = pose.peakPositionFullTorsoTop
            self.peakPositionFullTorsoMiddle = pose.peakPositionFullTorsoMiddle
            self.peakPositionFullTorsoBottom = pose.peakPositionFullTorsoBottom
            self.armMuscleSide = pose.armMuscleSide
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
            self.fusiformDeltoids = 0.5
            self.peakPositionBicep = values.peakPositionBicep ?? 0.5
            self.peakPositionTricep = values.peakPositionTricep ?? 0.5
            self.peakPositionLowerArms = values.peakPositionLowerArms ?? 0.35
            self.peakPositionUpperLegs = values.peakPositionUpperLegs ?? 0.2
            self.peakPositionLowerLegs = values.peakPositionLowerLegs ?? 0.2
            self.peakPositionUpperTorso = values.peakPositionUpperTorso ?? 0.5
            self.peakPositionLowerTorso = values.peakPositionLowerTorso ?? 0.5
            self.peakPositionDeltoids = values.peakPositionDeltoids ?? 0.3
            self.fusiformFullTorso = 0.0
            self.peakPositionFullTorsoTop = 0.15
            self.peakPositionFullTorsoMiddle = 0.5
            self.peakPositionFullTorsoBottom = 0.85
            self.armMuscleSide = values.armMuscleSide ?? "normal"
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
            self.leftHipAngle = pose.leftHipAngle
            self.rightHipAngle = pose.rightHipAngle
            self.leftKneeAngle = pose.leftKneeAngle
            self.rightKneeAngle = pose.rightKneeAngle
            self.leftFootAngle = pose.leftFootAngle
            self.rightFootAngle = pose.rightFootAngle
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
            self.leftHipAngle = 0
            self.rightHipAngle = 0
            self.leftKneeAngle = 0
            self.rightKneeAngle = 0
            self.leftFootAngle = 0
            self.rightFootAngle = 0
        }
        
        // Store stroke thickness properties from pose or values
        if let pose = pose {
            self.strokeThickness = pose.strokeThickness
            self.strokeThicknessJoints = pose.strokeThicknessJoints
            self.strokeThicknessLowerArms = pose.strokeThicknessLowerArms
            self.strokeThicknessLowerLegs = pose.strokeThicknessLowerLegs
            self.strokeThicknessLowerTorso = pose.strokeThicknessLowerTorso
            self.strokeThicknessBicep = pose.strokeThicknessBicep
            self.strokeThicknessTricep = pose.strokeThicknessTricep
            self.strokeThicknessUpperLegs = pose.strokeThicknessUpperLegs
            self.strokeThicknessUpperTorso = pose.strokeThicknessUpperTorso
            self.strokeThicknessFullTorso = pose.strokeThicknessFullTorso
            self.strokeThicknessDeltoids = pose.strokeThicknessDeltoids
            self.strokeThicknessTrapezius = pose.strokeThicknessTrapezius
        } else {
            // Use values from editor (EditModeValues) if available, otherwise use defaults
            self.strokeThickness = 4.0
            self.strokeThicknessJoints = values.strokeThicknessJoints ?? 2.5
            self.strokeThicknessLowerArms = values.strokeThicknessLowerArms ?? 3.5
            self.strokeThicknessLowerLegs = values.strokeThicknessLowerLegs ?? 3.5
            self.strokeThicknessLowerTorso = values.strokeThicknessLowerTorso ?? 4.5
            self.strokeThicknessBicep = values.strokeThicknessBicep ?? 4.0
            self.strokeThicknessTricep = values.strokeThicknessTricep ?? 4.0
            self.strokeThicknessUpperLegs = values.strokeThicknessUpperLegs ?? 4.5
            self.strokeThicknessUpperTorso = values.strokeThicknessUpperTorso ?? 5.0
            self.strokeThicknessFullTorso = values.strokeThicknessFullTorso ?? 1.0
            self.strokeThicknessDeltoids = values.strokeThicknessDeltoids ?? 4.0
            self.strokeThicknessTrapezius = values.strokeThicknessTrapezius ?? 4.0
        }
        
        // Store objects
        self.objects = objects
    }
    
    // MARK: - Codable Support for Backward Compatibility
    
    enum CodingKeys: String, CodingKey {
        case id, name, frameNumber, createdAt, objects, pose
        case figureScale
        case fusiformUpperTorso, fusiformLowerTorso, fusiformBicep, fusiformTricep, fusiformLowerArms
        case fusiformUpperLegs, fusiformLowerLegs, fusiformShoulders, fusiformDeltoids
        case peakPositionBicep, peakPositionTricep, peakPositionLowerArms, peakPositionUpperLegs
        case peakPositionLowerLegs, peakPositionUpperTorso, peakPositionLowerTorso, peakPositionDeltoids
        case fusiformFullTorso, peakPositionFullTorsoTop, peakPositionFullTorsoMiddle, peakPositionFullTorsoBottom
        case armMuscleSide
        case figureOffsetX, figureOffsetY, waistPositionX, waistPositionY
        case shoulderWidthMultiplier, waistWidthMultiplier
        case waistThicknessMultiplier, skeletonSizeTorso, skeletonSizeArm, skeletonSizeLeg, jointShapeSize, neckLength, neckWidth
        case handSize, footSize, waistTorsoAngle, midTorsoAngle, torsoRotationAngle, headAngle
        case leftShoulderAngle, rightShoulderAngle, leftElbowAngle, rightElbowAngle
        case leftHipAngle, rightHipAngle
        case leftKneeAngle, rightKneeAngle, leftFootAngle, rightFootAngle
        case strokeThicknessJoints, strokeThicknessLowerArms, strokeThicknessLowerLegs
        case strokeThicknessLowerTorso, strokeThicknessBicep, strokeThicknessTricep, strokeThicknessUpperLegs, strokeThicknessUpperTorso, strokeThicknessFullTorso, strokeThicknessDeltoids, strokeThicknessTrapezius
        case strokeThickness
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
        fusiformBicep = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformBicep) ?? 0.0
        fusiformTricep = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformTricep) ?? 0.0
        fusiformLowerArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerArms) ?? 0.0
        fusiformUpperLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformUpperLegs) ?? 0.0
        fusiformLowerLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformLowerLegs) ?? 0.0
        fusiformShoulders = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformShoulders) ?? 0.0
        fusiformDeltoids = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformDeltoids) ?? 0.5
        peakPositionBicep = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionBicep) ?? 0.0
        peakPositionTricep = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionTricep) ?? 0.0
        peakPositionLowerArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerArms) ?? 0.0
        peakPositionUpperLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionUpperLegs) ?? 0.0
        peakPositionLowerLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerLegs) ?? 0.0
        peakPositionUpperTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionUpperTorso) ?? 0.0
        peakPositionLowerTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionLowerTorso) ?? 0.0
        peakPositionDeltoids = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionDeltoids) ?? 0.3
        fusiformFullTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .fusiformFullTorso) ?? 0.0
        peakPositionFullTorsoTop = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionFullTorsoTop) ?? 0.15
        peakPositionFullTorsoMiddle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionFullTorsoMiddle) ?? 0.5
        peakPositionFullTorsoBottom = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .peakPositionFullTorsoBottom) ?? 0.85
        armMuscleSide = try poseContainer.decodeIfPresent(String.self, forKey: .armMuscleSide) ?? "normal"
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
        leftHipAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftHipAngle) ?? 0.0
        rightHipAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightHipAngle) ?? 0.0
        leftKneeAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftKneeAngle) ?? 0.0
        rightKneeAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightKneeAngle) ?? 0.0
        leftFootAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .leftFootAngle) ?? 0.0
        rightFootAngle = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .rightFootAngle) ?? 0.0
        
        // Decode stroke thickness properties from pose container - optional for backward compatibility
        strokeThickness = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThickness) ?? 4.0
        strokeThicknessJoints = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessJoints) ?? 2.5
        strokeThicknessLowerArms = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerArms) ?? 3.5
        strokeThicknessLowerLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerLegs) ?? 3.5
        strokeThicknessLowerTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerTorso) ?? 4.5
        strokeThicknessBicep = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessBicep) ?? 4.0
        strokeThicknessTricep = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessTricep) ?? 4.0
        strokeThicknessUpperLegs = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperLegs) ?? 4.5
        strokeThicknessUpperTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperTorso) ?? 5.0
        strokeThicknessFullTorso = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessFullTorso) ?? 1.0
        strokeThicknessDeltoids = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessDeltoids) ?? 4.0
        strokeThicknessTrapezius = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessTrapezius) ?? 4.0
        
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
        try poseContainer.encode(fusiformBicep, forKey: .fusiformBicep)
        try poseContainer.encode(fusiformTricep, forKey: .fusiformTricep)
        try poseContainer.encode(fusiformLowerArms, forKey: .fusiformLowerArms)
        try poseContainer.encode(fusiformUpperLegs, forKey: .fusiformUpperLegs)
        try poseContainer.encode(fusiformLowerLegs, forKey: .fusiformLowerLegs)
        try poseContainer.encode(fusiformShoulders, forKey: .fusiformShoulders)
        try poseContainer.encode(fusiformDeltoids, forKey: .fusiformDeltoids)
        try poseContainer.encode(peakPositionBicep, forKey: .peakPositionBicep)
        try poseContainer.encode(peakPositionTricep, forKey: .peakPositionTricep)
        try poseContainer.encode(peakPositionLowerArms, forKey: .peakPositionLowerArms)
        try poseContainer.encode(peakPositionUpperLegs, forKey: .peakPositionUpperLegs)
        try poseContainer.encode(peakPositionLowerLegs, forKey: .peakPositionLowerLegs)
        try poseContainer.encode(peakPositionUpperTorso, forKey: .peakPositionUpperTorso)
        try poseContainer.encode(peakPositionLowerTorso, forKey: .peakPositionLowerTorso)
        try poseContainer.encode(peakPositionDeltoids, forKey: .peakPositionDeltoids)
        try poseContainer.encode(fusiformFullTorso, forKey: .fusiformFullTorso)
        try poseContainer.encode(peakPositionFullTorsoTop, forKey: .peakPositionFullTorsoTop)
        try poseContainer.encode(peakPositionFullTorsoMiddle, forKey: .peakPositionFullTorsoMiddle)
        try poseContainer.encode(peakPositionFullTorsoBottom, forKey: .peakPositionFullTorsoBottom)
        try poseContainer.encode(armMuscleSide, forKey: .armMuscleSide)
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
        try poseContainer.encode(leftHipAngle, forKey: .leftHipAngle)
        try poseContainer.encode(rightHipAngle, forKey: .rightHipAngle)
        try poseContainer.encode(leftKneeAngle, forKey: .leftKneeAngle)
        try poseContainer.encode(rightKneeAngle, forKey: .rightKneeAngle)
        try poseContainer.encode(leftFootAngle, forKey: .leftFootAngle)
        try poseContainer.encode(rightFootAngle, forKey: .rightFootAngle)
        try poseContainer.encode(strokeThickness, forKey: .strokeThickness)
        try poseContainer.encode(strokeThicknessJoints, forKey: .strokeThicknessJoints)
        try poseContainer.encode(strokeThicknessLowerArms, forKey: .strokeThicknessLowerArms)
        try poseContainer.encode(strokeThicknessLowerLegs, forKey: .strokeThicknessLowerLegs)
        try poseContainer.encode(strokeThicknessLowerTorso, forKey: .strokeThicknessLowerTorso)
        try poseContainer.encode(strokeThicknessBicep, forKey: .strokeThicknessBicep)
        try poseContainer.encode(strokeThicknessTricep, forKey: .strokeThicknessTricep)
        try poseContainer.encode(strokeThicknessUpperLegs, forKey: .strokeThicknessUpperLegs)
        try poseContainer.encode(strokeThicknessUpperTorso, forKey: .strokeThicknessUpperTorso)
        try poseContainer.encode(strokeThicknessFullTorso, forKey: .strokeThicknessFullTorso)
        try poseContainer.encode(strokeThicknessDeltoids, forKey: .strokeThicknessDeltoids)
        try poseContainer.encode(strokeThicknessTrapezius, forKey: .strokeThicknessTrapezius)
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
        //print("✅ Frame saved: \(frame.name)")
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
        //print("✅ Frame deleted")
    }
    
    /// Rename a frame
    func renameFrame(id: UUID, newName: String) {
        var frames = getAllFrames()
        if let index = frames.firstIndex(where: { $0.id == id }) {
            frames[index].name = newName
            saveAll(frames)
            //print("✅ Frame renamed to: \(newName)")
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
        //print("✅ exportFrameAsJSON: Exporting frame '\(frame.name)'")
        
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
            // Determine type based on assetName (BOX_ prefix = box, otherwise image)
            let objectType = object.assetName.hasPrefix("BOX_") ? "box" : "image"
            jsonString += "        \"type\" : \"\(objectType)\",\n"
            // Always include imageName for serialization
            jsonString += "        \"imageName\" : \"\(object.assetName)\",\n"
            
            if objectType == "box" {
                // For box objects, parse the BOX_#COLOR_WIDTH_HEIGHT format
                let parts = object.assetName.split(separator: "_")
                let color = parts.count > 1 ? String(parts[1]) : "#FF0000"
                let width = parts.count > 2 ? Double(parts[2]) ?? 50.0 : 50.0
                let height = parts.count > 3 ? Double(parts[3]) ?? 50.0 : 50.0
                
                jsonString += "        \"color\" : \"\(color)\",\n"
                jsonString += "        \"width\" : \(width),\n"
                jsonString += "        \"height\" : \(height),\n"
            } else {
                // For image objects, export the final actual dimensions (baseWidth * scaleX, baseHeight * scaleY)
                // These should match what was displayed in the editor
                let baseWidth = object.baseWidth ?? 50.0
                let baseHeight = object.baseHeight ?? 50.0
                let actualWidth = baseWidth * object.scaleX
                let actualHeight = baseHeight * object.scaleY
                
                jsonString += "        \"width\" : \(roundAndFormat(actualWidth, decimals: 1)),\n"
                jsonString += "        \"height\" : \(roundAndFormat(actualHeight, decimals: 1)),\n"
            }
            
            jsonString += "        \"position\" : {\n"
            jsonString += "          \"x\" : \(roundAndFormat(object.position.x, decimals: 1)),\n"
            jsonString += "          \"y\" : \(roundAndFormat(object.position.y, decimals: 1))\n"
            jsonString += "        },\n"
            jsonString += "        \"editorSceneWidth\" : \(roundAndFormat(object.editorSceneWidth, decimals: 1)),\n"
            jsonString += "        \"rotation\" : \(roundAndFormat(object.rotation, decimals: 4))\n"
            jsonString += "      }"
            if index < frame.objects.count - 1 {
                jsonString += ","
            }
            jsonString += "\n"
        }
        jsonString += "    ],\n"
        jsonString += "    \"pose\" : {\n"
        
        // Build pose dictionary - sort alphabetically (V2 renderer properties only)
        let poseEntries: [(String, String)] = [
            ("figureScale", roundAndFormat(frame.figureScale, decimals: 1)),
            ("footColor", "\"#000000\""),
            ("footSize", roundAndFormat(frame.footSize, decimals: 1)),
            ("fusiformBicep", roundAndFormat(frame.fusiformBicep, decimals: 2)),
            ("fusiformUpperLegs", roundAndFormat(frame.fusiformUpperLegs, decimals: 2)),
            ("handColor", "\"#000000\""),
            ("handSize", roundAndFormat(frame.handSize, decimals: 1)),
            ("headAngle", "\(Int(frame.headAngle))"),
            ("headColor", "\"#000000\""),
            ("leftElbowAngle", "\(Int(frame.leftElbowAngle))"),
            ("leftFootAngle", "\(Int(frame.leftFootAngle))"),
            ("leftHipAngle", "\(Int(frame.leftHipAngle))"),
            ("leftKneeAngle", "\(Int(frame.leftKneeAngle))"),
            ("leftShoulderAngle", "\(Int(frame.leftShoulderAngle))"),
            ("midTorsoAngle", "\(Int(frame.midTorsoAngle))"),
            ("neckLength", roundAndFormat(frame.neckLength, decimals: 1)),
            ("neckWidth", roundAndFormat(frame.neckWidth, decimals: 1)),
            ("rightElbowAngle", "\(Int(frame.rightElbowAngle))"),
            ("rightFootAngle", "\(Int(frame.rightFootAngle))"),
            ("rightHipAngle", "\(Int(frame.rightHipAngle))"),
            ("rightKneeAngle", "\(Int(frame.rightKneeAngle))"),
            ("rightShoulderAngle", "\(Int(frame.rightShoulderAngle))"),
            ("scale", roundAndFormat(frame.figureScale, decimals: 1)),
            ("shoulderWidthMultiplier", roundAndFormat(frame.shoulderWidthMultiplier, decimals: 2)),
            ("strokeThickness", roundAndFormat(frame.strokeThickness, decimals: 1)),
            ("strokeThicknessBicep", roundAndFormat(frame.strokeThicknessBicep, decimals: 1)),
            ("strokeThicknessUpperLegs", roundAndFormat(frame.strokeThicknessUpperLegs, decimals: 1)),
            ("torsoColor", "\"#000000\""),
            ("torsoRotationAngle", "\(Int(frame.torsoRotationAngle))"),
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
                fusiformBicep: pose.fusiformBicep,
                fusiformTricep: pose.fusiformTricep,
                fusiformLowerArms: pose.fusiformLowerArms,
                fusiformUpperLegs: pose.fusiformUpperLegs,
                fusiformLowerLegs: pose.fusiformLowerLegs,
                fusiformShoulders: pose.fusiformShoulders,
                fusiformDeltoids: pose.fusiformDeltoids,
                peakPositionBicep: pose.peakPositionBicep,
                peakPositionTricep: pose.peakPositionTricep,
                peakPositionLowerArms: pose.peakPositionLowerArms,
                peakPositionUpperLegs: pose.peakPositionUpperLegs,
                peakPositionLowerLegs: pose.peakPositionLowerLegs,
                peakPositionUpperTorso: pose.peakPositionUpperTorso,
                peakPositionLowerTorso: pose.peakPositionLowerTorso,
                peakPositionDeltoids: pose.peakPositionDeltoids,
                fusiformFullTorso: pose.fusiformFullTorso,
                peakPositionFullTorsoTop: pose.peakPositionFullTorsoTop,
                peakPositionFullTorsoMiddle: pose.peakPositionFullTorsoMiddle,
                peakPositionFullTorsoBottom: pose.peakPositionFullTorsoBottom,
                skeletonSizeTorso: pose.skeletonSizeTorso,
                skeletonSizeArm: pose.skeletonSizeArm,
                skeletonSizeLeg: pose.skeletonSizeLeg,
                jointShapeSize: nil,
                shoulderWidthMultiplier: pose.shoulderWidthMultiplier,
                waistWidthMultiplier: pose.waistWidthMultiplier,
                waistThicknessMultiplier: pose.waistThicknessMultiplier,
                neckLength: pose.neckLength,
                neckWidth: pose.neckWidth,
                handSize: pose.handSize,
                footSize: pose.footSize,
                strokeThicknessJoints: pose.strokeThicknessJoints,
                strokeThicknessUpperTorso: pose.strokeThicknessUpperTorso,
                strokeThicknessLowerTorso: pose.strokeThicknessLowerTorso,
                strokeThicknessBicep: pose.strokeThicknessBicep,
                strokeThicknessTricep: pose.strokeThicknessTricep,
                strokeThicknessLowerArms: pose.strokeThicknessLowerArms,
                strokeThicknessUpperLegs: pose.strokeThicknessUpperLegs,
                strokeThicknessLowerLegs: pose.strokeThicknessLowerLegs,
                strokeThicknessFullTorso: pose.strokeThicknessFullTorso,
                strokeThicknessDeltoids: pose.strokeThicknessDeltoids,
                strokeThicknessTrapezius: pose.strokeThicknessTrapezius,
                armMuscleSide: pose.armMuscleSide,
                showGrid: true,
                showJoints: true,
                positionX: 0,
                positionY: 0,
                bodyPartColors: nil,
                showInteractiveJoints: nil
            )
            
            let editorObjects = animFrame.objects.map { animObj in
                if animObj.type == .box {
                    // Store box as special EditorObject with BOX_ prefix
                    let boxAssetName = "BOX_\(animObj.color)_\(Int(animObj.width))_\(Int(animObj.height))"
                    return EditorObject(
                        assetName: boxAssetName,
                        position: animObj.position,
                        rotation: animObj.rotation,
                        scaleX: 1.0,  // Scale is baked into dimensions
                        scaleY: 1.0
                    )
                } else {
                    // Image object
                    return EditorObject(
                        assetName: animObj.imageName,
                        position: animObj.position,
                        rotation: animObj.rotation,
                        scaleX: animObj.scale,
                        scaleY: animObj.scale
                    )
                }
            }
            
            let savedFrame = SavedEditFrame(
                id: animFrame.id,
                name: animFrame.name,
                frameNumber: animFrame.frameNumber,
                from: editValues,
                pose: pose,
                objects: editorObjects,
                timestamp: animFrame.createdAt
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
