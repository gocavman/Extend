import Foundation
import UIKit

// MARK: - Muscle System Data Structures

struct MuscleConfig: Codable {
    let config: ConfigSettings
    let actions: [GameAction]
    let properties: [PropertyDefinition]
    
    enum CodingKeys: String, CodingKey {
        case config, actions, properties
    }
    
    init(config: ConfigSettings, actions: [GameAction], properties: [PropertyDefinition]) {
        self.config = config
        self.actions = actions
        self.properties = properties
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Maintain order: config, actions, properties
        try container.encode(config, forKey: .config)
        try container.encode(actions, forKey: .actions)
        try container.encode(properties, forKey: .properties)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        config = try container.decode(ConfigSettings.self, forKey: .config)
        actions = try container.decode([GameAction].self, forKey: .actions)
        properties = try container.decode([PropertyDefinition].self, forKey: .properties)
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(pointsAwarded, forKey: .pointsAwarded)
        try container.encodeIfPresent(frequency, forKey: .frequency)
        try container.encode(targetMuscleGroups, forKey: .targetMuscleGroups)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        pointsAwarded = try container.decode(Int.self, forKey: .pointsAwarded)
        frequency = try container.decodeIfPresent(Frequency.self, forKey: .frequency)
        targetMuscleGroups = try container.decode([MuscleGroupDistribution].self, forKey: .targetMuscleGroups)
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

// Helper struct for ordered progression
struct OrderedProgression: Codable {
    var values: [(String, Double)] = []
    
    init(_ dict: [String: Double]) {
        let orderedKeys = ["0", "25", "50", "75", "100"]
        for key in orderedKeys {
            if let value = dict[key] {
                values.append((key, value))
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in values {
            try container.encode(value, forKey: DynamicKey(stringValue: key)!)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        for key in container.allKeys {
            if let value = try container.decodeIfPresent(Double.self, forKey: key) {
                values.append((key.stringValue, value))
            }
        }
    }
    
    struct DynamicKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
    
    subscript(key: String) -> Double? {
        get { values.first(where: { $0.0 == key })?.1 }
        set {
            if let newValue = newValue {
                if let index = values.firstIndex(where: { $0.0 == key }) {
                    values[index].1 = newValue
                } else {
                    values.append((key, newValue))
                }
            }
        }
    }
}

struct PropertyDefinition: Codable {
    let id: String
    let name: String
    let muscleGroups: [String]
    let progression: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case id, name, muscleGroups, progression
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode in specific order: id, name, muscleGroups, progression
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(muscleGroups, forKey: .muscleGroups)
        
        // Encode progression with explicitly ordered keys
        var progressionContainer = container.nestedContainer(keyedBy: ProgressionCodingKey.self, forKey: .progression)
        let orderedKeys = ["0", "25", "50", "75", "100"]
        for key in orderedKeys {
            if let value = progression[key] {
                try progressionContainer.encode(value, forKey: ProgressionCodingKey(stringValue: key)!)
            }
        }
    }
    
    struct ProgressionCodingKey: CodingKey {
        let stringValue: String
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        muscleGroups = try container.decode([String].self, forKey: .muscleGroups)
        
        let ordered = try container.decode(OrderedProgression.self, forKey: .progression)
        progression = Dictionary(uniqueKeysWithValues: ordered.values)
    }
    
    init(id: String, name: String, muscleGroups: [String], progression: [String: Double]) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.progression = progression
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
            //print("🦵 MuscleSystem.loadStandFrames: Decoded \(allFrames.count) total frames")
            //print("🦵 Frame names: \(allFrames.map { $0.name }.joined(separator: ", "))")
            
            // Explicitly load the 5 Stand frames in the required order
            let standNames = ["Extra Small Stand", "Small Stand", "Stand", "Large Stand", "Extra Large Stand"]
            var loadedFrames: [SavedEditFrame] = []
            
            for name in standNames {
                if let frame = allFrames.first(where: { $0.name == name }) {
                    loadedFrames.append(frame)
                    //print("🦵 Loaded: \(name) - strokeThicknessFullTorso=\(frame.strokeThicknessFullTorso), strokeThicknessUpperTorso=\(frame.strokeThicknessUpperTorso), fusiformDeltoids=\(frame.fusiformDeltoids), strokeThicknessDeltoids=\(frame.strokeThicknessDeltoids)")
                } else {
                    print("🦵 NOT FOUND: \(name)")
                }
            }
            
            // Only set if we got all 5 frames
            if loadedFrames.count == 5 {
                standFrames = loadedFrames
                //print("🦵 ✅ Successfully loaded all 5 stand frames")
            } else {
                print("🦵 ❌ Only loaded \(loadedFrames.count) frames, need 5")
            }
            
        } catch {
            print("🦵 ❌ Failed to decode animations.json: \(error)")
        }
    }
    
    /// Load muscle config from bundle
    func loadMuscleConfig() {
        //print("🦵 Loading muscle config...")
        var configData: Data?
        var source = "unknown"
        
        // First, try to load from Documents (regenerated file has priority)
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsURL.appendingPathComponent("game_muscles.json")
            print("🦵 Checking Documents: \(fileURL.path)")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    configData = try Data(contentsOf: fileURL)
                    source = "Documents"
                    print("🦵 ✅ Loaded game_muscles.json from Documents (\(configData?.count ?? 0) bytes)")
                } catch {
                    print("🦵 ⚠️ Failed to load game_muscles.json from Documents: \(error)")
                }
            } else {
                print("🦵 Documents file does not exist")
            }
        }
        
        // If Documents file doesn't exist or failed, load from Bundle
        if configData == nil {
            print("🦵 Checking Bundle...")
            if let bundleURL = Bundle.main.url(forResource: "game_muscles", withExtension: "json") {
                do {
                    configData = try Data(contentsOf: bundleURL)
                    source = "Bundle"
                    print("🦵 ✅ Loaded game_muscles.json from Bundle (\(configData?.count ?? 0) bytes)")
                } catch {
                    print("🦵 ❌ Failed to load game_muscles.json from Bundle: \(error)")
                }
            } else {
                print("🦵 ❌ Bundle file not found")
            }
        }
        
        // Decode the loaded data
        if let configData = configData {
            do {
                let decoder = JSONDecoder()
                config = try decoder.decode(MuscleConfig.self, from: configData)
                state.initializeProperties(with: config?.properties ?? [])
                print("🦵 ✅ Successfully decoded config from \(source)")
                print("🦵 Loaded \(config?.properties.count ?? 0) properties")
                print("🦵 Loaded \(config?.actions.count ?? 0) actions")
                
                // Debug: Show the actions
                if let actions = config?.actions {
                    for action in actions {
                        print("🦵   - Action: \(action.id) '\(action.name)'")
                    }
                }
            } catch {
                print("🦵 ❌ Failed to decode game_muscles.json: \(error)")
            }
        } else {
            print("🦵 ❌ No config data to decode")
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
        
        // Clamp to range [0, 100]
        if clamped <= 0 {
            let val = getPropertyValue(propertyKey, from: standFrames[0])
            if propertyKey == "strokeThicknessFullTorso" {
                //print("🦵   -> at 0 points: \(val)")
            }
            return val
        }
        if clamped >= 100 {
            let val = getPropertyValue(propertyKey, from: standFrames[4])
            // If frame value is 0, try to get from game_muscles.json progression
            if val == 0 && (propertyKey.contains("fusiform") || propertyKey.contains("peakPosition")) {
                let progressionVal = getProgressionValue(propertyKey, musclePoints: clamped)
                if progressionVal > 0 {
                    //print("🦵   -> at 100 points: frame=\(val), using progression=\(progressionVal)")
                    return progressionVal
                }
            }
            if propertyKey == "fusiformDeltoids" {
                //print("🦵   -> at 100 points from \(standFrames[4].name): \(val)")
            }
            if propertyKey == "strokeThicknessFullTorso" {
                //print("🦵   -> at 100 points: \(val)")
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
                    //print("🦵   -> between frames \(i) and \(i+1): v1=\(v1), v2=\(v2), ratio=\(ratio), result=\(interpolated)")
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
        case "strokeThickness": value = Double(frame.strokeThickness)
        case "shoulderWidthMultiplier": value = Double(frame.shoulderWidthMultiplier)
        case "waistWidthMultiplier": value = Double(frame.waistWidthMultiplier)
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
            //print("🦵 getPropertyValue strokeThicknessFullTorso: frame=\(frame.name), value=\(value)")
        case "peakPositionDeltoids": value = Double(frame.peakPositionDeltoids)
        case "peakPositionBicep": value = Double(frame.peakPositionBicep)
        case "peakPositionTricep": value = Double(frame.peakPositionTricep)
        case "peakPositionLowerArms": value = Double(frame.peakPositionLowerArms)
        case "peakPositionUpperLegs": value = Double(frame.peakPositionUpperLegs)
        case "peakPositionLowerLegs": value = Double(frame.peakPositionLowerLegs)
        case "peakPositionUpperTorso": value = Double(frame.peakPositionUpperTorso)
        case "peakPositionLowerTorso": value = Double(frame.peakPositionLowerTorso)
        case "fusiformFullTorso": value = Double(frame.fusiformFullTorso)
        case "peakPositionFullTorsoTop": value = Double(frame.peakPositionFullTorsoTop)
        case "peakPositionFullTorsoMiddle": value = Double(frame.peakPositionFullTorsoMiddle)
        case "peakPositionFullTorsoBottom": value = Double(frame.peakPositionFullTorsoBottom)
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
    
    /// Load actions from Bundle version (used before regeneration to ensure actions are preserved)
    func loadActionsFromBundle() -> [GameAction] {
        guard let bundleURL = Bundle.main.url(forResource: "game_muscles", withExtension: "json") else {
            print("🦵 ❌ Could not load actions from Bundle: file not found")
            return []
        }
        
        do {
            let data = try Data(contentsOf: bundleURL)
            let decoder = JSONDecoder()
            let bundleConfig = try decoder.decode(MuscleConfig.self, from: data)
            print("🦵 ✅ Loaded \(bundleConfig.actions.count) actions from Bundle")
            for action in bundleConfig.actions {
                print("🦵   - Action: \(action.id) '\(action.name)'")
            }
            return bundleConfig.actions
        } catch {
            print("🦵 ❌ Failed to load actions from Bundle: \(error)")
            return []
        }
    }
    
    /// Regenerate interpolation values in game_muscles.json based on current Stand frames
    func regenerateInterpolationFromStandFrames(standFrames: [AnimationFrame]) -> Bool {
        // Load BUNDLE version to get the authoritative property list (includes new properties)
        guard let bundleURL = Bundle.main.url(forResource: "game_muscles", withExtension: "json") else {
            print("🦵 ❌ REGEN FAILED: Bundle game_muscles.json not found")
            return false
        }
        
        let bundleConfig: MuscleConfig
        do {
            let data = try Data(contentsOf: bundleURL)
            let decoder = JSONDecoder()
            bundleConfig = try decoder.decode(MuscleConfig.self, from: data)
            print("🦵 ✅ Loaded Bundle config with \(bundleConfig.properties.count) properties (authoritative source)")
        } catch {
            print("🦵 ❌ Failed to load Bundle config: \(error)")
            return false
        }
        
        // Load current config to get actions (might be in Documents with user edits)
        guard let currentConfig = config else {
            print("🦵 ❌ REGEN FAILED: currentConfig is nil")
            return false
        }
        
        print("🦵 ========== REGENERATION START ==========")
        print("🦵 Found \(standFrames.count) stand frames to process")
        print("🦵 Bundle config has \(bundleConfig.properties.count) properties (using this as source)")
        print("🦵 Current config has \(currentConfig.actions.count) actions")
        
        // If current config has no actions, use Bundle actions
        var actionsToPreserve = currentConfig.actions
        if actionsToPreserve.isEmpty {
            print("🦵 ⚠️ Current config has 0 actions, using Bundle actions...")
            actionsToPreserve = bundleConfig.actions
        }
        
        print("🦵 Will preserve \(actionsToPreserve.count) actions")
        for action in actionsToPreserve {
            print("🦵   - Action: \(action.id) '\(action.name)'")
        }
        
        // Map Stand frames by name to their corresponding tiers
        let frameTierMapping: [(tierName: String, frameName: String)] = [
            ("0", "Extra Small Stand"),
            ("25", "Small Stand"),
            ("50", "Stand"),
            ("75", "Large Stand"),
            ("100", "Extra Large Stand")
        ]
        
        var interpolationMap: [String: AnimationFrame] = [:]
        for (tierName, requiredFrameName) in frameTierMapping {
            if let matchingFrame = standFrames.first(where: { $0.name == requiredFrameName }) {
                interpolationMap[tierName] = matchingFrame
                print("🦵 ✅ Mapped tier '\(tierName)' to frame: '\(requiredFrameName)'")
            } else {
                print("🦵 ❌ REGEN FAILED: Stand frame '\(requiredFrameName)' not found for tier '\(tierName)'")
                return false
            }
        }
        
        // Update progression values for each property using BUNDLE properties as source
        var updatedProperties: [PropertyDefinition] = []
        for property in bundleConfig.properties {
            var newProgression: [String: Double] = [:]
            
            // For each tier, extract the property value from corresponding Stand frame
            for (tier, frame) in interpolationMap {
                let value = extractPropertyValueFromFrame(frame: frame, propertyId: property.id)
                newProgression[tier] = value
                
                // DEBUG: Log all hourglass properties and some others
                if property.id.contains("FullTorso") || property.id == "strokeThicknessUpperTorso" || property.id == "fusiformShoulders" {
                    print("🦵   Property '\(property.id)' @ tier '\(tier)' (frame '\(frame.name)'): \(value)")
                }
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
        
        print("🦵 Created \(updatedProperties.count) updated properties")
        print("🦵 Property IDs: \(updatedProperties.map { $0.id }.joined(separator: ", "))")
        
        // Create new MuscleConfig with updated properties AND preserved actions
        let updatedConfig = MuscleConfig(
            config: currentConfig.config,
            actions: actionsToPreserve,
            properties: updatedProperties
        )
        
        print("🦵 Updated config has \(updatedConfig.actions.count) actions ready to save")
        
        // Save updated config to game_muscles.json
        print("🦵 Attempting to save game_muscles.json...")
        let saveSuccess = saveGameMusclesToBundle(config: updatedConfig)
        
        if saveSuccess {
            print("🦵 ✅ game_muscles.json saved successfully")
            print("🦵 ========== REGENERATION COMPLETE ==========")
        } else {
            print("🦵 ❌ Failed to save game_muscles.json")
        }
        
        return saveSuccess
    }
    
    /// Extract a property value from an AnimationFrame
    private func extractPropertyValueFromFrame(frame: AnimationFrame, propertyId: String) -> Double {
        // Map property IDs to frame properties
        switch propertyId {
        case "strokeThickness":
            return Double(frame.pose.strokeThickness)
        case "shoulderWidthMultiplier":
            return Double(frame.pose.shoulderWidthMultiplier)
        case "waistWidthMultiplier":
            return Double(frame.pose.waistWidthMultiplier)
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
        case "fusiformFullTorso":
            return Double(frame.pose.fusiformFullTorso)
        case "peakPositionFullTorsoTop":
            return Double(frame.pose.peakPositionFullTorsoTop)
        case "peakPositionFullTorsoMiddle":
            return Double(frame.pose.peakPositionFullTorsoMiddle)
        case "peakPositionFullTorsoBottom":
            return Double(frame.pose.peakPositionFullTorsoBottom)
        default:
            return 0
        }
    }
    
    /// Save game muscles config to bundle
    private func saveGameMusclesToBundle(config: MuscleConfig) -> Bool {
        do {
            // DEBUG: Check what we're about to encode
            print("🦵 About to encode config with:")
            print("🦵   - config: \(config.config)")
            print("🦵   - actions.count: \(config.actions.count)")
            for (i, action) in config.actions.enumerated() {
                print("🦵     [\(i)] \(action.id): \(action.name)")
            }
            print("🦵   - properties.count: \(config.properties.count)")
            
            // Manually build JSON with controlled key ordering
            var jsonString = "{\n"
            
            // 1. Encode config
            jsonString += "  \"config\" : {\n"
            jsonString += "    \"description\" : \(encodeString(config.config.description ?? "")),\n"
            jsonString += "    \"pointsPerCompletion\" : \(config.config.pointsPerCompletion),\n"
            jsonString += "    \"timeframeUnit\" : \(encodeString(config.config.timeframeUnit)),\n"
            jsonString += "    \"tiers\" : [\n"
            for (i, tier) in config.config.tiers.enumerated() {
                jsonString += "      \(encodeString(tier))"
                if i < config.config.tiers.count - 1 {
                    jsonString += ","
                }
                jsonString += "\n"
            }
            jsonString += "    ],\n"
            jsonString += "    \"tierGating\" : \(config.config.tierGating)\n"
            jsonString += "  },\n"
            
            // 2. Encode actions
            jsonString += "  \"actions\" : [\n"
            for (i, action) in config.actions.enumerated() {
                jsonString += encodeGameAction(action, indent: 4)
                if i < config.actions.count - 1 {
                    jsonString += ","
                }
                jsonString += "\n"
            }
            jsonString += "  ],\n"
            
            // 3. Encode properties
            jsonString += "  \"properties\" : [\n"
            for (i, property) in config.properties.enumerated() {
                jsonString += encodePropertyDefinition(property, indent: 4)
                if i < config.properties.count - 1 {
                    jsonString += ","
                }
                jsonString += "\n"
            }
            jsonString += "  ]\n"
            jsonString += "}"
            
            let jsonData = jsonString.data(using: .utf8)!
            print("🦵 Generated JSON: \(jsonData.count) bytes")
            
            // DEBUG: Print first 1500 chars
            let preview = String(jsonString.prefix(1500))
            print("🦵 JSON Preview:\n\(preview)")
            
            // Get the path to Documents/game_muscles.json
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsURL.appendingPathComponent("game_muscles.json")
                print("🦵 Saving to: \(fileURL.path)")
                
                try jsonData.write(to: fileURL, options: .atomic)
                
                // Verify the file was actually written
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let savedData = try Data(contentsOf: fileURL)
                    print("🦵 ✅ File saved successfully! Size: \(savedData.count) bytes")
                    
                    // Try to load it back to verify it's valid JSON
                    let decoder = JSONDecoder()
                    _ = try decoder.decode(MuscleConfig.self, from: savedData)
                    print("🦵 ✅ File is valid JSON and can be decoded")
                    
                    // COPY THE JSON TO CLIPBOARD
                    UIPasteboard.general.string = jsonString
                    print("🦵 ✅ JSON copied to clipboard!")
                    print("🦵 You can now paste it directly into game_muscles.json in your project")
                    
                    return true
                } else {
                    print("🦵 ❌ File does not exist after write!")
                    return false
                }
            } else {
                print("🦵 ❌ Could not get Documents directory")
                return false
            }
        } catch {
            print("🦵 ❌ Error saving game_muscles.json: \(error)")
            return false
        }
    }
    
    private func encodeString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
    
    private func encodeGameAction(_ action: GameAction, indent: Int) -> String {
        let ind = String(repeating: " ", count: indent)
        let ind2 = String(repeating: " ", count: indent + 2)
        let ind3 = String(repeating: " ", count: indent + 4)
        
        var result = "\(ind){\n"
        result += "\(ind2)\"id\" : \(encodeString(action.id)),\n"
        result += "\(ind2)\"name\" : \(encodeString(action.name)),\n"
        
        if let description = action.description {
            result += "\(ind2)\"description\" : \(encodeString(description)),\n"
        }
        
        result += "\(ind2)\"pointsAwarded\" : \(action.pointsAwarded),\n"
        
        if let frequency = action.frequency {
            result += "\(ind2)\"frequency\" : {\n"
            result += "\(ind3)\"count\" : \(frequency.count),\n"
            result += "\(ind3)\"unit\" : \(encodeString(frequency.unit))\n"
            result += "\(ind2)},\n"
        }
        
        result += "\(ind2)\"targetMuscleGroups\" : [\n"
        for (i, group) in action.targetMuscleGroups.enumerated() {
            result += "\(ind3){\n"
            result += "\(ind3)  \"muscleGroup\" : \(encodeString(group.muscleGroup)),\n"
            result += "\(ind3)  \"percentage\" : \(group.percentage)\n"
            result += "\(ind3)}"
            if i < action.targetMuscleGroups.count - 1 {
                result += ","
            }
            result += "\n"
        }
        result += "\(ind2)]\n"
        result += "\(ind)}"
        
        return result
    }
    
    private func encodePropertyDefinition(_ property: PropertyDefinition, indent: Int) -> String {
        let ind = String(repeating: " ", count: indent)
        let ind2 = String(repeating: " ", count: indent + 2)
        let ind3 = String(repeating: " ", count: indent + 4)
        
        var result = "\(ind){\n"
        result += "\(ind2)\"id\" : \(encodeString(property.id)),\n"
        result += "\(ind2)\"name\" : \(encodeString(property.name)),\n"
        result += "\(ind2)\"muscleGroups\" : [\n"
        for (i, group) in property.muscleGroups.enumerated() {
            result += "\(ind3)\(encodeString(group))"
            if i < property.muscleGroups.count - 1 {
                result += ","
            }
            result += "\n"
        }
        result += "\(ind2)],\n"
        
        result += "\(ind2)\"progression\" : {\n"
        let orderedKeys = ["0", "25", "50", "75", "100"]
        var progressionLines: [String] = []
        for key in orderedKeys {
            if let value = property.progression[key] {
                let formattedValue: String
                if value == Double(Int(value)) {
                    formattedValue = String(Int(value))
                } else {
                    formattedValue = String(value)
                }
                progressionLines.append("\(ind3)\(encodeString(key)) : \(formattedValue)")
            }
        }
        result += progressionLines.joined(separator: ",\n") + "\n"
        result += "\(ind2)}\n"
        result += "\(ind)}"
        
        return result
    }
    
    /// Helper to format Double values for JSON (remove unnecessary decimals)
    private func formatDouble(_ value: Double) -> String {
        if value == Double(Int(value)) {
            return String(Int(value))
        }
        return String(value)
    }
    
    /// Reload muscle config after regeneration (call this after clicking Regenerate button)
    func reloadMuscleConfig() {
        loadMuscleConfig()
    }
}
