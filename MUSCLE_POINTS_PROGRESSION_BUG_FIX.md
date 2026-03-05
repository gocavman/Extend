# Muscle Points Progression Bug - Root Cause & Fix

## Problem Statement
**When all muscle points = 0:** Stick figure is Extra Small Stand ✅  
**When all muscle points = 100:** Stick figure is **still Extra Small Stand** ❌  
Expected: Should be Extra Large Stand

## Root Cause Analysis

### Issue #1: Stroke Thickness Multiplier Double Application (FIXED)
**File:** `/Users/cavan/Developer/Extend/Extend/SpriteKit/GameplayScene.swift` (lines 706-713)

**Problem:**
- Stroke thicknesses are interpolated from 5 frames via `getBodyPartValue()` (lines 661-666)
- These interpolated values were then being multiplied by `strokeThicknessMultiplier` derived property
- This caused a **double application** that broke the progression

**Before Fix:**
```swift
// Get and apply stroke thickness multiplier to all stroke thicknesses
let strokeThicknessMultiplier = MuscleSystem.shared.getDerivedPropertyValue(
    for: "strokeThicknessMultiplier", 
    state: gameState.muscleState
)
scaledFigure.strokeThicknessUpperTorso *= strokeThicknessMultiplier  // WRONG!
scaledFigure.strokeThicknessLowerTorso *= strokeThicknessMultiplier  // WRONG!
// ... etc
```

**After Fix:**
```swift
// NOTE: Stroke thicknesses are already interpolated from the 5-frame system above.
// Do NOT apply an additional multiplier - they're direct interpolations of frame values.
```

### Issue #2: animations.json Frame Data Problem (NEEDS USER ACTION)
**File:** `/Users/cavan/Developer/Extend/Extend/animations.json`

**Current State (WRONG):**
- Extra Small Stand: strokeThicknessUpperTorso = **5** (should be 1-2)
- Small Stand: strokeThicknessUpperTorso = **4** (should be 2-3)
- Stand: strokeThicknessUpperTorso = **5** (should be 4)
- Large Stand: strokeThicknessUpperTorso = **5** (should be 5)
- Extra Large Stand: strokeThicknessUpperTorso = **5** (should be 5-6)

**The Problem:**
All stroke thicknesses are nearly identical across frames, so interpolation produces no visible change!

**Compare to game_muscles.json (which has correct progression):**
```json
"strokeThicknessUpperTorso": {
  "0": 2.0,
  "25": 3.0,
  "50": 4.5,
  "75": 4.8,
  "100": 5.0
}
```

## How the Interpolation System Works

1. **Load 5 Stand frames** from animations.json ordered as:
   - Frame 0: Extra Small Stand (0 points)
   - Frame 1: Small Stand (25 points)
   - Frame 2: Stand (50 points)
   - Frame 3: Large Stand (75 points)
   - Frame 4: Extra Large Stand (100 points)

2. **For any muscle point value 0-100:**
   - Find the 2 surrounding frames
   - Linearly interpolate property values between them
   - Example: At 60 points, interpolate between Stand and Large Stand

3. **The interpolation only works if frame values actually change**
   - If Stand and Large Stand have the same strokeThicknessUpperTorso (5.0), there's no change!

## Next Steps (User Must Do)

You need to regenerate or manually update the 5 Stand frames in animations.json so that stroke thicknesses progress:

### Recommended Stroke Thickness Values:

**Extra Small Stand (frameNumber: 0):**
```json
"strokeThicknessJoints": 1.0,
"strokeThicknessLowerArms": 1.5,
"strokeThicknessLowerLegs": 1.5,
"strokeThicknessLowerTorso": 1.5,
"strokeThicknessUpperArms": 1.5,
"strokeThicknessUpperLegs": 1.5,
"strokeThicknessUpperTorso": 1.5
```

**Small Stand (frameNumber: 0):**
```json
"strokeThicknessJoints": 1.4,
"strokeThicknessLowerArms": 2.5,
"strokeThicknessLowerLegs": 2.5,
"strokeThicknessLowerTorso": 3.0,
"strokeThicknessUpperArms": 3.0,
"strokeThicknessUpperLegs": 3.5,
"strokeThicknessUpperTorso": 3.0
```

**Stand (frameNumber: 0):** ✅ (Already correct)
```json
"strokeThicknessJoints": 1.8,
"strokeThicknessLowerArms": 4.0,
"strokeThicknessLowerLegs": 4.0,
"strokeThicknessLowerTorso": 5.0,
"strokeThicknessUpperArms": 4.0,
"strokeThicknessUpperLegs": 5.0,
"strokeThicknessUpperTorso": 5.0
```

**Large Stand (frameNumber: 0):** (Should be slightly larger than Stand)
```json
"strokeThicknessJoints": 1.9,
"strokeThicknessLowerArms": 4.2,
"strokeThicknessLowerLegs": 4.2,
"strokeThicknessLowerTorso": 5.2,
"strokeThicknessUpperArms": 4.2,
"strokeThicknessUpperLegs": 5.3,
"strokeThicknessUpperTorso": 5.2
```

**Extra Large Stand (frameNumber: 0):** (Maximum values)
```json
"strokeThicknessJoints": 2.0,
"strokeThicknessLowerArms": 4.5,
"strokeThicknessLowerLegs": 4.5,
"strokeThicknessLowerTorso": 5.5,
"strokeThicknessUpperArms": 4.5,
"strokeThicknessUpperLegs": 5.5,
"strokeThicknessUpperTorso": 5.5
```

## Summary

✅ **FIXED:** Removed double-application of strokeThicknessMultiplier in GameplayScene.swift

⏳ **PENDING:** User must update animations.json stroke thickness values to have proper progression from 0-100 points

## Testing After Frame Updates

Once you update the 5 Stand frames:
1. In Customization, set all muscle points to 0 → should be Extra Small Stand
2. Set all muscle points to 25 → should be Small Stand
3. Set all muscle points to 50 → should be Stand
4. Set all muscle points to 75 → should be Large Stand
5. Set all muscle points to 100 → should be Extra Large Stand (noticeably larger strokes and fusiforms)
