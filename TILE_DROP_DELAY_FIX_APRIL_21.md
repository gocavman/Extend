# Match Game - Tile Drop Overlap Fix (April 21, 2026)

## Problem Statement
When clearing tiles with a swap match, tiles were overlapping mid-animation - some pieces reaching their midpoint while others dropped past them to fill lower spaces.

## Root Cause Analysis

### The Real Issue
The `animatePiecesDrop()` function was using a **uniform duration for all pieces in a column**, regardless of their actual fall distance:

```swift
// OLD (WRONG): All pieces animate for maxDistance duration
let uniformDuration = Double(fallDistance / fallSpeedPixelsPerSecond)  // Based on furthest piece
// Then apply to ALL pieces:
UIView.animate(withDuration: uniformDuration, delay: delay, ...)
```

**Example Scenario:**
- Column with pieces at rows [1, 2, 3] and new piece at row [0]
- Max distance = 2 (new piece at row 0)
- uniformDuration = 0.5s (time for piece falling 2 cells)

**Animation Problem:**
- Row 3 (distance=0): delay=0.0s, animates for 0.5s (finishes at 0.5s)
  - **Falls way too long! Piece lands immediately but animates down for 0.5s more**
- Row 2 (distance=0): delay=0.04s, animates for 0.5s (finishes at 0.54s)
  - **Falls down past row 3 mid-animation**
- Row 1 (distance=0): delay=0.08s, animates for 0.5s (finishes at 0.58s)
  - **Continues falling while other pieces are already settled**
- Row 0 (distance=2): delay=0.12s, animates for 0.5s (finishes at 0.62s)
  - **Correct fall time but pieces have already passed through each other**

### Why Overlap Happened
All pieces forced to animate for the **maximum distance duration**, even though:
- Pieces with distance=0 need 0 duration
- Pieces with distance=1 need 0.25s duration
- Piece with distance=2 needs 0.5s duration

When they all animate for 0.5s, short-distance pieces overshoot while long-distance pieces complete early.

## Solution

### Change Made
Modified `animatePiecesDrop()` to calculate **individual duration for each piece** based on its actual fall distance:

```swift
// OLD (WRONG):
let uniformDuration = Double(fallDistance / fallSpeedPixelsPerSecond)  // Max distance
UIView.animate(withDuration: uniformDuration, delay: delay, ...)

// NEW (CORRECT):
let actualDistance = fallDistances["\(row),\(col)"] ?? 0
let fallDistance = cellHeight * CGFloat(actualDistance)
let individualDuration = Double(fallDistance / fallSpeedPixelsPerSecond)  // This piece's actual distance
UIView.animate(withDuration: individualDuration, delay: delay, ...)
```

### Why This Works

**Corrected Animation:**
- Row 3 (distance=0): delay=0.0s, duration=0.0s (instant, no animation)
- Row 2 (distance=0): delay=0.04s, duration=0.0s (instant after delay)
- Row 1 (distance=0): delay=0.08s, duration=0.0s (instant after delay)
- Row 0 (distance=2): delay=0.12s, duration=0.5s (falls for exactly 0.5s)

**No overlap!** Each piece animates for only as long as it needs to fall its actual distance.

## Files Modified
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/MatchGameViewController.swift`
  - Lines 2321-2371 in `animatePiecesDrop()` function (animation loop)
  - Removed `uniformDuration` parameter from tuple
  - Calculate `individualDuration` for each piece based on actual fall distance

## Technical Implementation

### Staggering Still Preserved
Delay calculation unchanged:
```swift
let cumulativeDelay = 0.0
for (button, row, distance) in columnAnimations {
    let distanceBasedDelay = Double(maxDistance - distance) * 0.5 * oneRowFallTime
    let adjustedDelay = cumulativeDelay + distanceBasedDelay
    cumulativeDelay += oneRowFallTime  // Stagger by time to fall one row
}
```

The key: **Delay prevents collision start** + **Duration prevents collision mid-animation**

### Physics-Based Animation
- Pieces fall at consistent 400 pixels/second
- Duration = distance / speed
- Staggered delays ensure pieces don't start simultaneously
- Individual durations ensure pieces complete at right time

## Expected Behavior After Fix

### All Match Types
- ✅ Bottom pieces start falling first
- ✅ Sequential stagger prevents collision
- ✅ Each piece animates for exactly its fall time
- ✅ No piece overshoots its landing position
- ✅ Swap matches drop at same visual speed as arrow powerups

### Timing Example (5x5 grid, 1 row cleared)
Total drop time: ~0.6s instead of stuttering/overlapping animation

## Testing Recommendations

1. **Overlap Check**
   - Make swap matches and watch carefully
   - No piece should pass through another mid-drop
   - All pieces should settle cleanly

2. **Timing Consistency**
   - Swap match vs arrow powerup drops should look similar
   - Full column vs partial column should look proportional

3. **Cascade Smoothness**
   - Trigger cascading matches
   - Should see smooth sequential drops without jank

## Performance Impact
✅ **Same** - Same number of animations, same GPU usage
✅ **Better** - Eliminated overlap issues through correct duration calculation
