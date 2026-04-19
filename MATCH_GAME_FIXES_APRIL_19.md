# Match Game Fixes - April 19, 2026

## Issues Fixed

### 1. ✅ Tiles Passing Through Each Other in First Row During Cascading
**Problem**: Pieces were sometimes passing through each other during cascading operations, particularly in the first row.

**Root Cause**: Timing mismatch between cascading powerup animations and gravity application. The delay (0.5s) didn't account for flame animation completion.

**Solution**: 
- Increased delay from 0.5s to 0.6s after cascading powerups complete to ensure flame animations finish before gravity applies
- This gives proper buffer time for all visual effects to settle before pieces start falling

### 2. ✅ Inconsistent Falling Speeds
**Problem**: Pieces fell at inconsistent speeds - some fast, some slow, creating visual jank.

**Root Cause**: All pieces were using a fixed 0.6s animation duration regardless of actual distance fallen.

**Solution**:
- Implemented speed-based falling: `600 pixels/second` constant speed
- Calculate animation duration based on actual fall distance: `duration = distance / 600`
- This ensures all pieces fall at consistent speed proportional to distance
- Sequential pieces now start after previous piece completes its actual animation time (not fixed 0.6s)

**Changed in**: `animatePiecesDrop()` function

### 3. ✅ Flames Not Moving Properly
**Problems**:
- Only one flame was showing per row/column clear
- Horizontal arrow flames appeared on wrong row
- Should shoot in BOTH directions (left+right for horizontal, up+down for vertical)

**Root Causes**:
- `shootFlamesVertically()` only shot downward, didn't shoot upward
- `shootFlamesHorizontally()` only shot rightward, didn't shoot leftward  
- Started from edge instead of center of cleared area
- Horizontal flames started from wrong row (lowerBound instead of middle)

**Solutions**:

#### shootFlamesVertically()
- Now creates TWO flame objects: one shooting UP, one shooting DOWN
- Finds middle row of the column range
- Starts both flames from middle row center
- One animates upward to top row, one animates downward to bottom row
- Both use consistent 0.5s animation

#### shootFlamesHorizontally()
- Now creates TWO flame objects: one shooting LEFT, one shooting RIGHT
- Finds middle column of the row range  
- Starts both flames from middle column center
- One animates leftward to leftmost column, one animates rightward to rightmost column
- Both use consistent 0.5s animation
- **Fixed**: Now correctly uses the actual row parameter instead of starting from wrong row

## Technical Changes

### Files Modified
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/MatchGameViewController.swift`

### Key Functions Updated
1. **animatePiecesDrop()** - Speed-based animations with consistent velocity
2. **shootFlamesVertically()** - Now shoots both up and down
3. **shootFlamesHorizontally()** - Now shoots both left and right, correct row positioning
4. **applyGravity()** - Updated to use new animation timing calculations
5. **applyGravityAfterCascade()** - Updated to use new animation timing calculations
6. **activateCascadingPowerups()** - Increased delay from 0.5s to 0.6s

### Animation Constants
- `fallSpeedPixelsPerSecond: CGFloat = 600` - Consistent falling velocity
- Flame duration: `0.5s` - Fixed for smooth effect

## Testing Recommendations

1. **Tile Falling**: Watch pieces fall after matches - should see smooth sequential falls without jank
2. **Cascading Powerups**: Activate arrows and bombs - verify cascades complete before new pieces settle
3. **Flame Effects**: 
   - Match 4+ horizontally - should see flames shoot left AND right from center
   - Match 4+ vertically - should see flames shoot up AND down from center
   - Flames should start/end at correct positions
4. **Speed**: All pieces should fall at visually consistent speed regardless of distance

## Performance Impact
- Minimal - animations are still GPU-accelerated UIView animations
- More accurate timing prevents overflow of pending animations
- Better visual quality through consistent physics
