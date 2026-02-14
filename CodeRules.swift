////zΩΩ
////
////  CodeRules.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////
///
////////////

/*
 EXTEND APP - CODING RULES & GUIDELINES
 =======================================
 iOS-First Workout App (iPhone & Apple Watch)
 
 These rules ensure consistency, maintainability, and scalability across the modular workout app.
 Review these before each code update.
 
 PLATFORM SCOPE
 ==============
 This app is built for iOS 17+ and Apple Watch (future).
 - No macOS or iPad support needed
 - Optimize for iPhone screen sizes (compact to regular)
 - Keep future watchOS support in mind for state management
 - Use iOS-specific UI patterns (no conditional compilation needed)
 
 ARCHITECTURE & DESIGN PATTERNS
 ==============================
 1. Modular Architecture
    - Use protocol-based design for extensibility
    - Each module is self-contained and registers with ModuleRegistry
    - Avoid tight coupling between modules
    - Use dependency injection for module dependencies
 
 2. State Management
    - Use @Observable for app-wide state (iOS 17+)
    - Use @State for local view state
    - Persist critical data with SwiftData (module order, visibility)
    - Use @StateObject for long-lived objects
 
 3. Navigation
    - Use NavigationStack for iOS 16+ navigation
    - Central navigation state managed in ContentView
    - Modules communicate via ModuleRegistry, not direct references
 
 NAMING CONVENTIONS
 ==================
 1. Files & Types
    - Types use PascalCase (e.g., WorkoutModule, ModuleRegistry)
    - Files match primary type name (ModuleRegistry.swift)
    - Protocol names can use -able/-ible suffixes (Workable, Identifiable)
 
 2. Variables & Functions
    - Variables use camelCase (e.g., selectedModuleID, isVisible)
    - Functions use camelCase (e.g., registerModule(), updateOrder())
    - Boolean properties use is/has/should prefixes (e.g., isActive, hasError)
 
 3. Constants
    - Global constants use UPPER_SNAKE_CASE (e.g., DEFAULT_MODULE_ORDER)
    - Private constants use camelCase (e.g., animationDuration)
 
 CODE STRUCTURE & FORMATTING
 ============================
 1. Spacing & Indentation
    - Use 4-space indentation (automatic in Xcode)
    - One blank line between properties and methods
    - Two blank lines between type definitions
 
 2. Access Control
    - Default to private, expand to internal/public only when needed
    - Use fileprivate for file-scoped helpers
    - Mark public APIs clearly with documentation
 
 3. Documentation
    - Document all public types with /// comments
    - Include brief description and any important parameters
    - Use MARK: - comments to organize large files
 
 4. Extensions
    - Organize extensions by functionality (separate files if large)
    - Use MARK: - to group related extensions
    - Example: MARK: - View Lifecycle, MARK: - Gestures
 
 SWIFTUI BEST PRACTICES
 =======================
 1. View Composition
    - Keep views focused (< 200 lines when possible)
    - Extract sub-views into separate files for reusability
    - Use @ViewBuilder for complex conditional layouts
 
 2. Performance
    - Use @State sparingly, prefer @Observable for complex state
    - Memoize expensive computations with @State or private properties
    - Avoid unnecessary view refreshes with proper binding usage
 
 3. Modifiers
    - Chain modifiers logically (layout → appearance → interaction)
    - Extract complex modifier chains into extension methods
    - Use .id() to force view updates when needed
 
 4. Safe Area & Spacing
    - Respect safe area for tab bars and notches
    - Use padding and spacing for rhythm (8, 12, 16, 24 pt)
    - Design for both portrait and landscape
 
 ERROR HANDLING
 ==============
 1. Use do-try-catch for error-prone operations
 2. Provide user-friendly error messages
 3. Log errors appropriately (print for debug, consider analytics in production)
 4. Never silently fail - always communicate status to user
 
 TESTING & VALIDATION
 =====================
 1. Write unit tests for module registration and state changes
 2. Test module reordering and visibility toggling
 3. Validate all modules conform to ModuleProtocol
 4. Use SwiftData test models for persistence tests
 5. Test on various iPhone sizes (SE, regular, Pro Max)
 
 MODULE PROTOCOL REQUIREMENTS
 =============================
 All modules must:
 1. Conform to AppModule protocol
 2. Have unique id (UUID) - use ModuleIDs constants, NEVER UUID()
 3. Provide displayName, icon, and description
 4. Be Identifiable and Hashable
 5. Return a View via moduleView property
 6. Support order/visibility management
 7. Be registered in ModuleRegistry at app launch
 8. Optimize layout for all iPhone screen sizes
 
 CRITICAL: MODULE IDENTIFICATION
 ================================
 🔴 NEVER use displayName, order, or other strings for module identification
 ✅ ALWAYS use ModuleIDs constants for referencing specific modules
 
 ModuleIDs are defined in ModuleRegistry.swift as static UUID constants:
 - ModuleIDs.dashboard
 - ModuleIDs.workouts
 - ModuleIDs.timer
 - ModuleIDs.progress
 - ModuleIDs.exercises
 - ModuleIDs.muscles
 - ModuleIDs.equipment
 - ModuleIDs.settings
 
 When you need to identify a module:
 ❌ WRONG: if module.displayName == "Dashboard"
 ❌ WRONG: registry.registeredModules.first(where: { $0.displayName == "Settings" })
 ✅ RIGHT: if moduleID == ModuleIDs.dashboard
 ✅ RIGHT: if module.id == ModuleIDs.settings
 
 This ensures identification is reliable and refactoring-safe.
 
 PERFORMANCE TARGETS (iOS)
 ==========================
 1. App launch: < 2 seconds
 2. Module switching: instant (< 100ms)
 3. Reordering: smooth 60fps animation
 4. Data persistence: < 500ms for module configuration
 5. Memory: < 100MB baseline
 6. Battery: Minimize location/motion tracking overhead
 
 iOS-SPECIFIC CONSIDERATIONS
 ============================
 1. Always use safe area padding for notch and home indicator
 2. Support dark mode (test with @Environment(\.colorScheme))
 3. Use HapticFeedback for module selection/reordering
 4. Test orientation changes (portrait only for MVP)
 5. Handle app lifecycle (background, foreground, suspend)
 6. Prepare for HealthKit integration (future modules)
*/
