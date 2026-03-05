# Stroke Thickness Fix Summary

## The Problem
The stroke thickness values in animations.json were being **multiplied** by `strokeThicknessMultiplier` from the MuscleSystem, which caused:

1. **At 0 muscle points**: The stroke was extremely thin (close to 0) because the multiplier was 0.5
2. **At 100 muscle points**: The stroke was still incorrect because the multiplier was 2.0, but the stored stroke values in animations.json were already the final intended values

This made the stick figure appear inconsistently rendered compared to the editor.

## Root Cause
In commit c497bbd, I incorrectly added a helper function `getStrokeThickness()` that multiplied the stored stroke thickness values by `MuscleSystem.shared.getDerivedPropertyValue(for: "strokeThicknessMultiplier")`.

**This was wrong** because:
- The stroke thickness values in animations.json are **already the final values** that should be used
- They are not base values meant to be scaled by a multiplier
- The `strokeThicknessMultiplier` field in animations.json is a separate property (likely for waist/proportion scaling)

## The Fix
Removed the multiplier logic entirely and now use the stroke thickness values directly as stored in the StickFigure2D object:

```swift
// BEFORE (WRONG):
let lowerTorsoStroke = getStrokeThickness(for: "lowerTorso")  // multiplied by muscle system multiplier
drawTaperedSegment(..., strokeThickness: lowerTorsoStroke, ...)

// AFTER (CORRECT):
drawTaperedSegment(..., strokeThickness: mutableFigure.strokeThicknessLowerTorso, ...)
```

## Changes Made
- Removed the `getStrokeThickness()` helper function
- Removed all calls to `getStrokeThickness()`
- Replaced all stroke references with direct values from `mutableFigure`:
  - `mutableFigure.strokeThicknessUpperTorso`
  - `mutableFigure.strokeThicknessLowerTorso`
  - `mutableFigure.strokeThicknessUpperArms`
  - `mutableFigure.strokeThicknessLowerArms`
  - `mutableFigure.strokeThicknessUpperLegs`
  - `mutableFigure.strokeThicknessLowerLegs`
  - `mutableFigure.strokeThicknessJoints`

## Verification
The stroke thickness values in animations.json match what was in commit 57d6d1d:
- **Extra Small Stand**: strokeThickness=0.0, strokeThicknessMultiplier=0.5
- **Small Stand**: strokeThickness=1.0, strokeThicknessMultiplier=1.0
- **Stand**: strokeThickness=1.2, strokeThicknessMultiplier=1.2
- **Large Stand**: strokeThickness=1.4, strokeThicknessMultiplier=1.4
- **Extra Large Stand**: strokeThickness=2.0, strokeThicknessMultiplier=2.0

These are now being used correctly without any additional multiplication.
