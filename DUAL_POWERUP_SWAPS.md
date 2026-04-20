# Dual Powerup Swap Mechanics - Updated April 20, 2026

## New Features

### 1. Two Bombs Swapped = 4x4 Grid Clear ✅

**What Changed:**
- When you swap two bombs with each other, they now clear a **4x4 grid** around the midpoint
- Instead of clearing the entire screen like before
- The 4x4 is centered between the two bomb positions

**How It Works:**
```
Before: Bomb1 + Bomb2 = Clear entire screen

After:  Bomb1 + Bomb2 = Clear 4x4 grid around midpoint
        
Example: You swap bomb at (2,2) with bomb at (4,4)
         Midpoint: (3,3)
         Clears 4x4 area from (1,1) to (4,4)
```

**Calculation:**
```swift
let midRow = (r1 + r2) / 2  // Midpoint row
let midCol = (c1 + c2) / 2  // Midpoint col

// Clear 4x4 (2 above/left, 1 below/right of midpoint)
for dr in -2...1 {
    for dc in -2...1 {
        // Clear tiles at midRow+dr, midCol+dc
    }
}
```

**Debug Output:**
```
🔍 [DEBUG] Two bombs merged! Clearing 4x4 grid around (3,3). Found 2 cascading powerups
```

---

### 2. Two Flames Swapped = Clear All Tiles ✅

**What Changed:**
- Added new mechanic: swapping two flames with each other clears **entire screen**
- Similar to what two bombs used to do
- More powerful reward for getting two flames together

**How It Works:**
```
Flame1 + Flame2 = Clear entire board

Example: You create a flame by matching 5 in a row
         You create another flame by matching 5 in a column
         Swap them together → BOOM! Entire screen clears
```

**Debug Output:**
```
🔍 [DEBUG] Two flames merged! Clearing entire screen. Found 5 cascading powerups
```

---

## Cascading Powerups

Both mechanics capture cascading powerups:

**Two Bombs (4x4 clear):**
- Any powerups in the 4x4 area are captured
- They cascade after the 4x4 is cleared
- Example: Bomb + Bomb clears 4x4 containing an Arrow → Arrow cascades

**Two Flames (full clear):**
- All powerups on the board are captured
- They cascade after entire screen is cleared
- Creates massive chain reactions

---

## Visual Feedback

### Border Highlighting
- Yellow border shows around **all affected tiles** before clearing
- Border appears for 0.2 seconds
- Then tiles disappear with fade animation
- 4x4 bombs: shows 16 bordered tiles
- 2 flames: shows all tiles on screen with borders

### Haptic Feedback
- Heavy impact feedback when activated
- Player feels the power of the combo

---

## Strategic Considerations

### Two Bombs (4x4 Clear)
- **When to use**: Want to clear a specific area with power
- **Pros**: Targeted clearing, smaller than full board
- **Cons**: Not as powerful as two flames
- **Strategy**: Good for clearing around important areas

### Two Flames (Full Clear)
- **When to use**: Want maximum clearing power
- **Pros**: Clears entire board, resets everything
- **Cons**: Harder to get two flames (need 5-match each)
- **Strategy**: Save for desperate situations or end-game

---

## Examples

### Scenario 1: Two Bombs
```
User has: Bomb at (1,3) and Bomb at (3,5)
Action: Swap them
Result: 4x4 grid centered at (2,4) clears
        Clears from (0,2) to (3,5) approximately
        Then gravity applies, board refills
```

### Scenario 2: Two Flames
```
User has: Flame at (0,0) and Flame at (4,6)
Action: Swap them
Result: Entire board clears!
        All tiles removed at once
        Board completely refills
        Can create chain of new matches
```

### Scenario 3: Cascading from Two Bombs
```
User swaps two bombs → 4x4 clears
Inside 4x4 there's an arrow and another bomb
→ Arrow cascades (clears entire row)
→ Bomb cascades (clears its 3x3 area)
→ Chain continues until no powerups left
```

---

## Debug Console Output

### Two Bombs Activation
```
🔍 [DEBUG] Two bombs merged! Clearing 4x4 grid around (2,3). Found 1 cascading powerups
🔥 Cascading bomb cleared 3x3 area around (2,3). Found 0 cascading powerups
```

### Two Flames Activation
```
🔍 [DEBUG] Two flames merged! Clearing entire screen. Found 3 cascading powerups
🔥 Cascading horizontal arrow cleared row 2. Found 1 cascading powerups
🔥 Cascading bomb cleared 3x3 area around (3,3). Found 0 cascading powerups
```

---

## Testing

### Test Two Bombs (4x4)
1. Create a level with bombs at opposite corners
2. Swap the two bombs
3. Watch 4x4 grid light up with yellow borders
4. Verify tiles in 4x4 disappear
5. Check console for debug message with coordinates

### Test Two Flames (Full Clear)
1. Create two separate 5-match situations to get flames
2. Swap the two flames
3. Watch entire screen light up with yellow borders
4. Verify all tiles disappear at once
5. Check console for "entire screen" message
6. Watch board refill completely

### Test Cascading
1. Position bombs/arrows in the cleared area
2. Watch them cascade automatically
3. Verify chain continues to completion

---

## Files Modified
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/MatchGameViewController.swift`
  - Two bombs logic (4x4 instead of full clear)
  - New two flames logic (full clear)
  - Debug logging for both cases

