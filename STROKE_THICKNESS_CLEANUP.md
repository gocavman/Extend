# Stroke Thickness Property Cleanup

## Summary
Removed the redundant generic `strokeThickness` property from JSON encoding. The application now uses **only** the specific body part stroke thickness properties for all rendering and persistence.

## What Was Changed

### 1. **SavedEditFrame.swift**
- **Removed line 593**: The duplicate `strokeThickness` property that was mapping `strokeThicknessMultiplier`
- **Removed line 402**: The encode statement writing `strokeThickness` to JSON

### 2. **StickFigure2D.swift** 
- **Removed line 411**: The encode statement writing `strokeThickness` to JSON

## Why This Matters

### Before (Problematic):
```json
"strokeThickness": 1.2,              // Generic (redundant)
"strokeThicknessJoints": 2,          // Specific
"strokeThicknessUpperArms": 4,       // Specific
"strokeThicknessLowerArms": 4,       // Specific
"strokeThicknessUpperLegs": 5,       // Specific
"strokeThicknessLowerLegs": 4,       // Specific
"strokeThicknessUpperTorso": 5,      // Specific
"strokeThicknessLowerTorso": 5,      // Specific
"strokeThicknessMultiplier": 1.2     // Also generic (different purpose)
```

### After (Clean):
```json
"strokeThicknessJoints": 2,          // Specific
"strokeThicknessUpperArms": 4,       // Specific
"strokeThicknessLowerArms": 4,       // Specific
"strokeThicknessUpperLegs": 5,       // Specific
"strokeThicknessLowerLegs": 4,       // Specific
"strokeThicknessUpperTorso": 5,      // Specific
"strokeThicknessLowerTorso": 5,      // Specific
"strokeThicknessMultiplier": 1.2     // Waist/proportion scaling
```

## Backward Compatibility
✅ **Preserved**: The `strokeThickness` property remains in the `StickFigure2DPose` model as **optional** (with default of 1.0) for backward compatibility. Old animations.json files that contain this property will still load without errors.

✅ **Forward Compatible**: New frames exported from the editor will NOT include `strokeThickness`, using only the specific body part properties.

## Technical Details

### Property Purposes:
| Property | Purpose | Source |
|----------|---------|--------|
| `strokeThicknessUpperArms` | Line thickness of upper arms | animations.json |
| `strokeThicknessLowerArms` | Line thickness of lower arms | animations.json |
| `strokeThicknessUpperLegs` | Line thickness of upper legs | animations.json |
| `strokeThicknessLowerLegs` | Line thickness of lower legs | animations.json |
| `strokeThicknessJoints` | Line thickness of joints/connections | animations.json |
| `strokeThicknessUpperTorso` | Line thickness of upper torso | animations.json |
| `strokeThicknessLowerTorso` | Line thickness of lower torso | animations.json |
| `strokeThicknessMultiplier` | Multiplier for waist/proportion scaling | animations.json |

### The Removed Property:
| Property | Issue | Status |
|----------|-------|--------|
| `strokeThickness` | Generic, redundant, confused developers | Removed from encoding |

## Impact on Gameplay
✅ **No negative impact** - Gameplay rendering uses the specific body part stroke properties, which were always the authoritative values. The generic `strokeThickness` was never actually used in rendering, only stored.

## Editor Changes
When the editor exports/saves frames, it will now exclude `strokeThickness` from the JSON, resulting in cleaner animation files with only the necessary properties.

---
**Updated**: March 5, 2026
