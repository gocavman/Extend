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
    
    private init() {
        loadMuscleConfig()
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
                // Handle error silently for now
            }
        }
    }
    
    /// Get muscle by ID
    func getMuscle(id: String) -> MuscleDefinition? {
        return config?.muscles.first { $0.id == id }
    }
    
    /// Get interpolated body part value based on muscle points
    func getBodyPartValue(for bodyPartKey: String, muscleId: String, state: MuscleState) -> Double {
        guard let muscle = getMuscle(id: muscleId) else { return 0 }
        guard muscle.bodyParts.contains(bodyPartKey) else { return 0 }
        
        let currentPoints = state.getPoints(for: muscleId)
        return interpolateValue(for: muscleId, at: currentPoints, bodyPart: bodyPartKey)
    }
    
    /// Linearly interpolate value between frame points
    private func interpolateValue(for muscleId: String, at points: Double, bodyPart: String) -> Double {
        guard let muscle = getMuscle(id: muscleId) else { return 0 }
        
        // Get frame values as doubles
        let framePoints = [0, 25, 50, 75, 100].map { Double($0) }
        var frameValues: [Double] = []
        
        for pointStr in ["0", "25", "50", "75", "100"] {
            if let codable = muscle.frameValues[pointStr], let value = codable.doubleValue {
                frameValues.append(value)
            } else {
                frameValues.append(0)
            }
        }
        
        // Find surrounding frames
        if points <= framePoints[0] {
            return frameValues[0]
        }
        if points >= framePoints[4] {
            let result = frameValues[4]
            print("🦵 INTERP: \(muscle.id) \(bodyPart) at \(points) points >= 100, returning \(result) (frameValues[4])")
            return result
        }
        
        // Find the two surrounding points
        for i in 0..<framePoints.count - 1 {
            if points >= framePoints[i] && points <= framePoints[i + 1] {
                let p1 = framePoints[i]
                let p2 = framePoints[i + 1]
                let v1 = frameValues[i]
                let v2 = frameValues[i + 1]
                
                // Linear interpolation: v = v1 + (v2 - v1) * (points - p1) / (p2 - p1)
                let ratio = (points - p1) / (p2 - p1)
                return v1 + (v2 - v1) * ratio
            }
        }
        
        return frameValues[0]
    }
    
    /// Calculate average muscle points across all muscles
    func getAverageMusclePoints(state: MuscleState) -> Double {
        guard let muscles = config?.muscles, !muscles.isEmpty else { return 0 }
        
        let totalPoints = muscles.reduce(0.0) { sum, muscle in
            sum + state.getPoints(for: muscle.id)
        }
        
        return totalPoints / Double(muscles.count)
    }
    
    /// Get derived property value (strokeThickness, skeletonSize, waistThicknessMultiplier)
    func getDerivedPropertyValue(for propertyKey: String, state: MuscleState) -> Double {
        guard let derivedProps = config?.pointsConfig else { return 0 }
        
        let avgPoints = getAverageMusclePoints(state: state)
        
        // Get the derived property values from the config
        // For now, we need to decode from AnyCodable
        // The values are stored with keys "0", "25", "50", "75", "100"
        
        let framePoints = [0.0, 25.0, 50.0, 75.0, 100.0]
        
        // Get frame values for this property from the JSON structure
        // This is a simplified approach - in production you'd parse the JSON properly
        let values = getDerivedPropertyFrameValues(for: propertyKey)
        
        guard !values.isEmpty else { return 0 }
        
        // Find surrounding frames and interpolate
        if avgPoints <= framePoints[0] {
            return values[0]
        }
        if avgPoints >= framePoints[4] {
            return values[4]
        }
        
        // Find the two surrounding points
        for i in 0..<framePoints.count - 1 {
            if avgPoints >= framePoints[i] && avgPoints <= framePoints[i + 1] {
                let p1 = framePoints[i]
                let p2 = framePoints[i + 1]
                let v1 = values[i]
                let v2 = values[i + 1]
                
                // Linear interpolation
                let ratio = (avgPoints - p1) / (p2 - p1)
                return v1 + (v2 - v1) * ratio
            }
        }
        
        return values[0]
    }
    
    /// Helper to get frame values for derived properties
    private func getDerivedPropertyFrameValues(for propertyKey: String) -> [Double] {
        // Map property names to their frame values
        let derivedValues: [String: [Double]] = [
            "neckWidth": [3.3, 3.3, 8.5, 8.8, 8.8],
            "handSize": [0.5, 0.5, 1, 7, 7],
            "footSize": [0.5, 0.5, 1, 7, 7],
            "strokeThickness": [0, 1, 1.2, 1.4, 2],
            "skeletonSize": [0, 3.19, 4.18, 5.11, 5.11],
            "waistThicknessMultiplier": [0, 0.9, 0.9, 0.9, 0.9]
        ]
        
        return derivedValues[propertyKey] ?? []
    }
}

