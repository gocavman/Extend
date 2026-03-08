# Implementation Steps: 3 Skeleton Size Sliders

This file documents the steps needed to implement the 3 skeleton size sliders (Torso, Arm, Leg) replacing the old single "Skeleton Size" slider.

Copy and paste these steps one at a time when you're ready to proceed.

---

## Step 1: Update StickFigure2D.swift

Add the 3 new properties to the StickFigure2D class and update StickFigure2DPose struct:

**Add properties to StickFigure2D class:**
```
// Skeleton size controls for each body part (1.0 = normal thickness)
var skeletonSizeTorso: CGFloat = 1.0   // Spine/torso connector thickness multiplier
var skeletonSizeArm: CGFloat = 1.0     // Arm connector thickness multiplier
var skeletonSizeLeg: CGFloat = 1.0     // Leg connector thickness multiplier
```

**Update StickFigure2DPose struct:**
- Add the 3 properties
- Add them to CodingKeys enum
- Update encode() method to encode all 3
- Update decode() method to decode all 3

---

## Step 2: Update SavedEditFrame.swift

**Add properties to SavedEditFrame struct:**
```
var skeletonSizeTorso: CGFloat = 1.0
var skeletonSizeArm: CGFloat = 1.0
var skeletonSizeLeg: CGFloat = 1.0
```

**Update CodingKeys enum:**
Add the 3 new keys

**Update init(name:from:pose:objects:):**
```
self.skeletonSizeTorso = pose.skeletonSizeTorso
self.skeletonSizeArm = pose.skeletonSizeArm
self.skeletonSizeLeg = pose.skeletonSizeLeg
```

**Update encode() method:**
```
try container.encode(skeletonSizeTorso, forKey: .skeletonSizeTorso)
try container.encode(skeletonSizeArm, forKey: .skeletonSizeArm)
try container.encode(skeletonSizeLeg, forKey: .skeletonSizeLeg)
```

**Update decode() method:**
```
skeletonSizeTorso = try container.decode(CGFloat.self, forKey: .skeletonSizeTorso) ?? 1.0
skeletonSizeArm = try container.decode(CGFloat.self, forKey: .skeletonSizeArm) ?? 1.0
skeletonSizeLeg = try container.decode(CGFloat.self, forKey: .skeletonSizeLeg) ?? 1.0
```

---

## Step 3: Update GameScene.swift (Skeleton Drawing)

Replace all `skeletonSize` references with the appropriate specific size:
- Use `skeletonSizeTorso` when drawing torso connectors
- Use `skeletonSizeArm` when drawing arm connectors
- Use `skeletonSizeLeg` when drawing leg connectors

---

## Step 4: Update StickFigureGameplayEditorViewController.swift

**Class properties:**
Replace:
```
private var skeletonSize: CGFloat = 1.0
```

With:
```
private var skeletonSizeTorso: CGFloat = 1.0   // Spine/torso connector thickness multiplier
private var skeletonSizeArm: CGFloat = 1.0     // Arm connector thickness multiplier
private var skeletonSizeLeg: CGFloat = 1.0     // Leg connector thickness multiplier
```

**numberOfRowsInSection:**
- Section 1 should have 9 rows (removed Skeleton Size)
- Section 4 should have 3 rows (new Skeleton section)

**titleForHeaderInSection:**
- Section 4 returns "SKELETON"

**cellForRowAt:**
Replace the old skeleton size slider case:
```
case (4, 0): addSliderCell(cell, label: "Torso Skeleton", value: skeletonSizeTorso, min: 0.0, max: 5.0, increment: 0.1, onChange: { [weak self] val in self?.skeletonSizeTorso = val; self?.updateFigure() })
case (4, 1): addSliderCell(cell, label: "Arm Skeleton", value: skeletonSizeArm, min: 0.0, max: 5.0, increment: 0.1, onChange: { [weak self] val in self?.skeletonSizeArm = val; self?.updateFigure() })
case (4, 2): addSliderCell(cell, label: "Leg Skeleton", value: skeletonSizeLeg, min: 0.0, max: 5.0, increment: 0.1, onChange: { [weak self] val in self?.skeletonSizeLeg = val; self?.updateFigure() })
```

**loadStandFrameValues():**
Replace:
```
skeletonSize = standFrame.skeletonSize
```

With:
```
skeletonSizeTorso = standFrame.skeletonSizeTorso
skeletonSizeArm = standFrame.skeletonSizeArm
skeletonSizeLeg = standFrame.skeletonSizeLeg
```

**updateFigure():**
Replace:
```
skeletonSize: skeletonSize,
```

With:
```
skeletonSizeTorso: skeletonSizeTorso,
skeletonSizeArm: skeletonSizeArm,
skeletonSizeLeg: skeletonSizeLeg,
```

**applyFrame():**
Replace:
```
skeletonSize = frame.skeletonSize
```

With:
```
skeletonSizeTorso = frame.skeletonSizeTorso
skeletonSizeArm = frame.skeletonSizeArm
skeletonSizeLeg = frame.skeletonSizeLeg
```

**savePressed():**
Replace:
```
tempPose.skeletonSize = self.skeletonSize
```

With:
```
tempPose.skeletonSizeTorso = self.skeletonSizeTorso
tempPose.skeletonSizeArm = self.skeletonSizeArm
tempPose.skeletonSizeLeg = self.skeletonSizeLeg
```

---

## Step 5: Update MuscleSystem.swift

Replace old `skeletonSize` references with the 3 new ones in property interpolation.

---

## Step 6: Update GameplayScene.swift

Replace old `skeletonSize` references with the 3 new ones when loading frames in gameplay.

---

## Testing Checklist

- [ ] Build succeeds with no errors
- [ ] 3 sliders appear in "SKELETON" section in editor
- [ ] Sliders update stick figure in real-time
- [ ] Refresh button resets all 3 sliders to Stand frame values
- [ ] Saving frames persists all 3 skeleton size values
- [ ] Loading frames restores all 3 skeleton size values
- [ ] JSON copy includes all 3 skeleton size values
- [ ] Gameplay displays stick figures with correct skeleton sizes

