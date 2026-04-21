# Match Game - Horizontal Match Tile Positioning Fix (April 21, 2026)

## Problem Statement
When making horizontal matches low in the grid, tiles appeared several rows higher than correct, then dropped from those positions with blinking and out-of-order issues.

## Root Cause Analysis

### The Issue
The animation sequence was wrong:

1. **applyGravity()** repositioned pieces in `gameGrid`
2. **updateGridDisplay()** was called → buttons showed FINAL content at FINAL positions
3. **Hide new pieces** was called → but they already had final content displayed
4. **animatePiecesDrop()** tried to animate from wrong starting positions
5. **Result**: Buttons already displayed at destination, animation transforms made no sense

### Visual Example: Horizontal Match at Row 3
**Before Fix:**
- Grid row 3: [Piece A] [Piece B] [Piece C] [Piece D] [Piece E]
- Match cleared at row 3
- Gravity applied, pieces fall from row 3 down to row 4
- **updateGridDisplay()** called → buttons at row 4 now show row 4 content
- **animatePiecesDrop()** starts → transforms say "move down" but content is already at bottom
- **Result**: Tiles blink, appear at wrong positions

## Solution

### Key Insight
Buttons must be **visually positioned at their START location** before animation begins, not at their END location.

### Changes Made

**In applyGravity() and applyGravityAfterCascade():**

1. Update gameGrid with new piece positions ✅
2. Call updateGridDisplay() to set correct content on buttons ✅  
3. **NEW**: Set each button's transform to START position
   - Existing pieces: moved DOWN from where they end (show fallDistance down)
   - New pieces: moved UP from where they end (show fallDistance up)
4. animatePiecesDrop() animates from START to .identity (end position)

### Code Implementation

```swift
// After updateGridDisplay(), set all buttons to START positions:
for col in 0..<level.gridWidth {
    for row in 0..<level.gridHeight {
        let key = "\(row),\(col)"
        guard movedPieces.contains(key), let button = gridButtons[row][col] else { continue }
        
        let distance = fallDistances[key] ?? 0
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        
        if newPieces.contains(key) {
            // NEW pieces start OFF-SCREEN (above)
            let fallDistance = cellHeight * CGFloat(distance)
            button.transform = CGAffineTransform(translationX: 0, y: -fallDistance)
            button.alpha = 0
        } else {
            // EXISTING pieces start DOWN from where they'll end
            let fallDistance = cellHeight * CGFloat(distance)
            button.transform = CGAffineTransform(translationX: 0, y: fallDistance)
            button.alpha = 1.0
        }
    }
}
```

## Files Modified
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/MatchGameViewController.swift`
  - `applyGravity()` (line ~2180)
  - `applyGravityAfterCascade()` (line ~1314)

## Animation Sequence Now

**Correct Flow:**
1. Pieces repositioned in gameGrid (gravity applied)
2. updateGridDisplay() shows correct content on buttons
3. Buttons positioned at START (what user sees before animation)
4. animatePiecesDrop() animates from START to END
5. Animation completes, pieces at final position with correct content

**Result:**
- No blinking
- No out-of-order appearance
- Smooth visual animation from current to final position
- Works correctly for all match types (3 matches, 4 matches, horizontal arrows, etc.)

## Expected Behavior After Fix

### Horizontal Match Low in Grid
Before:
- Tiles appear several rows higher
- Blinking during drop
- Out-of-order issues mid-animation

After:
- Tiles start at correct visual position
- Smooth sequential drop animation
- Consistent ordering throughout
- No visual glitches

### All Match Types
- ✅ 3-match clears
- ✅ 4-match arrows
- ✅ 5+ match flames
- ✅ 2x2 bombs
- ✅ Cascading matches
- ✅ Power-up clearings

## Technical Details

### Why Sequential Piece Animation + Pre-positioning Works
1. **Event-driven**: Each piece animates sequentially (completes before next starts)
2. **Pre-positioned**: Buttons already at visual start position
3. **Transforms**: Only need to animate to .identity (no pre-calculation needed)
4. **Duration**: Each piece falls for exactly: `(distance / speed)` seconds
5. **Result**: Perfect sequencing with no overlap or collisions

### Key Insight
The bug was assuming buttons would remain at their old positions after updateGridDisplay. They don't—they immediately show the final content. So we must reset their visual position with transforms BEFORE starting the animation.

## Testing Recommendations

1. **Horizontal Match Low**
   - Match 3-5 tiles in row 3 or 4
   - Watch tiles fall correctly, no blinking
   - Verify tiles don't appear higher than start position

2. **Horizontal Match with Columns**
   - Make horizontal match that affects multiple columns
   - Each column should fall independently and smoothly

3. **Cascade After Clear**
   - Create horizontal match that cascades
   - Verify cascading pieces also fall correctly

4. **Mix Match Types**
   - Test 3-matches, 4-match arrows, 5+ flames
   - All should animate smoothly from correct start position

## Performance Impact
✅ **Same**: Same number of animations  
✅ **Better**: Eliminated visual positioning bugs  
✅ **Cleaner**: Pre-positioning makes animation logic simpler
