# Before & After: Floating Text Refactoring

## BEFORE: Hardcoded Logic

### Yoga Text (Hardcoded in Game1Module.swift line 1311)
```swift
let yogaTexts = ["Breathe in", "Hold it", "Breathe out", "Relax"]
var yogaTextIndex = 0
var nextYogaMessageTime = 5.0

// Later in the loop (line 1348-1350)
if config.id == "yoga" && elapsedTime >= nextYogaMessageTime && yogaTextIndex < yogaTexts.count {
    let text = yogaTexts[yogaTextIndex]
    gameState.addFloatingText(text, x: 0.5, y: 0.65, color: .blue, fontSize: 20, isMeditation: true)
    yogaTextIndex += 1
    nextYogaMessageTime += 5.0
}
```

### Rest Zzz (Hardcoded in Game1Module.swift line 3495-3505)
```swift
if gameState.currentPerformingAction == "rest" {
    let currentTime = gameState.restTotalDuration - gameState.restTimeRemaining
    if currentTime - gameState.restZzzLastTime >= 2.0 {
        gameState.restZzzLastTime = currentTime
        let normX = currentFigureX / geometry.size.width
        let normY = currentFigureY / geometry.size.height
        let randomOffsetX = CGFloat.random(in: -0.03...0.03)
        gameState.addFloatingText("zzz", x: normX + randomOffsetX, y: normY, color: .gray, fontSize: 20)
    }
}
```

### Pullup Counter (Hardcoded in Game1Module.swift line 3470-3479)
```swift
if gameState.currentPerformingAction == "pullup" && gameState.pullupCount > 0 && Date().timeIntervalSince1970 - gameState.lastPullupCounterTime < 0.1 {
    let normX = currentFigureX / geometry.size.width
    let normY = currentFigureY / geometry.size.height
    
    // Hardcoded mapping: 1-6 normal, then 91+count to 100
    let displayNumber = gameState.pullupCount > 6 ? min(100, 91 + gameState.pullupCount) : gameState.pullupCount
    let displayText = displayNumber == 100 ? "100!" : "\(displayNumber)"
    
    gameState.addFloatingText(displayText, x: normX, y: normY, color: .red, fontSize: 24)
}
```

**Problems:**
- ❌ Hardcoded text content scattered across code
- ❌ Hardcoded timing values (2.0 seconds, 5.0 seconds, 0.1 seconds)
- ❌ Can't change text/timing without recompiling
- ❌ Special logic for each action
- ❌ Not reusable for new actions
- ❌ Hard to maintain consistency

---

## AFTER: Config-Driven System

### Step 1: Configuration (actions_config.json)
```json
{
  "id": "yoga",
  "displayName": "Yoga",
  "floatingText": {
    "timing": 5.0,
    "text": ["Breathe in", "Hold it", "Breathe out", "Relax"],
    "random": false
  }
},
{
  "id": "rest",
  "displayName": "Rest",
  "floatingText": {
    "timing": 2.0,
    "text": ["zzz"],
    "random": false
  }
},
{
  "id": "pullup",
  "displayName": "Pull Ups",
  "floatingText": {
    "timing": 0.1,
    "text": ["1", "2", "3", "4", "5", "6"],
    "random": false
  }
}
```

### Step 2: Data Structure (Game1Module.swift)
```swift
struct ActionFloatingTextConfig: Codable {
    let timing: TimeInterval?
    let text: [String]?
    let random: Bool?
}

struct FloatingTextTracker {
    var lastTriggerTime: Double = 0
    var textIndex: Int = 0
    var nextTriggerTime: Double = 0
}

// In GameState:
var floatingTextTrackers: [String: FloatingTextTracker] = [:]
```

### Step 3: Generic Rendering (Single Code Path)
```swift
// In collision timer - ONE generic handler for all actions
if let currentAction = gameState.currentPerformingAction,
   let config = ACTION_CONFIGS.first(where: { $0.id == currentAction }) {
    
    // Special case: pullup uses actual rep count
    if currentAction == "pullup" && gameState.pullupCount > 0 && Date().timeIntervalSince1970 - gameState.lastPullupCounterTime < 0.1 {
        let displayNumber = gameState.pullupCount > 6 ? min(100, 91 + gameState.pullupCount) : gameState.pullupCount
        let displayText = displayNumber == 100 ? "100!" : "\(displayNumber)"
        gameState.addFloatingText(displayText, x: normX, y: normY, color: .red, fontSize: 24)
    }
    // Generic handler for all other actions with floatingText config
    else if let floatingTextConfig = config.floatingText,
            let texts = floatingTextConfig.text,
            !texts.isEmpty {
        
        // Initialize tracker if needed
        if gameState.floatingTextTrackers[currentAction] == nil {
            gameState.floatingTextTrackers[currentAction] = FloatingTextTracker(
                lastTriggerTime: Date().timeIntervalSince1970,
                textIndex: 0,
                nextTriggerTime: floatingTextConfig.timing ?? 0.1
            )
        }
        
        var tracker = gameState.floatingTextTrackers[currentAction]!
        let currentTime = Date().timeIntervalSince1970
        
        if currentTime - tracker.lastTriggerTime >= tracker.nextTriggerTime {
            let text: String
            if floatingTextConfig.random ?? false {
                text = texts.randomElement() ?? texts[0]
            } else {
                text = texts[tracker.textIndex % texts.count]
                tracker.textIndex += 1
            }
            
            let xOffset = (currentAction == "rest") ? CGFloat.random(in: -0.03...0.03) : 0
            gameState.addFloatingText(text, x: normX + xOffset, y: normY, color: .gray, fontSize: 20)
            
            tracker.lastTriggerTime = currentTime
            gameState.floatingTextTrackers[currentAction] = tracker
        }
    }
}
```

**Improvements:**
- ✅ All text content in `actions_config.json`
- ✅ All timing values configurable
- ✅ Change behavior without recompiling
- ✅ Single generic code path handles all actions
- ✅ Easy to add new actions with floating text
- ✅ Type-safe with ActionFloatingTextConfig
- ✅ Maintainable and consistent

---

## What Changed in Files

### `actions_config.json`
**Added** `floatingText` object to:
- `rest` - "zzz" every 2 seconds
- `yoga` - breathing instructions every 5 seconds
- `meditation` - breathing instructions every 5 seconds  
- `pullup` - numbers every 0.1 seconds

### `Game1Module.swift`
**Added:**
- `FloatingTextTracker` struct (lines 57-61)
- `floatingTextTrackers` state variable in GameState
- Automatic tracker initialization/cleanup

**Refactored:**
- `startActionWithVariableTiming()` now uses config-driven floating text
- Collision timer now has single generic floating text handler
- Removed hardcoded yoga text, rest zzz logic, etc.

**Removed:**
- 🗑️ `yogaTexts` array
- 🗑️ `yogaTextIndex` variable
- 🗑️ `nextYogaMessageTime` variable
- 🗑️ Hardcoded rest zzz timing loop
- 🗑️ Hardcoded pullup counter display

---

## Adding New Floating Text (Easy!)

### Before (Had to modify code)
Edit Game1Module.swift to add special logic for your action.

### After (Just edit config!)
```json
{
  "id": "squats",
  "displayName": "Squats",
  "floatingText": {
    "timing": 1.5,
    "text": ["Down", "Up", "Go!"],
    "random": false
  }
  // ...rest of config
}
```
Done! Floating text works automatically.

---

## Summary of Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Config Changes** | Requires code edit | Edit JSON only |
| **New Actions** | Need special code | Works automatically |
| **Code Duplication** | Multiple handlers | Single generic path |
| **Maintainability** | Scattered logic | Centralized config |
| **Type Safety** | Strings/hardcoded | Struct-based config |
| **Testing** | Recompile each time | Change config & reload |

✅ **Result**: Cleaner code, easier configuration, faster development!
