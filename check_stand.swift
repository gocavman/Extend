import Foundation

// Just print what Stand frame exists
if let data = UserDefaults.standard.data(forKey: "saved_animation_frames"),
   let jsonString = String(data: data, encoding: .utf8) {
    
    // Parse to find Stand frame
    if let jsonData = jsonString.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
        
        for frame in json {
            if let name = frame["name"] as? String, name == "Stand" {
                print("✅ Found Stand frame:")
                if let pose = frame["pose"] as? [String: Any] {
                    print("waistTorsoAngle: \(pose["waistTorsoAngle"] ?? "?")")
                    print("midTorsoAngle: \(pose["midTorsoAngle"] ?? "?")")
                    print("headAngle: \(pose["headAngle"] ?? "?")")
                    print("leftShoulderAngle: \(pose["leftShoulderAngle"] ?? "?")")
                    print("rightShoulderAngle: \(pose["rightShoulderAngle"] ?? "?")")
                    print("leftElbowAngle: \(pose["leftElbowAngle"] ?? "?")")
                    print("rightElbowAngle: \(pose["rightElbowAngle"] ?? "?")")
                    print("leftKneeAngle: \(pose["leftKneeAngle"] ?? "?")")
                    print("rightKneeAngle: \(pose["rightKneeAngle"] ?? "?")")
                    print("leftFootAngle: \(pose["leftFootAngle"] ?? "?")")
                    print("rightFootAngle: \(pose["rightFootAngle"] ?? "?")")
                    print("scale: \(pose["scale"] ?? "?")")
                    print("strokeThickness: \(pose["strokeThickness"] ?? "?")")
                    print("headRadiusMultiplier: \(pose["headRadiusMultiplier"] ?? "?")")
                }
                break
            }
        }
    }
} else {
    print("❌ No saved frames found")
}
