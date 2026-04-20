# Visual Order of Operations Comparison

## REQUIREMENT vs CURRENT IMPLEMENTATION

### 1. Match Detection Scanning Order

#### REQUIREMENT: Bottom-Left to Top-Right
```
     Col: 0  1  2  3  4
Row:
 0   [ ][ ][ ][ ][ ]    (top)
 1   [ ][ ][ ][ ][ ]
 2   [ ][ ][ ][ ][ ]
 3   [ ][ ][ ][ ][ ]
 4   [→]→→→→[↑]        (bottom-left) START HERE

Scanning pattern:
→ Row 4: Check 0→1→2→3→4 (left to right)
↑ Then Row 3: Check 0→1→2→3→4
↑ Then Row 2: Check 0→1→2→3→4
... and so on moving UP
```

#### CURRENT: Top-to-Bottom, Left-to-Right
```
     Col: 0  1  2  3  4
Row:
 0   [↓]↓↓↓↓[→]        (top) START HERE
 1   [ ][ ][ ][ ][ ]
 2   [ ][ ][ ][ ][ ]
 3   [ ][ ][ ][ ][ ]
 4   [ ][ ][ ][ ][ ]    (bottom)

Scanning pattern:
↓ Row 0: Check 0→1→2→3→4
↓ Then Row 1: Check 0→1→2→3→4
↓ Then Row 2: Check 0→1→2→3→4
... and so on moving DOWN
```

**ISSUE**: ❌ Starts at top instead of bottom

---

### 2. Match Removal Animation Sequence

#### REQUIREMENT: Border First, Then Fade
```
TIMELINE:

T=0ms:  Show matched tiles (normal)
        ┌─────────────────┐
        │    Matched      │
        │     Tile        │
        └─────────────────┘

T=100ms: Show YELLOW BORDER (bright)
        ┌═════════════════┐
        ║  Matched Tile   ║  ← Yellow border highlights
        ║  (selected)     ║
        └═════════════════┘

T=200ms: FADE & SCALE START
        ┌═════════════════┐
        ║   Scale:0.8     ║  ← Border still visible
        ║    Alpha:0.7    ║
        └═════════════════┘

T=400ms: Completely removed
        (empty space - gravity will fill)
```

#### CURRENT: Immediate Fade, No Border
```
TIMELINE:

T=0ms:   Show matched tile
        ┌─────────────────┐
        │    Matched      │
        │     Tile        │
        └─────────────────┘

T=50ms:  IMMEDIATELY START FADE (NO BORDER)
        ┌─────────────────┐
        │ Scale: 0.5      │  ← No yellow border!
        │ Alpha: 0.5      │
        │ Rotate: 180°    │
        └─────────────────┘

T=200ms: Completely gone
        (empty space)
```

**ISSUE**: ❌ No border shown, immediate animation

---

### 3. Powerup Effect Timeline

#### REQUIREMENT: Show Affected Tiles With Border, Then Effect
```
USER SWAPS: Regular tile + Bomb powerup
                        ↓

STEP 1: Show which tiles will be affected
        ┌─────────┐
        │ Bomb 💣 │
        └─────────┘
             ↓↓↓ affects 3x3 area
        
        ┌──────────────────┐
        │ ┌─╋─┐            │
        │ ╋ 💣 ╋  ← Yellow │
        │ ┌─╋─┐  borders   │
        └──────────────────┘

STEP 2: Wait 0.2 seconds (player sees which tiles)

STEP 3: Remove the tiles
        (animation shows removal)

STEP 4: Apply gravity (tiles fall, refill from top)

STEP 5: Check for cascading matches
```

#### CURRENT: Immediately Remove, No Visual
```
USER SWAPS: Regular tile + Bomb powerup
                        ↓

STEP 1: Immediately clear grid[nr][nc] = nil
        (NO VISUAL FEEDBACK)
        
        ┌──────────────────┐
        │          ┌─┐     │
        │  💣 POOF │ │     │  ← Tiles just vanish!
        │ (GONE!)  └─┘     │     No warning!
        └──────────────────┘

STEP 2: Apply gravity
```

**ISSUE**: ❌ Tiles cleared immediately, no border, no animation feedback

---

### 4. After User Move - Complete Sequence

#### REQUIREMENT
```
USER MOVE (Swap tiles)
        ↓
ANIMATE SWAP (0.3s)
        ↓
CHECK IF POWERUP
    ├─ YES: Show borders around affected tiles (0.2s)
    │                ↓
    │       Remove tiles (animate)
    │                ↓
    │       Apply gravity
    │                ↓
    │       Check cascading matches
    │
    └─ NO: Check for match
                     ↓
              IF MATCH:
              ├─ Show border around matched (0.2s)
              ├─ Remove tiles (animate)
              ├─ Apply gravity
              └─ Check cascading matches
              
              IF NO MATCH:
              └─ Revert swap (slow 2.5s)
```

#### CURRENT
```
USER MOVE (Swap tiles)
        ↓
ANIMATE SWAP (0.3s)
        ↓
CHECK IF POWERUP
    ├─ YES: gameGrid[x][y] = nil (IMMEDIATE) ❌
    │       applyGravity()
    │
    └─ NO: checkForMatches()
            ├─ IF MATCH: animateFade() (NO BORDER) ❌
            │            applyGravity()
            │
            └─ IF NO MATCH: revertSwap()
```

---

## Summary Table

| Step | Requirement | Current | Status |
|------|-------------|---------|--------|
| 1. Match scanning from bottom-left | ✓ Specified | Starts from top | ❌ WRONG |
| 2. Show border before matched removal | ✓ Specified | No border shown | ❌ MISSING |
| 3. Animate matched removal | ✓ Specified | Fade/scale (no border) | ⚠️ PARTIAL |
| 4. Apply gravity after removal | ✓ Specified | ✓ Applied | ✅ CORRECT |
| 5. Refill from top | ✓ Specified | ✓ Refilled | ✅ CORRECT |
| 6. Check cascade matches | ✓ Specified | ✓ Checked | ✅ CORRECT |
| 7. Show border before powerup effect | ✓ Specified | No border shown | ❌ MISSING |
| 8. Remove powerup affected tiles | ✓ Specified | Immediate clear | ⚠️ WRONG TIMING |

---

## What Needs to Be Fixed

### Priority 1 (HIGH): Border Highlights
- [ ] Add yellow border before matched tiles disappear
- [ ] Add yellow border before powerup effects activate
- [ ] Border should display 0.2 seconds, then fade animation starts

### Priority 2 (HIGH): Match Detection Order
- [ ] Change scanning to start from bottom-left
- [ ] Scan right (col++) along bottom row
- [ ] Then move up (row--) to check rows above

### Priority 3 (MEDIUM): Powerup Animation
- [ ] Don't immediately clear grid on powerup activation
- [ ] Show border first
- [ ] Then animate removal
- [ ] Then apply gravity

