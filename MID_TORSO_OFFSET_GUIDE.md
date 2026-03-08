# Mid Torso Y Offset Implementation Guide

## Overview
A new property `midTorsoYOffset` has been added to allow fine-tuning of where the upper torso's bottom point pins to the mid-torso dot during waist rotation.

## Property Details

### Location in Code
- **StickFigure2D.swift** (line 638): `var midTorsoYOffset: CGFloat = 0.0`
- **SavedEditFrame.swift**: Persisted in animations.json
- **StickFigureGameplayEditorViewController.swift**: Editor slider at section 3, row 13

### Value Range
- **Minimum**: -10.0 (moves offset UP)
- **Maximum**: +10.0 (moves offset DOWN)
- **Default**: 0.0 (no offset - original position)
- **Increment**: 0.1 per slider step

## How It Works

### In StickFigure2D.swift (line 1055-1058)
```swift
// Apply mid-torso Y offset to adjust where upper torso bottom pins to mid-torso
let midTorsoWithOffset = CGPoint(x: midTorsoPos.x, y: midTorsoPos.y + figure.midTorsoYOffset)

// Upper torso: point at neck, wide in middle, point at midTorso (with offset applied)
drawSegment(from: neckPos, to: midTorsoWithOffset, ...)
```

The offset is applied by adding the value to the Y-coordinate of the midTorsoPos before drawing.

## Usage in Editor

### Slider Location
- **Section**: Fusiform section (expanded)
- **Label**: "Mid Torso Y Offset"
- **Row**: 13 (after Peak Lower Torso slider)

### Adjustment
- Slide LEFT (negative values): Moves the upper torso's bottom attachment point UPWARD
- Slide RIGHT (positive values): Moves the upper torso's bottom attachment point DOWNWARD
- Changes save automatically when you adjust the slider

## Saving & Loading

### JSON Representation
The offset is stored in `animations.json` under each frame's pose data:
```json
{
  "frameNumber": 0,
  "pose": {
    "midTorsoYOffset": 0.5,
    ...other properties...
  }
}
```

### Persistence
- Automatically saved when you save a frame
- Automatically loaded when you load a frame
- Defaults to 0.0 for backward compatibility

## Testing Tips

1. **Default (0.0)**: Upper torso bottom is at the exact mid-torso position
2. **Small offset (0.5-2.0)**: Subtle adjustment - good for fine-tuning proportions
3. **Larger offset (5.0+)**: More dramatic movement - useful for stylized figures
4. **Negative offset (-1.0 to -5.0)**: Moves attachment point upward for compact torsos

## Technical Notes

- The offset only affects the visual connection point; it doesn't change the mid-torso pivot position for rotation
- When rotating around the waist, the upper torso will bend from the offset position, not the original mid-torso
- The offset applies to BOTH the upper torso AND lower torso segments (they both connect at the offset point)
