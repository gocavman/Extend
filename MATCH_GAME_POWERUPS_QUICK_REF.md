# Match Game Power-ups - Quick Reference

## Power-Up Types

| Power-up | Symbol | Color | Created By | Effect |
|----------|--------|-------|-----------|--------|
| **Vertical Arrow** | ↕️ | Gold | 5+ vertical match | Clears entire column |
| **Horizontal Arrow** | ↔️ | Gold | 5+ horizontal match | Clears entire row |
| **Bomb** | 💣 | Red | 2×2 square | Clears 3×3 area |

---

## How to Create Power-ups

### Vertical Arrow (↕️)
```
Match 5+ pieces vertically:

Before:          After:
🍎               (empty)
🍎               (empty)
🍎       ══→     ↕️  ← Arrow here
🍎               (empty)
🍎               (empty)
```

### Horizontal Arrow (↔️)
```
Match 5+ pieces horizontally:

Before:          After:
🍎 🍎 🍎 🍎 🍎   (empty) ↔️ (empty) ↔️ (empty)
                   Arrow at middle position
```

### Bomb (💣)
```
Match 2×2 square:

Before:          After:
🍎 🍎            (empty) (empty)
🍎 🍎     ══→    (empty) 💣 ← Bomb
                   (at center of 2×2)
```

---

## Power-up Effects

### Vertical Arrow (↕️) - Clears Column
- Tap the arrow piece
- **Effect**: Entire vertical column clears
- **Score**: +50 per cleared piece
- **Haptic**: Medium feedback

### Horizontal Arrow (↔️) - Clears Row
- Tap the arrow piece
- **Effect**: Entire horizontal row clears
- **Score**: +50 per cleared piece
- **Haptic**: Medium feedback

### Bomb (💣) - Clears 3×3 Area
- Tap the bomb piece
- **Effect**: All pieces in 3×3 area around bomb clear
- **Score**: +75 per cleared piece
- **Haptic**: Medium feedback

---

## Power-up Combinations

### Arrow + Arrow = Row + Column Clear
```
Move a vertical arrow (↕️) on top of horizontal arrow (↔️)
        ↓
Clears entire row + entire column
        ↓
Score: +50 per piece cleared
Haptic: Heavy feedback
```

### Bomb + Bomb = Screen Clear
```
Move one bomb (💣) on top of another bomb (💣)
        ↓
Entire grid clears!
        ↓
Score: +100 per piece cleared
Haptic: Extra heavy feedback
```

---

## Scoring

| Action | Points per Piece |
|--------|------------------|
| Normal 3-4 match | +100 |
| Vertical arrow clear | +50 |
| Horizontal arrow clear | +50 |
| Bomb clear (3×3) | +75 |
| Arrow combo (row+col) | +50 |
| Screen clear (bombs) | +100 |

---

## Gameplay Tips

### Maximize Score
1. Create 5+ matches to get arrows ↕️↔️
2. Combine arrows for big clears
3. Build 2×2 squares for bombs 💣
4. Merge bombs for maximum impact

### Strategic Play
- **Early game**: Build up power-ups
- **Mid game**: Create combinations
- **Late game**: Set up bomb merges
- **Watch cascades**: Matches create new matches!

### Combo Chain
```
Clear with arrow → Creates new matches
                 → Check for new power-ups
                 → More matches → More power-ups
                 → Chain reaction!
```

---

## Visual Guide

### Grid with Power-ups
```
🍎 ↕️ 🍊
🍌 💣 🍓
↔️ 🍉 🍇
```

**Gold cells** = Arrows (premium)  
**Red cells** = Bombs (explosive)  
**Colored cells** = Normal pieces  

---

## Haptic Feedback

- ✅ **Heavy vibration** → Pieces clear (match)
- ✅ **Medium vibration** → Power-up activates
- ✅ **Extra heavy** → Screen clears (bomb combo)

---

## What NOT to Do

❌ Don't waste moves on normal matches when you could build power-ups  
❌ Don't activate arrows until you need them (save for strategic moments)  
❌ Don't forget bombs can chain (bomb + bomb = whole screen!)  

---

## Cascading Matches

After clearing pieces:
1. Remaining pieces fall (gravity)
2. New pieces drop from top
3. Check for new matches automatically
4. Can create power-ups mid-cascade!

---

## Configuration (matchgame.json)

**No special config needed!** Power-ups work with any level:
- Any items can create power-ups
- Grid shapes supported
- Colors from config used
- Difficulty unaffected

---

**Status**: ✨ POWER-UP SYSTEM READY

