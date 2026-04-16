# Match Game - Quick Reference

## Quick Start

1. **Access Match Game**: Enter the "Match Challenge" room from the main map (bottom-right door)
2. **Play**: Tap a piece, then tap an adjacent piece to swap
3. **Make Matches**: Get 3+ of the same item and color in a row or column
4. **Score**: +100 per matched piece
5. **Exit**: Tap ✕ button (top-left) to return to map

---

## Key Features

| Feature | Details |
|---------|---------|
| **Grid Shapes** | Configurable per level (L-shape, cross, diamond, etc.) |
| **Items** | Emojis or assets (currently 6 types: 🍎🍌🍊🍇🍉🍓) |
| **Colors** | Each item can be multiple colors (red, yellow, orange, etc.) |
| **Moves** | Limited per level (20-40) |
| **Score Target** | Goal to reach before running out of moves |
| **High Score** | Global high score saved automatically |
| **Gravity** | Pieces fall after matches cleared |
| **Cascades** | Multiple matches processed in succession |

---

## File Locations

| File | Purpose |
|------|---------|
| `matchgame.json` | Level configs (items, colors, grids, targets) |
| `MatchGameViewController.swift` | Game UI and logic |
| `rooms.json` | Room definition with `matchGame: true` |
| `doors.json` | Door configuration for entry/exit |
| `Game1Module.swift` | RoomConfig struct with matchGame property |
| `MapScene.swift` | Room entry detection and launcher |

---

## How to Add a Level

### Edit matchgame.json:
1. Add new level object to `levels` array
2. Set unique `id` and descriptive `name`
3. Define `gridWidth` and `gridHeight`
4. Create `gridShape` array (X=playable, _=blocked)
5. Configure `items` (id, emoji, asset)
6. Set `colors` (hex codes)
7. Set `movesAllowed` and `scoreTarget`

### Example:
```json
{
  "id": 6,
  "name": "Level 6 - Advanced",
  "gridWidth": 8,
  "gridHeight": 8,
  "items": [
    {"id": "apple", "emoji": "🍎", "asset": null},
    {"id": "banana", "emoji": "🍌", "asset": null}
  ],
  "colors": ["#FF0000", "#FFFF00"],
  "gridShape": ["XXXXXXXX", "XXXXXXXX", ...],
  "movesAllowed": 50,
  "scoreTarget": 4000
}
```

---

## Game Mechanics

### Match Detection
- ✅ 3+ same item AND same color in horizontal row
- ✅ 3+ same item AND same color in vertical column

### Scoring
- ✅ +100 points per piece matched
- ✅ Cascading matches add up

### Moves
- ✅ Each piece swap costs 1 move
- ✅ Game over when moves reach 0

### Grid Shapes
- ✅ "X" = playable cell
- ✅ "_" = blocked/inaccessible cell

---

## High Score Storage

**Stored in**: `UserDefaults` under key `"matchGameHighScore"`  
**Scope**: Global (one high score for entire game)  
**Persistence**: Survives app restart  
**Updated**: Automatically when exiting if score > current high score

---

## UI Layout

```
┌─────────────────────────────────┐
│ ✕  Level 1    Score: 500        │
│    Moves: 15   High Score: 2000 │
│    Target: 1000                 │
├─────────────────────────────────┤
│                                 │
│      🍎🍌🍊🍎🍌                  │
│      🍊🍎🍌🍊🍎                  │
│      🍌🍊🍎🍌🍊                  │
│      🍎🍌🍊🍎🍌                  │
│      🍊🍎🍌🍊🍎                  │
│                                 │
└─────────────────────────────────┘
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Game won't launch | Check that door is configured in doors.json |
| High score not saving | Verify UserDefaults key is `"matchGameHighScore"` |
| Pieces not matching | Ensure item ID AND color match exactly |
| Gravity not working | Check that pieces have valid row/col after removal |
| Grid looks wrong | Verify gridShape string lengths match gridWidth |

---

## Configuration Files Summary

### matchgame.json Structure
```
levels: [
  {
    id, name, gridWidth, gridHeight,
    items: [{id, emoji, asset}],
    colors: [hex strings],
    gridShape: [string pattern],
    movesAllowed, scoreTarget
  }
]
```

### rooms.json (Match Challenge room)
```
{
  "id": "match_challenge",
  "name": "Match Challenge",
  "matchGame": true,
  "doors": ["door_to_main_map_from_match"],
  ...
}
```

### doors.json (Match Challenge doors)
```
[
  {
    "id": "door_to_match_challenge",
    "destinationRoomId": "match_challenge",
    "returnDoorId": "door_to_main_map_from_match"
  },
  {
    "id": "door_to_main_map_from_match",
    "destinationRoomId": "main_map",
    "returnDoorId": "door_to_match_challenge"
  }
]
```

---

**Status**: ✅ READY TO PLAY

