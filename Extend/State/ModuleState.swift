////
////  ModuleState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Observation
import UIKit

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

/// Navbar position preference
public enum NavBarPosition: String, CaseIterable {
    case top = "Top"
    case bottom = "Bottom"
    case both = "Top & Bottom"
}

/// Gradient direction for navigation bar
public enum GradientDirection: String, CaseIterable, Codable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"

    var startPoint: UnitPoint {
        switch self {
        case .horizontal: return .leading
        case .vertical: return .top
        }
    }

    var endPoint: UnitPoint {
        switch self {
        case .horizontal: return .trailing
        case .vertical: return .bottom
        }
    }
}

/// Central state management for the app, coordinating module navigation and configuration.
@Observable
public final class ModuleState {
    public static let shared = ModuleState()

    /// Currently selected module ID
    public var selectedModuleID: UUID?

    /// Navigation path for nested navigation within modules
    public var navigationPath: [String] = []

    /// Navbar position preference (top or bottom)
    public var navBarPosition: NavBarPosition = .bottom

    /// Module IDs to show in top navbar
    public var topNavBarModules: [UUID] = []

    /// Module IDs to show in bottom navbar
    public var bottomNavBarModules: [UUID] = []

    private let topNavBarKey = "topNavBarModules"
    private let bottomNavBarKey = "bottomNavBarModules"

    // MARK: - NavBar Appearance

    public var navBarBackgroundColor: Color
    public var navBarTextColor: Color
    public var navBarUseGradient: Bool
    public var navBarGradientSecondaryColor: Color
    public var navBarGradientDirection: GradientDirection

    private let navBarBackgroundColorKey = "navBarBackgroundColor"
    private let navBarTextColorKey = "navBarTextColor"
    private let navBarUseGradientKey = "navBarUseGradient"
    private let navBarGradientSecondaryColorKey = "navBarGradientSecondaryColor"
    private let navBarGradientDirectionKey = "navBarGradientDirection"

    // MARK: - Dashboard Appearance

    public var dashboardBackgroundColor: Color?
    public var dashboardUseGradient: Bool
    public var dashboardGradientSecondaryColor: Color
    public var dashboardGradientDirection: GradientDirection

    private let dashboardBackgroundColorKey = "dashboardBackgroundColor"
    private let dashboardUseGradientKey = "dashboardUseGradient"
    private let dashboardGradientSecondaryColorKey = "dashboardGradientSecondaryColor"
    private let dashboardGradientDirectionKey = "dashboardGradientDirection"

    private init() {
        navBarBackgroundColor = ModuleState.loadColor(for: navBarBackgroundColorKey)
            ?? Color(red: 0.98, green: 0.98, blue: 1.0)
        navBarTextColor = ModuleState.loadColor(for: navBarTextColorKey)
            ?? Color.black
        navBarUseGradient = defaults.bool(forKey: navBarUseGradientKey)
        navBarGradientSecondaryColor = ModuleState.loadColor(for: navBarGradientSecondaryColorKey)
            ?? Color(red: 0.96, green: 0.96, blue: 0.97)

        if let dirRaw = defaults.string(forKey: navBarGradientDirectionKey),
           let dir = GradientDirection(rawValue: dirRaw) {
            navBarGradientDirection = dir
        } else {
            navBarGradientDirection = .horizontal
        }

        dashboardBackgroundColor = ModuleState.loadColor(for: dashboardBackgroundColorKey)
        dashboardUseGradient = defaults.bool(forKey: dashboardUseGradientKey)
        dashboardGradientSecondaryColor = ModuleState.loadColor(for: dashboardGradientSecondaryColorKey)
            ?? Color(UIColor.secondarySystemBackground)

        if let dirRaw = defaults.string(forKey: dashboardGradientDirectionKey),
           let dir = GradientDirection(rawValue: dirRaw) {
            dashboardGradientDirection = dir
        } else {
            dashboardGradientDirection = .horizontal
        }

        loadNavBarPreferences()
    }

    // MARK: - Navigation Management

    /// Select a module by ID
    public func selectModule(_ id: UUID) {
        selectedModuleID = id
        navigationPath.removeAll()
    }

    /// Navigate to a specific view within the selected module
    public func navigateTo(_ destination: String) {
        navigationPath.append(destination)
    }

    /// Go back in the navigation stack
    public func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    /// Reset all navigation
    public func resetNavigation() {
        selectedModuleID = nil
        navigationPath.removeAll()
    }

    // MARK: - Settings Management

    /// Update which modules show in top navbar
    public func setTopNavBarModules(_ modules: [UUID]) {
        topNavBarModules = Array(modules.prefix(5))
        saveNavBarPreferences()
    }

    /// Update which modules show in bottom navbar
    public func setBottomNavBarModules(_ modules: [UUID]) {
        bottomNavBarModules = Array(modules.prefix(5))
        saveNavBarPreferences()
    }

    // MARK: - NavBar Appearance Updates

    public func updateNavBarBackgroundColor(_ color: Color) {
        navBarBackgroundColor = color
        ModuleState.saveColor(color, for: navBarBackgroundColorKey)
    }

    public func updateNavBarTextColor(_ color: Color) {
        navBarTextColor = color
        ModuleState.saveColor(color, for: navBarTextColorKey)
    }

    public func updateNavBarUseGradient(_ useGradient: Bool) {
        navBarUseGradient = useGradient
        defaults.set(useGradient, forKey: navBarUseGradientKey)
    }

    public func updateNavBarGradientSecondaryColor(_ color: Color) {
        navBarGradientSecondaryColor = color
        ModuleState.saveColor(color, for: navBarGradientSecondaryColorKey)
    }

    public func updateNavBarGradientDirection(_ direction: GradientDirection) {
        navBarGradientDirection = direction
        defaults.set(direction.rawValue, forKey: navBarGradientDirectionKey)
    }

    // MARK: - Dashboard Appearance Updates

    public func updateDashboardBackgroundColor(_ color: Color?) {
        dashboardBackgroundColor = color
        if let color {
            ModuleState.saveColor(color, for: dashboardBackgroundColorKey)
        } else {
            defaults.removeObject(forKey: dashboardBackgroundColorKey)
        }
    }

    public func updateDashboardUseGradient(_ useGradient: Bool) {
        dashboardUseGradient = useGradient
        defaults.set(useGradient, forKey: dashboardUseGradientKey)
    }

    public func updateDashboardGradientSecondaryColor(_ color: Color) {
        dashboardGradientSecondaryColor = color
        ModuleState.saveColor(color, for: dashboardGradientSecondaryColorKey)
    }

    public func updateDashboardGradientDirection(_ direction: GradientDirection) {
        dashboardGradientDirection = direction
        defaults.set(direction.rawValue, forKey: dashboardGradientDirectionKey)
    }

    public func resetNavBarAppearance() {
        let defaultBg = Color(red: 0.98, green: 0.98, blue: 1.0)
        let defaultSecondary = Color(red: 0.96, green: 0.96, blue: 0.97)
        navBarBackgroundColor = defaultBg
        navBarTextColor = .black
        navBarUseGradient = false
        navBarGradientSecondaryColor = defaultSecondary
        navBarGradientDirection = .horizontal
        ModuleState.saveColor(defaultBg, for: navBarBackgroundColorKey)
        ModuleState.saveColor(.black, for: navBarTextColorKey)
        defaults.set(false, forKey: navBarUseGradientKey)
        ModuleState.saveColor(defaultSecondary, for: navBarGradientSecondaryColorKey)
        defaults.removeObject(forKey: navBarGradientDirectionKey)
    }

    private func saveNavBarPreferences() {
        defaults.set(topNavBarModules.map { $0.uuidString }, forKey: topNavBarKey)
        defaults.set(bottomNavBarModules.map { $0.uuidString }, forKey: bottomNavBarKey)
    }

    private func loadNavBarPreferences() {
        if let topStrings = defaults.stringArray(forKey: topNavBarKey) {
            topNavBarModules = topStrings.compactMap { UUID(uuidString: $0) }
        }
        if let bottomStrings = defaults.stringArray(forKey: bottomNavBarKey) {
            bottomNavBarModules = bottomStrings.compactMap { UUID(uuidString: $0) }
        }
    }
}

// MARK: - Color Persistence

private struct NavBarRGBAColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

private extension ModuleState {
    static func saveColor(_ color: Color, for key: String) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgba = NavBarRGBAColor(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        if let data = try? JSONEncoder().encode(rgba) {
            defaults.set(data, forKey: key)
        }
    }

    static func loadColor(for key: String) -> Color? {
        guard let data = defaults.data(forKey: key),
              let rgba = try? JSONDecoder().decode(NavBarRGBAColor.self, from: data) else {
            return nil
        }
        return Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
