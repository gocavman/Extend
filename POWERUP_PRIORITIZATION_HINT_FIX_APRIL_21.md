# Match Game - Powerup Prioritization & Hint System Fix (April 21, 2026)

## Fix #1: Powerup Prioritization

### Problem
When a single swap could result in multiple powerups at different locations, or when there was overlap in match detection, the game would create all powerups without prioritizing them. This could result in lower-value powerups being placed instead of higher-value ones.

### Solution
Implemented a prioritization system that runs AFTER all powerups are detected but BEFORE they're placed:

**Priority Order:**
1. **Flame (↕️ or ↔️)** - Created from 5+ matches (highest value)
2. **Arrow (↕️ or ↔️)** - Created from 4+ matches
3. **Bomb (💣)** - Created from 2×2 patterns (lowest value)

### How It Works

```swift
// After all powerups are detected:
var prioritizedPowerups: [(row: Int, col: Int, type: PieceType)] = []
var powerupLocations: [String: PieceType] = [:]  // Track (row,col) -> highest priority type

for powerup in powerUpsToCreate {
    let key = "\(powerup.row),\(powerup.col)"
    
    // Compare priorities: flame (3) > arrow (2) > bomb (1)
    if newPriority > existingPriority {
        powerupLocations[key] = powerup.type  // Replace with higher priority
    }
}
```

**Example:**
- Horizontal match creates arrow at (3,5)
- Vertical match creates bomb at (3,5)
- **Result**: Arrow is kept, bomb is discarded
- **Why**: Flame has priority 3, Arrow has priority 2

### Code Location
- File: `MatchGameViewController.swift`
- Function: `checkForMatches()`
- Lines: ~1970-2005 (after match detection, before grid update)

### Testing
1. Create a scenario where match detection could place multiple powerups at same location
2. Verify that only the highest-priority powerup appears
3. Try flame vs arrow at same location → flame wins
4. Try arrow vs bomb at same location → arrow wins

---

## Fix #2: Hint Pulsing - Cascading Match Detection

### Problem
The idle hint system would sometimes show a pulsing tile immediately after pieces fell and cascading matches were still being processed. This made it look like the game was suggesting a move when matches were already detected on the board.

**Timeline of Issue:**
1. Player makes swap → match detected
2. Tiles removed, gravity applied
3. Pieces fall → **new cascading matches appear**
4. checkForMatches() is about to run
5. **BUT** hint timer fires and shows pulse on tile
6. Player sees pulse while cascading matches exist

### Solution
Added `hasCascadingMatches()` check before showing hint. If matches exist on board, don't show hint—reschedule the hint timer instead.

```swift
private func showIdleHint() {
    // ... existing checks ...
    
    // NEW: Check if cascading matches currently exist
    if hasCascadingMatches() {
        print("Skipping hint - cascading matches detected")
        resetIdleHintTimer()  // Reschedule for later
        return
    }
    
    // Continue with normal hint logic
    // ...
}

private func hasCascadingMatches() -> Bool {
    // Scan grid for any 3+ matches that currently exist
    // Returns true if matches found, false if none
}
```

### How It Works

**Before showing hint:**
1. Check if any horizontal matches exist (3+ pieces)
2. Check if any vertical matches exist (3+ pieces)
3. If found, reschedule hint and return early
4. If none found, proceed with hint logic

**Result:**
- Hints only show when board is in stable state (no pending matches)
- After gravity completes and cascading matches are detected
- New cascade is processed
- Hint timer resets (user can interact)
- Next hint shows 10 seconds later if still idle

### Code Location
- File: `MatchGameViewController.swift`
- Functions:
  - `showIdleHint()` - Added cascading check at start
  - `hasCascadingMatches()` - New function to detect pending matches
- Lines: ~2824-2981

### Why This Works

**Cascading Match Timeline (Fixed):**
```
T=0s:    User makes swap
T=0.2s:  Match animation completes
T=0.5s:  Gravity animation completes  ← Cascading matches appear on board
T=0.5s+: checkForMatches() runs        ← NEW: hasCascadingMatches() detects them
T=0.5s+: Hint timer fires              ← NEW: But we skip hint and reschedule!
T=0.5+:  Cascading matches processed
T=10.5s: Only NOW does hint show (stable board)
```

### Testing
1. Make a swap that causes cascading matches
2. Watch pieces fall
3. Notice **NO** pulsing hint appears while cascades process
4. Wait 10 more seconds with no interaction
5. See hint pulse on a valid move suggestion
6. Compare with before: hint should appear LESS frequently now

---

## Performance Impact

### Powerup Prioritization
- ✅ Negligible - runs only when matches detected
- ✅ O(n) where n = number of powerups (typically 1-3)
- ✅ Dictionary lookup and comparison only

### Cascading Match Detection
- ⚠️ Adds scanning of entire grid
- ⚠️ O(n²) where n = grid size (5×5 grid = 25 checks)
- ✅ Only runs every 10 seconds (hint timer)
- ✅ Early exit if match found (doesn't scan entire board)

**Optimization**: Could cache match positions, but not needed for typical 5×5 grid

---

## Expected Behavior After Fixes

### Powerup Prioritization
**Before:**
- Swap creates both arrow and bomb conditions
- Either one might appear randomly

**After:**
- Flame ALWAYS created if 5+ match exists
- Arrow created if 4+ exists and no flame
- Bomb created if 2×2 exists and no flame/arrow

### Hint Pulsing
**Before:**
- Hint pulses immediately after cascade completes
- Looks like game is suggesting move during active cascade
- Confusing timing

**After:**
- Hint waits until board is stable
- Only pulses when no pending matches exist
- Clear visual signal that there ARE no active cascades
- More useful hint timing

---

## Code Changes Summary

### checkForMatches() - Powerup Prioritization
- Added prioritization logic after match detection
- Creates mapping of location → highest priority powerup
- Only places highest priority at each location

### showIdleHint() - Cascade Detection
- Added `hasCascadingMatches()` check before showing hint
- Reschedules timer if cascades detected
- Prints debug message

### NEW: hasCascadingMatches()
- Scans grid for any 3+ matches (horizontal and vertical)
- Returns boolean
- Early exit on first match found
