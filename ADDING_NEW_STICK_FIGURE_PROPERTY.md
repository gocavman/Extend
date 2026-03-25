# Complete Checklist: Adding a New Stick Figure Property

This document outlines ALL the files and locations that must be updated when adding a new property to the stick figure system. Based on the hourglass torso implementation (fusiformFullTorso + 3 peak positions).

---

## 1. Core Model - StickFigure2D.swift

### 1.1 Add Property to StickFigure2D struct
**File:** `Extend/Models/StickFigure2D.swift`
**Location:** Main `struct StickFigure2D` (around line 750-800)
**Action:** Add the property as a `var` with default value
```swift
var myNewProperty: CGFloat = 0.0
```

### 1.2 Add Property to StickFigure2DPose struct
**File:** `Extend/Models/StickFigure2D.swift`
**Location:** `struct StickFigure2DPose` (around line 149-230)
**Action:** Add property as `let` (immutable, for serialization)
```swift
let myNewProperty: CGFloat
```

### 1.3 Add to CodingKeys enum
**File:** `Extend/Models/StickFigure2D.swift`
**Location:** `enum CodingKeys` inside `StickFigure2DPose` (around line 310-320)
**Action:** Add case
```swift
case myNewProperty
```

### 1.4 Update init(from:) in StickFigure2DPose
**File:** `Extend/Models/StickFigure2D.swift`
**Location:** `init(from figure: StickFigure2D)` (around line 270-280)
**Action:** Assign from figure
```swift
self.myNewProperty = figure.myNewProperty
```

### 1.5 Update toStickFigure2D() method
**File:** `Extend/Models/StickFigure2D.swift`
**Location:** `func toStickFigure2D()` in StickFigure2DPose (around line 360-410)
**Action:** Assign back to figure
```swift
figure.myNewProperty = myNewProperty
```

### 1.6 Update encode() function
**File:** `Extend/Models/StickFigure2D.swift`
**Location:** `func encode(to encoder:)` in StickFigure2DPose (around line 450-500)
**Action:** Add encoding line
```swift
try container.encode(round(myNewProperty), forKey: .myNewProperty)
```

### 1.7 Update init(from decoder:) function
**File:** `Extend/Models/StickFigure2D.swift`
**Location:** `init(from decoder:)` in StickFigure2DPose (around line 550-610)
**Action:** Add decoding line with default
```swift
self.myNewProperty = try container.decodeIfPresent(CGFloat.self, forKey: .myNewProperty) ?? 0.0
```

---

## 2. Editor Model - SavedEditFrame.swift

### 2.1 Add Property to SavedEditFrame struct
**File:** `Extend/Models/SavedEditFrame.swift`
**Location:** `struct SavedEditFrame` (around line 75-145)
**Action:** Add property as `let`
```swift
let myNewProperty: CGFloat
```

### 2.2 Add to CodingKeys enum
**File:** `Extend/Models/SavedEditFrame.swift`
**Location:** `enum CodingKeys` (around line 295-310)
**Action:** Add case
```swift
case myNewProperty
```

### 2.3 Update init(from values:pose:) method
**File:** `Extend/Models/SavedEditFrame.swift`
**Location:** Both the `if let pose` block AND the `else` block (around line 200-230)
**Action:** In `if let pose` section, assign from pose:
```swift
self.myNewProperty = pose.myNewProperty
```
In `else` section, assign default:
```swift
self.myNewProperty = 0.0
```

### 2.4 Update encode() function
**File:** `Extend/Models/SavedEditFrame.swift`
**Location:** `func encode(to encoder:)` (around line 440-460)
**Action:** Add encoding
```swift
try poseContainer.encode(myNewProperty, forKey: .myNewProperty)
```

### 2.5 Update init(from decoder:) function
**File:** `Extend/Models/SavedEditFrame.swift`
**Location:** Decoding from poseContainer (around line 360-370)
**Action:** Add decoding
```swift
myNewProperty = try poseContainer.decodeIfPresent(CGFloat.self, forKey: .myNewProperty) ?? 0.0
```

### 2.6 Update exportFrameAsJSON() function
**File:** `Extend/Models/SavedEditFrame.swift`
**Location:** `func exportFrameAsJSON()` poseEntries array (around line 680-700)
**Action:** Add to alphabetically sorted poseEntries:
```swift
("myNewProperty", roundAndFormat(frame.myNewProperty, decimals: 2)),
```

---

## 3. Editor UI - GameplayEditModeView.swift

### 3.1 Add Property to EditModeValues struct
**File:** `Extend/Views/GameplayEditModeView.swift`
**Location:** `struct EditModeValues` (around line 244-290)
**Action:** Add property as optional
```swift
let myNewProperty: CGFloat?
```

### 3.2 Update EditModeValues initializers (3 places)
**File:** `Extend/Views/GameplayEditModeView.swift`
**Locations:** 
- Line ~191 (in return statement)
- Line ~1385 (StickFigureGameplayEditorViewController)
- Line ~764 (SavedEditFrame.swift)

**Action:** Add parameter in each initialization:
```swift
myNewProperty: nil,  // or specific value in editor ViewController
myNewProperty: pose.myNewProperty,  // in SavedEditFrame
myNewProperty: self.myNewProperty,  // in editor ViewController
```

---

## 4. Editor Controller - StickFigureGameplayEditorViewController.swift

### 4.1 Add Property Instance Variable
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** Property declarations (around line 30-50)
**Action:** Add
```swift
private var myNewProperty: CGFloat = 0.0
```

### 4.2 Add Editor Slider
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** `cellForRowAt` switch statement for section 3 (Fusiform) (around line 700-750)
**Action:** Add case
```swift
case (3, 9): addSliderCell(cell, label: "My New Property", value: myNewProperty, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.myNewProperty = val; self?.updateFigure() })
```
*Note: Adjust case number based on existing count*

### 4.3 Update numberOfRowsInSection
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** `func numberOfRowsInSection` (around line 317-330)
**Action:** Increment section 3 row count by 1
```swift
case 3: return isExpanded ? 23 : 0  // was 22, now 23
```

### 4.4 Add to updateWithValues() signature
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** `func updateWithValues()` parameters (around line 2431-2470)
**Action:** Add parameter after peakPositionDeltoids
```swift
myNewProperty: CGFloat = 0.0,
```

### 4.5 Add to updateWithValues() body
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** Inside `updateWithValues()` where properties are assigned to updatedFrame (around line 2520)
**Action:** Add assignment
```swift
updatedFrame.myNewProperty = myNewProperty
```

### 4.6 Update loadStandFrameValues()
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** `private func loadStandFrameValues()` (around line 1197-1210)
**Action:** Add assignment
```swift
myNewProperty = standFrame.myNewProperty
```

### 4.7 Update applyFrame()
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** `private func applyFrame()` (around line 1900-1920)
**Action:** Add assignment
```swift
myNewProperty = frame.myNewProperty
```

### 4.8 Update FrameListViewController bundle frame loading
**File:** `Extend/SpriteKit/StickFigureGameplayEditorViewController.swift`
**Location:** Frame loading code where EditModeValues is created (around line 2870)
**Action:** Add to EditModeValues initialization
```swift
myNewProperty: pose.myNewProperty,
```

---

## 5. Rendering - GameScene.swift

### 5.1 Add Property Case in applyMuscleScaling()
**File:** `Extend/SpriteKit/GameScene.swift`
**Location:** `private func applyMuscleScaling()` switch statement (around line 1050-1070)
**Action:** Add case
```swift
case "myNewProperty": scaledFigure.myNewProperty = interpolatedValue
```

### 5.2 Add Property Case in getPropertyValue()
**File:** `Extend/SpriteKit/GameScene.swift`
**Location:** (Actually in MuscleSystem.swift - see section 6)

---

## 6. Muscle System - MuscleSystem.swift

### 6.1 Add Property Case in extractPropertyValueFromFrame()
**File:** `Extend/Models/MuscleSystem.swift`
**Location:** `private func extractPropertyValueFromFrame()` switch statement (around line 820-850)
**Action:** Add case
```swift
case "myNewProperty":
    return Double(frame.pose.myNewProperty)
```

### 6.2 Add Property Case in getPropertyValue()
**File:** `Extend/Models/MuscleSystem.swift`
**Location:** `private func getPropertyValue()` switch statement (around line 590-610)
**Action:** Add case
```swift
case "myNewProperty": value = Double(frame.myNewProperty)
```

---

## 7. JSON Configuration - animations.json

### 7.1 Add Property to All Stand Frames
**File:** `Extend/animations.json`
**Locations:** In the `pose` object of each frame:
- Extra Small Stand
- Small Stand
- Stand
- Large Stand
- Extra Large Stand

**Action:** Add property with appropriate value for that tier:
```json
"myNewProperty": 0.0,
```

---

## 8. Muscle Configuration - game_muscles.json

### 8.1 Add Property Definition
**File:** `Extend/game_muscles.json`
**Location:** `properties` array (add at end before closing bracket)
**Action:** Add complete property definition
```json
{
  "id" : "myNewProperty",
  "name" : "My New Property Display Name",
  "muscleGroups" : [
    "Chest",
    "Abs",
    "Back"
  ],
  "progression" : {
    "0" : 0.0,
    "25" : 0.1,
    "50" : 0.2,
    "75" : 0.3,
    "100" : 0.4
  }
}
```

---

## Summary Table

| Category | File | Locations | Count |
|----------|------|-----------|-------|
| Core Model | StickFigure2D.swift | 7 locations | 7 |
| Editor Model | SavedEditFrame.swift | 6 locations | 6 |
| Editor UI | GameplayEditModeView.swift | 1 location | 1 |
| Editor Controller | StickFigureGameplayEditorViewController.swift | 8 locations | 8 |
| Rendering | GameScene.swift | 1 location | 1 |
| Muscle System | MuscleSystem.swift | 2 locations | 2 |
| Config Files | animations.json + game_muscles.json | 6 Stand frames + 1 property | 7 |
| **TOTAL** | | | **32 updates** |

---

## Verification Checklist

After adding a new property, verify:

- [ ] Code compiles with no errors (`get_errors` check)
- [ ] New slider appears in editor section 3 when expanded
- [ ] Slider value updates in real-time when moved
- [ ] Refresh button loads correct values from Stand frame
- [ ] Frame save/load works (values persist)
- [ ] Copy to JSON includes new property
- [ ] At 0 muscle points, property shows tier 0 value
- [ ] At 100 muscle points, property shows tier 100 value
- [ ] At 50 muscle points, property interpolates correctly
- [ ] Stick figure rendering reflects property changes in gameplay
- [ ] Regenerate button properly extracts and updates property

---

## Example: Adding "myNewProperty" Quick Reference

1. **StickFigure2D.swift** (7 changes)
   - Add var, add to Pose, CodingKeys, init(from:), toStickFigure2D(), encode(), decode()

2. **SavedEditFrame.swift** (6 changes)
   - Add let, CodingKeys, init branches (2), encode(), decode(), exportFrameAsJSON()

3. **GameplayEditModeView.swift** (1 change)
   - Add to EditModeValues struct

4. **StickFigureGameplayEditorViewController.swift** (8 changes)
   - Add private var, slider case, numberOfRowsInSection, updateWithValues params & body, loadStandFrameValues(), applyFrame(), bundle loading

5. **GameScene.swift** (1 change)
   - Add case in applyMuscleScaling()

6. **MuscleSystem.swift** (2 changes)
   - Add cases in extractPropertyValueFromFrame() and getPropertyValue()

7. **animations.json** (5 changes)
   - Add "myNewProperty" to all 5 Stand frames

8. **game_muscles.json** (1 change)
   - Add complete property definition with progression

---

**Last Updated:** March 25, 2026
**Property Example:** fusiformFullTorso + peakPositionFullTorsoTop/Middle/Bottom (hourglass implementation)
