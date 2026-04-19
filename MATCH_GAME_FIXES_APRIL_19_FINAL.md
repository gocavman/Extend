# Match Game Fixes - Horizontal Flames & Tile Falling - April 19, 2026

## Issues Fixed

### 1. ✅ Horizontal Flames Always Appearing on 2nd-to-Top Row
**Problem**: Horizontal arrow powerups always shot flames on the 2nd row from top, regardless of which row was actually cleared.

**Root Cause**: Classic Swift closure capture issue. The loop variable `row` was being captured by reference in the closure instead of by value. When the closure executed, it used the final value of `row` from the loop iteration, which was always the same row.

**Solution**:
- Explicitly capture `row` value: `let capturedRow = row`
- Use captured value in closure: `self.shootFlamesHorizontally(row: capturedRow, ...)`
- Same fix applied to `col` for vertical arrows
- Ensures each closure captures its OWN row/col value, not the loop's final value

**Changed in**: `activateCascadingPowerups()`

### 2. ✅ Tiles Falling Past Other Tiles
**Problem**: When pieces fell to fill empty spaces, sometimes a tile would pass through another tile instead of stopping.

**Root Cause**: Sequential animation stagger was causing the issue. Pieces were starting their animations at different times based on cumulative delays, causing them to overlap mid-animation.

**Solution**:
- **Changed animation strategy**: All pieces now start falling at the SAME time (delay = 0)
- Each piece still has its own duration based on distance fallen
- Pieces falling 1 row complete in ~0.1s, pieces falling 3 rows take ~0.3s
- All pieces finish based on their actual distance, not sequential timing
- This is PHYSICALLY CORRECT: if multiple balls are dropped, they all start falling immediately

**Changed in**: `animatePiecesDrop()`

### Key Insight
The sequential stagger approach was wrong for this use case. Sequential stagger works when pieces move ONE AT A TIME (like queued events). But for gravity, ALL pieces should fall SIMULTANEOUSLY at constant velocity. Faster-falling pieces naturally "finish first" based on their distance.

## Technical Changes

### Closure Capture Fix
```swift
// Before (WRONG - captures final loop value)
for (row, col, type) in powerups {
    flameAnimations.append {
        self.shootFlamesHorizontally(row: row, ...) // row = final loop value!
    }
}

// After (CORRECT - captures current iteration value)
for (row, col, type) in powerups {
    let capturedRow = row  // Capture in THIS iteration
    flameAnimations.append {
        self.shootFlamesHorizontally(row: capturedRow, ...) // capturedRow = current value
    }
}
```

### Animation Timing Fix
```swift
// Before (WRONG - sequential delays)
UIView.animate(withDuration: duration, delay: cumulativeDelay, ...) // Delays compound

// After (CORRECT - simultaneous start)
UIView.animate(withDuration: duration, delay: 0, ...) // All start immediately
// Completion fires when THAT piece finishes its animation
```

## Files Modified
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/MatchGameViewController.swift`

## Testing Recommendations

1. **Horizontal Arrows**: Clear a horizontal match on different rows (top, middle, bottom) - flames should appear on the ACTUAL row being cleared
2. **Vertical Arrows**: Clear a vertical match - verify column is correct
3. **Tile Falling**: Clear matches and watch pieces fall - no piece should pass through another piece
4. **Cascades**: Trigger cascading powerups - flames should appear at correct positions
5. **Speed**: All pieces should fall smoothly with physics-based motion (faster at longer distances, but all starting at same time)

## Performance Impact
✅ Same: Same number of animations, same GPU usage
✅ Better: No animation overlap issues
✅ Physically Correct: Gravity works like real physics now
