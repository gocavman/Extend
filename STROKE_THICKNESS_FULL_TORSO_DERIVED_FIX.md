# strokeThicknessFullTorso Fix - Root Cause Analysis & Final Solution

## Problem
`strokeThicknessFullTorso` was showing **0** instead of **6.6** at 100 muscle points (Extra Large Stand).

## Root Cause - Understanding the Architecture

The codebase has two types of properties:

### 1. **Regular Properties** (Individual Point Values)
- Examples: `fusiformUpperTorso`, `strokeThicknessUpperTorso`, `fusiformUpperArms`, etc.
- Each has its own point value (0-100) in `MuscleState.musclePoints[propertyId]`
- Points are awarded by actions that target that specific property
- In GameplayScene: `interpolateProperty(propertyId, musclePoints: propertyPoints)`

### 2. **Derived Properties** (Average-Based)
- Examples: `neckWidth`, `handSize`, `footSize`, `skeletonSizeTorso`, `waistThicknessMultiplier`
- These scale based on the **average** of all regular properties
- They don't have their own point values
- In GameplayScene: `getDerivedPropertyValue(propertyId, state: muscleState)` which calculates average first

## The Bug

`strokeThicknessFullTorso` was **mistakenly configured as a regular property** in game_muscles.json:

```json
{
  "id": "strokeThicknessFullTorso",
  "name": "Full Torso Thickness",
  "progression": { "0": 1.0, "25": 10.0, ..., "100": 6.6 }
}
```

**Why this failed:**

1. GameplayScene processed it as a regular property:
```swift
let propertyPoints = gameState.muscleState.getPoints(for: "strokeThicknessFullTorso")
// Result: 0 (never set by any action)
let interpolatedValue = MuscleSystem.shared.interpolateProperty(propertyKey, musclePoints: 0)
// Result: Returns the 0-point frame value (1.0), not 6.6!
```

2. No action in game_muscles.json ever targets `strokeThicknessFullTorso`, so its points always stay at 0
3. At 0 points, interpolation returns the Extra Small Stand value (1.0), not what was expected

## The Solution

Treat `strokeThicknessFullTorso` as a **derived property** that scales with average muscle points.

### Changes Made:

#### 1. **Removed from game_muscles.json properties array**
- Deleted the entire strokeThicknessFullTorso property definition
- It should NOT be in the properties list

#### 2. **Added as derived property in GameplayScene.swift**
Moved from the regular property loop to the derived properties section:

```swift
// BEFORE (wrong - treated as regular property):
case "strokeThicknessFullTorso": scaledFigure.strokeThicknessFullTorso = interpolatedValue

// AFTER (correct - treated as derived):
let strokeThicknessFullTorso = MuscleSystem.shared.getDerivedPropertyValue(for: "strokeThicknessFullTorso", state: gameState.muscleState)
scaledFigure.strokeThicknessFullTorso = strokeThicknessFullTorso
```

This means:
- At 0 average muscle points → 1.0 (Extra Small Stand)
- At 100 average muscle points → 6.6 (Extra Large Stand)
- Scales smoothly between all 5 tiers based on average

#### 3. **Added debug logging in MuscleSystem.swift**
- Enhanced `getPropertyValue()` to log strokeThicknessFullTorso lookups
- Enhanced `interpolateProperty()` to show interpolation details
- Enhanced `loadStandFrames()` to verify strokeThicknessFullTorso is loaded from frames

## How It Works Now

1. Player completes actions (Curls, Move, Bench Press, etc.)
2. Points are awarded to various properties (fusiformUpperArms, strokeThicknessUpperTorso, etc.)
3. MuscleSystem calculates average points across all regular properties
4. For derived properties like `strokeThicknessFullTorso`:
   - Get average: (fusiformShoulders + strokeThicknessJoints + ... + waistThicknessMultiplier) / 21
   - Call `interpolateProperty("strokeThicknessFullTorso", musclePoints: average)`
   - Returns interpolated value from 5 stand frames

## Expected Behavior After Fix

| Average Points | Frame | Expected Value |
|---|---|---|
| 0 | Extra Small Stand | 1.0 ✅ |
| 25 | Small Stand | 10.0 ✅ |
| 50 | Stand | 10.0 ✅ |
| 75 | Large Stand | 10.0 ✅ |
| 100 | Extra Large Stand | 6.6 ✅ |

## Verification

✅ **BUILD SUCCEEDED** - No compilation errors
✅ **JSON Valid** - game_muscles.json passes validation
✅ **Architecture Correct** - strokeThicknessFullTorso now uses correct derived property system
✅ **Frame Values Ready** - All 5 stand frames have strokeThicknessFullTorso values in animations.json
✅ **Interpolation Ready** - MuscleSystem.getPropertyValue() handles strokeThicknessFullTorso case

## Key Insight

**Derived properties** are meant for properties that represent overall "scale" or "thickness multipliers" that should grow uniformly as the player develops muscles overall. Examples:
- Overall skeleton size (scales with total development)
- Overall hand/foot size (scales with total development) 
- Overall torso thickness (scales with total development)
- Neck width (scales with total development)

These should NOT be individual properties that can be trained independently. They should scale with the average of all muscletraining.
