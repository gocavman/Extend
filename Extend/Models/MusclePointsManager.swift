import Foundation
import Observation

/// Represents a single muscle group with its development points
struct MusclePoint: Identifiable, Codable {
    let id: UUID
    let displayName: String
    var points: CGFloat  // 0-100
    
    var normalized: CGFloat {
        return points / 100.0  // Returns 0.0-1.0 for rendering
    }
}

/// Manages muscle development points that sync with MuscleGroupsState
@Observable
final class MusclePointsManager {
    static let shared = MusclePointsManager()
    
    private let storageKey = "muscle_points_data"
    
    var musclePoints: [UUID: CGFloat] = [:]  // UUID -> Points (0-100)
    
    private init() {
        loadPoints()
    }
    
    /// Get all muscles from MuscleGroupsState with their current points
    var allMuscles: [MusclePoint] {
        let muscleGroupsState = MuscleGroupsState.shared
        return muscleGroupsState.sortedGroups.map { group in
            MusclePoint(
                id: group.id,
                displayName: group.name,
                points: musclePoints[group.id] ?? 0
            )
        }
    }
    
    /// Get points for a specific muscle (0-100)
    func getPoints(_ muscleID: UUID) -> CGFloat {
        return musclePoints[muscleID] ?? 0
    }
    
    /// Get normalized points for a specific muscle (0.0-1.0)
    func getNormalized(_ muscleID: UUID) -> CGFloat {
        return getPoints(muscleID) / 100.0
    }
    
    /// Update points for a muscle by delta amount
    func updatePoints(_ muscleID: UUID, delta: CGFloat) {
        let current = musclePoints[muscleID] ?? 0
        let newValue = max(0, min(100, current + delta))  // Clamp between 0-100
        musclePoints[muscleID] = newValue
        savePoints()
    }
    
    /// Set points directly for a muscle
    func setPoints(_ muscleID: UUID, points: CGFloat) {
        let clamped = max(0, min(100, points))  // Clamp between 0-100
        musclePoints[muscleID] = clamped
        savePoints()
    }
    
    /// Reset all muscle points to 0
    func resetAllPoints() {
        musclePoints.removeAll()
        savePoints()
    }
    
    /// Set all muscles to max development (100)
    func maxAllPoints() {
        let muscleGroupsState = MuscleGroupsState.shared
        for group in muscleGroupsState.groups {
            musclePoints[group.id] = 100
        }
        savePoints()
    }
    
    // MARK: - Persistence
    
    private func savePoints() {
        if let data = try? JSONEncoder().encode(musclePoints) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadPoints() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([UUID: CGFloat].self, from: data) {
            musclePoints = decoded
        } else {
            // Initialize with all muscles at 0 points
            let muscleGroupsState = MuscleGroupsState.shared
            for group in muscleGroupsState.groups {
                musclePoints[group.id] = 0
            }
            savePoints()
        }
    }
}
