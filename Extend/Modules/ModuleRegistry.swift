////
////  ModuleRegistry.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Observation

/// Module ID Constants - Use these UUIDs to reference specific modules
/// NEVER use displayName or order for identifying modules in code
public struct ModuleIDs {
    /// Dashboard module - main landing page
    public static let dashboard = UUID(uuidString: "00000001-0000-0000-0000-000000000000")!
    
    /// Workouts module - workout management
    public static let workouts = UUID(uuidString: "00000002-0000-0000-0000-000000000000")!
    
    /// Timer module - rest timers
    public static let timer = UUID(uuidString: "00000003-0000-0000-0000-000000000000")!
    
    /// Progress module - progress tracking
    public static let progress = UUID(uuidString: "00000004-0000-0000-0000-000000000000")!
    
    /// Exercises module - exercise management with muscle groups and equipment
    public static let exercises = UUID(uuidString: "00000005-0000-0000-0000-000000000000")!
    
    /// Muscles module - muscle group management
    public static let muscles = UUID(uuidString: "00000006-0000-0000-0000-000000000000")!
    
    /// Equipment module - equipment management
    public static let equipment = UUID(uuidString: "00000007-0000-0000-0000-000000000000")!
    
    /// Settings module - app settings
    public static let settings = UUID(uuidString: "00000008-0000-0000-0000-000000000000")!
    
    /// Generate module - random workout generation
    public static let generate = UUID(uuidString: "00000009-0000-0000-0000-000000000000")!
    
    /// Quick Workout module - quick workout from exercises
    public static let quickWorkout = UUID(uuidString: "0000000A-0000-0000-0000-000000000000")!
    
    /// Voice Trainer module - speak text with customizable timing
    public static let voiceTrainer = UUID(uuidString: "0000000B-0000-0000-0000-000000000000")!
    
    /// Game 1 module - dog catching hearts game
    public static let game1 = UUID(uuidString: "0000000C-0000-0000-0000-000000000000")!
}

/// Module Registry - manages all registered modules in the app
@Observable
public final class ModuleRegistry {
    public static let shared = ModuleRegistry()
    
    public var registeredModules: [AnyAppModule] = []
    
    public var visibleModules: [AnyAppModule] {
        registeredModules.filter { $0.isVisible }
    }
    
    private init() {}
    
    /// Register a new module
    public func registerModule<M: AppModule>(_ module: M) {
        guard !registeredModules.contains(where: { $0.id == module.id }) else { return }
        registeredModules.append(AnyAppModule(module))
        registeredModules.sort { $0.order < $1.order }
    }
    
    /// Clear all modules (for testing)
    public func clearAllModules() {
        registeredModules.removeAll()
    }
    
    /// Get a module by ID
    public func moduleWithID(_ id: UUID) -> AnyAppModule? {
        registeredModules.first { $0.id == id }
    }
    
    /// Set module visibility
    public func setModuleVisibility(id: UUID, isVisible: Bool) {
        if let index = registeredModules.firstIndex(where: { $0.id == id }) {
            registeredModules[index].isVisible = isVisible
        }
    }
    
    /// Move a module up or down
    public func moveModule(id: UUID, direction: MoveDirection) {
        guard let currentIndex = registeredModules.firstIndex(where: { $0.id == id }) else { return }
        
        let newIndex: Int
        switch direction {
        case .up:
            newIndex = max(0, currentIndex - 1)
        case .down:
            newIndex = min(registeredModules.count - 1, currentIndex + 1)
        }
        
        registeredModules.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: newIndex > currentIndex ? newIndex + 1 : newIndex)
    }
    
    public enum MoveDirection {
        case up
        case down
    }
}

/// Type-erased module wrapper
public struct AnyAppModule: Identifiable, Hashable {
    public let id: UUID
    public var displayName: String
    public let iconName: String
    public let description: String
    public var order: Int
    public var isVisible: Bool
    public let hidesNavBars: Bool
    private let _moduleView: () -> AnyView
    
    public var moduleView: AnyView {
        _moduleView()
    }
    
    public init<M: AppModule>(_ module: M) {
        self.id = module.id
        self.displayName = module.displayName
        self.iconName = module.iconName
        self.description = module.description
        self.order = module.order
        self.isVisible = module.isVisible
        self.hidesNavBars = module.hidesNavBars
        self._moduleView = { module.moduleView }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: AnyAppModule, rhs: AnyAppModule) -> Bool {
        lhs.id == rhs.id
    }
}
