////
////  ModuleProtocol.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI

/// Protocol that all modules in the Extend app must conform to.
/// Modules are self-contained features that can be added, removed, and reordered via the navbar.
public protocol AppModule: Identifiable, Hashable {
    /// Unique identifier for this module
    var id: UUID { get }
    
    /// Display name shown in the navbar
    var displayName: String { get }
    
    /// SF Symbol name for the navbar icon
    var iconName: String { get }
    
    /// Brief description of the module's purpose
    var description: String { get }
    
    /// Order in the navbar (lower numbers appear first)
    var order: Int { get set }
    
    /// Whether this module is currently visible in the navbar
    var isVisible: Bool { get set }
    
    /// Whether this module should hide the navigation bars (for full-screen experiences)
    var hidesNavBars: Bool { get }
    
    /// The view to display when this module is selected
    var moduleView: AnyView { get }
}

// MARK: - Default Hashable Implementation
extension AppModule {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    // Default: don't hide navbars
    public var hidesNavBars: Bool {
        return false
    }
}
