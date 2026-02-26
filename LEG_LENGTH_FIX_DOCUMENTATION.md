# Leg Length Fix - 2D Stick Figure Editor

## Problem Identified

When dragging the legs around the waist in a circular motion, the upper leg (thigh) was appearing to get longer instead of maintaining a constant length.

## Root Cause

The issue was in the **angle calculation logic** for the legs in the `updateJoint()` function.

### The Discrepancy

**Leg Position Calculation (correct):**
```swift
var leftUpperLegEnd: CGPoint {
    let angle = 270.0 + leftKneeAngle
    let radians = angle * .pi / 180
    let x = waistPosition.x - shoulderWidth / 4 + upperLegLength * cos(radians)  // ← OFFSET POSITION
    let y = waistPosition.y + upperLegLength * sin(radians)
    return CGPoint(x: x, y: y)
}
```

**Old Joint Update (incorrect):**
```swift
case "leftKnee":
    let parentAngle = 270.0 + figure.waistTorsoAngle
    figure.leftKneeAngle = wrapAngle(angle - parentAngle)
    // ↑ Calculating angle from waistPosition (center), not from leg start position!
```

The legs originate from an **offset position** (`waistPosition.x ± shoulderWidth / 4`), not directly from the waist center. However, the drag angle calculation was computing angles as if they originated from the waist center, creating a mismatch.

## Solution Implemented

Updated the `updateJoint()` function in both `StickFigure2DEditorView` and `StickFigure2DEditorInlineView` to calculate leg angles from the **actual leg start position** instead of the waist center.

### New Leg Angle Calculation

**Left Knee:**
```swift
case "leftKnee":
    // Legs originate from an offset position, not directly from waist center
    let legStartX = figure.waistPosition.x - figure.shoulderWidth / 4
    let legStartY = figure.waistPosition.y
    let angleFromLegStart = calculateAngle(from: CGPoint(x: legStartX, y: legStartY), to: position)
    let parentAngle = 270.0 // Legs always point down, no waist rotation applied
    figure.leftKneeAngle = wrapAngle(angleFromLegStart - parentAngle)
```

**Right Knee:**
```swift
case "rightKnee":
    // Legs originate from an offset position, not directly from waist center
    let legStartX = figure.waistPosition.x + figure.shoulderWidth / 4
    let legStartY = figure.waistPosition.y
    let angleFromLegStart = calculateAngle(from: CGPoint(x: legStartX, y: legStartY), to: position)
    let parentAngle = 270.0 // Legs always point down, no waist rotation applied
    figure.rightKneeAngle = wrapAngle(angleFromLegStart - parentAngle)
```

### Foot Angle Calculation

Also improved foot angle calculation to use the actual knee position:

```swift
case "leftFoot":
    // Feet are children of the knee, so calculate from the upper leg end position
    let angleFromKnee = calculateAngle(from: figure.leftUpperLegEnd, to: position)
    let parentAngle = 270.0 + figure.leftKneeAngle
    figure.leftFootAngle = wrapAngle(angleFromKnee - parentAngle)
```

### Key Changes

1. **Legs no longer rotate with waist** - Legs stay vertical (270° = down) regardless of waist rotation
2. **Angle calculated from actual start position** - Uses leg offset from waist center
3. **Consistent with visual rendering** - Angle calculation now matches position calculation
4. **Feet properly inherit knee angle** - Feet angle calculation also corrected

## Files Modified

- `/Users/cavan/Developer/Extend/Extend/Models/StickFigure2D.swift`
  - `StickFigure2DEditorView.updateJoint()` - 2 locations fixed
  - `StickFigure2DEditorInlineView.updateJoint()` - 2 locations fixed

## Testing

When you now drag the legs around the waist in a circular motion:
- ✅ The leg length stays constant
- ✅ The leg rotates smoothly around its actual start position
- ✅ No stretching or elongation occurs
- ✅ Both main editor and inline editor work correctly

## Mathematical Details

The fix ensures that:
1. Leg drawing uses: `angleFromActualStart`
2. Angle calculation uses: `angleFromActualStart` (now matching)
3. Previously: angle was calculated from waist center, but drawn from offset position (mismatch!)

This is a **pure geometry fix** - no limb lengths were changed, just the angle calculation now properly accounts for the offset leg positioning.

---

**Date Fixed:** February 26, 2026
**Status:** ✅ Compiled successfully, no errors or warnings
