# Bomb Powerup Position Fix - Smart Placement

## Problem
The bomb powerup was appearing at a fixed position (always bottom-right or always bottom-left) regardless of where the actual swap happened. This looked wrong when:
- You swapped in the first column → bomb appeared in wrong place
- You swapped in a different corner → bomb appeared in wrong place

## Solution
The bomb now appears **exactly where one of the swapped tiles is located** within the 2x2 match!

## How It Works

When a 2x2 match is created:

```
BEFORE (Fixed position):
Old: Always bottom-right
     Tile Tile     Bomb appears here
     Tile Tile     regardless of where swap was

NEW (Smart position):
If user swapped TOP-LEFT:   Bomb appears in TOP-LEFT
If user swapped TOP-RIGHT:  Bomb appears in TOP-RIGHT
If user swapped BOTTOM-LEFT:  Bomb appears in BOTTOM-LEFT
If user swapped BOTTOM-RIGHT: Bomb appears in BOTTOM-RIGHT
```

## Technical Implementation

The code now:
1. **Checks `lastSwappedPositions`** - tracks the two tiles that were swapped
2. **Tests if either swapped tile is in the 2x2** - checks all 4 positions
3. **Places bomb at the swapped position** - wherever the swap happened

```swift
if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
    if (r1 is in the 2x2) {
        bomb placed at (r1, c1)
    } else if (r2 is in the 2x2) {
        bomb placed at (r2, c2)
    }
}
```

## Debug Output

When you create a 2x2 match, you'll see in Xcode Console:

```
🔍 [DEBUG] Found 2x2 bomb pattern at 2x2 square (row,col) to (row+1,col+1). Bomb placed at (bombRow,bombCol)
```

For example:
```
🔍 [DEBUG] Found 2x2 bomb pattern at 2x2 square (3,1) to (4,2). Bomb placed at (3,2)
```

This tells you:
- The 2x2 is between coordinates (3,1) and (4,2)
- The bomb appeared at position (3,2) - which is where you moved the tile!

## Examples

### Example 1: Swap Upward into Column 2
```
Before swap:        After swap (with match):       Bomb placement:
A  B  C             A  C  C                        A  C  💣
D  B  C             D  B  C                        D  B  C
E  F  G             E  F  G                        E  F  G

User moved C up into (row 0, col 2)
Bomb appears at (row 0, col 2) - the swapped position!
```

### Example 2: Swap Leftward into Column 1
```
Before swap:        After swap (with match):       Bomb placement:
A  B  C             A  B  B                        A  B  💣
D  B  C             D  C  C                        D  C  C
E  F  G             E  F  G                        E  F  G

User moved B left into (row 0, col 1)
Bomb appears at (row 0, col 1) - the swapped position!
```

## Testing

To test this:
1. Create a 2x2 match by swapping into ANY position
2. Open Xcode Console
3. Look for the bomb placement debug message
4. Verify the bomb appears where you swapped the tile

The bomb should now always appear at the position of the tile you moved!

