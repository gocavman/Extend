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

// MARK: - DEVELOPER WORKFLOW GUIDES

/*
 HOW TO CREATE A NEW ANIMATION/FRAME & LEVEL
 =============================================
 
 An Animation is a sequence of frames that represents a workout movement.
 Each animation can be associated with a level in the game.
 
 STEP 1: CREATE ANIMATION FRAMES IN THE 2D STICK FIGURE EDITOR
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 1. Open the app and navigate to "Animator" module
 2. Click "Create Custom Animation" button
 3. Adjust the stick figure to the first pose of your animation
 4. Click "Save Frame" button
 5. Enter:
    - Frame Name: The name of the animation (e.g., "Push Ups", "Jump")
    - Frame Number: 1 (for the first frame)
 6. Repeat steps 3-5 for each pose in the sequence (frame 2, 3, 4, etc.)
 7. Once all frames are created, close the editor
    → All frames are automatically saved to animations.json in Bundle
 
 STEP 2: VERIFY FRAMES IN animations.json
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 File: Extend/animations.json
 
 Your new frames should appear as objects with:
 - "name": "Push Ups" (matches your Frame Name)
 - "frameNumber": 1, 2, 3, 4 (matches your Frame Numbers)
 - "pose": { all the joint angles and colors }
 
 STEP 3: CREATE THE NEW LEVEL IN Game1Module.swift
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 File: Extend/Modules/Game1Module.swift
 
 1. Find the ACTION_CONFIGS array (around line 100-300)
 2. Add a new ActionConfig entry at the end:
 
    ActionConfig(
        id: "pushup",                           // Unique lowercase ID
        displayName: "Push Ups",                // User-visible name
        unlockLevel: 7,                         // Level number where this unlocks
        pointsPerCompletion: 7,                 // Points awarded
        animationFrames: [1, 2, 3, 4, 3, 2],   // Sequence of frame numbers
        baseFrameInterval: 0.4,                 // Seconds between frames
        variableTiming: nil,                    // Optional: frame-specific timings
        flipMode: .none,                        // .none, .random, or .alternating
        supportsSpeedBoost: true,               // Can speed boost be applied?
        imagePrefix: "pushup",                  // Legacy image for fallback
        allowMovement: true,                    // Can player move during action?
        stickFigureAnimation: StickFigureAnimationConfig(
            animationName: "Push Ups",          // MUST match Frame Name from Step 1
            frameNumbers: [1, 2, 3, 4, 3, 2],  // Frame sequence to use
            baseFrameInterval: 0.4
        )
    )
 
 STEP 4: ADD LEVEL TO GAME MAP
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 File: Extend/Modules/Game1Module.swift
 
 Find the mapTiles array (stores level positions on the map):
 Add entry for your new level:
 
    mapTiles.append(StickFigureMapTile(
        id: UUID(),
        level: 7,                 // Must match unlockLevel from ACTION_CONFIGS
        position: .init(x: 50, y: 200),  // Screen coordinates
        isCompleted: false
    ))
 
 STEP 5: VERIFY IN GAME1 MODULE
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 1. Build and run the app
 2. Go to Game 1 module
 3. You should see the new level on the map
 4. Level unlocks when previous level is completed
 5. Perform the action and verify the animation plays correctly
 6. Verify points are awarded
 
 TROUBLESHOOTING:
 - Animation doesn't play: Check animationName matches Frame Name exactly (case-sensitive)
 - Points not awarded: Verify unlockLevel is reached and pointsPerCompletion is set
 - Level not on map: Check mapTiles has entry with matching level number
 - Wrong animation plays: Check frameNumbers in ACTION_CONFIGS matches your Frame Numbers

 QUICK REFERENCE: GAMEPLAY CHARACTER SIZE
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 The stick figure character size in gameplay is defined in 3 places in Game1Module.swift.
 To adjust the character size, change all 3 locations to maintain consistency:
 
 1. STAND FRAME (Standing still - around line 3176):
    StickFigure2DView(figure: standFrame, canvasSize: CGSize(width: 150, height: 225))
        .frame(width: 150, height: 225)
 
 2. MOVE FRAMES (Walking/running - around line 3215):
    StickFigure2DView(figure: gameState.moveFrames[moveIndex], canvasSize: CGSize(width: 150, height: 225))
        .frame(width: 150, height: 225)
 
 3. ACTION FRAMES (Push ups, exercises, etc. - around line 3129):
    StickFigure2DView(figure: stickFigure, canvasSize: CGSize(width: 150, height: 225))
        .frame(width: 150, height: 225)
 
 To resize the character, change both the canvasSize CGSize and the .frame() modifier width/height.
 Keep the 2:3 aspect ratio (width:height) for proper proportions.
 
 Examples:
   - Smaller (50% of current): CGSize(width: 75, height: 112)
   - Current (100%): CGSize(width: 150, height: 225) ✅
   - Larger (150% of current): CGSize(width: 225, height: 337)


 HOW TO CREATE NEW CATCHABLES
 =============================
 
 Catchables are collectible items in the game (health, points, buffs, etc.)
 They appear throughout the game and must be wired into multiple systems.
 
 STEP 1: DEFINE THE CATCHABLE TYPE
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 File: Extend/Models/Equipment.swift (or new file if not a equipment type)
 
 Add to the Equipment enum:
 
    case myNewCatchable  // Unique identifier
 
 Then add properties:
 
    var displayName: String {
        switch self {
        case .myNewCatchable:
            return "My Catchable"
        // ... existing cases ...
        }
    }
    
    var iconName: String {
        switch self {
        case .myNewCatchable:
            return "icon_name"  // Must exist in Assets.xcassets
        // ... existing cases ...
        }
    }
 
 STEP 2: ADD ASSET IMAGE
 ━━━━━━━━━━━━━━━━━━━━━━
 1. Prepare image file (PNG recommended)
 2. In Xcode: Assets.xcassets
 3. Drag image into assets folder
 4. Rename to match iconName from Step 1
 5. Set appropriate scale (1x, 2x, 3x for different devices)
 
 STEP 3: WIRE INTO GAME LOGIC
 ━━━━━━━━━━━━━━━━━━━━━━━━━━
 File: Extend/Modules/Game1Module.swift
 
 Find where catchables are spawned. Add your catchable:
 
    let catchables = [
        .myNewCatchable,
        // ... existing catchables ...
    ]
 
 Find the catchable effects/behavior:
 
    if catchable == .myNewCatchable {
        // Handle what happens when caught
        gameState.addPoints(10)  // Example
    }
 
 STEP 4: ADD TO GAME STATE TRACKING
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 File: Extend/Modules/Game1Module.swift (StickFigureGameState)
 
 In the state initialization or update:
 
    @State private var caughtCatchables: [Equipment] = []  // Track what was caught
 
 STEP 5: ADD RENDERING IN GAME VIEW
 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 File: Extend/Modules/Game1Module.swift (rendering code)
 
 In the game canvas where catchables are drawn:
 
    ForEach(activeCatchables, id: \.self) { catchable in
        if let image = UIImage(named: catchable.iconName) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 40, height: 40)
                .position(catchable.position)
        }
    }
 
 STEP 6: ADD TO UI DISPLAYS
 ━━━━━━━━━━━━━━━━━━━━━━━
 Search for all places Equipment is displayed:
 
 a) Inventory display:
    File: Extend/Modules/Game1Module.swift (or relevant module)
    Add to inventory list view
 
 b) Settings/Equipment selector:
    File: Extend/Modules/EquipmentModule.swift
    Add to equipment picker
 
 c) Stats/Progress:
    File: Extend/Modules/ProgressModule.swift
    Add tracking if relevant
 
 STEP 7: TEST EVERYWHERE
 ━━━━━━━━━━━━━━━━━━━━━
 1. ✓ Game module - catchable spawns and can be caught
 2. ✓ Inventory - shows correct count/status
 3. ✓ Game state - persists across app restart
 4. ✓ Stats - tracked correctly if applicable
 5. ✓ All screen sizes - icon renders properly
 6. ✓ Dark mode - icon visible in dark mode
 
 TROUBLESHOOTING:
 - Icon not visible: Check name matches iconName exactly (case-sensitive)
 - Catchable not spawning: Check it's added to catchables array in game logic
 - State not persisting: Verify it's part of GameState serialization
 - Not appearing in UI: Search for all Equipment.allCases and add filtering if needed


 COMMON WORKFLOWS QUICK REFERENCE
 =================================
 
 Add a new Module:
   1. Create XxxModule.swift conforming to AppModule protocol
   2. Register in ModuleRegistry.swift with unique ModuleIDs.xxx
   3. Add to moduleViews() in ModuleRegistry
 
 Add a new State Type:
   1. Create XxxState.swift in State/ folder
   2. Make @Observable or use @State depending on scope
   3. Add to relevant view if needed
 
 Add a new Model Type:
   1. Create XxxModel.swift in Models/ folder
   2. Conform to Codable if it needs persistence
   3. Add computed properties for display strings
 
 Persist Data:
   1. Conform model to Codable
   2. Use JSONEncoder/JSONDecoder with UserDefaults or file storage
   3. Use SwiftData for complex data relationships
 
 Add a new Screen Size Support:
   1. Test on all iPhone sizes (SE, regular, Pro Max)
   2. Use @Environment(\.horizontalSizeClass) if needed
   3. Adjust padding and font sizes with GeometryReader
 
 Add Object to 2D Stick Figure Editor:
   1. Add image asset to Assets.xcassets (PNG format recommended)
      - Name the asset clearly (e.g., "Dumbbell", "Shaker", "Kettlebell")
      - Asset should have transparent background for best results
   2. Add asset name to availableImages array in StickFigure2D.swift
      Location: ImagePickerView struct, line ~583
      Example: "Apple", "Dumbbell", "Kettlebell", "Shaker"
   3. Test in the editor:
      - Open Stick Figure Animator module
      - Tap "Add Object" button
      - Verify new asset appears in Built-in tab
      - Add to canvas and verify it can be positioned/rotated
      - Save a frame with the object to verify persistence
 */

