# Stroke Thickness Debug & Analysis

## Current Status
- ✅ Generic `strokeThickness` property removed from all frames in animations.json
- ✅ Typo fixed in "Small Stand" frame (`shoulderWidthMu0plier` → `shoulderWidthMultiplier`)
- ✅ All 5 Stand frames have individual stroke thickness properties:
  - `strokeThicknessJoints`
  - `strokeThicknessUpperTorso`
  - `strokeThicknessLowerTorso`
  - `strokeThicknessUpperArms`
  - `strokeThicknessLowerArms`
  - `strokeThicknessUpperLegs`
  - `strokeThicknessLowerLegs`

## Expected Flow

### 1. Animation JSON Storage
Each frame stores stroke thickness values:
```json
"strokeThicknessUpperTorso" : 5,
"strokeThicknessLowerTorso" : 5,
"strokeThicknessUpperArms" : 4,
"strokeThicknessLowerArms" : 4,
"strokeThicknessUpperLegs" : 5,
"strokeThicknessLowerLegs" : 4,
"strokeThicknessJoints" : 2
```

### 2. MuscleSystem Loading
When `MuscleSystem.loadStandFrames()` is called, it should:
1. Load all frames from animations.json
2. Find the 5 Stand frames (Extra Small, Small, Stand, Large, Extra Large)
3. Store them in `standFrames` array in order

### 3. Gameplay Interpolation
When muscle points change (0-100):
1. `GameplayScene.applyMuscleScaling()` is called
2. For each property like "strokeThicknessUpperTorso":
   - Call `MuscleSystem.interpolateProperty("strokeThicknessUpperTorso", points: 37)`
   - This looks up values from all 5 frames
   - Linear interpolation occurs between frames
3. Result is applied to `scaledFigure.strokeThicknessUpperTorso`

### 4. Rendering
The `StickFigure2D` drawing functions use these stroke values:
```swift
drawSegment(..., strokeThickness: figure.strokeThicknessUpperTorso, ...)
```

## What Should Happen at Each Muscle Point Level

### At 0 points (Extra Small Stand)
- All stroke thicknesses should match the "Extra Small Stand" frame values
- Expected: All visible strokes should be minimal

### At 25 points (Small Stand)
- All stroke thicknesses interpolate between Extra Small and Small frames
- Expected: Slightly thicker strokes than 0 points

### At 50 points (Stand)
- All stroke thicknesses interpolate between Small and Stand frames
- Expected: Medium stroke thickness (original frame values)

### At 75 points (Large Stand)
- All stroke thicknesses interpolate between Stand and Large frames
- Expected: Thicker strokes than 50 points

### At 100 points (Extra Large Stand)
- All stroke thicknesses should match the "Extra Large Stand" frame values
- Expected: Maximum stroke thickness

## Current Issue
Console shows: `skeletonSize=0.0, fusiformUpperTorso=0.0, fusiformUpperArms=0.0`

This suggests:
1. Either the standFrames array is empty (0 frames loaded)
2. Or the interpolateProperty method is not finding these properties

## Next Steps to Debug
1. Add logging to `MuscleSystem.loadStandFrames()` to verify all 5 frames are loaded
2. Add logging to `MuscleSystem.interpolateProperty()` to verify property lookup
3. Check that `getPropertyValue()` is returning correct values for stroke thickness properties
4. Verify animations.json is in the app bundle and can be decoded
