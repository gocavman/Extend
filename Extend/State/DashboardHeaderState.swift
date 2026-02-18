import Foundation
import Observation
import SwiftUI
import UIKit

public enum HeaderImageStyle: String, CaseIterable, Codable {
    case square
    case rounded
    case circle

    var displayName: String {
        switch self {
        case .square: return "Square"
        case .rounded: return "Rounded"
        case .circle: return "Circle"
        }
    }
}

@Observable
final class DashboardHeaderState {
    static let shared = DashboardHeaderState()

    private let titleKey = "dashboardHeaderTitle"
    private let imageKey = "dashboardHeaderImageData"
    private let imageStyleKey = "dashboardHeaderImageStyle"
    private let backgroundColorKey = "dashboardHeaderBackgroundColor"
    private let textColorKey = "dashboardHeaderTextColor"
    private let backgroundUseGradientKey = "dashboardHeaderBackgroundUseGradient"
    private let backgroundGradientSecondaryKey = "dashboardHeaderBackgroundGradientSecondary"

    var title: String
    var imageData: Data?
    var imageStyle: HeaderImageStyle
    private var backgroundComponents: RGBAColor
    private var textComponents: RGBAColor
    private var backgroundGradientComponents: RGBAColor
    var backgroundUseGradient: Bool

    var backgroundColor: Color {
        Color(.sRGB,
              red: backgroundComponents.red,
              green: backgroundComponents.green,
              blue: backgroundComponents.blue,
              opacity: backgroundComponents.alpha)
    }

    var backgroundGradientSecondaryColor: Color {
        Color(.sRGB,
              red: backgroundGradientComponents.red,
              green: backgroundGradientComponents.green,
              blue: backgroundGradientComponents.blue,
              opacity: backgroundGradientComponents.alpha)
    }

    var textColor: Color {
        Color(.sRGB,
              red: textComponents.red,
              green: textComponents.green,
              blue: textComponents.blue,
              opacity: textComponents.alpha)
    }

    private init() {
        let storedTitle = UserDefaults.standard.string(forKey: titleKey)
        title = storedTitle?.isEmpty == false ? storedTitle! : "Dashboard"
        imageData = UserDefaults.standard.data(forKey: imageKey)

        if let styleRaw = UserDefaults.standard.string(forKey: imageStyleKey),
           let style = HeaderImageStyle(rawValue: styleRaw) {
            imageStyle = style
        } else {
            imageStyle = .rounded
        }

        backgroundComponents = RGBAColor.load(from: backgroundColorKey)
            ?? RGBAColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)
        textComponents = RGBAColor.load(from: textColorKey)
            ?? RGBAColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        backgroundGradientComponents = RGBAColor.load(from: backgroundGradientSecondaryKey)
            ?? RGBAColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        backgroundUseGradient = UserDefaults.standard.bool(forKey: backgroundUseGradientKey)
    }

    func updateTitle(_ newTitle: String) {
        title = newTitle
        UserDefaults.standard.set(newTitle, forKey: titleKey)
    }

    func updateImageData(_ data: Data?) {
        imageData = data
        if let data {
            UserDefaults.standard.set(data, forKey: imageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: imageKey)
        }
    }

    func updateImageStyle(_ style: HeaderImageStyle) {
        imageStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: imageStyleKey)
    }

    func updateBackgroundColor(_ color: Color) {
        backgroundComponents = RGBAColor(from: color)
        backgroundComponents.save(to: backgroundColorKey)
    }

    func updateBackgroundGradientSecondaryColor(_ color: Color) {
        backgroundGradientComponents = RGBAColor(from: color)
        backgroundGradientComponents.save(to: backgroundGradientSecondaryKey)
    }

    func updateBackgroundUseGradient(_ useGradient: Bool) {
        backgroundUseGradient = useGradient
        UserDefaults.standard.set(useGradient, forKey: backgroundUseGradientKey)
    }

    func updateTextColor(_ color: Color) {
        textComponents = RGBAColor(from: color)
        textComponents.save(to: textColorKey)
    }

    func resetDefaults() {
        title = "Dashboard"
        imageData = nil
        imageStyle = .rounded
        backgroundComponents = RGBAColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)
        textComponents = RGBAColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        backgroundGradientComponents = RGBAColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        backgroundUseGradient = false

        UserDefaults.standard.set(title, forKey: titleKey)
        UserDefaults.standard.removeObject(forKey: imageKey)
        UserDefaults.standard.set(imageStyle.rawValue, forKey: imageStyleKey)
        backgroundComponents.save(to: backgroundColorKey)
        textComponents.save(to: textColorKey)
        backgroundGradientComponents.save(to: backgroundGradientSecondaryKey)
        UserDefaults.standard.set(backgroundUseGradient, forKey: backgroundUseGradientKey)
    }
}

private struct RGBAColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(from color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
    }

    func save(to key: String) {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load(from key: String) -> RGBAColor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RGBAColor.self, from: data)
    }
}
