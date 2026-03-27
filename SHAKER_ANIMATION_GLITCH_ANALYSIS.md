# Shaker Animation Glitch Analysis

## Issue Found ✓

The "shaker" animation is glitchy because the `variableTiming` configuration is **completely ignored** in the playback code.

## Current Shaker Config

From `actions_config.json`:
```json
{
  "id": "shaker",
  "displayName": "Shaker",
  "variableTiming": {
    "1": 5.0
  },
  "stickFigureAnimation": {
    "animationName": "Shaker",
    "frameNumbers": [1, 2, 3, 3, 3, 2, 1],
    "baseFrameInterval": 0.2
  }
}
```

**Intent**: Frame 1 should hold for 5.0 seconds, then frames 2-7 should play at 0.2s each.

**Current Behavior**: ALL frames play at 0.2s intervals, ignoring the 5.0s timing for frame 1.

## Root Cause

**Location**: `Game1Module.swift`, `startActionWithVariableTiming()` method (lines ~1430-1530)

**The Problem**:
```swift
// Line 1512-1516 - IGNORES variableTiming parameter
let baseInterval = config.stickFigureAnimation?.baseFrameInterval ?? 0.15
let interval = baseInterval * speedMultiplier
elapsedTime += interval

DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
    scheduleNextFrame()
}
```

**What's Wrong**:
1. The function receives `variableTiming: [Int: TimeInterval]` as a parameter
2. It's never used anywhere in the function
3. All frames use the same `baseFrameInterval`
4. The frame delay calculations ignore frame-specific custom timings

## Expected Behavior

The function should:
1. Look at the current frame number (1-based from config, but needs conversion)
2. Check if `variableTiming[currentFrameNumber]` exists
3. Use the custom timing if available, otherwise fall back to `baseFrameInterval`
4. Schedule the next frame with the correct delay

## What This Affects

- **Shaker**: Frame 1 should hold for 5s (currently only 0.2s) - This is why it looks glitchy
- Any other action with `variableTiming` in the config
- Affects animations that need variable timing between frames

## Technical Details

### Frame Number Mapping Issue
The config uses 1-based frame numbers (as displayed to users):
- `frameNumbers: [1, 2, 3, 3, 3, 2, 1]`

The code uses 0-based array indices:
- `frameIndex` ranges from 0 to 6

When checking `variableTiming`:
- `variableTiming["1"]` should apply to `frameIndex` 0
- `variableTiming["2"]` should apply to `frameIndex` 1
- etc.

## Fix Required

The `startActionWithVariableTiming()` method needs to be refactored to:

1. Get the current frame number from the config:
   ```swift
   let frameNumber = config.stickFigureAnimation?.frameNumbers[frameIndex] ?? 1
   ```

2. Check if custom timing exists for this frame:
   ```swift
   let customTiming = variableTiming[frameNumber]
   let interval = (customTiming ?? baseInterval) * speedMultiplier
   ```

3. Use the correct interval for scheduling the next frame

## Impact Assessment

**Severity**: Medium
- Only affects actions with `variableTiming` config
- Currently only Shaker uses this feature
- Makes shaker animation play incorrectly

**Complexity to Fix**: Low
- Simple logic fix in one function
- No architectural changes needed
- No impact on other animation systems

---

**Analysis Date**: March 26, 2026
**Status**: Issue identified, fix ready to implement
