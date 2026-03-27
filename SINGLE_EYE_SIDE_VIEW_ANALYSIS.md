# Single Eye for Side View - Technical Analysis

## Question
**Can only 1 eye be shown when the stick figure is in side view in gameplay?**

**Answer**: YES, absolutely! This is very feasible and would be a simple code change.

---

## Current Eye Rendering

**Location**: `/Users/cavan/Developer/Extend/Extend/Models/StickFigure2D.swift`  
**Lines**: ~1260-1283 in the `StickFigure2DView` struct

**Current Code** (draws TWO eyes):
```swift
if figure.eyesEnabled {
    let eyeRadius = scaledHeadRadius * 0.2  // 20% of head radius
    let eyeSpacing = scaledHeadRadius * 0.4  // Space between eyes
    let eyeVerticalOffset = scaledHeadRadius * 0.1  // Slight vertical offset
    
    // Left eye
    let leftEyePos = CGPoint(x: headPos.x - eyeSpacing / 2, y: headPos.y - eyeVerticalOffset)
    let leftEyePath = Circle().path(in: CGRect(
        x: leftEyePos.x - eyeRadius,
        y: leftEyePos.y - eyeRadius,
        width: eyeRadius * 2,
        height: eyeRadius * 2
    ))
    context.fill(leftEyePath, with: .color(figure.eyeColor))
    
    // Right eye
    let rightEyePos = CGPoint(x: headPos.x + eyeSpacing / 2, y: headPos.y - eyeVerticalOffset)
    let rightEyePath = Circle().path(in: CGRect(
        x: rightEyePos.x - eyeRadius,
        y: rightEyePos.y - eyeRadius,
        width: eyeRadius * 2,
        height: eyeRadius * 2
    ))
    context.fill(rightEyePath, with: .color(figure.eyeColor))
}
```

---

## How to Detect Side View

The GameplayScene already has a concept of "side view" through the `isSideView` parameter. However, looking at the actual rendering code in GameplayScene.swift, the head/eyes are rendered as part of the SpriteKit view, not through direct SwiftUI Canvas.

**Key Detection Points**:
1. **Character facing direction**: `gameState.facingRight` tells us which direction the character faces
2. **Current pose/animation**: The stick figure could be in various poses (standing, running, etc.)
3. **Animation frame**: Some frames might naturally show a side view

**Implementation Approach**:
Add a property to `StickFigure2D` to indicate "side view" mode, then pass it down when rendering.

---

## Proposed Solution

### Option A: Add a Property to StickFigure2D (Recommended)

**What to add to StickFigure2D**:
```swift
var sideViewMode: Bool = false  // When true, only show one eye
```

**Then modify the eye rendering in StickFigure2DView**:
```swift
if figure.eyesEnabled {
    let eyeRadius = scaledHeadRadius * 0.2
    let eyeVerticalOffset = scaledHeadRadius * 0.1
    
    if figure.sideViewMode {
        // Side view: show ONLY the visible eye (right eye from viewer's perspective)
        let visibleEyePos = CGPoint(x: headPos.x + scaledHeadRadius * 0.15, y: headPos.y - eyeVerticalOffset)
        let visibleEyePath = Circle().path(in: CGRect(
            x: visibleEyePos.x - eyeRadius,
            y: visibleEyePos.y - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        ))
        context.fill(visibleEyePath, with: .color(figure.eyeColor))
    } else {
        // Front view: show both eyes (current behavior)
        let eyeSpacing = scaledHeadRadius * 0.4
        
        // Left eye
        let leftEyePos = CGPoint(x: headPos.x - eyeSpacing / 2, y: headPos.y - eyeVerticalOffset)
        let leftEyePath = Circle().path(in: CGRect(
            x: leftEyePos.x - eyeRadius,
            y: leftEyePos.y - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        ))
        context.fill(leftEyePath, with: .color(figure.eyeColor))
        
        // Right eye
        let rightEyePos = CGPoint(x: headPos.x + eyeSpacing / 2, y: headPos.y - eyeVerticalOffset)
        let rightEyePath = Circle().path(in: CGRect(
            x: rightEyePos.x - eyeRadius,
            y: rightEyePos.y - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        ))
        context.fill(rightEyePath, with: .color(figure.eyeColor))
    }
}
```

**Then in GameplayScene.swift**, when rendering the stick figure:
```swift
let shouldFlip = !gameState.facingRight
var frameWithAppearance = scaledFrame
StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)

// ⭐ NEW: Set side view mode if needed
frameWithAppearance.sideViewMode = true  // Set based on animation/view type

let stickFigureNode = renderStickFigure(
    frameWithAppearance, 
    at: offsetPosition, 
    scale: 1.2, 
    flipped: shouldFlip, 
    jointShapeSize: frameWithAppearance.jointShapeSize
)
```

---

### Option B: Alternative - Base on Facing Direction

If you want it automatic based on facing direction:

```swift
if figure.eyesEnabled {
    let eyeRadius = scaledHeadRadius * 0.2
    let eyeVerticalOffset = scaledHeadRadius * 0.1
    
    // In side view, only show the eye on the side the character is facing
    if figure.isSideView {
        let eyePos = CGPoint(
            x: headPos.x + (figure.isFacingRight ? 1 : -1) * scaledHeadRadius * 0.15,
            y: headPos.y - eyeVerticalOffset
        )
        let eyePath = Circle().path(in: CGRect(
            x: eyePos.x - eyeRadius,
            y: eyePos.y - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        ))
        context.fill(eyePath, with: .color(figure.eyeColor))
    } else {
        // Front view: show both eyes (existing code)
        // ...
    }
}
```

---

## Location in Code Where Change Would Go

**File**: `/Users/cavan/Developer/Extend/Extend/Models/StickFigure2D.swift`

**Section**: `StickFigure2DView` struct, inside the `drawFigure(in:)` method

**Exact Location**: Lines 1260-1283 (the eye drawing section)

**Snippet to replace**:
```swift
// Draw eyes if enabled
if figure.eyesEnabled {
    // REPLACE THIS ENTIRE BLOCK WITH THE NEW CONDITIONAL LOGIC
    let eyeRadius = scaledHeadRadius * 0.2
    let eyeSpacing = scaledHeadRadius * 0.4
    let eyeVerticalOffset = scaledHeadRadius * 0.1
    
    // Left eye
    let leftEyePos = CGPoint(x: headPos.x - eyeSpacing / 2, y: headPos.y - eyeVerticalOffset)
    // ... draw left eye ...
    
    // Right eye
    let rightEyePos = CGPoint(x: headPos.x + eyeSpacing / 2, y: headPos.y - eyeVerticalOffset)
    // ... draw right eye ...
}
```

---

## Implementation Checklist

✅ Add `sideViewMode: Bool = false` property to StickFigure2D  
✅ Modify eye rendering logic in StickFigure2DView to check `sideViewMode`  
✅ Update GameplayScene to set `sideViewMode` when creating frames  
✅ Test with both front-view and side-view animations  

---

## Visual Effect

### Before (Current - Front View):
```
    👁️ 👁️
     \ /
     (_)
```

### After (Side View - Single Eye):
```
    👁️
     |
     (_)
```

---

## Additional Considerations

**Where to detect side view**:
- Look at the stick figure pose/animation name
- Check if specific frames (like running side view) should show one eye
- Could check animation properties or add a flag to animation config

**Which eye to show**:
- Right eye (from viewer perspective) for normal side view
- Could flip based on character direction if needed

**File Size Impact**: Minimal - just a few lines added  
**Performance Impact**: None - same number of eyes rendered, just logic to skip some  
**Compatibility**: Fully backward compatible - existing animations unchanged

---

**Analysis Date**: March 26, 2026  
**Feasibility**: Very High ✅  
**Estimated Implementation Time**: 30 minutes
