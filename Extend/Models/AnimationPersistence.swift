import Foundation

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
            UserDefaults.standard.set(data, forKey: "persisted_frame_ids")
            print("✓ Saved persisted frame markers to local memory")
        } catch {
            print("✗ Error saving persisted frame markers: \(error)")
        }
    }
    
    /// Load persisted frame marker IDs from UserDefaults
    /// - Returns: Set of frame IDs that are marked for export
    static func loadPersistedFrameMarkers() -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: "persisted_frame_ids") else {
            return []
        }
        
        let decoder = JSONDecoder()
        if let uuids = try? decoder.decode([UUID].self, from: data) {
            print("✓ Loaded persisted frame markers from local memory")
            return Set(uuids)
        }
        
        return []
    }
}

