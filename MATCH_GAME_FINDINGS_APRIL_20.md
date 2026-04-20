# Match Game Order of Operations - FINDINGS (April 20, 2026)

## Executive Summary

After detailed code review, the match game has **CRITICAL ISSUES** with the order of operations:

| Issue | Status | Severity |
|-------|--------|----------|
| Match detection scans TOP-to-BOTTOM instead of BOTTOM-to-TOP | ❌ FAIL | HIGH |
| Missing yellow border highlight before matched tiles disappear | ❌ FAIL | HIGH |
| Missing yellow border highlight before powerup effects activate | ❌ FAIL | HIGH |
| Gravity and refill sequence | ✅ PASS | - |
| Cascade loop continues until no matches | ✅ PASS | - |

---

## ISSUE #1: Match Detection Scanning Order ❌ WRONG

**File**: `MatchGameViewController.swift`, lines 1360-1470
**Function**: `checkForMatches()`

### User Requirement
"The logic should look for matches starting at the bottom left of the grid and working right and up."

### Current Implementation (WRONG)
```swift
// Horizontal matches - scans TOP to BOTTOM
for row in 0..<level.gridHeight {  // ❌ 0 = TOP
    var col = 0
    while col < level.gridWidth {  // ✓ LEFT to RIGHT
        // Check horizontal match at [row][col]
        col = max(col + 1, checkCol)
    }
}

// Vertical matches - scans TOP to BOTTOM
for col in 0..<level.gridWidth {   // ✓ LEFT to RIGHT
    var row = 0  // ❌ 0 = TOP
    while row < level.gridHeight {  // ❌ increases downward = TOP to BOTTOM
        // Check vertical match at [row][col]
        row = max(row + 1, checkRow)
    }
}
```

### Grid Coordinate System
- `row = 0` is at the TOP
- `row = gridHeight-1` is at the BOTTOM
- `col = 0` is at the LEFT
- `col = gridWidth-1` is at the RIGHT

### What Should Happen
Start at **bottom-left** (`row = gridHeight-1, col = 0`) and work:
- RIGHT (col++) along the bottom row
- UP (row--) to check rows above

### Impact
- Matches are detected in different order than specified
- Could affect cascading match behavior in edge cases
- Game plays correctly but doesn't follow specification

---

## ISSUE #2: Missing Border Highlight Before Match Removal ❌ MISSING

**File**: `MatchGameViewController.swift`, lines 1460-1620
**Functions**: 
- `checkForMatches()` line 1508
- `animateMatchedPieces()` line 1572

### User Requirement
"if it finds a match of 3+, those tiles should have a border highlight them quickly, they should disappear"

### Current Implementation (WRONG)
```swift
// In checkForMatches() - when matches found
if !matchesToRemove.isEmpty {
    let impact = UIImpactFeedbackGenerator(style: .heavy)
    impact.impactOccurred()
    
    // Directly animate removal WITHOUT border first
    animateMatchedPieces(matchesToRemove) { [weak self] in
        // Remove from grid
        for posString in matchesToRemove {
            self?.score += 1
            self?.gameGrid[parts[0]][parts[1]] = nil
        }
        // Create power-ups
        // Apply gravity
    }
}

// In animateMatchedPieces() - NO BORDER SHOWN
for posString in matchesToRemove {
    if let button = gridButtons[row][col] {
        animationCount += 1
        
        // Immediately fade + scale + rotate
        UIView.animate(withDuration: 0.2, animations: {
            button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: CGFloat.pi)
            button.alpha = 0.0
        }, completion: { _ in
            button.transform = .identity
            button.alpha = 1.0
            
            completedCount += 1
            if completedCount == animationCount {
                completion()
            }
        })
    }
}
```

### What Should Happen
1. Show yellow border around matched tiles (0.2s)
2. Then fade/scale out (0.2s)
3. Total animation time: 0.4s

### Current Behavior
- Pieces immediately scale, rotate, and fade
- No border shown
- Visual feedback unclear

### Impact
- Player can't see which tiles are being matched
- Confusing visual experience
- Especially problematic in cascading matches

---

## ISSUE #3: Missing Border Highlight Before Powerup Removal ❌ MISSING

**File**: `MatchGameViewController.swift`, lines 760-1040
**Function**: `activatePowerUps()`

### User Requirement
"powerups will also display a border highlight of the tiles that they'll remove, prior to removing them"

### Current Implementation (WRONG)

**Example 1: Horizontal Arrow** (lines 862-876)
```swift
if piece1?.type == .horizontalArrow {
    let impact = UIImpactFeedbackGenerator(style: .medium)
    impact.impactOccurred()
    
    // Immediately marks tiles and clears them
    for col in 0..<level.gridWidth {
        if gridShapeMap[r1][col] && gameGrid[r1][col] != nil {
            if let piece = gameGrid[r1][col], piece.type != .normal {
                cascadingPowerups.append((row: r1, col: col, type: piece.type))
            }
            clearedTiles.insert("\(r1),\(col)")  // ← Marked for clearing
            score += 1
            gameGrid[r1][col] = nil  // ← IMMEDIATELY CLEARED (no animation)
        }
    }
    gameGrid[r1][c1] = nil
}
```

**Example 2: Bomb Powerup** (lines 905-927)
```swift
if piece1?.type == .bomb {
    let impact = UIImpactFeedbackGenerator(style: .medium)
    impact.impactOccurred()
    
    // Clears 3x3 area immediately without showing which tiles
    for dr in -1...1 {
        for dc in -1...1 {
            let nr = r1 + dr
            let nc = c1 + dc
            if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
               gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                if let piece = gameGrid[nr][nc], piece.type != .normal {
                    cascadingPowerups.append((row: nr, col: nc, type: piece.type))
                }
                clearedTiles.insert("\(nr),\(nc)")
                score += 1
                gameGrid[nr][nc] = nil  // ← IMMEDIATELY CLEARED (no animation)
            }
        }
    }
    gameGrid[r1][c1] = nil
}
```

### What Should Happen
1. Show yellow border around all affected tiles (0.2-0.3s)
2. Then apply effect/remove tiles (0.2s)
3. Then continue with gravity/cascade

### Current Behavior
- Powerup immediately clears grid without animation
- Player doesn't see which tiles will be affected
- No border highlight shown
- Then `applyGravity()` called directly

### Problem Timeline
```
User swaps → Powerup detected → gameGrid[x][y] = nil immediately → applyGravity()
                               ↑ No visual feedback or border ↑
```

### Impact
- Player confused by what powerup does
- Tiles disappear with no warning
- Visual experience is jarring
- Especially bad when powerup triggers cascading powerups

---

## VERIFIED ✅: Gravity and Refill Sequence

**File**: `MatchGameViewController.swift`, lines 1627-1695
**Function**: `applyGravity()`

### Correct Sequence
1. **Step 1**: Gravity applied - existing pieces fall down (line 1635-1658)
2. **Step 2**: Refill - new pieces created for empty spaces (line 1660-1687)
3. **Step 3**: Display updated immediately (line 1689)
4. **Step 4**: Animation shown with proper sequencing (line 1691)
5. **Step 5**: After animation completes, cascade check (line 1694 → `checkForMatches()`)

✅ This sequence is **CORRECT** and follows user requirements.

---

## VERIFIED ✅: Cascade Loop

**File**: `MatchGameViewController.swift`, lines 1360-1620

Cascade check called from:
1. After gravity animation completes (line 1694)
2. Recursively when matches found and removed (line 1508)

✅ This sequence is **CORRECT** - continues until no matches found.

---

## User Move Sequence (PARTIALLY CORRECT)

**File**: `MatchGameViewController.swift`, lines 696-768
**Function**: `swapPieces()`

### Current Flow
```
1. User drags to adjacent tile ✓
2. Pieces animate swap (0.3s) ✓
3. Swap confirmed in data ✓
4. Check if either swapped piece is powerup (lines 761-765)
5. If powerup:
   - activatePowerUps() called (line 764)
   - ❌ Tiles cleared WITHOUT border highlight
   - Then applyGravity()
6. If no powerup:
   - checkForMatches() called (line 768)
   - If matches: show animation, gravity, cascade check ✓
   - If no matches: revert swap ✓
```

### Issues
- When powerup swapped: tiles cleared without border highlight ❌
- Same issues as Issue #3 above

---

## Order of Operations Summary

### Initial Level Load (START LEVEL)
```
1. Level initialized ✓
2. Wait 0.5 seconds
3. checkForMatches()
   - Scan for 3+ matches
   - ❌ Starting from TOP not BOTTOM
   - If found:
     - ❌ No border highlight
     - Remove with animation
     - applyGravity()
       - Pieces fall ✓
       - New pieces fill ✓
     - After animation: checkForMatches() again ✓
   - Repeat until no matches
```

### User Move (SWAP TILES)
```
1. User swaps two adjacent pieces
2. Animate swap (0.3s)
3. Check for powerups
   - If powerup swapped:
     - ❌ Activate without border highlight
     - Clear tiles immediately
     - applyGravity()
   - If no powerup:
     - checkForMatches()
       - If match found:
         - ❌ No border highlight
         - Remove with animation
         - applyGravity()
         - After animation: checkForMatches() ✓
       - If no match:
         - Revert swap (very slow 2.5s)
```

---

## Issues to Fix

1. **Fix Match Detection Scanning** to start from BOTTOM-LEFT
2. **Add Border Highlight** before matched tiles disappear
3. **Add Border Highlight** before powerup effects activate

---

## Files That Need Changes

1. `MatchGameViewController.swift` - lines 1360-1470 (scanning order)
2. `MatchGameViewController.swift` - lines 1572-1620 (match border animation)
3. `MatchGameViewController.swift` - lines 760-1040 (powerup border animation)

