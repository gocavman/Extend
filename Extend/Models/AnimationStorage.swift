import Foundation

/// Manages animation storage
/// Loads animations ONLY from animations.json in the app bundle
/// This is the authoritative source for all animations
struct AnimationStorage {
    static let shared = AnimationStorage()
    
    // MARK: - Load Frames from Bundle
    
    /// Load all animation frames from Bundle's animations.json
    /// This is the authoritative source - no Document storage, no UserDefaults
    func loadFrames() -> [AnimationFrame] {
        // Load ONLY from Bundle - this is the single source of truth
        if let bundleURL = Bundle.main.url(forResource: "animations", withExtension: "json") {
            do {
                let data = try Data(contentsOf: bundleURL)
                let decoder = JSONDecoder()
                let frames = try decoder.decode([AnimationFrame].self, from: data)
                print("✓ Loaded \(frames.count) frames from Bundle (animations.json)")
                return frames
            } catch {
                print("✗ Error loading from Bundle: \(error.localizedDescription)")
                return []
            }
        }
        
        print("ℹ Bundle/animations.json not found")
        return []
    }
    
    // MARK: - Export Frames
    
    /// Export frames to Documents folder for manual integration into animations.json
    func exportFrames(_ frames: [AnimationFrame]) -> URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportURL = documentsURL.appendingPathComponent("exported_frames.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(frames)
            try data.write(to: exportURL, options: .atomic)
            print("✓ Exported \(frames.count) frames to Documents/exported_frames.json")
            print("  Copy this file's contents to animations.json to persist")
            return exportURL
        } catch {
            print("✗ Error exporting frames: \(error)")
            return nil
        }
    }
    
    // MARK: - Debug
    
    /// Print storage location (Bundle only)
    func printStorageLocation() {
        if let bundleURL = Bundle.main.url(forResource: "animations", withExtension: "json") {
            print("📁 Animation Storage Location (Bundle):")
            print("   \(bundleURL.path)")
        }
    }
}
