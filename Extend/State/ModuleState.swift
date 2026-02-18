////
////  ModuleState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Observation
import UIKit

/// Navbar position preference
public enum NavBarPosition: String, CaseIterable {
    case top = "Top"
    case bottom = "Bottom"
    case both = "Top & Bottom"
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

    private let navBarBackgroundColorKey = "navBarBackgroundColor"
    private let navBarTextColorKey = "navBarTextColor"
    private let navBarUseGradientKey = "navBarUseGradient"
    private let navBarGradientSecondaryColorKey = "navBarGradientSecondaryColor"

    private init() {
        navBarBackgroundColor = ModuleState.loadColor(for: navBarBackgroundColorKey)
            ?? Color(red: 0.98, green: 0.98, blue: 1.0)
        navBarTextColor = ModuleState.loadColor(for: navBarTextColorKey)
            ?? Color.black
        navBarUseGradient = UserDefaults.standard.bool(forKey: navBarUseGradientKey)
        navBarGradientSecondaryColor = ModuleState.loadColor(for: navBarGradientSecondaryColorKey)
            ?? Color(red: 0.96, green: 0.96, blue: 0.97)

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
        UserDefaults.standard.set(useGradient, forKey: navBarUseGradientKey)
    }

    public func updateNavBarGradientSecondaryColor(_ color: Color) {
        navBarGradientSecondaryColor = color
        ModuleState.saveColor(color, for: navBarGradientSecondaryColorKey)
    }

    private func saveNavBarPreferences() {
        UserDefaults.standard.set(topNavBarModules.map { $0.uuidString }, forKey: topNavBarKey)
        UserDefaults.standard.set(bottomNavBarModules.map { $0.uuidString }, forKey: bottomNavBarKey)
    }

    private func loadNavBarPreferences() {
        if let topStrings = UserDefaults.standard.stringArray(forKey: topNavBarKey) {
            topNavBarModules = topStrings.compactMap { UUID(uuidString: $0) }
        }
        if let bottomStrings = UserDefaults.standard.stringArray(forKey: bottomNavBarKey) {
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
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadColor(for key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rgba = try? JSONDecoder().decode(NavBarRGBAColor.self, from: data) else {
            return nil
        }
        return Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
