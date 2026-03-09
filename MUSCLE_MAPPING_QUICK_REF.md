# Quick Reference: Where Is The Mapping?

## JSON File Structure (game_muscles.json)

```
config
  ├─ pointsPerCompletion: 10
  ├─ timeframeUnit: "day"
  └─ tierGating: true

actions[]  ← What players DO
  ├─ "Move"
  ├─ "Curls"
  ├─ "Bench Press"
  └─ "Core Work"

properties[]  ← What CHANGES on the stick figure
  ├─ fusiformShoulders
  ├─ strokeThicknessJoints
  ├─ fusiformUpperTorso
  ├─ ... (21 total properties)
  └─ waistThicknessMultiplier
```

## The Mapping Connections

### 1. **Actions → Properties** (The Distribution)
**File**: `game_muscles.json`

```json
"actions": [
  {
    "id": "curls",
    "propertyDistribution": [
      {"propertyId": "fusiformUpperArms", "percentage": 40},
      {"propertyId": "strokeThicknessUpperArms", "percentage": 40},
      {"propertyId": "fusiformLowerArms", "percentage": 20}
    ]
  }
]
```

**What it means**: "Curls" action affects 3 properties with specific percentages.

---

### 2. **Properties → Progression** (The Values)
**File**: `game_muscles.json`

```json
"properties": [
  {
    "id": "fusiformUpperArms",
    "progression": {
      "0": 0,       // Extra Small Stand
      "25": 2.74,   // Small Stand
      "50": 2.74,   // Stand
      "75": 2.74,   // Large Stand
      "100": 3.17   // Extra Large Stand
    }
  }
]
```

**What it means**: At 50% points, fusiformUpperArms becomes 2.74. At 100%, it becomes 3.17.

---

### 3. **Code That Reads This Mapping**

#### **MuscleSystem.swift** (Loads & Interpolates)
```swift
// Line 243-253: Load game_muscles.json
func loadMuscleConfig() {
    config = try decoder.decode(MuscleConfig.self, from: data)
    state.initializeProperties(with: config?.properties ?? [])
}

// Line 316-330: Get interpolated value
private func getPropertyValue(_ propertyKey: String, from frame: SavedEditFrame) -> Double {
    switch propertyKey {
    case "fusiformUpperArms": return Double(frame.fusiformUpperArms)
    case "strokeThicknessUpperArms": return Double(frame.strokeThicknessUpperArms)
    // ...
    }
}
```

#### **StickFigureAppearanceViewController.swift** (UI Display)
```swift
// Line 94: Show all properties
let properties = muscleSystem.config?.properties
// Line 343: Create control row for each property
let row = createPropertyControlRow(property: property)

// Line 623-637: Reset/Max All buttons
@objc private func resetAllPropertiesTapped() {
    for property in properties {
        gameState.muscleState.setPoints(0, for: property.id)
    }
}

@objc private func maxAllPropertiesTapped() {
    for property in properties {
        gameState.muscleState.setPoints(100, for: property.id)
    }
}
```

#### **GameScene.swift** (Rendering)
```swift
// When drawing the stick figure:
let fusiformValue = MuscleSystem.shared.getDerivedPropertyValue(
    for: "fusiformUpperArms", 
    state: gameState.muscleState
)
drawTaperedSegment(
    from: leftShoulderPos, 
    to: leftUpperArmEnd, 
    fusiform: fusiformValue,  // ← Uses property value
    peakPosition: ...
)
```

---

## Data Flow

```
1. Player completes "Curls"
   ↓
2. MuscleSystem reads action.propertyDistribution
   ↓
3. Distributes points to: fusiformUpperArms, strokeThicknessUpperArms, fusiformLowerArms
   ↓
4. muscleState stores new point values (0-100 for each property)
   ↓
5. StickFigureAppearanceViewController shows updated values in UI
   ↓
6. GameScene.renderStickFigure() calls getDerivedPropertyValue() for each property
   ↓
7. MuscleSystem interpolates: points (0-100) → progression values (0, 25, 50, 75, 100)
   ↓
8. Stick figure renders with new property values
```

---

## Summary

| Component | Location | Purpose |
|-----------|----------|---------|
| **Actions** | game_muscles.json | Define what players can do |
| **propertyDistribution** | game_muscles.json | Map actions to properties with percentages |
| **Properties** | game_muscles.json | Define stick figure visual elements |
| **Progression** | game_muscles.json | Define values at each tier (0-100%) |
| **MuscleSystem.swift** | Swift code | Load JSON, interpolate values, manage state |
| **StickFigureAppearanceViewController.swift** | Swift code | UI display, +/- buttons, bulk actions |
| **GameScene.swift** | Swift code | Render stick figure with property values |

---

## How to Find & Modify

**Want to change Curls distribution?**
→ Edit `game_muscles.json` → `actions[curls].propertyDistribution`

**Want to add new property?**
→ Add to `game_muscles.json` → `properties[]` with progression values

**Want to see all properties displayed?**
→ Look at `StickFigureAppearanceViewController.swift` line 94-356

**Want to see how rendering uses properties?**
→ Look at `GameScene.swift` line 686-710 (applyMuscleScaling)

