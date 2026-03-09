# Muscle Development System - Refactored with Muscle Groups

## Overview

The game_muscles.json has been restructured to use **muscle groups** as the primary organizational unit. This makes it much easier to:
- Add new exercises that target specific muscle groups
- Have multiple properties contribute to the same muscle group
- Understand the mapping between exercises, muscle groups, and visual properties

## New Structure

### Before (Property-Based Distribution)
```json
{
  "id": "curls",
  "propertyDistribution": [
    {"propertyId": "fusiformUpperArms", "percentage": 40},
    {"propertyId": "strokeThicknessUpperArms", "percentage": 40},
    {"propertyId": "fusiformLowerArms", "percentage": 20}
  ]
}
```

**Problem:** Had to manually list every property affected by each action.

### After (Muscle Group-Based Distribution)
```json
{
  "id": "curls",
  "targetMuscleGroups": [
    {"muscleGroup": "Biceps", "percentage": 100}
  ]
}
```

**Benefit:** Automatically distributes to ALL properties in the "Biceps" muscle group.

## Muscle Groups Defined

| Muscle Group | Properties | Visual Effect |
|---|---|---|
| **Shoulders** | fusiformShoulders, strokeThicknessJoints | Shoulder width & joint size |
| **Chest** | fusiformUpperTorso, strokeThicknessUpperTorso | Upper torso bulge & thickness |
| **Back** | *(Shares upper torso properties with Chest)* | Same as Chest |
| **Biceps** | fusiformUpperArms, strokeThicknessUpperArms | Upper arm bulge & thickness |
| **Triceps** | fusiformLowerArms, strokeThicknessLowerArms | Lower arm bulge & thickness |
| **Abs** | fusiformLowerTorso, strokeThicknessLowerTorso | Lower torso bulge & thickness |
| **Quads** | fusiformUpperLegs, strokeThicknessUpperLegs | Upper leg bulge & thickness |
| **Hamstrings** | *(Shares upper leg properties with Quads)* | Same as Quads |
| **Calfs** | fusiformLowerLegs, strokeThicknessLowerLegs | Lower leg bulge & thickness |
| **Derived** | neckWidth, handSize, footSize, skeletonSize*, waistThickness | Overall body scale (automatic) |

## How It Works

### 1. Action Execution
User completes "Curls" exercise

### 2. Points Distribution
```
"Curls" awards 5 points
↓
Target: Biceps (100%)
↓
Find all properties in "Biceps" group:
  - fusiformUpperArms
  - strokeThicknessUpperArms
↓
Divide 100% equally:
  - fusiformUpperArms: 5 points × 50% = 2.5 points
  - strokeThicknessUpperArms: 5 points × 50% = 2.5 points
```

### 3. Rendering
Each property interpolates from progression values:
```
fusiformUpperArms: 2.5 points → 0.92 visual value (interpolated)
strokeThicknessUpperArms: 2.5 points → 4.2 visual value (interpolated)
```

### 4. Visual Update
Upper arms render with the interpolated values → visible growth!

## Adding New Exercises

**Example: Add a "Back Workout" exercise**

```json
{
  "id": "backWorkout",
  "name": "Back Workout",
  "description": "Back exercise",
  "pointsAwarded": 5,
  "frequency": { "count": 1, "unit": "day" },
  "targetMuscleGroups": [
    {"muscleGroup": "Back", "percentage": 100}
  ]
}
```

That's it! The system automatically knows to distribute points to all properties in the "Back" group.

## Combining Multiple Muscle Groups

**Example: Full Body Workout**

```json
{
  "id": "fullBody",
  "name": "Full Body Workout",
  "pointsAwarded": 10,
  "targetMuscleGroups": [
    {"muscleGroup": "Chest", "percentage": 20},
    {"muscleGroup": "Back", "percentage": 20},
    {"muscleGroup": "Biceps", "percentage": 20},
    {"muscleGroup": "Triceps", "percentage": 20},
    {"muscleGroup": "Quads", "percentage": 20}
  ]
}
```

Each muscle group gets 20% of the points, divided equally among its properties.

## Code Changes

### MuscleSystem.swift
- **GameAction** now uses `targetMuscleGroups: [MuscleGroupDistribution]`
- **PropertyDefinition** now uses `muscleGroup: String?` instead of `category`
- Removed `PropertyDistribution` struct (no longer needed)

### Game1Module.swift
- **awardMuscleLevelPoints()** now:
  1. Gets target muscle groups from action
  2. Finds all properties in each group
  3. Divides points equally among properties in group
  4. Awards to each property

### StickFigureAppearanceViewController.swift
- **getRegularProperties()** filter changed from `category != "derived"` to `muscleGroup != "Derived"`

## Benefits

✅ **Simpler JSON**: Exercises reference muscle groups, not individual properties  
✅ **Extensible**: Add new properties to a muscle group without changing action definitions  
✅ **Maintainable**: Clear mapping between exercises and visual effects  
✅ **Flexible**: Can combine multiple muscle groups in single exercise  
✅ **Scalable**: Works with any number of properties per muscle group

## Build Status

✅ **BUILD SUCCEEDED** - No compilation errors
✅ **JSON VALID** - game_muscles.json passes validation
✅ **Code Refactored** - All references updated to use new structure
