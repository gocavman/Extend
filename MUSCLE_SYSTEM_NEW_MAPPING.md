# Muscle Development System - Updated Mapping

## Overview

The muscle development system now maps **Actions** → **Property Distribution** → **Property Progression** with tier gating to ensure balanced character growth.

---

## How It Works

### 1. **Actions** (User Behaviors)
When a player completes an action (e.g., "Move", "Curls"), they trigger point distribution:

```json
{
  "id": "curls",
  "name": "Curls",
  "pointsAwarded": 5,
  "propertyDistribution": [
    {"propertyId": "fusiformUpperArms", "percentage": 40},
    {"propertyId": "strokeThicknessUpperArms", "percentage": 40},
    {"propertyId": "fusiformLowerArms", "percentage": 20}
  ]
}
```

**Result**: Completing "Curls" gives 5 points distributed as:
- 40% → fusiformUpperArms (2 points)
- 40% → strokeThicknessUpperArms (2 points)  
- 20% → fusiformLowerArms (1 point)

### 2. **Properties** (Visual Changes)
Each property has 5 progression tiers (0%, 25%, 50%, 75%, 100%):

```json
{
  "id": "fusiformUpperArms",
  "name": "Upper Arm Bulge",
  "category": "upper_arms",
  "progression": {
    "0": 0,      // Extra Small Stand
    "25": 2.74,  // Small Stand
    "50": 2.74,  // Stand
    "75": 2.74,  // Large Stand
    "100": 3.17  // Extra Large Stand
  }
}
```

### 3. **Tier Gating** (Balanced Progression)
Players cannot advance to the next tier until **ALL properties** reach that tier.

**Example Scenario**:
- Player only does "Curls" (arm exercises)
- Upper arm properties reach 50% quickly
- Leg, torso, shoulder properties stay at 0%
- **Tier locked**: Can't progress to 75% until legs/torso also reach 50%
- **Solution**: Player must do "Move" (leg exercises) and "Bench Press" (chest)

This forces variety and prevents grinding one exercise.

---

## Code Mapping

### In Game_Muscles.json:

```
Actions
├── id: "curls"
├── propertyDistribution[]
│   ├── propertyId: "fusiformUpperArms"  ← Links to property
│   └── percentage: 40
└── ...

Properties
├── id: "fusiformUpperArms"
├── name: "Upper Arm Bulge"
├── progression {0, 25, 50, 75, 100}  ← Values from Stand frames
└── ...
```

### In Swift Code (MuscleSystem.swift):

```swift
// When action completes:
for distribution in action.propertyDistribution {
    let pointsForProperty = action.pointsAwarded * (distribution.percentage / 100)
    muscleState.addPoints(pointsForProperty, to: distribution.propertyId)
}

// When rendering:
let propertyPoints = muscleState.getPoints(for: "fusiformUpperArms")  // e.g., 47
let tierValues = propertyDefinition.progression  // {0, 25, 50, 75, 100}
let interpolatedValue = interpolate(propertyPoints, tierValues)  // e.g., 2.73
```

### In UI (StickFigureAppearanceViewController.swift):

```swift
// Display all properties with +/- buttons
for property in config.properties {
    let currentPoints = muscleState.getPoints(for: property.id)
    // Show: Property Name [−5] [−] [47] [+] [+5]
    // Display matches current tier progress
}

// Bulk actions
resetAllPropertiesTapped()  // Sets all to 0
maxAllPropertiesTapped()    // Sets all to 100
```

---

## Example Flow

**Player Routine:**
1. Complete "Move" action (5 points)
   - fusiformUpperLegs += 1.67 pts
   - fusiformLowerLegs += 1.67 pts
   - strokeThicknessUpperLegs += 1.67 pts

2. Complete "Curls" action (5 points)
   - fusiformUpperArms += 2 pts
   - strokeThicknessUpperArms += 2 pts
   - fusiformLowerArms += 1 pt

3. Complete "Bench Press" action (5 points)
   - fusiformUpperTorso += 2.5 pts
   - strokeThicknessUpperTorso += 2.5 pts

**After Multiple Completions:**
- When ALL properties reach 50% tier → Character advances to "Stand" size
- Stick figure rendering automatically interpolates to correct values
- Visual feedback: Figure visibly grows in muscle definition

---

## Customization

To add a new exercise:

```json
{
  "id": "squats",
  "name": "Squats",
  "pointsAwarded": 5,
  "propertyDistribution": [
    {"propertyId": "fusiformUpperLegs", "percentage": 50},
    {"propertyId": "strokeThicknessUpperLegs", "percentage": 50}
  ]
}
```

To add a new property:

```json
{
  "id": "neckThickness",
  "name": "Neck Thickness",
  "progression": {
    "0": 1.0,
    "25": 1.2,
    "50": 1.4,
    "75": 1.6,
    "100": 2.0
  }
}
```

Then add action(s) that target it in propertyDistribution.

---

## Summary

✅ **Clear Mapping**: Actions → Properties → Progression values
✅ **Configurable**: Easy to add actions/properties
✅ **Balanced**: Tier gating forces exercise variety
✅ **Visual**: Real-time stick figure updates as properties progress
✅ **Flexible**: Properties can have different percentage distributions per action

