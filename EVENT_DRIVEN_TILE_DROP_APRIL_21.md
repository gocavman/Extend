# Match Game - Event-Driven Sequential Tile Drop (April 21, 2026)

## Problem Statement
Tile dropping animations were problematic with duration-based delays:
- Awkward pauses before items start falling
- Overlap issues when pieces overshooted their landing
- Complex duration calculations that didn't account for all scenarios

## Solution: Event-Driven Sequential Animation

### Core Concept
Instead of using **pre-calculated delays and uniform durations**, use **chained completion handlers** to drive animations sequentially:

```swift
// OLD: Calculate all delays/durations upfront, animate all at once
for (button, delay, duration) in allAnimations {
    UIView.animate(withDuration: duration, delay: delay, ...) { ... }
}

// NEW: Animate pieces one at a time, next piece starts when previous completes
animatePieceSequentially(index: 0) {
    if index < pieces.count {
        animate(pieces[index], completion: {
            animatePieceSequentially(index: index + 1, completion: completion)
        })
    }
}
```

### How It Works

**Per Column Sequential Animation:**
1. Pieces in each column are sorted bottom-to-top
2. Animate bottom piece with its calculated duration
3. When bottom piece **completes**, animate next piece up
4. When all pieces in column complete, move to next column
5. When all columns complete, call main completion handler

**No Delays Needed:**
- Each piece animates for exactly its fall distance / speed
- Each piece starts when the previous one finishes
- No guessing, no overlap, no awkward pauses

### Key Advantages

✅ **Event-Driven**: Next animation triggered by completion of previous  
✅ **No Timing Guesses**: Each piece falls for exactly its duration  
✅ **No Overlap**: Sequential execution prevents mid-animation collisions  
✅ **Individual Durations**: Each piece calculates its own duration  
✅ **Cleaner Logic**: Recursive approach is easier to understand  
✅ **No Pause Issues**: Pieces start immediately after predecessor completes  

## Implementation Details

### New Helper Struct
```swift
private struct AnimatingPiece {
    let button: UIButton
    let row: Int
    let distance: Int
    let isNew: Bool
}
```

Tracks everything needed for animation without pre-calculating delays.

### Recursive Animation Function
```swift
private func animateColumnPiecesSequentially(
    pieces: [AnimatingPiece],
    index: Int,
    cellHeight: CGFloat,
    fallSpeed: CGFloat,
    col: Int,
    completion: @escaping () -> Void
)
```

- Calls itself recursively for each piece
- When `index >= pieces.count`, calls completion
- Each recursive call triggers the next animation

### Main Function Logic

1. **Build pieces per column** (sorted bottom-to-top)
2. **Per-column animation**:
   - Track completed columns
   - For each column, call `animateColumnPiecesSequentially`
   - When all columns complete, call main completion

### Timing Calculation
```swift
let fallDistance = cellHeight * CGFloat(piece.distance)
let duration = Double(fallDistance / fallSpeed)
```

Each piece animates for exactly: `distance / speed`  
No additional stagger needed - sequential execution provides natural spacing.

## Files Modified
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/MatchGameViewController.swift`
  - Completely rewrote `animatePiecesDrop()` function
  - Added `AnimatingPiece` struct
  - Added `animateColumnPiecesSequentially()` helper function

## Expected Behavior

### Before
- Awkward pauses before items start falling
- Complex delay calculations
- Potential overlap during mid-animation
- Duration-based timing issues

### After
- Items start falling immediately after previous piece completes
- No pauses or delays
- Event-driven sequencing prevents overlap
- Each piece falls for exactly its calculated duration
- Smooth, predictable animations

## Testing Recommendations

1. **Timing**
   - Swap match vs arrow powerup drops should look similar
   - No noticeable pauses before movement starts
   - Consistent speed across all match types

2. **Sequencing**
   - Watch bottom pieces start first
   - Each piece finishes before next starts (within column)
   - Columns can animate simultaneously (different columns)

3. **Cascades**
   - Trigger cascading matches
   - Should see smooth, sequential drops without stutter

4. **Visual Verification**
   - No overlap mid-animation
   - Pieces land at correct final positions
   - New pieces fade in smoothly as they fall

## Performance Impact
✅ **Same**: Same number of animations, same GPU usage  
✅ **Better**: Event-driven approach eliminates timing complexity  
✅ **Cleaner**: Recursive pattern is easier to maintain  

## Why Event-Driven Is Better

**Duration-based approach problems:**
- Requires pre-calculating all delays
- Can't account for animation timing variations
- Creates awkward pauses when calculations are conservative
- Overlap happens when durations don't match reality

**Event-driven approach benefits:**
- Triggered by actual completion of previous animation
- Each animation takes exactly as long as needed
- No pauses (next animation starts immediately after)
- No overlap (sequential execution is enforced by event chain)
- Much simpler logic to reason about

## Future Improvements
- Could parallelize columns instead of sequences if needed
- Could add easing curve variations per distance
- Could add spring physics if desired
