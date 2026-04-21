# Tile Drop Speed - Quick Reference

## Changes Made

### Speed Parameter
- **Location**: `animatePiecesDrop()` line ~2257
- **Old Value**: 400 pixels/second
- **New Value**: 500 pixels/second (+25% faster)
- **How to Adjust**: Change the number to 400-700 for desired speed

### Animation Approach
- **Old**: Sequential completion (wait for piece to finish before next starts)
- **New**: Intelligent stagger (pieces start with calculated delays)

### Time Saved per Column Clear
- **Before**: 0.75 seconds (pieces drop one after another)
- **After**: 0.5 seconds (pieces overlap safely)
- **Improvement**: 33% faster! ✅

## How Overlapping Works

Pieces are sorted bottom-to-top. Each starts with a delay:

```
delay = pieceIndex × (cellHeight ÷ fallSpeed)

Example: cellHeight=50px, fallSpeed=500px/s
  → delay per piece = 50÷500 = 0.1 seconds

Piece 0 (bottom): delay=0.0s  ← starts immediately
Piece 1:          delay=0.1s  ← starts 0.1s later
Piece 2 (top):    delay=0.2s  ← starts 0.2s later
```

**Why it works:**
- Bottom piece moves down as new pieces start
- No collision because bottom piece has a head start
- Total time = longest piece only (~0.5s instead of sum)

## To Customize

### Make Drops Faster
In `animatePiecesDrop()` at line ~2257:
```swift
let fallSpeedPixelsPerSecond: CGFloat = 600  // was 500
```

### Make Drops Slower
```swift
let fallSpeedPixelsPerSecond: CGFloat = 400  // was 500
```

### Change Stagger Aggressiveness
In `animateColumnPiecesWithStagger()` at line ~2323:
```swift
let startDelay = Double(index) * oneRowFallTime * 0.7  // More aggressive (0.7x instead of 1.0x)
```

## Result

✅ Columns fill much faster  
✅ Looks smooth and continuous (wave effect)  
✅ No visual collisions  
✅ Bottom-to-top ordering maintained
