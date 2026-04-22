# Match Game - Flame Cascading & Powerup Overlap Swaps (April 21, 2026)

## Fix #1: Flame Powerup Cascading

### Problem
When a bomb cleared a 3×3 area that contained a flame powerup, the flame would just disappear instead of cascading. This made flame powerups inconsistent with arrows and other powerups.

### Solution
Added full flame cascading support to `activateCascadingPowerups()`:

**How Flame Cascading Works:**
1. Flame powerup is detected in cleared area
2. Pick a random adjacent tile (up, down, left, right)
3. Clear ALL pieces matching that tile's type across entire board
4. Capture any OTHER powerups found during clearing
5. Those powerups cascade in turn

**Example:**
```
Bomb clears 3×3 area
  ├─ Area contains Flame powerup
  ├─ Flame picks random adjacent tile (happens to be 🍎)
  └─ Flame cascades: clears ALL 🍎 on board
      └─ Found Arrow in cleared area
          └─ Arrow cascades next...
```

### Code Changes
**File**: `MatchGameViewController.swift`
**Function**: `activateCascadingPowerups()`

**Changes:**
1. Added `.flame` to `flameAnimationsInProgress` counter
2. Added `case .flame:` handler in powerup switch
3. Finds adjacent non-normal tiles
4. Randomly selects one
5. Clears all matching pieces across board
6. Captures cascading powerups found

### Debug Output
```
🔥 Cascading flame cleared all matching apples. Found 2 cascading powerups
```

---

## Fix #2: Powerup-to-Powerup Overlap Swaps

### Problem
When swapping two powerups that don't have special combinations (e.g., bomb + arrow), they would swap places like normal pieces. User wanted them to:
- NOT switch places
- Moving powerup overlaps stationary one at target location
- Original space stays blank
- Both activate at the target location

### Solution
Added special handling for non-combo powerup-to-powerup swaps:

**When Does This Trigger?**
- Both swapped pieces are powerups (type != .normal)
- They DON'T have a special combo (not bomb+bomb, flame+flame, arrow+arrow)

**Examples of Combinations:**
- ✅ Bomb + Arrow → overlap and both activate at arrow location
- ✅ Flame + Bomb → overlap and both activate at bomb location
- ❌ Bomb + Bomb → special combo (clears 4×4)
- ❌ Flame + Flame → special combo (clears screen)
- ❌ Arrow + Arrow → special combo (clears row+col)

### How It Works

**Before (Normal Swap):**
```
Before:                After:
[Bomb] [Arrow]  →     [Arrow] [Bomb]
Location A      B     Location A  B
```

**After (Powerup Overlap):**
```
Before:                After:
[Bomb] [Arrow]  →     [ ]    [Bomb+Arrow]
Loc A   Loc B         Loc A   Loc B (overlapping)
```

**What Happens:**
1. User swaps bomb at A with arrow at B
2. Bomb moves toward B (normal swap animation)
3. BUT: Don't fully swap - bomb lands on arrow
4. Original position A becomes blank (no piece there)
5. Position B has overlapped pieces (Bomb ON TOP OF Arrow)
6. Both powerups activate at position B:
   - If Bomb: 3×3 area from position B cleared
   - If Arrow: row/column from position B cleared
   - PLUS any areas overlapped by first powerup

### Code Changes
**File**: `MatchGameViewController.swift`
**Function**: `activatePowerUps()`

**Changes:**
1. Detect if swap involves two non-combo powerups
2. Skip the normal position swap
3. Keep moving powerup at target position (r2, c2)
4. Clear original position (r1, c1)
5. Collect cleared tiles based on powerup type at NEW location
6. Both powerups' effects apply
7. Original space shows empty after gravity

### Debug Output
```
🔍 [DEBUG] Powerup-to-powerup overlap: bomb at (2,3) overlaps arrow
```

### Example Scenario
**User Action:** Swap bomb left → arrow
```
Grid Before:
Row 2: 🍎 [💣] [↔️] 🍏 🍎
       Pos A  B

Grid After Swap:
Row 2: 🍎  [ ]  [💣↔️] 🍏 🍎  (overlapped at B)
       Pos A      B

What Clears:
- Arrow clears row 2: all 5 pieces
- Bomb clears 3×3 around (2, 3)
- Both areas combined clear
```

---

## Performance Impact

### Flame Cascading
- ✅ Negligible - only on cascading activation
- ✅ Searches board once per flame
- ✅ Early exit on full board scan

### Powerup Overlap
- ✅ Minimal - just detection and different path
- ✅ Same animation as swap
- ✅ Same number of tile clears

---

## Testing Recommendations

### Test 1: Flame Cascading
1. Create bomb to clear area with flame
2. Watch flame activate and pick random adjacent
3. Verify all matching pieces clear
4. Check console: `🔥 Cascading flame cleared...`

### Test 2: Powerup Overlap
1. Create bomb powerup
2. Create arrow powerup
3. Swap them (bomb toward arrow)
4. Watch them overlap instead of swap
5. Verify both effects apply
6. Check original position is blank after gravity

### Test 3: Special Combos Still Work
1. Create two bombs
2. Swap them → should clear 4×4 (normal combo)
3. Create bomb and arrow
4. Swap them → should overlap (new behavior)

---

## Expected User Experience

### Flame Cascading
- Flame powerups now feel consistent with other powerups
- Surprise mechanic: which tile gets cleared depends on random pick
- Can create chain reactions

### Powerup Overlaps
- Intuitive: when swapping different powerups, they "stack" visually
- Original space empties out
- More powerful effect (both activate in same area)
- Feels like a bonus move combination

