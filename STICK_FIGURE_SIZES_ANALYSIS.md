# Stick Figure Sizes Analysis - animations.json

## Overview
Document comparing the 5 stand frames and their sizing properties to identify discrepancies in how they're being rendered.

---

## Frame-by-Frame Analysis

### 1. **Extra Small Stand** (frameNumber: 0)
**Purpose:** Base size when muscle points = 0
- **skeletonSize:** 0.0
- **strokeThickness:** 0.0
- **strokeThicknessMultiplier:** 0.5
- **Fusiforms (all body parts):** All 0.0
- **neckWidth:** 3.3
- **waistThicknessMultiplier:** 0.0

**Issue:** 
- `skeletonSize = 0.0` makes the skeleton invisible
- All fusiforms = 0.0 means no body width
- `strokeThickness = 0.0` means no outline
- This is working as expected visually (tiny stick figure)

---

### 2. **Small Stand** (frameNumber: 0)
**Purpose:** When muscle points ≈ 25
- **skeletonSize:** 3.19
- **strokeThickness:** 1.0
- **strokeThicknessMultiplier:** 1.0
- **Fusiforms:**
  - upperTorso: 2.18
  - lowerArms: 1.64
  - upperArms: 2.1
  - upperLegs: 1.69
  - lowerLegs: 1.8
- **neckWidth:** 3.3
- **waistThicknessMultiplier:** 0.9

---

### 3. **Stand** (frameNumber: 0) - ORIGINAL
**Purpose:** When muscle points ≈ 50 (baseline/default)
- **skeletonSize:** 4.18
- **strokeThickness:** 1.2
- **strokeThicknessMultiplier:** 1.2
- **Fusiforms:**
  - fusiformShoulders: 1.52
  - fusiformUpperTorso: 5.85 ✅
  - fusiformLowerTorso: 1.0
  - fusiformUpperArms: 2.74 ✅
  - fusiformLowerArms: 2.0
  - fusiformUpperLegs: 2.95 ✅
  - fusiformLowerLegs: 2.48 ✅
- **neckWidth:** 8.5
- **waistThicknessMultiplier:** 0.9

**Status:** This is the original "Stand" frame and looks correct

---

### 4. **Large Stand** (frameNumber: 0)
**Purpose:** When muscle points ≈ 75
- **skeletonSize:** 5.11
- **strokeThickness:** 1.4
- **strokeThicknessMultiplier:** 1.4
- **Fusiforms:**
  - fusiformShoulders: 1.81
  - fusiformUpperTorso: 5.82 (slightly less than Stand)
  - fusiformLowerTorso: 0.0 ⚠️
  - fusiformUpperArms: 3.17
  - fusiformLowerArms: 2.74
  - fusiformUpperLegs: 3.18
  - fusiformLowerLegs: 3.15
- **neckWidth:** 8.8
- **waistThicknessMultiplier:** 0.9

**Issue Found:**
- fusiformUpperTorso decreased from 5.85 to 5.82 (should increase)
- fusiformLowerTorso set to 0.0 (should be higher)

---

### 5. **Extra Large Stand** (frameNumber: 0)
**Purpose:** When muscle points = 100
- **skeletonSize:** 5.11 (same as Large Stand)
- **strokeThickness:** 2.0 ✅ (largest)
- **strokeThicknessMultiplier:** 2.0 ✅
- **Fusiforms:**
  - fusiformShoulders: 1.81 (same as Large)
  - fusiformUpperTorso: 5.82 (same as Large, should be higher)
  - fusiformLowerTorso: 0.0 (same as Large, should be different)
  - fusiformUpperArms: 3.17 (same as Large)
  - fusiformLowerArms: 2.74 (same as Large)
  - fusiformUpperLegs: 2.68 (less than Large!)
  - fusiformLowerLegs: 2.95 (less than Large!)
- **neckWidth:** 8.8 (same as Large)
- **waistThicknessMultiplier:** 0.9

**Major Issues Found:**
- Most fusiforms are identical to "Large Stand"
- fusiformUpperLegs went DOWN from 3.18 to 2.68
- fusiformLowerLegs went DOWN from 3.15 to 2.95
- skeletonSize didn't increase beyond Large Stand
- Differences are minimal between Large and Extra Large

---

## Summary of Problems

### Critical Issues:
1. **Large Stand and Extra Large Stand are nearly identical** - only strokeThickness differs slightly
2. **Fusiforms don't progressively increase** from Small → Stand → Large → ExtraLarge
3. **Some fusiforms decrease** (legs in Extra Large vs Large)
4. **Lower torso is 0.0 in both Large and Extra Large** - This may be intentional but seems odd
5. **skeletonSize plateaus at 5.11** for both Large and ExtraLarge (should increase)

### Expected Progression:
```
Extra Small (0):     skeletonSize: 0.0  → all fusiforms: 0.0
Small (25):          skeletonSize: 3.19 → proportionally smaller
Stand (50):          skeletonSize: 4.18 → baseline (looks correct)
Large (75):          skeletonSize: 5.11 → larger proportionally
ExtraLarge (100):    skeletonSize: 5.50+ → maximum size (currently 5.11, same as Large)
```

### Current Actual:
```
Extra Small:  skeletonSize: 0.0   ✅
Small:        skeletonSize: 3.19  ✅
Stand:        skeletonSize: 4.18  ✅
Large:        skeletonSize: 5.11
ExtraLarge:   skeletonSize: 5.11  ⚠️ (identical to Large)
```

---

## Conclusion

The stick figure isn't displaying at full size at 100 muscle points because:
1. **Large Stand and Extra Large Stand are functionally the same** (except strokeThickness)
2. **skeletonSize doesn't increase** from 75 → 100 points (stuck at 5.11)
3. **Most body part fusiforms are identical** between these two frames
4. **Some leg fusiforms actually decrease** in Extra Large vs Large

**Recommendation:**
Regenerate the "Large Stand" and "Extra Large Stand" frames with:
- Progressively larger skeletonSize values
- Progressively larger fusiform values for each body part
- Extra Large should be visibly larger than Large across all metrics
