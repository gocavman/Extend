# Muscle System Simplification Plan

## Vision
Simplify the muscle progression system to match the editor's slider behavior. When muscle points increase (0 → 100), the stick figure should visually transform smoothly and continuously, just like dragging a slider in the editor.

## Core Principle
**No thresholds, no stages, no multipliers** — just smooth linear interpolation between 5 defined frames.

### Linear Progression Example
If Shoulder fusiform progression is:
- 0 points: 0.0 (Extra Small)
- 25 points: 0.34 (Small)
- 50 points: 1.52 (Stand)
- 75 points: 1.81 (Large)
- 100 points: 2.1 (Extra Large)

Then at:
- 12.5 points: 0.17 (halfway between Extra Small and Small)
- 37.5 points: 0.93 (halfway between Small and Stand)
- 62.5 points: 1.67 (halfway between Stand and Large)
- 87.5 points: 1.96 (halfway between Large and Extra Large)

This creates **smooth visual transformation** matching the editor behavior.

## Data Structure Changes

### Current Problem
- `strokeThicknessMultiplier` complicates calculations
- Multiple stroke thickness values per body part override system values
- No clear mapping of muscle points → visual properties

### Solution
Store **only the 5 stage values** in each frame's pose:
```json
"fusiformShoulders": 0.0  // Extra Small
"fusiformShoulders": 0.34 // Small
"fusiformShoulders": 1.52 // Stand
"fusiformShoulders": 1.81 // Large
"fusiformShoulders": 2.1  // Extra Large
```

The frames themselves become the **lookup table** for interpolation.

## Interpolation Logic

```swift
func interpolateProperty(musclePoints: Double, frames: [SavedEditFrame]) -> Double {
    // musclePoints: 0 to 100
    // frames: [ExtraSmall, Small, Stand, Large, ExtraLarge]
    
    let index = musclePoints / 25.0  // 0-4 range
    let lowerIndex = Int(floor(index))
    let upperIndex = min(lowerIndex + 1, 4)
    let fraction = index - Double(lowerIndex)
    
    let lowerValue = frames[lowerIndex].pose[property]
    let upperValue = frames[upperIndex].pose[property]
    
    return lowerValue + (upperValue - lowerValue) * fraction
}
```

## Implementation Steps

### Phase 1: Data Preparation
- [ ] Verify all 5 "Stand" frames have correct properties (Extra Small, Small, Stand, Large, Extra Large)
- [ ] Remove `strokeThicknessMultiplier` from all frames
- [ ] Ensure each frame's pose contains all necessary properties

### Phase 2: Update MuscleSystem
- [ ] Remove `calculateDerivedProperties()` complexity
- [ ] Implement simple `interpolateFusiform()` using 5-frame lookup
- [ ] Implement simple `interpolateStroke()` using 5-frame lookup
- [ ] Implement simple `interpolateSkeletonSize()` using 5-frame lookup
- [ ] Implement simple `interpolateNeckWidth()` using 5-frame lookup
- [ ] Implement simple `interpolateWaistWidth()` using 5-frame lookup

### Phase 3: Update Rendering
- [ ] Pass interpolated values directly to `renderStickFigure()`
- [ ] Remove all multiplier calculations
- [ ] Verify smooth visual transitions across the 0-100 range

### Phase 4: Testing
- [ ] Test at 0 points → Extra Small appearance
- [ ] Test at 25 points → Small appearance
- [ ] Test at 50 points → Stand appearance
- [ ] Test at 75 points → Large appearance
- [ ] Test at 100 points → Extra Large appearance
- [ ] Test at intermediate values (12.5, 37.5, etc.) → smooth transitions

## Key Benefits

1. **Predictable**: Each point increment produces visible change
2. **Smooth**: No sudden jumps or thresholds
3. **Simple**: Linear interpolation, no complex multipliers
4. **Editable**: Slider in editor matches gameplay progression
5. **Maintainable**: Easy to add more stages or adjust progression

## Frame Requirements

Must have these 5 frames with these exact names (or identify by sequence):
1. **Extra Small Stand** (frameNumber: 0)
2. **Small Stand** (frameNumber: 0)
3. **Stand** (frameNumber: 0)
4. **Large Stand** (frameNumber: 0)
5. **Extra Large Stand** (frameNumber: 0)

Each frame must have complete pose data for:
- fusiformShoulders, fusiformUpperTorso, fusiformLowerTorso
- fusiformUpperArms, fusiformLowerArms
- fusiformUpperLegs, fusiformLowerLegs
- strokeThicknessUpperTorso, strokeThicknessLowerTorso
- strokeThicknessUpperArms, strokeThicknessLowerArms
- strokeThicknessUpperLegs, strokeThicknessLowerLegs
- strokeThicknessJoints
- skeletonSize
- neckWidth
- shoulderWidthMultiplier, waistWidthMultiplier

## Current Status
- Plan created and documented
- Ready for Phase 1 implementation
