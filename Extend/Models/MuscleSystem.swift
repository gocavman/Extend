import Foundation

// MARK: - Muscle System Data Structures

struct MuscleConfig: Codable {
    let config: ConfigSettings
    let actions: [GameAction]
    let properties: [PropertyDefinition]
    
    enum CodingKeys: String, CodingKey {
        case config, actions, properties
    }
}

struct ConfigSettings: Codable {
    let description: String?
    let pointsPerCompletion: Int
    let timeframeUnit: String
    let tiers: [String]
    let tierGating: Bool
}

struct GameAction: Codable {
    let id: String
    let name: String
    let description: String?
    let pointsAwarded: Int
    let frequency: Frequency?
    let targetMuscleGroups: [MuscleGroupDistribution]
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, pointsAwarded, frequency, targetMuscleGroups
    }
}

struct MuscleGroupDistribution: Codable {
    let muscleGroup: String
    let percentage: Double
}

struct Frequency: Codable {
    let count: Int
    let unit: String
}

struct PropertyDefinition: Codable {
    let id: String
    let name: String
    let muscleGroups: [String]  // Now supports multiple muscle groups
    let progression: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case id, name, muscleGroups, progression
    }
}

// MARK: - Muscle State (Runtime)

class MuscleState: Codable {
    var musclePoints: [String: Double] = [:]  // muscleId -> points (0-100)
    var lastPointAwardTime: [String: Date] = [:]  // muscleId -> last timestamp
    
    enum CodingKeys: String, CodingKey {
        case musclePoints, lastPointAwardTime
    }
    
    init() {}
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        musclePoints = try container.decodeIfPresent([String: Double].self, forKey: .musclePoints) ?? [:]
        lastPointAwardTime = try container.decodeIfPresent([String: Date].self, forKey: .lastPointAwardTime) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(musclePoints, forKey: .musclePoints)
        try container.encode(lastPointAwardTime, forKey: .lastPointAwardTime)
    }
    
    /// Initialize property points to 0 for all properties
    func initializeProperties(with properties: [PropertyDefinition]) {
        for property in properties {
            if musclePoints[property.id] == nil {
                musclePoints[property.id] = 0
            }
        }
    }
    
    /// Get current points for a muscle
    func getPoints(for muscleId: String) -> Double {
        return musclePoints[muscleId] ?? 0
    }
    
    /// Set points for a muscle (clamped 0-100)
    func setPoints(_ points: Double, for muscleId: String) {
        musclePoints[muscleId] = max(0, min(100, points))
    }
    
    /// Add points to a muscle (clamped 0-100)
    func addPoints(_ points: Double, to muscleId: String) {
        let current = musclePoints[muscleId] ?? 0
        musclePoints[muscleId] = max(0, min(100, current + points))
    }
    
    /// Check if enough time has passed to award points
    func canAwardPoints(to propertyId: String, frequency: Frequency?) -> Bool {
        guard let lastTime = lastPointAwardTime[propertyId] else {
            return true  // Never awarded before
        }
        
        guard let frequency = frequency else {
            return true  // If no frequency specified, always allow
        }
        
        let timeInterval: TimeInterval
        switch frequency.unit {
        case "minutes":
            timeInterval = TimeInterval(frequency.count * 60)
        case "hours":
            timeInterval = TimeInterval(frequency.count * 3600)
        case "days":
            timeInterval = TimeInterval(frequency.count * 86400)
        default:
            timeInterval = TimeInterval(frequency.count * 60)  // Default to minutes
        }
        
        return Date().timeIntervalSince(lastTime) >= timeInterval
    }
    
    /// Record point award time
    func recordPointAward(for muscleId: String) {
        lastPointAwardTime[muscleId] = Date()
    }
}

// MARK: - AnyCodable Helper

enum AnyCodable: Codable {
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }
    
    /// Convert to Double if possible
    var doubleValue: Double? {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        default:
            return nil
        }
    }
}

// MARK: - Muscle System Manager

class MuscleSystem {
    static let shared = MuscleSystem()
    
    var config: MuscleConfig?
    var state: MuscleState = MuscleState()
    
    // The 5 stand frames loaded from animations.json
    // Index: [0=ExtraSmall, 1=Small, 2=Stand, 3=Large, 4=ExtraLarge]
    private var standFrames: [SavedEditFrame] = []
    
    private init() {
        loadStandFrames()
        loadMuscleConfig()
    }
    
    /// Explicitly reload the 5 Stand frames (useful after app launch)
    func ensureStandFramesLoaded() {
        // If frames are already loaded, skip
        if standFrames.count == 5 {
            return
        }
        
        // Otherwise, attempt to load them
        loadStandFrames()
    }
    
    /// Load the 5 Stand frames from animations.json
    private func loadStandFrames() {
        guard let bundleURL = Bundle.main.url(forResource: "animations", withExtension: "json") else {
            return
        }
        
        do {
            let data = try Data(contentsOf: bundleURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            let allFrames = try decoder.decode([SavedEditFrame].self, from: data)
            print("🦵 MuscleSystem.loadStandFrames: Decoded \(allFrames.count) total frames")
            print("🦵 Frame names: \(allFrames.map { $0.name }.joined(separator: ", "))")
            
            // Explicitly load the 5 Stand frames in the required order
            let standNames = ["Extra Small Stand", "Small Stand", "Stand", "Large Stand", "Extra Large Stand"]
            var loadedFrames: [SavedEditFrame] = []
            
            for name in standNames {
                if let frame = allFrames.first(where: { $0.name == name }) {
                    loadedFrames.append(frame)
                    print("🦵 Loaded: \(name) - strokeThicknessFullTorso=\(frame.strokeThicknessFullTorso), strokeThicknessUpperTorso=\(frame.strokeThicknessUpperTorso), fusiformDeltoids=\(frame.fusiformDeltoids), strokeThicknessDeltoids=\(frame.strokeThicknessDeltoids)")
                } else {
                    print("🦵 NOT FOUND: \(name)")
                }
            }
            
            // Only set if we got all 5 frames
            if loadedFrames.count == 5 {
                standFrames = loadedFrames
                print("🦵 ✅ Successfully loaded all 5 stand frames")
            } else {
                print("🦵 ❌ Only loaded \(loadedFrames.count) frames, need 5")
            }
            
        } catch {
            print("🦵 ❌ Failed to decode animations.json: \(error)")
        }
    }
    
    /// Load muscle config from bundle
    func loadMuscleConfig() {
        if let bundleURL = Bundle.main.url(forResource: "game_muscles", withExtension: "json") {
            do {
                let data = try Data(contentsOf: bundleURL)
                let decoder = JSONDecoder()
                config = try decoder.decode(MuscleConfig.self, from: data)
                state.initializeProperties(with: config?.properties ?? [])
            } catch {
                print("🦵 ❌ Failed to load game_muscles.json: \(error)")
            }
        }
    }
    
    /// Interpolate a property value based on muscle points using 5-frame lookup
    /// Falls back to game_muscles.json progression if frames don't have the data
    func interpolateProperty(_ propertyKey: String, musclePoints: Double) -> Double {
        if standFrames.count != 5 {
            print("🦵 INTERP ERROR: standFrames.count=\(standFrames.count), need 5 for \(propertyKey)")
            return getProgressionValue(propertyKey, musclePoints: musclePoints)
        }
        
        let framePoints = [0.0, 25.0, 50.0, 75.0, 100.0]
        let clamped = max(0, min(100, musclePoints))
        
        // Debug for deltoid at 100 points
        if propertyKey == "fusiformDeltoids" && clamped == 100.0 {
            print("🦵 DEBUG fusiformDeltoids at 100pts: tier4Frame=\(standFrames[4].name), fusiform=\(standFrames[4].fusiformDeltoids)")
        }
        
        if propertyKey == "strokeThicknessFullTorso" {
            print("🦵 interpolateProperty strokeThicknessFullTorso: musclePoints=\(musclePoints), clamped=\(clamped)")
        }
        
        // Clamp to range [0, 100]
        if clamped <= 0 {
            let val = getPropertyValue(propertyKey, from: standFrames[0])
            if propertyKey == "strokeThicknessFullTorso" {
                print("🦵   -> at 0 points: \(val)")
            }
            return val
        }
        if clamped >= 100 {
            let val = getPropertyValue(propertyKey, from: standFrames[4])
            // If frame value is 0, try to get from game_muscles.json progression
            if val == 0 && (propertyKey.contains("fusiform") || propertyKey.contains("peakPosition")) {
                let progressionVal = getProgressionValue(propertyKey, musclePoints: clamped)
                if progressionVal > 0 {
                    print("🦵   -> at 100 points: frame=\(val), using progression=\(progressionVal)")
                    return progressionVal
                }
            }
            if propertyKey == "fusiformDeltoids" {
                print("🦵   -> at 100 points from \(standFrames[4].name): \(val)")
            }
            if propertyKey == "strokeThicknessFullTorso" {
                print("🦵   -> at 100 points: \(val)")
            }
            return val
        }
        
        // Find surrounding frames
        for i in 0..<4 {
            if clamped >= framePoints[i] && clamped <= framePoints[i + 1] {
                let v1 = getPropertyValue(propertyKey, from: standFrames[i])
                let v2 = getPropertyValue(propertyKey, from: standFrames[i + 1])
                
                let p1 = framePoints[i]
                let p2 = framePoints[i + 1]
                let ratio = (clamped - p1) / (p2 - p1)
                let interpolated = v1 + (v2 - v1) * ratio
                
                if propertyKey == "strokeThicknessFullTorso" {
                    print("🦵   -> between frames \(i) and \(i+1): v1=\(v1), v2=\(v2), ratio=\(ratio), result=\(interpolated)")
                }
                
                return interpolated
            }
        }
        
        return getPropertyValue(propertyKey, from: standFrames[0])
    }
    
    /// Get progression value from game_muscles.json as a fallback
    private func getProgressionValue(_ propertyKey: String, musclePoints: Double) -> Double {
        guard let property = config?.properties.first(where: { $0.id == propertyKey }) else {
            return 0
        }
        
        let clamped = max(0, min(100, musclePoints))
        let tiers = ["0", "25", "50", "75", "100"]
        let points = [0.0, 25.0, 50.0, 75.0, 100.0]
        
        // Find surrounding tiers
        for i in 0..<4 {
            if clamped >= points[i] && clamped <= points[i + 1] {
                let v1 = property.progression[tiers[i]] ?? 0
                let v2 = property.progression[tiers[i + 1]] ?? 0
                let ratio = (clamped - points[i]) / (points[i + 1] - points[i])
                return v1 + (v2 - v1) * ratio
            }
        }
        
        return property.progression[tiers[4]] ?? 0
    }
    
    /// Helper to get a property value from a frame
    private func getPropertyValue(_ propertyKey: String, from frame: SavedEditFrame) -> Double {
        let value: Double
        switch propertyKey {
        case "fusiformShoulders": value = Double(frame.fusiformShoulders)
        case "fusiformDeltoids": value = Double(frame.fusiformDeltoids)
        case "fusiformUpperTorso": value = Double(frame.fusiformUpperTorso)
        case "fusiformLowerTorso": value = Double(frame.fusiformLowerTorso)
        case "fusiformBicep": value = Double(frame.fusiformBicep)
        case "fusiformTricep": value = Double(frame.fusiformTricep)
        case "fusiformLowerArms": value = Double(frame.fusiformLowerArms)
        case "fusiformUpperLegs": value = Double(frame.fusiformUpperLegs)
        case "fusiformLowerLegs": value = Double(frame.fusiformLowerLegs)
        case "neckWidth": value = Double(frame.neckWidth)
        case "handSize": value = Double(frame.handSize)
        case "footSize": value = Double(frame.footSize)
        case "skeletonSizeTorso": value = Double(frame.skeletonSizeTorso)
        case "skeletonSizeArm": value = Double(frame.skeletonSizeArm)
        case "skeletonSizeLeg": value = Double(frame.skeletonSizeLeg)
        case "waistThicknessMultiplier": value = Double(frame.waistThicknessMultiplier)
        case "strokeThicknessDeltoids": value = Double(frame.strokeThicknessDeltoids)
        case "strokeThicknessTrapezius": value = Double(frame.strokeThicknessTrapezius)
        case "strokeThicknessUpperTorso": value = Double(frame.strokeThicknessUpperTorso)
        case "strokeThicknessLowerTorso": value = Double(frame.strokeThicknessLowerTorso)
        case "strokeThicknessBicep": value = Double(frame.strokeThicknessBicep)
        case "strokeThicknessTricep": value = Double(frame.strokeThicknessTricep)
        case "strokeThicknessLowerArms": value = Double(frame.strokeThicknessLowerArms)
        case "strokeThicknessUpperLegs": value = Double(frame.strokeThicknessUpperLegs)
        case "strokeThicknessLowerLegs": value = Double(frame.strokeThicknessLowerLegs)
        case "strokeThicknessJoints": value = Double(frame.strokeThicknessJoints)
        case "jointShapeSize": value = Double(frame.jointShapeSize)
        case "strokeThicknessFullTorso":
            value = Double(frame.strokeThicknessFullTorso)
            print("🦵 getPropertyValue strokeThicknessFullTorso: frame=\(frame.name), value=\(value)")
        case "peakPositionDeltoids": value = Double(frame.peakPositionDeltoids)
        case "peakPositionBicep": value = Double(frame.peakPositionBicep)
        case "peakPositionTricep": value = Double(frame.peakPositionTricep)
        case "peakPositionLowerArms": value = Double(frame.peakPositionLowerArms)
        case "peakPositionUpperLegs": value = Double(frame.peakPositionUpperLegs)
        case "peakPositionLowerLegs": value = Double(frame.peakPositionLowerLegs)
        case "peakPositionUpperTorso": value = Double(frame.peakPositionUpperTorso)
        case "peakPositionLowerTorso": value = Double(frame.peakPositionLowerTorso)
        case "Heart": value = 0  // Non-visual property, use default
        default:
            value = 0
            print("🦵 getPropertyValue UNKNOWN: propertyKey=\(propertyKey)")
        }
        return value
    }
    
    /// Get property by ID
    func getProperty(id: String) -> PropertyDefinition? {
        return config?.properties.first { $0.id == id }
    }
    
    /// Calculate average property points across all properties
    func getAveragePropertyPoints(state: MuscleState) -> Double {
        guard let properties = config?.properties, !properties.isEmpty else { return 0 }
        
        let totalPoints = properties.reduce(0.0) { sum, property in
            sum + state.getPoints(for: property.id)
        }
        
        return totalPoints / Double(properties.count)
    }
    
    /// Get derived property value using 5-frame interpolation
    func getDerivedPropertyValue(for propertyKey: String, state: MuscleState) -> Double {
        let avgPoints = getAveragePropertyPoints(state: state)
        return interpolateProperty(propertyKey, musclePoints: avgPoints)
    }
    
    /// Regenerate interpolation values in game_muscles.json based on current Stand frames
    func regenerateInterpolationFromStandFrames(standFrames: [AnimationFrame]) -> Bool {
        // Load current game_muscles.json config
        guard let currentConfig = config else { return false }
        
        // Sort stand frames by scale (smallest to largest)
        let sortedFrames = standFrames.sorted { $0.pose.scale < $1.pose.scale }
        
        // Map scales to tier names
        let tiers = ["0", "25", "50", "75", "100"]
        let interpolationMap: [String: AnimationFrame] = Dictionary(uniqueKeysWithValues:
            zip(tiers, sortedFrames.prefix(5)).map { ($0, $1) }
        )
        
        // Update progression values for each property by creating new PropertyDefinition objects
        var updatedProperties: [PropertyDefinition] = []
        for property in currentConfig.properties {
            var newProgression: [String: Double] = [:]
            
            // For each tier, extract the property value from corresponding Stand frame
            for (tier, frame) in interpolationMap {
                let value = extractPropertyValueFromFrame(frame: frame, propertyId: property.id)
                newProgression[tier] = value
            }
            
            // Create new PropertyDefinition with updated progression
            let updatedProperty = PropertyDefinition(
                id: property.id,
                name: property.name,
                muscleGroups: property.muscleGroups,
                progression: newProgression
            )
            updatedProperties.append(updatedProperty)
        }
        
        // Create new MuscleConfig with updated properties
        let updatedConfig = MuscleConfig(
            config: currentConfig.config,
            actions: currentConfig.actions,
            properties: updatedProperties
        )
        
        // Save updated config to game_muscles.json
        return saveGameMusclesToBundle(config: updatedConfig)
    }
    
    /// Extract a property value from an AnimationFrame
    private func extractPropertyValueFromFrame(frame: AnimationFrame, propertyId: String) -> Double {
        // Map property IDs to frame properties
        switch propertyId {
        case "fusiformShoulders":
            return Double(frame.pose.fusiformShoulders)
        case "fusiformDeltoids":
            return Double(frame.pose.fusiformDeltoids)
        case "fusiformUpperTorso":
            return Double(frame.pose.fusiformUpperTorso)
        case "fusiformLowerTorso":
            return Double(frame.pose.fusiformLowerTorso)
        case "fusiformBicep":
            return Double(frame.pose.fusiformBicep)
        case "fusiformTricep":
            return Double(frame.pose.fusiformTricep)
        case "fusiformLowerArms":
            return Double(frame.pose.fusiformLowerArms)
        case "fusiformUpperLegs":
            return Double(frame.pose.fusiformUpperLegs)
        case "fusiformLowerLegs":
            return Double(frame.pose.fusiformLowerLegs)
        case "strokeThicknessJoints":
            return Double(frame.pose.strokeThicknessJoints)
        case "strokeThicknessUpperTorso":
            return Double(frame.pose.strokeThicknessUpperTorso)
        case "strokeThicknessLowerTorso":
            return Double(frame.pose.strokeThicknessLowerTorso)
        case "strokeThicknessBicep":
            return Double(frame.pose.strokeThicknessBicep)
        case "strokeThicknessTricep":
            return Double(frame.pose.strokeThicknessTricep)
        case "strokeThicknessLowerArms":
            return Double(frame.pose.strokeThicknessLowerArms)
        case "strokeThicknessUpperLegs":
            return Double(frame.pose.strokeThicknessUpperLegs)
        case "strokeThicknessLowerLegs":
            return Double(frame.pose.strokeThicknessLowerLegs)
        case "strokeThicknessDeltoids":
            return Double(frame.pose.strokeThicknessDeltoids)
        case "strokeThicknessTrapezius":
            return Double(frame.pose.strokeThicknessTrapezius)
        case "neckWidth":
            return Double(frame.pose.neckWidth)
        case "handSize":
            return Double(frame.pose.handSize)
        case "footSize":
            return Double(frame.pose.footSize)
        case "skeletonSizeTorso":
            return Double(frame.pose.skeletonSizeTorso)
        case "skeletonSizeArm":
            return Double(frame.pose.skeletonSizeArm)
        case "skeletonSizeLeg":
            return Double(frame.pose.skeletonSizeLeg)
        case "waistThicknessMultiplier":
            return Double(frame.pose.waistThicknessMultiplier)
        case "peakPositionDeltoids":
            return Double(frame.pose.peakPositionDeltoids)
        case "peakPositionBicep":
            return Double(frame.pose.peakPositionBicep)
        case "peakPositionTricep":
            return Double(frame.pose.peakPositionTricep)
        case "peakPositionLowerArms":
            return Double(frame.pose.peakPositionLowerArms)
        case "peakPositionUpperLegs":
            return Double(frame.pose.peakPositionUpperLegs)
        case "peakPositionLowerLegs":
            return Double(frame.pose.peakPositionLowerLegs)
        case "peakPositionUpperTorso":
            return Double(frame.pose.peakPositionUpperTorso)
        case "peakPositionLowerTorso":
            return Double(frame.pose.peakPositionLowerTorso)
        case "strokeThicknessFullTorso":
            return Double(frame.pose.strokeThicknessFullTorso)
        default:
            return 0
        }
    }
    
    /// Save game muscles config to bundle
    private func saveGameMusclesToBundle(config: MuscleConfig) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(config)
            
            // Get the path to Documents/game_muscles.json
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsURL.appendingPathComponent("game_muscles.json")
                try jsonData.write(to: fileURL, options: .atomic)
                print("✅ game_muscles.json regenerated and saved")
                return true
            }
        } catch {
            print("❌ Error saving game_muscles.json: \(error)")
        }
        return false
    }
}
