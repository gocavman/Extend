import Foundation
import Observation
import SwiftUI
import UIKit

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

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
    private let imageFilenameKey = "dashboardHeaderImageFilename"
    private let legacyImageKey = "dashboardHeaderImageData"     // legacy — migration only
    private let imageStyleKey = "dashboardHeaderImageStyle"
    private let backgroundColorKey = "dashboardHeaderBackgroundColor"
    private let textColorKey = "dashboardHeaderTextColor"
    private let backgroundUseGradientKey = "dashboardHeaderBackgroundUseGradient"
    private let backgroundGradientSecondaryKey = "dashboardHeaderBackgroundGradientSecondary"
    private let isVisibleKey = "dashboardHeaderIsVisible"

    private static let imageFilename = "dashboard_header_image.jpg"

    private static var imageStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent(imageFilename)
    }

    var title: String
    /// In-memory image loaded from disk. Nil when no image is set.
    var imageData: Data?
    var imageStyle: HeaderImageStyle
    private var backgroundComponents: RGBAColor
    private var textComponents: RGBAColor
    private var backgroundGradientComponents: RGBAColor
    var backgroundUseGradient: Bool
    var isVisible: Bool

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
        let storedTitle = defaults.string(forKey: titleKey)
        title = storedTitle?.isEmpty == false ? storedTitle! : "Dashboard"

        // Load image from disk
        if defaults.string(forKey: imageFilenameKey) != nil {
            imageData = try? Data(contentsOf: DashboardHeaderState.imageStorageURL)
        } else if let legacyData = defaults.data(forKey: legacyImageKey) {
            // Migrate legacy blob to disk
            try? legacyData.write(to: DashboardHeaderState.imageStorageURL, options: .atomic)
            defaults.set(DashboardHeaderState.imageFilename, forKey: imageFilenameKey)
            defaults.removeObject(forKey: legacyImageKey)
            imageData = legacyData
        } else {
            imageData = nil
        }

        if let styleRaw = defaults.string(forKey: imageStyleKey),
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
        backgroundUseGradient = defaults.bool(forKey: backgroundUseGradientKey)
        isVisible = defaults.object(forKey: isVisibleKey) as? Bool ?? true
    }

    func updateTitle(_ newTitle: String) {
        title = newTitle
        defaults.set(newTitle, forKey: titleKey)
    }

    func updateImageData(_ data: Data?) {
        imageData = data
        if let data {
            try? data.write(to: DashboardHeaderState.imageStorageURL, options: .atomic)
            defaults.set(DashboardHeaderState.imageFilename, forKey: imageFilenameKey)
        } else {
            try? FileManager.default.removeItem(at: DashboardHeaderState.imageStorageURL)
            defaults.removeObject(forKey: imageFilenameKey)
        }
    }

    func updateImageStyle(_ style: HeaderImageStyle) {
        imageStyle = style
        defaults.set(style.rawValue, forKey: imageStyleKey)
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
        defaults.set(useGradient, forKey: backgroundUseGradientKey)
    }

    func updateTextColor(_ color: Color) {
        textComponents = RGBAColor(from: color)
        textComponents.save(to: textColorKey)
    }

    func updateIsVisible(_ visible: Bool) {
        isVisible = visible
        defaults.set(visible, forKey: isVisibleKey)
    }

    func resetDefaults() {
        title = "Dashboard"
        imageData = nil
        imageStyle = .rounded
        backgroundComponents = RGBAColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)
        textComponents = RGBAColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        backgroundGradientComponents = RGBAColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        backgroundUseGradient = false
        isVisible = true

        defaults.set(title, forKey: titleKey)
        try? FileManager.default.removeItem(at: DashboardHeaderState.imageStorageURL)
        defaults.removeObject(forKey: imageFilenameKey)
        defaults.set(imageStyle.rawValue, forKey: imageStyleKey)
        backgroundComponents.save(to: backgroundColorKey)
        textComponents.save(to: textColorKey)
        backgroundGradientComponents.save(to: backgroundGradientSecondaryKey)
        defaults.set(backgroundUseGradient, forKey: backgroundUseGradientKey)
        defaults.set(true, forKey: isVisibleKey)
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
            defaults.set(data, forKey: key)
        }
    }

    static func load(from key: String) -> RGBAColor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RGBAColor.self, from: data)
    }
}
