import SwiftUI

/// Manages stick figure appearance colors that persist in UserDefaults
@Observable
class StickFigureAppearance {
    static let shared = StickFigureAppearance()
    
    private let headColorKey = "appearance_headColor"
    private let torsoColorKey = "appearance_torsoColor"
    private let leftUpperArmColorKey = "appearance_leftUpperArmColor"
    private let rightUpperArmColorKey = "appearance_rightUpperArmColor"
    private let leftLowerArmColorKey = "appearance_leftLowerArmColor"
    private let rightLowerArmColorKey = "appearance_rightLowerArmColor"
    private let leftUpperLegColorKey = "appearance_leftUpperLegColor"
    private let rightUpperLegColorKey = "appearance_rightUpperLegColor"
    private let leftLowerLegColorKey = "appearance_leftLowerLegColor"
    private let rightLowerLegColorKey = "appearance_rightLowerLegColor"
    private let handColorKey = "appearance_handColor"
    private let footColorKey = "appearance_footColor"
    private let jointColorKey = "appearance_jointColor"
    
    var headColor: Color {
        get { colorFromKey(headColorKey, default: .black) }
        set { saveColor(newValue, to: headColorKey) }
    }
    
    var torsoColor: Color {
        get { colorFromKey(torsoColorKey, default: .black) }
        set { saveColor(newValue, to: torsoColorKey) }
    }
    
    var leftUpperArmColor: Color {
        get { colorFromKey(leftUpperArmColorKey, default: .black) }
        set { saveColor(newValue, to: leftUpperArmColorKey) }
    }
    
    var rightUpperArmColor: Color {
        get { colorFromKey(rightUpperArmColorKey, default: .black) }
        set { saveColor(newValue, to: rightUpperArmColorKey) }
    }
    
    var leftLowerArmColor: Color {
        get { colorFromKey(leftLowerArmColorKey, default: .black) }
        set { saveColor(newValue, to: leftLowerArmColorKey) }
    }
    
    var rightLowerArmColor: Color {
        get { colorFromKey(rightLowerArmColorKey, default: .black) }
        set { saveColor(newValue, to: rightLowerArmColorKey) }
    }
    
    var leftUpperLegColor: Color {
        get { colorFromKey(leftUpperLegColorKey, default: .black) }
        set { saveColor(newValue, to: leftUpperLegColorKey) }
    }
    
    var rightUpperLegColor: Color {
        get { colorFromKey(rightUpperLegColorKey, default: .black) }
        set { saveColor(newValue, to: rightUpperLegColorKey) }
    }
    
    var leftLowerLegColor: Color {
        get { colorFromKey(leftLowerLegColorKey, default: .black) }
        set { saveColor(newValue, to: leftLowerLegColorKey) }
    }
    
    var rightLowerLegColor: Color {
        get { colorFromKey(rightLowerLegColorKey, default: .black) }
        set { saveColor(newValue, to: rightLowerLegColorKey) }
    }
    
    var handColor: Color {
        get { colorFromKey(handColorKey, default: .black) }
        set { saveColor(newValue, to: handColorKey) }
    }
    
    var footColor: Color {
        get { colorFromKey(footColorKey, default: .black) }
        set { saveColor(newValue, to: footColorKey) }
    }
    
    var jointColor: Color {
        get { colorFromKey(jointColorKey, default: .blue) }
        set { saveColor(newValue, to: jointColorKey) }
    }
    
    // MARK: - Helper Methods
    
    private func colorFromKey(_ key: String, default defaultColor: Color) -> Color {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decodedColor = try? JSONDecoder().decode(ColorData.self, from: data) else {
            return defaultColor
        }
        return decodedColor.toColor()
    }
    
    private func saveColor(_ color: Color, to key: String) {
        let colorData = ColorData(from: color)
        if let encoded = try? JSONEncoder().encode(colorData) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    /// Apply appearance colors to a StickFigure2D instance
    func applyToStickFigure(_ figure: inout StickFigure2D) {
        figure.headColor = headColor
        figure.torsoColor = torsoColor
        figure.leftUpperArmColor = leftUpperArmColor
        figure.rightUpperArmColor = rightUpperArmColor
        figure.leftLowerArmColor = leftLowerArmColor
        figure.rightLowerArmColor = rightLowerArmColor
        figure.leftUpperLegColor = leftUpperLegColor
        figure.rightUpperLegColor = rightUpperLegColor
        figure.leftLowerLegColor = leftLowerLegColor
        figure.rightLowerLegColor = rightLowerLegColor
        figure.handColor = handColor
        figure.footColor = footColor
        figure.jointColor = jointColor
    }
    
    /// Reset all colors to default
    func resetToDefaults() {
        headColor = .black
        torsoColor = .black
        leftUpperArmColor = .black
        rightUpperArmColor = .black
        leftLowerArmColor = .black
        rightLowerArmColor = .black
        leftUpperLegColor = .black
        rightUpperLegColor = .black
        leftLowerLegColor = .black
        rightLowerLegColor = .black
        handColor = .black
        footColor = .black
        jointColor = .blue
    }
}

/// Helper struct for encoding/decoding Color to UserDefaults
struct ColorData: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    
    init(from color: Color) {
        // Convert SwiftUI Color to RGBA components
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }
    
    func toColor() -> Color {
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
