# How to Use Side View Eyes in Gameplay

## Quick Reference

The `isSideView` property on `StickFigure2D` controls whether to display one eye (side view) or two eyes (front view).

---

## Implementation Points in GameplayScene

There are three main places where stick figure frames are rendered in `updateGameLogic()`:

### 1. Action Animation Playback
**Location**: GameplayScene.swift, ~line 660

```swift
if let currentStickFigure = gameState.currentStickFigure {
    // Apply muscle scaling and appearance to the action frame
    let scaledFrame = applyMuscleScaling(to: currentStickFigure)
    var frameWithAppearance = scaledFrame
    StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
    
    // ⭐ ADD THIS TO ENABLE SIDE VIEW:
    // frameWithAppearance.isSideView = true
    
    // Clear character node and render the new frame
    character.removeAllChildren()
    let shouldFlip = gameState.actionFlip
    // ... rest of rendering code
}
```

**When to use**: Set `isSideView = true` if the current action is a side-view animation (e.g., "Run", "Walk")

---

### 2. Movement Animation
**Location**: GameplayScene.swift, `startMovementAnimation()` function, ~line 730

```swift
private func startMovementAnimation() {
    // ... setup code ...
    
    // When rendering each frame in the movement animation:
    let scaledFrame = applyMuscleScaling(to: currentFrame)
    var frameWithAppearance = scaledFrame
    StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
    
    // ⭐ ADD THIS FOR RUNNING SIDE VIEW:
    // frameWithAppearance.isSideView = true
    
    // Render the frame
    character.removeAllChildren()
    // ... rest of rendering code
}
```

**When to use**: Set `isSideView = true` if the movement frames show the character from the side

---

### 3. Stand Idle State
**Location**: GameplayScene.swift, ~line 690

```swift
if let standFrame = gameState.standFrame {
    let scaledFrame = applyMuscleScaling(to: standFrame)
    var frameWithAppearance = scaledFrame
    StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
    
    // ⭐ ADD THIS IF STAND FRAME IS SIDE VIEW:
    // frameWithAppearance.isSideView = true
    
    character.removeAllChildren()
    // ... rest of rendering code
}
```

**When to use**: Set `isSideView = true` if the stand frame should show the character from the side

---

## Practical Example: Running Animation with Side View

Here's how to implement side-view running:

```swift
private func startMovementAnimation() {
    print("🎮 Starting movement animation")
    
    characterNode?.removeAction(forKey: "moveAnimation")
    animationFrameIndex = 0
    
    guard let gameState = gameState else { return }
    
    var frameInterval: TimeInterval = 0.15
    var frameNumbers: [Int] = [0, 1, 2, 3]
    
    if let config = ACTION_CONFIGS.first(where: { $0.id == "run" }),
       let animation = config.stickFigureAnimation {
        frameInterval = animation.baseFrameInterval
        frameNumbers = animation.frameNumbers.map { $0 - 1 }
    }
    
    // Create the animation action
    let animationAction = SKAction.sequence([
        SKAction.run { [weak self] in
            guard let self = self,
                  self.animationFrameIndex < frameNumbers.count else { return }
            
            let frameIdx = frameNumbers[self.animationFrameIndex]
            if frameIdx < gameState.moveFrames.count {
                let moveFrame = gameState.moveFrames[frameIdx]
                
                // Apply processing
                let scaledFrame = self.applyMuscleScaling(to: moveFrame)
                var frameWithAppearance = scaledFrame
                StickFigureAppearance.shared.applyToStickFigure(&frameWithAppearance)
                
                // ⭐ ENABLE SIDE VIEW FOR RUNNING ANIMATION
                frameWithAppearance.isSideView = true  // Show single eye during run
                
                // Render
                self.characterNode?.removeAllChildren()
                let shouldFlip = !gameState.facingRight
                var offsetPosition = CGPoint(x: frameWithAppearance.figureOffsetX, 
                                            y: frameWithAppearance.figureOffsetY)
                if shouldFlip {
                    offsetPosition.x = -offsetPosition.x
                }
                
                let stickFigureNode = self.renderStickFigure(
                    frameWithAppearance, 
                    at: offsetPosition, 
                    scale: 1.2, 
                    flipped: shouldFlip, 
                    jointShapeSize: frameWithAppearance.jointShapeSize
                )
                self.characterNode?.addChild(stickFigureNode)
                
                self.animationFrameIndex += 1
            }
        },
        SKAction.wait(forDuration: frameInterval)
    ])
    
    characterNode?.run(SKAction.repeatForever(animationAction), withKey: "moveAnimation")
}
```

---

## Conditional Side View Logic

### Based on Animation Type

```swift
// Determine if animation should use side view based on name
let shouldUseSideView: Bool
if let actionName = gameState.currentActionName {
    shouldUseSideView = ["run", "walk", "jump"].contains(actionName.lowercased())
} else {
    shouldUseSideView = false
}

frameWithAppearance.isSideView = shouldUseSideView
```

### Based on Character Direction

```swift
// Show side view when moving
let isMoving = gameState.isMovingLeft || gameState.isMovingRight
frameWithAppearance.isSideView = isMoving

// Alternative: Show single eye based on which direction facing
if isMoving {
    if gameState.facingRight {
        // Show right eye (default single eye position)
        frameWithAppearance.isSideView = true
    } else {
        // Could add logic to show left eye if isSideView=true with facingLeft
        frameWithAppearance.isSideView = true
    }
}
```

---

## Current Implementation Notes

### Which Eye Shows?

When `isSideView = true`:
- **SwiftUI**: Right eye at `headPos.x + scaledHeadRadius * 0.15`
- **SpriteKit**: Right eye at `headPos.x + headRadius * 0.25`

### Direction Flipping

The `flipped` parameter in `renderStickFigure()` mirrors the entire figure horizontally:
- `flipped = false` (right-facing character): Single eye appears on the right
- `flipped = true` (left-facing character): Single eye appears on the left (due to horizontal flip)

This creates the correct side-view perspective regardless of facing direction.

---

## Testing the Feature

### In the Stick Figure Editor

If you have access to the editor, you can manually test by:

1. Creating a new animation frame
2. Setting `isSideView = true` in code (requires code modification)
3. Viewing the frame to see single eye rendering

### In GameplayScene

To quickly test:

```swift
// In updateGameLogic(), temporarily always enable side view:
frameWithAppearance.isSideView = true  // Always show single eye

// Then play animations to verify they work correctly
```

---

## Backward Compatibility

✅ Existing code works without changes:
- Default: `isSideView = false`
- Default behavior: Both eyes render as before
- No side effects on other features

---

## Eye Iris Support

The iris rendering respects the side view mode:

```swift
// When isSideView = true and irisEnabled = true:
// Single iris appears at the same position as the single eye

frameWithAppearance.isSideView = true
frameWithAppearance.irisEnabled = true  // Iris will show on single eye

// Rendering handles this automatically
```

---

## Summary

1. **Find a place** where `StickFigure2D` frame is rendered (in `updateGameLogic()`)
2. **Add one line**: `frameWithAppearance.isSideView = true`
3. **Condition it** based on animation type, movement state, etc.
4. **Test** by running the action/animation

That's it! The single eye will render automatically in both SwiftUI and SpriteKit paths.
