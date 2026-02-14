// PROJECT BUILD INSTRUCTIONS
// ==========================
//
// If you're seeing "missingTarget(guid:...)" error in Xcode:
//
// This is a known Xcode project cache issue that occurs when files are added
// programmatically or when the project file synchronization doesn't catch up.
//
// SOLUTION:
// 1. Close the Extend.xcodeproj in Xcode (File > Close)
// 2. In Finder, navigate to /Users/cavan/Developer/Extend/
// 3. Delete the "Extend.xcodeproj/xcuserdata" folder
// 4. Delete any "DerivedData" folders
// 5. Reopen Extend.xcodeproj in Xcode
// 6. Select Product > Clean Build Folder (Cmd + Shift + K)
// 7. Select Product > Build (Cmd + B)
//
// The project uses PBXFileSystemSynchronizedRootGroup which will automatically
// discover all Swift files in the Extend folder and its subfolders:
//  - Extend/Modules/*.swift
//  - Extend/Components/*.swift
//  - Extend/State/*.swift
//
// These folders and files already exist and are ready to be picked up by Xcode.
//
// FILES PRESENT:
// ✅ Extend/Modules/ModuleProtocol.swift
// ✅ Extend/Modules/ModuleRegistry.swift
// ✅ Extend/Modules/WorkoutModule.swift
// ✅ Extend/Modules/TimerModule.swift
// ✅ Extend/Modules/ProgressModule.swift
// ✅ Extend/Components/ModuleNavBar.swift
// ✅ Extend/Components/ModuleSettingsView.swift
// ✅ Extend/State/ModuleState.swift
// ✅ Extend/ContentView.swift (updated)
// ✅ Extend/ExtendApp.swift (updated)
// ✅ CodeRules.swift (updated with guidelines)
