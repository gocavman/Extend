# Property Save/Load Fix Summary

## Problem
When saving a frame in the editor, `armMuscleSide` and several other properties were not being saved to the JSON, even though they were properly defined in `EditModeValues` and being passed to the `SavedEditFrame` initializer.

## Root Cause
The `SavedEditFrame` initializer had two paths:
1. **Path 1 (when `pose` is provided)**: Read properties from the pose object
2. **Path 2 (when `pose` is nil)**: Fall back to default values

When saving frames from the editor, `pose` was being passed as `nil`, which meant the initializer was ignoring the `EditModeValues` data and using hardcoded defaults instead.

## Properties Affected
All stroke thickness values and `armMuscleSide` were not being saved:
- ❌ `armMuscleSide` 
- ❌ `strokeThicknessJoints`
- ❌ `strokeThicknessLowerArms`
- ❌ `strokeThicknessLowerLegs`
- ❌ `strokeThicknessLowerTorso`
- ❌ `strokeThicknessBicep`
- ❌ `strokeThicknessTricep`
- ❌ `strokeThicknessUpperLegs`
- ❌ `strokeThicknessUpperTorso`
- ❌ `strokeThicknessFullTorso`
- ❌ `strokeThicknessDeltoids`
- ❌ `strokeThicknessTrapezius`
- ❌ `peakPositionBicep` (was using hardcoded default instead of values)
- ❌ `peakPositionTricep` (was using hardcoded default instead of values)
- ❌ `peakPositionLowerArms` (was using hardcoded default instead of values)
- ❌ `peakPositionUpperLegs` (was using hardcoded default instead of values)
- ❌ `peakPositionLowerLegs` (was using hardcoded default instead of values)
- ❌ `peakPositionUpperTorso` (was using hardcoded default instead of values)
- ❌ `peakPositionLowerTorso` (was using hardcoded default instead of values)
- ❌ `peakPositionDeltoids` (was using hardcoded default instead of values)

## Solution
Modified the `SavedEditFrame` initializer (`init(id:name:frameNumber:from:pose:objects:)`) in `SavedEditFrame.swift` to:

1. **For peak positions** (lines 165-173): Changed from using hardcoded defaults to using values from `EditModeValues` when pose is nil:
   ```swift
   self.peakPositionBicep = values.peakPositionBicep ?? 0.5
   self.peakPositionTricep = values.peakPositionTricep ?? 0.5
   // ... etc
   self.armMuscleSide = values.armMuscleSide ?? "normal"
   ```

2. **For stroke thickness** (lines 260-281): Changed from using hardcoded defaults to using values from `EditModeValues` when pose is nil:
   ```swift
   self.strokeThicknessJoints = values.strokeThicknessJoints ?? 2.5
   self.strokeThicknessLowerArms = values.strokeThicknessLowerArms ?? 3.5
   // ... etc
   ```

## Result
✅ All properties are now correctly saved to JSON when saving frames from the editor
✅ When the frame is loaded or copied, all these properties are preserved
✅ The `armMuscleSide` property is now persisted in animations.json with values like "normal", "flipped", or "both"

## Files Modified
- `/Users/cavan/Developer/Extend/Extend/Models/SavedEditFrame.swift`

## Testing
1. Create a new frame in the editor
2. Adjust `armMuscleSide`, stroke thickness, and peak position values
3. Copy the frame to clipboard
4. Verify that all these properties appear in the JSON (they should now be present)
