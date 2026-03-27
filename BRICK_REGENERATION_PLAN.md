# Brick Regeneration on Screen Wrap - Implementation Plan

## Overview
When the stick figure runs off-screen (left/right) and wraps to the opposite side, bricks should seamlessly regenerate/refresh so they fill the entire visible screen at all times.

**Status**: ✅ Yes, this is fully implementable

---

## Current System Analysis

### Screen Wrapping (Already Implemented)
- **Location**: `GameplayScene.swift`, `updateGameLogic()` method (~line 723)
- **Mechanism**:
  ```swift
  if character.position.x > size.width + 50 {
      character.position.x = -50
  } else if character.position.x < -50 {
      character.position.x = size.width + 50
  }
  ```
- Character smoothly wraps around without clamping
- We can hook into this wrap detection to trigger brick regeneration

### Brick System (Exists but Static)
- **Location**: `setupBrickGround()` method (~line 260)
- **Current Implementation**:
  - Creates a static "brickGround" node in `didMove(to:)` once at scene initialization
  - Generates 3 rows of bricks with bond pattern
  - Bricks span from x=0 to roughly size.width
  - Uses fixed colors with 3D effects and mortar lines
  - **Problem**: Bricks don't move or regenerate as character moves

### What Needs to Change
Currently, bricks are:
- Created once and statically positioned
- Never updated or refreshed
- Never tied to character movement

---

## Proposed Solution

### Architecture: Two-Pronged Approach

#### **Option A: Dynamic Brick Positioning System** (Recommended)
Track the brick "viewport" independently and shift bricks as the character moves.

**Advantages**:
- More efficient (reuse brick nodes)
- Smoother visual experience
- Can handle infinite running
- Standard approach for platformers

**Implementation Strategy**:
1. Create a "brick viewport system" that tracks which section of the infinite brick world is visible
2. Store brick properties (position, color, row) in a data structure
3. Update brick positions dynamically in `updateGameLogic()`
4. When character wraps to the opposite side, regenerate bricks for the new visible area

---

#### **Option B: Regenerate-on-Wrap System** (Simpler)
Completely rebuild the brick ground each time the character wraps.

**Advantages**:
- Simpler to implement
- No need to track state
- Works well for small wrapped areas

**Disadvantages**:
- Slight frame spike when regenerating
- Less elegant
- Only works for discrete wrap events

---

## Detailed Implementation Plan

### **Selected Approach: Hybrid System**
Combine elements of both for best results:

#### Step 1: Add Brick Tracking Properties
```swift
class GameplayScene: GameScene {
    // ...existing code...
    
    // Brick tracking
    private var brickGroundNode: SKNode?
    private var currentBrickViewportX: CGFloat = 0  // Track which X offset we're rendering
    private var brickViewportWidth: CGFloat = 0     // Cache the viewport width
}
```

#### Step 2: Refactor `setupBrickGround()`
- Extract brick generation logic into a reusable function
- Accept viewport X position as parameter
- Store reference to ground node for updates
- Make it callable from both init and update methods

#### Step 3: Implement Brick Refresh Detection
Add to `updateGameLogic()`:
- Calculate current "brick section" based on character position
- Detect when character wraps across screen boundaries
- Trigger brick regeneration when wrap is detected

#### Step 4: Create `regenerateBricks(forViewport:)` Method
- Calculate which bricks should be visible
- Remove old brick nodes
- Create new bricks for the new viewport
- Maintain seamless visual appearance

#### Step 5: Handle Edge Cases
- Ensure bricks appear immediately with no gaps
- Account for brick overlap at boundaries
- Maintain visual consistency with existing brick patterns

---

## Implementation Details

### Key Methods to Create/Modify

#### **`setupBrickGround()`** (MODIFY)
- Extract to generate bricks within a given viewport
- Should be callable multiple times
- Store the brickGroundNode for reference

#### **`regenerateBricks(atPosition:)`** (NEW)
- Triggered when character position changes significantly
- Calculates new viewport boundaries
- Clears old bricks, creates new ones

#### **`updateGameLogic()`** (MODIFY)
- Add brick regeneration check after character position update
- Compare character position to last brick viewport
- Call regenerateBricks if threshold exceeded

### Threshold Strategy
Instead of regenerating every frame, use a threshold:
- Regenerate when character has moved **~half the brick grid width** from last generation
- This prevents excessive updates while ensuring continuous coverage

---

## Pseudo-Code Structure

```swift
private func updateGameLogic() {
    // ...existing code...
    
    // Update character position
    if gameState.isMovingLeft {
        character.position.x -= speed
    } else if gameState.isMovingRight {
        character.position.x += speed
    }
    
    // Handle screen wrapping
    if character.position.x > size.width + 50 {
        character.position.x = -50
    } else if character.position.x < -50 {
        character.position.x = size.width + 50
    }
    
    // ⭐ NEW: Regenerate bricks if needed
    checkAndRegenerateBricks(characterPosition: character.position)
    
    // ...rest of existing code...
}

private func checkAndRegenerateBricks(characterPosition: CGPoint) {
    // Calculate which viewport section should be visible
    let targetViewportX = calculateViewportX(forCharacterX: characterPosition.x)
    
    // If character has moved to a new section, regenerate
    if abs(targetViewportX - currentBrickViewportX) > brickRegenerationThreshold {
        regenerateBricks(atViewportX: targetViewportX)
    }
}

private func regenerateBricks(atViewportX: CGFloat) {
    // Remove old bricks
    brickGroundNode?.removeAllChildren()
    
    // Generate new bricks for this viewport
    generateBricksForViewport(atViewportX)
    
    // Update tracking
    currentBrickViewportX = atViewportX
}

private func generateBricksForViewport(_ viewportX: CGFloat) {
    // Create bricks visible in current viewport
    // Similar logic to setupBrickGround() but parameterized
}
```

---

## Visual Behavior Expected

1. **Player moves right** → Bricks stay in place until threshold hit
2. **Threshold crossed** → Bricks regenerate with seamless visual continuation
3. **Wrap happens** → Bricks regenerate for new visible area
4. **Player moves left** → Same process in reverse

---

## Testing Strategy

1. **Manual testing in simulator**:
   - Run left/right continuously
   - Watch for brick gaps or visual glitches
   - Verify no frame rate drops during regeneration

2. **Edge cases**:
   - Run left until wrap, verify bricks appear
   - Run right until wrap, verify bricks appear
   - Change direction rapidly
   - Watch for flickers or inconsistencies

3. **Performance**:
   - Monitor frame rate during regeneration
   - Check memory usage for brick nodes

---

## Estimated Complexity
- **Difficulty**: Medium (straightforward but requires careful positioning math)
- **Time to implement**: ~1-2 hours
- **Risk level**: Low (isolated to gameplay scene, doesn't affect other systems)

---

## Files to Modify
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/GameplayScene.swift`
  - Add brick tracking properties
  - Refactor `setupBrickGround()` into reusable functions
  - Add brick regeneration logic to `updateGameLogic()`
  - Add new helper methods for viewport calculation

---

## Next Steps
1. ✅ Understand current brick system (DONE)
2. ✅ Understand screen wrapping (DONE)
3. ⏳ **AWAITING APPROVAL**: Should we proceed with implementation?
   - Any preferences on the approach?
   - Any performance concerns?
   - Should we add visual debug info during development?

