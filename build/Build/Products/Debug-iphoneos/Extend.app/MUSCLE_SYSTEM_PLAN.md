# Muscle Points & Progression System - Implementation Plan

## Overview
The muscle system is designed to map **actions** (exercises) → **muscles** → **body parts** → **stick figure properties**, with smooth interpolation across 5 size stages.

---

## Data Flow

### 1. Action Performed
```
User Action: "Bicep Curls"
↓
game_muscles.json: actions[] finds "Bicep Curls"
↓
Maps to targetMuscle: "upper_arms"
↓
Awards pointsConfig: 5 points per 5 minutes (configurable)
```

### 2. Muscle Point Accumulation
```
MuscleState.musclePoints["upper_arms"] += 5
(clamped to 0-100 range)
```

### 3. Property Interpolation (5-Frame Model)
```
Current points: 37 (between 25 and 50)
↓
MuscleSystem.interpolateProperty("fusiformUpperArms", 37)
↓
Frame values at boundaries:
  - 25 points: fusiformUpperArms = 2.1
  - 50 points: fusiformUpperArms = 2.74
↓
Linear interpolation: 2.1 + (2.74 - 2.1) × (37-25)/(50-25) = 2.407
↓
Result: 2.407 (smooth progression between stages)
```

### 4. Rendering
```
StickFigure2D receives interpolated values
↓
Upper arm limb drawn with fusiformUpperArms = 2.407
↓
Stroke thickness also interpolated:
  strokeThicknessUpperArms = 2.8 + (3.5 - 2.8) × ratio = ~3.088
↓
Visual result: Arms visibly growing as points increase
```

---

## 5 Size Stages (Points Thresholds)

| Points | Level | Frame Name | Description |
|--------|-------|-----------|-------------|
| 0 | Level 1 | Extra Small Stand | Minimum size |
| 25 | Level 2 | Small Stand | 25% progression |
| 50 | Level 3 | Stand | 50% (default) |
| 75 | Level 4 | Large Stand | 75% progression |
| 100 | Level 5 | Extra Large Stand | Maximum size |

**Example for Upper Torso:**
- 0 points: fusiform=0 (very thin)
- 25 points: fusiform=2.18 (small)
- 50 points: fusiform=5.85 (normal)
- 75 points: fusiform=5.82 (large)
- 100 points: fusiform=5.82 (extra large)

---

## Muscle → Body Parts Mapping

Each muscle can affect **multiple body parts**:

```
"upper_arms" muscle →
  - fusiformUpperArms
  - strokeThicknessUpperArms
  - (future) upperArmSkeletonSize
  - (future) jointThicknessArms
```

**Key Principle:** All mapped properties scale together based on that muscle's current points.

---

## game_muscles.json Structure

```json
{
  "actions": [
    {
      "name": "Move",
      "targetMuscle": "lower_legs",
      "percentage": 100
    },
    {
      "name": "Bicep Curls",
      "targetMuscle": "upper_arms",
      "percentage": 100
    }
  ],
  
  "pointsConfig": {
    "count": 5,          // Award 5 points per timeframe
    "timeframe": "minutes",
    "value": 5           // Per 5 minutes
  },
  
  "muscles": [
    {
      "id": "upper_arms",
      "name": "Biceps/Triceps",
      "bodyParts": ["fusiformUpperArms", "strokeThicknessUpperArms"],
      "frameValues": {
        "0": { "fusiformUpperArms": 0, "strokeThicknessUpperArms": 1.5 },
        "25": { "fusiformUpperArms": 2.1, "strokeThicknessUpperArms": 2.8 },
        "50": { "fusiformUpperArms": 2.74, "strokeThicknessUpperArms": 3.5 },
        "75": { "fusiformUpperArms": 3.17, "strokeThicknessUpperArms": 3.8 },
        "100": { "fusiformUpperArms": 3.17, "strokeThicknessUpperArms": 4.0 }
      }
    }
  ]
}
```

---

## Rendering in Gameplay

```swift
// Get interpolated values for each muscle
let upperArmFusiform = MuscleSystem.shared.interpolateProperty(
  "fusiformUpperArms",
  musclePoints: muscleState.getPoints(for: "upper_arms")
)

let upperArmStroke = MuscleSystem.shared.interpolateProperty(
  "strokeThicknessUpperArms",
  musclePoints: muscleState.getPoints(for: "upper_arms")
)

// Apply to figure
mutableFigure.fusiformUpperArms = upperArmFusiform
mutableFigure.strokeThicknessUpperArms = upperArmStroke

// Render
renderStickFigure(with: mutableFigure)
```

---

## Key Principles

1. **Simple 5-Frame Model**: Values are defined only at 0, 25, 50, 75, 100 points
2. **Linear Interpolation**: Smooth transitions between points
3. **Per-Muscle Scaling**: Each muscle independently controls its body parts
4. **No Multipliers**: Values are direct (no strokeThicknessMultiplier)
5. **Always Passing Values**: Gameplay always receives interpolated values from frames

---

## TODO Checklist

- [ ] Verify all 5 Stand frames exist in animations.json
- [ ] Remove `strokeThicknessMultiplier` from all frames
- [ ] Implement `interpolateProperty()` in MuscleSystem (done)
- [ ] Wire up gameplay to use interpolated values for each muscle
- [ ] Test at 0, 25, 50, 75, 100 points for smooth progression
- [ ] Implement point awarding logic when actions are performed
- [ ] Add visual feedback (optional: show muscle point bars in UI)

