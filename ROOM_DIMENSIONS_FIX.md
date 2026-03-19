# Room Dimensions Fix - rooms.json Integration

## Problem
The `width` and `height` properties in `rooms.json` were being loaded but not actually used by MapScene. The map dimensions were hardcoded as constants (2000 x 2000).

## Solution
Modified `MapScene.swift` to dynamically load room dimensions from the room configuration:

### Changes Made

#### 1. Changed Constants to Variables (MapScene.swift, lines 16-23)

**Before:**
```swift
private let MAP_WIDTH: CGFloat = 2000
private let MAP_HEIGHT: CGFloat = 2000
private let VISIBLE_AREA_WIDTH: CGFloat = 500
private let VISIBLE_AREA_HEIGHT: CGFloat = 500
```

**After:**
```swift
private var MAP_WIDTH: CGFloat = 2000  // Will be set from room config
private var MAP_HEIGHT: CGFloat = 2000  // Will be set from room config
private var VISIBLE_AREA_WIDTH: CGFloat { MAP_WIDTH / 4 }  // Quarter of room width
private var VISIBLE_AREA_HEIGHT: CGFloat { MAP_HEIGHT / 4 }  // Quarter of room height
```

**Why:** 
- Changed from `let` (constants) to `var` (variables) so dimensions can be updated at runtime
- Made `VISIBLE_AREA_WIDTH` and `VISIBLE_AREA_HEIGHT` computed properties that scale with room size
- This ensures the camera shows an appropriate viewport for rooms of any size

#### 2. Load Room Config in didMove (MapScene.swift, lines 39-46)

**Added:**
```swift
// Load room dimensions from config
if let roomConfig = getRoomConfig(currentRoomId) {
    MAP_WIDTH = CGFloat(roomConfig.width)
    MAP_HEIGHT = CGFloat(roomConfig.height)
    print("🗺️ Room '\(roomConfig.name)' dimensions: \(MAP_WIDTH) x \(MAP_HEIGHT)")
}
```

**Why:** 
- When MapScene loads, it reads the room configuration from rooms.json
- Sets MAP_WIDTH and MAP_HEIGHT to the values defined in the JSON
- Logs the room name and dimensions for debugging

## Impact

### For existing rooms.json:
```json
{
  "id": "main_map",
  "name": "Main Training Area",
  "width": 2000,
  "height": 2000,
  "backgroundImage": "map_bg",
  "levels": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  "doors": ["door_to_training_room_1"]
}
```

The map will now correctly be 2000x2000 pixels.

### For the training room:
```json
{
  "id": "training_room_1",
  "name": "Advanced Training Room",
  "width": 1000,
  "height": 1000,
  "backgroundImage": "training_room_1_bg",
  "levels": [],
  "doors": ["door_to_main_map_from_training_1"]
}
```

The map will now correctly be 1000x1000 pixels, and the camera viewport will scale proportionally.

## Testing
- Build succeeds with no errors
- The dimensions are logged when each room loads
- Can verify by checking console output when entering different rooms
- Different room sizes are now properly reflected in gameplay

## Future Enhancements
- Consider adding a debugDraw option to show room boundaries
- Room dimension validation in rooms.json loading
- Performance optimization for very large rooms
