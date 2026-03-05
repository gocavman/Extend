# Muscle System - Simplified Implementation

## What Changed

We simplified the muscle points progression system to use a **5-frame model** with **linear interpolation** instead of complex multipliers and calculations.

### Removed
- `strokeThicknessMultiplier` property from all frames in `animations.json`
- Any complex multiplier math in muscle scaling
- Unnecessary frame blending logic

### Kept
- 5 size stages (Extra Small, Small, Medium/Stand, Large, Extra Large)  
- Direct property values in each frame
- Linear interpolation between threshold points (0, 25, 50, 75, 100)

---

## How It Works Now

### 1. Frame Definition (animations.json)
Each stick figure frame (stand, move animations, etc.) is defined with explicit property values:

```json
{
  "name": "Extra Small Stand",
  "pose": {
    "fusiformUpperTorso": 0.0,
    "fusiformUpperArms": 0.0,
    "strokeThicknessUpperTorso": 0.0,
    "skeletonSize": 0.0,
    ... other properties
  }
}
```

**No multipliers.** Just the actual values for that size level.

### 2. Muscle Points Stored (0-100)
In gameplay, each muscle tracks points from 0 to 100:

```swift
muscleState.setPoints(100, for: "upper_arms")  // Max strength
```

### 3. Interpolation on Render
When rendering the stick figure, `GameplayScene.applyMuscleScaling()` interpolates property values based on current muscle points:

```swift
// Pseudo-code
let upperArmFusiform = interpolate(property: "fusiformUpperArms", points: 37)
// If points=37 (between 25 and 50):
//   Frame at 25: 2.1
//   Frame at 50: 2.74
//   Result: 2.1 + (2.74 - 2.1) × (37-25)/(50-25) = ~2.407
```

### 4. Visual Result
As muscle points increase from 0 → 100, the stick figure smoothly grows:

| Points | Level | Frame | Visual |
|--------|-------|-------|--------|
| 0 | 1 | Extra Small Stand | Very thin skeleton |
| ~12 | 1.5 | Interpolated | Growing slightly |
| 25 | 2 | Small Stand | Small but defined |
| 50 | 3 | Stand (Normal) | Regular build |
| 75 | 4 | Large Stand | Muscular |
| 100 | 5 | Extra Large Stand | Maximum size |

---

## Key Principles

1. **No Multipliers**: Each frame defines explicit values. No calculation needed.
2. **Simple Linear Interpolation**: Between any two threshold points, values scale linearly.
3. **Per-Muscle Control**: Each muscle independently controls its body parts.
4. **Always Rendering Interpolated Values**: Gameplay never uses frame values directly; always interpolates based on current points.

---

## Muscle → Body Part Mapping

Example: Upper Arms Muscle

```json
{
  "id": "upper_arms",
  "name": "Biceps/Triceps",
  "bodyParts": [
    "fusiformUpperArms",
    "strokeThicknessUpperArms"
  ],
  "frameValues": {
    "0": { "fusiformUpperArms": 0, "strokeThicknessUpperArms": 1.5 },
    "25": { "fusiformUpperArms": 2.1, "strokeThicknessUpperArms": 2.8 },
    "50": { "fusiformUpperArms": 2.74, "strokeThicknessUpperArms": 3.5 },
    "75": { "fusiformUpperArms": 3.17, "strokeThicknessUpperArms": 3.8 },
    "100": { "fusiformUpperArms": 3.17, "strokeThicknessUpperArms": 4.0 }
  }
}
```

As the muscle gains points, **all mapped body parts scale together**.

---

## Code Flow

### In GameplayScene

```swift
func applyMuscleScaling(to figure: StickFigure2D) -> StickFigure2D {
    var scaledFigure = figure
    
    // For each muscle
    for muscle in MuscleSystem.shared.config?.muscles ?? [] {
        // For each body part this muscle affects
        for bodyPart in muscle.bodyParts {
            // Get interpolated value at current muscle points
            let value = MuscleSystem.shared.getBodyPartValue(
                for: bodyPart,
                muscleId: muscle.id,
                state: gameState.muscleState
            )
            
            // Apply to figure
            apply(value, to: &scaledFigure, for: bodyPart)
        }
    }
    
    return scaledFigure
}
```

### In MuscleSystem

```swift
func getBodyPartValue(for bodyPart: String, muscleId: String, state: MuscleState) -> CGFloat {
    // Get the muscle's current points (0-100)
    let points = state.getPoints(for: muscleId)
    
    // Get frame values at each threshold
    let frames = loadFrames()  // Extra Small, Small, Stand, Large, Extra Large
    
    // Determine which threshold range points falls into
    // (0-25, 25-50, 50-75, 75-100)
    
    // Linear interpolation between those two frames' values
    return interpolated value
}
```

---

## Benefits

✅ **Simple**: No complex multipliers or configuration  
✅ **Predictable**: What you define in the frame is what you get  
✅ **Extensible**: Easy to add new body parts to muscles  
✅ **Performant**: Just linear interpolation, no heavy calculations  
✅ **Flexible**: Each frame can have completely different body proportions  

---

## Testing the System

To verify progression is working:

1. Set all muscle points to **0** → See Extra Small Stand
2. Set all muscle points to **25** → See Small Stand (slightly grown)
3. Set all muscle points to **50** → See Stand (normal)
4. Set all muscle points to **75** → See Large Stand (more muscular)
5. Set all muscle points to **100** → See Extra Large Stand (maximum)

Each transition should be **smooth and gradual** because of linear interpolation between points.

---

## Next Steps

1. Wire up action performance to award points (see point awarding system)
2. Update editor UI to show current frame definition (0, 25, 50, 75, 100)
3. Add visual feedback in gameplay (muscle bars, strength indicators, etc.)
4. Fine-tune frame definitions based on gameplay feel

