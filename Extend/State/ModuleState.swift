////
////  ModuleState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Observation

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
    
    private init() {
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
