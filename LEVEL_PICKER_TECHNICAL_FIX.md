# Level Picker Fix - Technical Explanation

## The Problem in Detail

### Before Fix:
```
View Hierarchy:
├── body (switches between screens)
│   ├── mapScreen (ZStack)
│   │   ├── Map content
│   │   ├── StatsOverlayView (contains "Set Level" button)
│   │   └── if showLevelPicker { Level Picker UI } ✅ EXISTS HERE
│   │
│   └── gameplayScreen (ZStack)
│       ├── Gameplay content
│       ├── if showActionPicker { Action Picker UI } ✅
│       └── StatsOverlayView (contains "Set Level" button)
│           └── if showLevelPicker { Level Picker UI } ❌ MISSING!
```

### What Happened:
1. User opens stats panel in **gameplay screen**
2. User clicks "Set Level" button
3. Button sets `showLevelPicker = true`
4. SwiftUI looks for `if showLevelPicker` conditional in current view
5. ❌ Not found in gameplayScreen ZStack!
6. User switches to map screen
7. ✅ Map screen has the conditional, so picker appears there

### After Fix:
```
View Hierarchy:
├── body (switches between screens)
│   ├── mapScreen (ZStack)
│   │   ├── Map content
│   │   ├── StatsOverlayView (contains "Set Level" button)
│   │   └── if showLevelPicker { Level Picker UI } ✅ (zIndex: 201)
│   │
│   └── gameplayScreen (ZStack)
│       ├── Gameplay content
│       ├── if showActionPicker { Action Picker UI } ✅ (zIndex: 201)
│       ├── if showLevelPicker { Level Picker UI } ✅ ADDED! (zIndex: 202)
│       └── StatsOverlayView (contains "Set Level" button) (zIndex: 100)
```

## Key Insight
In SwiftUI, when you have shared state (`@State private var showLevelPicker = false`) used across different views, **each view needs its own UI rendering logic** for that state. The state being shared doesn't automatically make the UI appear in both places - you need to explicitly add the conditional rendering block to both screens.

## The Fix
Duplicated the level picker UI block from map screen to gameplay screen with proper z-index ordering:
- Action Picker: zIndex 201 (appears for action selection)
- Level Picker: zIndex 202 (appears for level selection, higher than action picker)
- Both use zIndex 200 for their dimming backgrounds

This ensures that no matter which screen you're on, clicking "Set Level" will show the picker in the current screen.
