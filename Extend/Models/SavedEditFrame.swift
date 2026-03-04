import Foundation

/// Represents an object placed in the editor
struct EditorObject: Codable, Identifiable {
    let id: UUID
    let assetName: String  // "Apple", "Dumbbell", etc.
    var position: CGPoint
    var rotation: CGFloat  // in radians
    var scaleX: CGFloat
    var scaleY: CGFloat
    
    init(assetName: String, position: CGPoint, rotation: CGFloat = 0, scaleX: CGFloat = 1.0, scaleY: CGFloat = 1.0) {
        self.id = UUID()
        self.assetName = assetName
        self.position = position
        self.rotation = rotation
        self.scaleX = scaleX
        self.scaleY = scaleY
    }
}

/// Represents a frame saved in the gameplay editor
struct SavedEditFrame: Codable, Identifiable {
    var id: UUID
    var name: String
    var frameNumber: Int = 0  // Frame number for animation playback
    let timestamp: Date
    let figureScale: CGFloat
    let strokeThicknessMultiplier: CGFloat
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
    let skeletonSize: CGFloat
    let jointShapeSize: CGFloat
    let neckLength: CGFloat
    let neckWidth: CGFloat
    let handSize: CGFloat
    let footSize: CGFloat
    
    // Additional stroke thickness properties needed for complete frame export
    let strokeThicknessJoints: CGFloat
    let strokeThicknessLowerArms: CGFloat
    let strokeThicknessLowerLegs: CGFloat
    let strokeThicknessLowerTorso: CGFloat
    let strokeThicknessUpperArms: CGFloat
    let strokeThicknessUpperLegs: CGFloat
    let strokeThicknessUpperTorso: CGFloat
    
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
        self.strokeThicknessMultiplier = values.strokeThicknessMultiplier
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
            self.skeletonSize = pose.skeletonSize
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
            self.skeletonSize = 1.0
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
        } else {
            // Use defaults that match the Stand frame
            self.strokeThicknessJoints = 2.5
            self.strokeThicknessLowerArms = 3.5
            self.strokeThicknessLowerLegs = 3.5
            self.strokeThicknessLowerTorso = 4.5
            self.strokeThicknessUpperArms = 4.0
            self.strokeThicknessUpperLegs = 4.5
            self.strokeThicknessUpperTorso = 5.0
        }
        
        // Store objects
        self.objects = objects
    }
    
    // MARK: - Codable Support for Backward Compatibility
    
    enum CodingKeys: String, CodingKey {
        case id, name, frameNumber, timestamp, figureScale, strokeThicknessMultiplier
        case fusiformUpperTorso, fusiformLowerTorso, fusiformUpperArms, fusiformLowerArms
        case fusiformUpperLegs, fusiformLowerLegs, fusiformShoulders
        case peakPositionUpperArms, peakPositionLowerArms, peakPositionUpperLegs
        case peakPositionLowerLegs, peakPositionUpperTorso, peakPositionLowerTorso
        case positionX, positionY, shoulderWidthMultiplier, waistWidthMultiplier
        case waistThicknessMultiplier, skeletonSize, jointShapeSize, neckLength, neckWidth
        case handSize, footSize, waistTorsoAngle, midTorsoAngle, torsoRotationAngle, headAngle
        case leftShoulderAngle, rightShoulderAngle, leftElbowAngle, rightElbowAngle
        case leftHandAngle, rightHandAngle, leftHipAngle, rightHipAngle
        case leftKneeAngle, rightKneeAngle, leftFootAngle, rightFootAngle
        case strokeThicknessJoints, strokeThicknessLowerArms, strokeThicknessLowerLegs
        case strokeThicknessLowerTorso, strokeThicknessUpperArms, strokeThicknessUpperLegs, strokeThicknessUpperTorso
        case objects
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        frameNumber = try container.decode(Int.self, forKey: .frameNumber)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        figureScale = try container.decode(CGFloat.self, forKey: .figureScale)
        strokeThicknessMultiplier = try container.decode(CGFloat.self, forKey: .strokeThicknessMultiplier)
        
        // Decode all CGFloat properties
        fusiformUpperTorso = try container.decode(CGFloat.self, forKey: .fusiformUpperTorso)
        fusiformLowerTorso = try container.decode(CGFloat.self, forKey: .fusiformLowerTorso)
        fusiformUpperArms = try container.decode(CGFloat.self, forKey: .fusiformUpperArms)
        fusiformLowerArms = try container.decode(CGFloat.self, forKey: .fusiformLowerArms)
        fusiformUpperLegs = try container.decode(CGFloat.self, forKey: .fusiformUpperLegs)
        fusiformLowerLegs = try container.decode(CGFloat.self, forKey: .fusiformLowerLegs)
        fusiformShoulders = try container.decode(CGFloat.self, forKey: .fusiformShoulders)
        peakPositionUpperArms = try container.decode(CGFloat.self, forKey: .peakPositionUpperArms)
        peakPositionLowerArms = try container.decode(CGFloat.self, forKey: .peakPositionLowerArms)
        peakPositionUpperLegs = try container.decode(CGFloat.self, forKey: .peakPositionUpperLegs)
        peakPositionLowerLegs = try container.decode(CGFloat.self, forKey: .peakPositionLowerLegs)
        peakPositionUpperTorso = try container.decode(CGFloat.self, forKey: .peakPositionUpperTorso)
        peakPositionLowerTorso = try container.decode(CGFloat.self, forKey: .peakPositionLowerTorso)
        positionX = try container.decode(CGFloat.self, forKey: .positionX)
        positionY = try container.decode(CGFloat.self, forKey: .positionY)
        shoulderWidthMultiplier = try container.decode(CGFloat.self, forKey: .shoulderWidthMultiplier)
        waistWidthMultiplier = try container.decode(CGFloat.self, forKey: .waistWidthMultiplier)
        waistThicknessMultiplier = try container.decode(CGFloat.self, forKey: .waistThicknessMultiplier)
        skeletonSize = try container.decode(CGFloat.self, forKey: .skeletonSize)
        jointShapeSize = try container.decode(CGFloat.self, forKey: .jointShapeSize)
        neckLength = try container.decode(CGFloat.self, forKey: .neckLength)
        neckWidth = try container.decode(CGFloat.self, forKey: .neckWidth)
        handSize = try container.decode(CGFloat.self, forKey: .handSize)
        footSize = try container.decode(CGFloat.self, forKey: .footSize)
        
        // Decode angles
        waistTorsoAngle = try container.decode(CGFloat.self, forKey: .waistTorsoAngle)
        midTorsoAngle = try container.decode(CGFloat.self, forKey: .midTorsoAngle)
        torsoRotationAngle = try container.decode(CGFloat.self, forKey: .torsoRotationAngle)
        headAngle = try container.decode(CGFloat.self, forKey: .headAngle)
        leftShoulderAngle = try container.decode(CGFloat.self, forKey: .leftShoulderAngle)
        rightShoulderAngle = try container.decode(CGFloat.self, forKey: .rightShoulderAngle)
        leftElbowAngle = try container.decode(CGFloat.self, forKey: .leftElbowAngle)
        rightElbowAngle = try container.decode(CGFloat.self, forKey: .rightElbowAngle)
        leftHandAngle = try container.decode(CGFloat.self, forKey: .leftHandAngle)
        rightHandAngle = try container.decode(CGFloat.self, forKey: .rightHandAngle)
        leftHipAngle = try container.decode(CGFloat.self, forKey: .leftHipAngle)
        rightHipAngle = try container.decode(CGFloat.self, forKey: .rightHipAngle)
        leftKneeAngle = try container.decode(CGFloat.self, forKey: .leftKneeAngle)
        rightKneeAngle = try container.decode(CGFloat.self, forKey: .rightKneeAngle)
        leftFootAngle = try container.decode(CGFloat.self, forKey: .leftFootAngle)
        rightFootAngle = try container.decode(CGFloat.self, forKey: .rightFootAngle)
        
        // Decode stroke thickness properties - optional for backward compatibility
        strokeThicknessJoints = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessJoints) ?? 2.5
        strokeThicknessLowerArms = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerArms) ?? 3.5
        strokeThicknessLowerLegs = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerLegs) ?? 3.5
        strokeThicknessLowerTorso = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessLowerTorso) ?? 4.5
        strokeThicknessUpperArms = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperArms) ?? 4.0
        strokeThicknessUpperLegs = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperLegs) ?? 4.5
        strokeThicknessUpperTorso = try container.decodeIfPresent(CGFloat.self, forKey: .strokeThicknessUpperTorso) ?? 5.0
        
        // Decode objects - optional for backward compatibility with old saved frames
        objects = try container.decodeIfPresent([EditorObject].self, forKey: .objects) ?? []
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
    /// Export frame as JSON string
    func exportFrameAsJSON(id: UUID) -> String? {
        guard let frame = getFrame(id: id) else { return nil }
        
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
            ("skeletonSize", roundAndFormat(frame.skeletonSize, decimals: 2)),
            ("strokeThickness", roundAndFormat(frame.strokeThicknessMultiplier, decimals: 1)),
            ("strokeThicknessJoints", roundAndFormat(frame.strokeThicknessJoints, decimals: 1)),
            ("strokeThicknessLowerArms", roundAndFormat(frame.strokeThicknessLowerArms, decimals: 1)),
            ("strokeThicknessLowerLegs", roundAndFormat(frame.strokeThicknessLowerLegs, decimals: 1)),
            ("strokeThicknessLowerTorso", roundAndFormat(frame.strokeThicknessLowerTorso, decimals: 1)),
            ("strokeThicknessMultiplier", roundAndFormat(frame.strokeThicknessMultiplier, decimals: 1)),
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
    
    /// Clear all saved frames (for testing)
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("⚠️ All saved frames cleared")
    }
}
