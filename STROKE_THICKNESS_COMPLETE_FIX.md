# Stroke Thickness Fix - Complete Solution

## Problem Identified
Stroke thickness values were not being rendered in gameplay even though:
1. ✅ Individual stroke thickness properties existed in animations.json (strokeThicknessUpperTorso, etc.)
2. ✅ They were being decoded from animations.json
3. ✅ The StickFigure2D model had the properties defined
4. ✅ The rendering code used these properties

**Root Cause**: The interpolation logic was using the wrong data source!

## The Root Cause - Two Different Interpolation Systems

The codebase had **two different ways to interpolate values**:

### 1. Muscle FrameValues System (Used Incorrectly)
```swift
// From GameplayScene.applyMuscleScaling()
let interpolatedValue = MuscleSystem.shared.getBodyPartValue(for: bodyPart, muscleId: muscle.id, ...)
// This looks up values from the muscle's frameValues in game_muscles.json
// Problem: game_muscles.json doesn't have stroke thickness properties!
```

### 2. Stand Frames System (Correct for Strokes)
```swift
// Should be used instead
let interpolatedValue = MuscleSystem.shared.interpolateProperty("strokeThicknessUpperTorso", musclePoints: 37)
// This looks up values from the 5 Stand frames in animations.json
// This is correct because animations.json has all stroke thickness properties
```

## The Fix

Changed `GameplayScene.applyMuscleScaling()` to use the correct interpolation for each type of property:

```swift
// For stroke thickness properties - use Stand frames (animations.json)
if bodyPart.hasPrefix("strokeThickness") {
    let interpolatedValue = MuscleSystem.shared.interpolateProperty(bodyPart, musclePoints: musclePoints)
    // Apply to figure...
}

// For fusiform properties - use muscle frameValues (game_muscles.json)
else {
    let interpolatedValue = MuscleSystem.shared.getBodyPartValue(for: bodyPart, muscleId: muscle.id, ...)
    // Apply to figure...
}
```

## Changes Made

### 1. ✅ Cleaned up animations.json
- Removed generic `"strokeThickness"` property from all frames (Stand, Large Stand, Extra Large Stand, Extra Small Stand, Small Stand, all Move frames, Curls frame)
- Fixed typo in "Small Stand" frame: `"shoulderWidthMu0plier"` → `"shoulderWidthMultiplier"`
- Verified all specific stroke thickness properties are present:
  - `strokeThicknessJoints`
  - `strokeThicknessUpperTorso`
  - `strokeThicknessLowerTorso`
  - `strokeThicknessUpperArms`
  - `strokeThicknessLowerArms`
  - `strokeThicknessUpperLegs`
  - `strokeThicknessLowerLegs`

### 2. ✅ Fixed GameplayScene.applyMuscleScaling()
- Separated stroke thickness interpolation from fusiform interpolation
- Stroke thicknesses now use `interpolateProperty()` (Stand frames)
- Fusiform values continue to use `getBodyPartValue()` (muscle frameValues)

## Expected Behavior After Fix

### At 0 Muscle Points
- Uses "Extra Small Stand" frame values
- Minimal stroke thicknesses (per frame definition)

### At 25 Muscle Points
- Interpolates between Extra Small and Small Stand frames
- Stroke thickness increases gradually

### At 50 Muscle Points
- Interpolates between Small and Stand frames
- Medium stroke thickness (original frame values)

### At 75 Muscle Points
- Interpolates between Stand and Large Stand frames
- Thicker strokes than 50 points

### At 100 Muscle Points
- Uses "Extra Large Stand" frame values
- Maximum stroke thicknesses (per frame definition)

## Data Flow Summary

```
Muscle Points (0-100)
  ↓
applyMuscleScaling()
  ├─ Stroke properties → interpolateProperty() → Stand frames (animations.json)
  └─ Fusiform properties → getBodyPartValue() → Muscle frameValues (game_muscles.json)
  ↓
StickFigure2D object receives interpolated values
  ↓
renderStickFigure() uses these values to draw body parts
  └─ drawSegment(..., strokeThickness: figure.strokeThicknessUpperTorso, ...)
```

## Files Modified
1. `/Users/cavan/Developer/Extend/Extend/animations.json` - Cleanup
2. `/Users/cavan/Developer/Extend/Extend/SpriteKit/GameplayScene.swift` - Fix interpolation logic

## Verification
- ✅ No build errors
- ✅ animations.json is valid JSON
- ✅ All 5 Stand frames present in animations.json
- ✅ All frames have stroke thickness properties
- ✅ GameplayScene correctly uses frame-based interpolation for strokes
