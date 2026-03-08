# Mid-Torso Y Offset Fix

## Issues Addressed

### 1. Refresh Button Not Resetting midTorsoYOffset Slider
**Problem:** When clicking the refresh button in the editor, the `midTorsoYOffset` slider was not being reset to the Stand frame value.

**Root Cause:** The `loadStandFrameValues()` function in `StickFigureGameplayEditorViewController.swift` was not loading the `midTorsoYOffset` property from the standFrame.

**Fix:** Added the missing line in `loadStandFrameValues()` (after line 1046):
```swift
// Load mid torso Y offset
midTorsoYOffset = standFrame.midTorsoYOffset
```

**File:** `/Users/cavan/Developer/Extend/Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`

---

### 2. Upper Torso Bottom Point Not Curving at Mid-Torso Rotation
**Problem:** When rotating at the mid-torso (using the neck dot), the bottom of the upper torso was pointing left/right instead of properly curving toward the lower torso.

**Root Cause:** The offset calculation in `GameScene.swift` was incorrectly combining both `waistTorsoAngle` AND `midTorsoAngle` for the rotation:
```swift
let offsetRotationRadians = (mutableFigure.waistTorsoAngle + mutableFigure.midTorsoAngle) * .pi / 180
```

This caused the offset to rotate incorrectly relative to the mid-torso point. The offset point should rotate ONLY with the `midTorsoAngle`, not the combined torso rotation.

**Fix:** Changed the offset rotation to use ONLY `midTorsoAngle` in `GameScene.swift` (line 625):
```swift
// The offset is ROTATED to follow ONLY the mid-torso rotation (not waist rotation)
// The offset point curves toward the lower torso as mid-torso rotates
let offsetRotationRadians = mutableFigure.midTorsoAngle * .pi / 180
```

This ensures:
- When rotating at the waist (waistTorsoAngle), the offset stays relative to the mid-torso position
- When rotating at the mid-torso (midTorsoAngle), the offset properly rotates with the mid-torso
- The bottom of the upper torso curves naturally toward the lower torso

**File:** `/Users/cavan/Developer/Extend/Extend/SpriteKit/GameScene.swift`

---

## Technical Details

### midTorsoYOffset Property Flow
1. **Stored in:** `SavedEditFrame` model
2. **Loaded in:** `StickFigure2D` model (as `midTorsoYOffset`)
3. **Edited in:** `StickFigureGameplayEditorViewController.swift` (UIKit)
4. **Used in:** 
   - Editor rendering: `StickFigure2D.swift` (simple Y offset applied)
   - Gameplay rendering: `GameScene.swift` (rotated offset applied)

### Rotation Logic
When rotating at different points:
- **Waist rotation (waistTorsoAngle):** Upper body rotates around waist, midTorsoYOffset stays pinned to lower torso
- **Mid-torso rotation (midTorsoAngle):** Upper body rotates around mid-torso, offset properly curves with the rotation
- **Combined:** Both rotations work independently and correctly

---

## Testing
Both fixes have been validated for:
- ✅ No build errors
- ✅ midTorsoYOffset slider now resets when refresh button is clicked
- ✅ Upper torso bottom point curves properly when rotating at mid-torso
- ✅ Offset remains pinned correctly during all rotations
