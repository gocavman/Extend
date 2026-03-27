# Side View Eyes - Quick Reference Card

## TL;DR

Set `isSideView = true` to show single eye. Set `isSideView = false` to show both eyes.

---

## One-Liner Integration

```swift
frameWithAppearance.isSideView = true  // Add this line before rendering
```

---

## Where to Add It

### In updateGameLogic() - Action Playback
```swift
var frameWithAppearance = scaledFrame
StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
frameWithAppearance.isSideView = true  // ← ADD HERE
let stickFigureNode = renderStickFigure(frameWithAppearance, ...)
```

### In startMovementAnimation()
```swift
var frameWithAppearance = scaledFrame
StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
frameWithAppearance.isSideView = true  // ← ADD HERE
let stickFigureNode = renderStickFigure(frameWithAppearance, ...)
```

### In Stand Frame Rendering
```swift
var frameWithAppearance = scaledFrame
StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
frameWithAppearance.isSideView = true  // ← ADD HERE
let stickFigureNode = renderStickFigure(frameWithAppearance, ...)
```

---

## Common Patterns

### Always Side View for Running
```swift
frameWithAppearance.isSideView = true
```

### Side View When Moving
```swift
frameWithAppearance.isSideView = gameState.isMovingLeft || gameState.isMovingRight
```

### Side View for Specific Animation Type
```swift
let isRunning = gameState.currentActionName?.lowercased().contains("run") ?? false
frameWithAppearance.isSideView = isRunning
```

### Side View for Specific Frame
```swift
let frameNumber = gameState.currentFrameIndex
frameWithAppearance.isSideView = frameNumber % 2 == 0  // Even frames only
```

---

## Properties Modified

**File 1**: `Extend/Models/StickFigure2D.swift`
- Added: `var isSideView: Bool = false` (line ~717)

**File 2**: `Extend/SpriteKit/GameScene.swift`
- Updated: Eye rendering conditional logic

---

## Default Behavior

```swift
// By default:
var frame = StickFigure2D()
frame.isSideView  // = false (both eyes show)

// Both eyes render automatically
renderStickFigure(frame, ...)  // Shows 👁️ 👁️

// Enable single eye:
frame.isSideView = true
renderStickFigure(frame, ...)  // Shows 👁️
```

---

## Eye Position

### Single Eye (isSideView = true)
- Always on the **right side** of the head
- When character flips, the eye visually moves due to horizontal flip
- Result: Correct side profile in both directions

### Both Eyes (isSideView = false) - DEFAULT
- Left eye: slightly left of center
- Right eye: slightly right of center
- Both visible

---

## Iris Support

Iris rendering works the same in both modes:

```swift
frame.eyesEnabled = true      // Eyes visible
frame.irisEnabled = true      // Iris visible
frame.isSideView = true       // Single eye mode

// Result: Single eye with iris
```

---

## Backward Compatibility

✅ Safe to implement without breaking changes:

```swift
// Old code continues to work:
var frame = gameState.standFrame
renderStickFigure(frame, ...)  // Shows both eyes (isSideView defaults to false)

// New code uses single eye:
frame.isSideView = true
renderStickFigure(frame, ...)  // Shows single eye
```

---

## Testing

### Quick Test
```swift
// In updateGameLogic(), temporarily:
frameWithAppearance.isSideView = true
// Run the app - all characters show single eye
```

### Conditional Test
```swift
// Test specific condition:
frameWithAppearance.isSideView = gameState.isMovingLeft
// Run the app - only left-moving characters show single eye
```

---

## Common Issues & Solutions

### Issue: Eye not showing
**Solution**: Verify `eyesEnabled = true`
```swift
frame.eyesEnabled = true    // Must be true
frame.isSideView = true     // Then single eye shows
```

### Issue: Both eyes still showing
**Solution**: Check property value
```swift
print("isSideView = \(frame.isSideView)")  // Should be true
```

### Issue: Eye in wrong position
**Solution**: This is normal - flipped rendering handles positioning
```swift
// When character flips left, eye appears on left visually
// This is correct behavior
```

---

## File Size Impact

- **Code added**: ~50 lines across 2 files
- **Binary size**: Negligible (conditional logic only)
- **Performance**: No impact (same rendering, just conditional)

---

## One-Minute Integration

1. Find where `renderStickFigure()` is called
2. Add: `frameWithAppearance.isSideView = true`
3. Test
4. Done!

```swift
// Before:
let stickFigureNode = renderStickFigure(frameWithAppearance, ...)

// After:
frameWithAppearance.isSideView = true
let stickFigureNode = renderStickFigure(frameWithAppearance, ...)
```

---

## Documentation Files

For more details, see:
- `SIDE_VIEW_EYES_COMPLETE.md` - Full implementation details
- `SIDE_VIEW_EYES_USAGE_GUIDE.md` - Detailed usage examples
- `SIDE_VIEW_EYES_IMPLEMENTATION.md` - Technical specs

---

**Status**: ✅ Complete & Ready to Use  
**Effort Required**: < 5 minutes to integrate  
**Risk**: None (backward compatible)
