import Foundation

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

// MARK: - SavedAnimation

/// A named animation sequence saved by the user in Animation Studio.
struct SavedAnimation: Codable, Identifiable {
    var id: UUID
    var name: String
    /// Ordered list of frame IDs (references into SavedFramesManager)
    var frameIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    var frameCount: Int { frameIDs.count }

    init(name: String, frameIDs: [UUID]) {
        self.id = UUID()
        self.name = name
        self.frameIDs = frameIDs
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - SavedAnimationsManager

class SavedAnimationsManager {
    static let shared = SavedAnimationsManager()
    private let key = "savedAnimations_v1"

    func getAll() -> [SavedAnimation] {
        guard let data = defaults.data(forKey: key),
              let animations = try? JSONDecoder().decode([SavedAnimation].self, from: data) else { return [] }
        return animations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ animation: SavedAnimation) {
        var all = getAll()
        if let idx = all.firstIndex(where: { $0.id == animation.id }) {
            all[idx] = animation
        } else {
            all.append(animation)
        }
        saveAll(all)
    }

    func delete(id: UUID) {
        let remaining = getAll().filter { $0.id != id }
        saveAll(remaining)
    }

    func clone(_ animation: SavedAnimation) -> SavedAnimation {
        var copy = animation
        copy.id = UUID()
        copy.name = animation.name + " Copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        save(copy)
        return copy
    }

    func rename(id: UUID, newName: String) {
        var all = getAll()
        if let idx = all.firstIndex(where: { $0.id == id }) {
            all[idx].name = newName
            all[idx].updatedAt = Date()
            saveAll(all)
        }
    }

    private func saveAll(_ animations: [SavedAnimation]) {
        if let data = try? JSONEncoder().encode(animations) {
            defaults.set(data, forKey: key)
        }
    }
}

/// Shared utility for managing animation persistence
/// Loads frames from animations.json and tracks which frames are marked for export
/// Does NOT write to animations.json - developer manually copies JSON to clipboard
struct AnimationPersistence {
    static let projectPath = "/Users/cavan/Developer/Extend/Extend/animations.json"
    
    /// Load existing frames from animations.json (read-only)
    static func loadFramesFromDisk() -> [AnimationFrame] {
        let animationsURL = URL(fileURLWithPath: projectPath)
        guard let data = try? Data(contentsOf: animationsURL) else {
            return []
        }
        
        let decoder = JSONDecoder()
        return (try? decoder.decode([AnimationFrame].self, from: data)) ?? []
    }
    
    /// Export persisted frames as JSON string (ready to paste into animations.json)
    /// - Parameters:
    ///   - framesToExport: Frames marked for export
    ///   - completion: Returns JSON string or error
    static func exportFramesAsJSON(
        _ framesToExport: [AnimationFrame],
        completion: @escaping (String?, Error?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(framesToExport)
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        completion(jsonString, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "AnimationPersistence", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to string"]))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Save persisted frame marker IDs to UserDefaults (local memory only)
    /// - Parameter persistedIDs: Set of frame IDs to mark for export
    static func savePersistedFrameMarkers(_ persistedIDs: Set<UUID>) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(Array(persistedIDs))
            defaults.set(data, forKey: "persisted_frame_ids")
        } catch {
        }
    }
    
    /// Load persisted frame marker IDs from UserDefaults
    /// - Returns: Set of frame IDs that are marked for export
    static func loadPersistedFrameMarkers() -> Set<UUID> {
        guard let data = defaults.data(forKey: "persisted_frame_ids") else {
            return []
        }
        
        let decoder = JSONDecoder()
        if let uuids = try? decoder.decode([UUID].self, from: data) {
            return Set(uuids)
        }
        
        return []
    }
}

