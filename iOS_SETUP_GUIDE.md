// iOS-FIRST SETUP & DEVELOPMENT GUIDE
// ====================================
//
// PLATFORM DETAILS
// ================
// Target: iOS 17+
// Future: Apple Watch (watchOS 10+)
// Minimum Device: iPhone SE (3rd gen)
// Maximum: iPhone Pro Max
// Orientation: Portrait (primary), Landscape (secondary for future expansion)
//
// WHAT WAS SIMPLIFIED
// ====================
// ✅ Removed macOS conditional compilation (#if os(macOS))
// ✅ Removed iPad/iPadOS support
// ✅ Using iOS-specific List style (.insetGrouped)
// ✅ Using iOS-specific toolbar placements (.navigationBarTrailing)
// ✅ All UI patterns optimized for iPhone screen sizes
//
// PROJECT STRUCTURE (CLEAN & FOCUSED)
// ====================================
// Extend/
// ├── Modules/
// │   ├── ModuleProtocol.swift .............. App module interface
// │   ├── ModuleRegistry.swift .............. Module management
// │   ├── WorkoutModule.swift ............... Sample module
// │   ├── TimerModule.swift ................. Sample module
// │   └── ProgressModule.swift .............. Sample module
// ├── Components/
// │   ├── ModuleNavBar.swift ................ Navbar component
// │   └── ModuleSettingsView.swift .......... Settings view (iOS optimized)
// ├── State/
// │   └── ModuleState.swift ................. App state management
// ├── ContentView.swift ..................... Main navigation coordinator
// ├── ExtendApp.swift ....................... App entry point
// └── CodeRules.swift ....................... Coding guidelines (iOS-first)
//
// DEVELOPMENT TIPS
// ================
// 1. Test on all iPhone sizes:
//    - iPhone SE (small)
//    - iPhone 14/15 (standard)
//    - iPhone 14/15 Pro Max (large)
//
// 2. Always test in:
//    - Light mode
//    - Dark mode
//    - With Dynamic Type enabled
//
// 3. Safe area considerations:
//    - Top: Notch or Dynamic Island
//    - Bottom: Home indicator or home bar
//    - Use .safeAreaInset() for persistent UI
//
// 4. Performance targeting:
//    - App launch: < 2 seconds
//    - Module switching: Instant
//    - Smooth 60 fps animations
//
// 5. Future Apple Watch considerations:
//    - ModuleRegistry is watch-compatible (@Observable)
//    - Keep state management framework-agnostic
//    - Prepare for HealthKit integration
//
// NEXT STEPS FOR FEATURES
// =======================
// Coming soon modules can be easily added:
// 1. Create YourModule.swift conforming to AppModule
// 2. Register in ContentView.registerSampleModules()
// 3. It automatically appears in navbar and settings
//
// Example:
//     public struct YourModule: AppModule {
//         public let id: UUID = UUID()
//         public let displayName: String = "Your Module"
//         public let iconName: String = "star"
//         public let description: String = "Description"
//         public var order: Int = 3
//         public var isVisible: Bool = true
//         public var moduleView: AnyView {
//             AnyView(YourModuleView())
//         }
//     }
//
// COLORS & DESIGN
// ===============
// Using explicit RGB values instead of systemColors for better compatibility:
// - Background: Color(red: 0.98, green: 0.98, blue: 1.0)
// - Gray backgrounds: Color(red: 0.96, green: 0.96, blue: 0.97)
// - Borders: Color(red: 0.92, green: 0.92, blue: 0.93)
//
// Automatically adapts to light/dark mode via SwiftUI
