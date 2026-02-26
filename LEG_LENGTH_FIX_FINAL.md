# Leg Length Fix - FINAL SOLUTION - 2D Stick Figure Editor

## Problem Description

When dragging the legs around the editor, they were getting longer:
- **Right leg**: Gets longer when dragging to the RIGHT
- **Left leg**: Gets longer when dragging to the LEFT

## Root Cause (CORRECTED)

The legs were using a **fixed horizontal offset** combined with angle-based rotation:

```swift
// WRONG - This caused double-counting of horizontal distance:
let x = waistPosition.x - shoulderWidth / 4 + upperLegLength * cos(radians)
                          ^^^^^^^^^^^^^^^^^^^^^^^ 
                          Fixed offset + angle calculation = longer leg!
```

When the leg rotated to the side, the fixed offset would ADD to the angle-based position, making the leg appear longer.

## Solution: Pure Angle-Based Rotation

### 1. Leg Position Calculation

**BEFORE (Wrong):**
```swift
var leftUpperLegEnd: CGPoint {
    let angle = 270.0 + leftKneeAngle
    let radians = angle * .pi / 180
    let x = waistPosition.x - shoulderWidth / 4 + upperLegLength * cos(radians)
    //                       ^^^^^^^^^^^^^^^^^^^^
    //                       Fixed offset causing the problem!
    let y = waistPosition.y + upperLegLength * sin(radians)
    return CGPoint(x: x, y: y)
}
```

**AFTER (Correct):**
```swift
var leftUpperLegEnd: CGPoint {
    let angle = 270.0 + leftKneeAngle
    let radians = angle * .pi / 180
    let x = waistPosition.x + upperLegLength * cos(radians)
    //      No offset - pure angle-based rotation
    let y = waistPosition.y + upperLegLength * sin(radians)
    return CGPoint(x: x, y: y)
}
```

### 2. Angle Calculation Update

**BEFORE (Wrong):**
```swift
case "leftKnee":
    let legStartX = figure.waistPosition.x - figure.shoulderWidth / 4
    let angleFromLegStart = calculateAngle(from: CGPoint(x: legStartX, y: legStartY), to: position)
    figure.leftKneeAngle = wrapAngle(angleFromLegStart - 270.0)
```

**AFTER (Correct):**
```swift
case "leftKnee":
    let angleFromWaist = calculateAngle(from: figure.waistPosition, to: position)
    figure.leftKneeAngle = wrapAngle(angleFromWaist - 270.0)
```

## Why This Works

With pure trigonometric rotation from waist center:

```
Distance = √(cos(angle)² + sin(angle)²) = √1 = 1 unit

So: x = waist.x + length × cos(angle)
    y = waist.y + length × sin(angle)

Always maintains: (x - waist.x)² + (y - waist.y)² = length²
```

The leg always stays exactly `upperLegLength` away from the waist, regardless of angle.

## Files Changed

`/Users/cavan/Developer/Extend/Extend/Models/StickFigure2D.swift`

1. **Leg position calculations** (lines ~505-530)
   - Removed `- shoulderWidth / 4` offset from left leg
   - Removed `+ shoulderWidth / 4` offset from right leg
   - Both now use pure: `waistPosition + trigonometry`

2. **StickFigure2DEditorView.updateJoint()** (leg case statements)
   - Calculate angles from waist center, not offset position

3. **StickFigure2DEditorInlineView.updateJoint()** (leg case statements)
   - Same fix as main editor

## Test Results ✅

- Leg length is constant in all directions
- No elongation when moving left/right
- Works identically for both legs
- No compilation errors

---

**Fix Date:** February 26, 2026
**Problem:** Fixed by removing offset, using pure angle-based rotation
**Status:** ✅ Complete and tested
