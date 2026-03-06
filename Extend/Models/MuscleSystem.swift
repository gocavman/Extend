import Foundation

// MARK: - Muscle System Data Structures

struct MuscleConfig: Codable {
    let actions: [MuscleActionMapping]
    let pointsConfig: PointsConfig
    let muscles: [MuscleDefinition]
}

struct MuscleActionMapping: Codable {
    let name: String
    let targetMuscle: String
    let percentage: Double
}

struct PointsConfig: Codable {
    let count: Int          // Points to award
    let timeframe: String   // "minutes", "hours", or "days"
    let value: Int          // Timeframe value (e.g., 5 minutes)
}

struct MuscleDefinition: Codable {
    let id: String
    let name: String
    let bodyParts: [String]
    let frameValues: [String: AnyCodable]  // Points (0, 25, 50, 75, 100) -> values
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
    
    /// Initialize muscle points to 0 for all muscles
    func initializeMuscles(with muscles: [MuscleDefinition]) {
        for muscle in muscles {
            if musclePoints[muscle.id] == nil {
                musclePoints[muscle.id] = 0
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
    func canAwardPoints(to muscleId: String, pointsConfig: PointsConfig) -> Bool {
        guard let lastTime = lastPointAwardTime[muscleId] else {
            return true  // Never awarded before
        }
        
        let timeInterval: TimeInterval
        switch pointsConfig.timeframe {
        case "minutes":
            timeInterval = TimeInterval(pointsConfig.value * 60)
        case "hours":
            timeInterval = TimeInterval(pointsConfig.value * 3600)
        case "days":
            timeInterval = TimeInterval(pointsConfig.value * 86400)
        default:
            timeInterval = TimeInterval(pointsConfig.value * 60)  // Default to minutes
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
                    print("🦵 Loaded: \(name) - stroke=\(frame.strokeThicknessUpperTorso)")
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
                state.initializeMuscles(with: config?.muscles ?? [])
            } catch {
                // Handle error silently
            }
        }
    }
    
    /// Interpolate a property value based on muscle points using 5-frame lookup
    /// - Parameters:
    ///   - propertyKey: The property name (e.g., "fusiformUpperTorso", "strokeThicknessJoints")
    ///   - musclePoints: Points value 0-100
    /// - Returns: Interpolated value
    func interpolateProperty(_ propertyKey: String, musclePoints: Double) -> Double {
        if standFrames.count != 5 {
            print("🦵 INTERP ERROR: standFrames.count=\(standFrames.count), need 5 for \(propertyKey)")
            return 0
        }
        
        let framePoints = [0.0, 25.0, 50.0, 75.0, 100.0]
        let clamped = max(0, min(100, musclePoints))
        
        // Clamp to range [0, 100]
        if clamped <= 0 { 
            let val = getPropertyValue(propertyKey, from: standFrames[0])
            return val
        }
        if clamped >= 100 { 
            let val = getPropertyValue(propertyKey, from: standFrames[4])
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
                
                return v1 + (v2 - v1) * ratio
            }
        }
        
        return getPropertyValue(propertyKey, from: standFrames[0])
    }
    
    /// Helper to get a property value from a frame
    private func getPropertyValue(_ propertyKey: String, from frame: SavedEditFrame) -> Double {
        switch propertyKey {
        case "fusiformShoulders": return Double(frame.fusiformShoulders)
        case "fusiformUpperTorso": return Double(frame.fusiformUpperTorso)
        case "fusiformLowerTorso": return Double(frame.fusiformLowerTorso)
        case "fusiformUpperArms": return Double(frame.fusiformUpperArms)
        case "fusiformLowerArms": return Double(frame.fusiformLowerArms)
        case "fusiformUpperLegs": return Double(frame.fusiformUpperLegs)
        case "fusiformLowerLegs": return Double(frame.fusiformLowerLegs)
        case "neckWidth": return Double(frame.neckWidth)
        case "handSize": return Double(frame.handSize)
        case "footSize": return Double(frame.footSize)
        case "skeletonSize": return Double(frame.skeletonSize)
        case "waistThicknessMultiplier": return Double(frame.waistThicknessMultiplier)
        case "strokeThicknessUpperTorso": return Double(frame.strokeThicknessUpperTorso)
        case "strokeThicknessLowerTorso": return Double(frame.strokeThicknessLowerTorso)
        case "strokeThicknessUpperArms": return Double(frame.strokeThicknessUpperArms)
        case "strokeThicknessLowerArms": return Double(frame.strokeThicknessLowerArms)
        case "strokeThicknessUpperLegs": return Double(frame.strokeThicknessUpperLegs)
        case "strokeThicknessLowerLegs": return Double(frame.strokeThicknessLowerLegs)
        case "strokeThicknessJoints": return Double(frame.strokeThicknessJoints)
        default: return 0
        }
    }
    
    /// Get muscle by ID (for legacy code compatibility)
    func getMuscle(id: String) -> MuscleDefinition? {
        return config?.muscles.first { $0.id == id }
    }
    
    /// Get interpolated body part value based on muscle points (legacy)
    func getBodyPartValue(for bodyPartKey: String, muscleId: String, state: MuscleState) -> Double {
        let currentPoints = state.getPoints(for: muscleId)
        
        // Find the muscle definition with this ID
        guard let muscle = config?.muscles.first(where: { $0.id == muscleId }) else {
            return 0
        }
        
        // Use the frameValues from the muscle definition
        return interpolateFromMuscleFrameValues(bodyPartKey, musclePoints: currentPoints, muscle: muscle)
    }
    
    /// Interpolate from a muscle's frameValues (new method)
    private func interpolateFromMuscleFrameValues(_ bodyPartKey: String, musclePoints: Double, muscle: MuscleDefinition) -> Double {
        let framePoints = [0.0, 25.0, 50.0, 75.0, 100.0]
        let clamped = max(0, min(100, musclePoints))
        
        // Get the value at exact frame points
        if clamped <= 0 {
            if let value = getFrameValue(bodyPartKey, fromFrameValues: muscle.frameValues, atPoint: 0) {
                return value
            }
        }
        if clamped >= 100 {
            if let value = getFrameValue(bodyPartKey, fromFrameValues: muscle.frameValues, atPoint: 100) {
                return value
            }
        }
        
        // Interpolate between two frame points
        for i in 0..<4 {
            if clamped >= framePoints[i] && clamped <= framePoints[i + 1] {
                let p1 = framePoints[i]
                let p2 = framePoints[i + 1]
                
                if let v1 = getFrameValue(bodyPartKey, fromFrameValues: muscle.frameValues, atPoint: Int(p1)),
                   let v2 = getFrameValue(bodyPartKey, fromFrameValues: muscle.frameValues, atPoint: Int(p2)) {
                    let ratio = (clamped - p1) / (p2 - p1)
                    return v1 + (v2 - v1) * ratio
                }
            }
        }
        
        // Fallback to 0 frame
        if let value = getFrameValue(bodyPartKey, fromFrameValues: muscle.frameValues, atPoint: 0) {
            return value
        }
        return 0
    }
    
    /// Helper to get a body part value from frameValues
    private func getFrameValue(_ bodyPartKey: String, fromFrameValues: [String: AnyCodable], atPoint: Int) -> Double? {
        let pointKey = String(atPoint)
        guard let frameData = fromFrameValues[pointKey] else { return nil }
        
        if case .dictionary(let dict) = frameData,
           let valueData = dict[bodyPartKey],
           let doubleValue = valueData.doubleValue {
            return doubleValue
        }
        return nil
    }
    
    /// Calculate average muscle points across all muscles
    func getAverageMusclePoints(state: MuscleState) -> Double {
        guard let muscles = config?.muscles, !muscles.isEmpty else { return 0 }
        
        let totalPoints = muscles.reduce(0.0) { sum, muscle in
            sum + state.getPoints(for: muscle.id)
        }
        
        return totalPoints / Double(muscles.count)
    }
    
    /// Get derived property value using 5-frame interpolation
    func getDerivedPropertyValue(for propertyKey: String, state: MuscleState) -> Double {
        let avgPoints = getAverageMusclePoints(state: state)
        return interpolateProperty(propertyKey, musclePoints: avgPoints)
    }
}

