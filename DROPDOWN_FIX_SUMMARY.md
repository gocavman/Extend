# Dropdown Z-Index Fix

## Issue
The level picker dropdown was not appearing in the gameplay screen when clicked from the stats panel. Instead, it would only become visible when navigating back to the map screen. This indicated the picker UI was missing from the gameplay screen entirely.

## Root Cause
The `showLevelPicker` state variable was shared between both screens, but **the level picker UI was only defined in the map screen's ZStack**. When clicking the "Set Level" button in the gameplay screen's stats panel:
1. It correctly set `showLevelPicker = true`
2. But there was no corresponding `if showLevelPicker { ... }` block in the gameplay screen
3. The picker UI only existed in the map screen, so it would appear there instead

This is a common SwiftUI issue where state is shared but the conditional UI rendering is not duplicated across both screens.

## Solution
Added the level picker overlay UI to **both** the map screen and gameplay screen, with proper z-index values:

### Map Screen (Level Picker)
- **StatsOverlayView**: `.zIndex(100)` - Ensures stats overlay is above map content
- **Level Picker Background (dimming)**: `.zIndex(200)` - Semi-transparent overlay
- **Level Picker Content**: `.zIndex(201)` - Picker menu with options

### Gameplay Screen (Action Picker + Level Picker)
- **StatsOverlayView**: `.zIndex(100)` - Ensures stats overlay is above gameplay content
- **Action Picker Background (dimming)**: `.zIndex(200)` - Semi-transparent overlay
- **Action Picker Content**: `.zIndex(201)` - Picker menu with options
- **Level Picker Background (dimming)**: `.zIndex(200)` - Semi-transparent overlay
- **Level Picker Content**: `.zIndex(202)` - Picker menu with options (higher than action picker)

## Z-Index Hierarchy
```
202 - Level picker content in gameplay screen (highest priority)
201 - Action picker content / Level picker content in map screen
200 - Picker background overlays (dimming effect)
100 - Stats overlay
  0 - Default content (map/gameplay elements)
```

## Testing
✅ Build succeeded with no errors
✅ Level picker now appears in gameplay screen when clicked
✅ Level picker still works correctly in map screen
✅ Action picker works correctly in gameplay screen
✅ Options are visible and clickable immediately
✅ Background dimming works correctly for all pickers

## Files Modified
- `/Users/cavan/Developer/Extend/Extend/Modules/Game1Module.swift`
  - Added level picker overlay to gameplay screen (was missing completely)
  - Added `.zIndex()` to level picker overlay in map screen
  - Added `.zIndex()` to action picker overlay in gameplay screen
  - Added `.zIndex()` to both StatsOverlayView instances
