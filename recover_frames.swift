import Foundation

print("🔍 Checking UserDefaults for saved animation frames...")

let defaults = UserDefaults.standard

if let data = defaults.data(forKey: "saved_animation_frames") {
    print("✅ Found data in UserDefaults (\(data.count) bytes)")
    
    if let jsonString = String(data: data, encoding: .utf8) {
        print("\n📄 Raw JSON data:")
        print(jsonString)
    } else {
        print("❌ Could not convert data to string")
    }
} else {
    print("❌ No data found in UserDefaults for key 'saved_animation_frames'")
}

print("\n✅ Check completed")
