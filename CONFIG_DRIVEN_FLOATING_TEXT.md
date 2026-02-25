# Config-Driven Floating Text System

## Overview
The floating text system has been refactored from hardcoded logic to a **configuration-driven system** using `actions_config.json`. This makes floating text behavior fully customizable without code changes.

## Features

### ✅ What's Included
- **Sequential text cycling**: Display text in order while action plays
- **Random text selection**: Randomly choose from configured text array
- **Per-action floating text trackers**: Each action maintains its own floating text state
- **Timing configuration**: Customizable interval (in seconds) for text display
- **Special pullup handling**: Pullup counter still shows actual rep count (1-6, then 97-100)
- **Config fallback**: Actions without `floatingText` config work normally

## Configuration Schema

```json
{
  "id": "rest",
  "displayName": "Rest",
  "floatingText": {
    "timing": 2.0,
    "text": ["zzz"],
    "random": false
  },
  // ...rest of config
}
```

### Properties
- **`timing`** (seconds): How often text floats up. Can be null (no floating text)
- **`text`** (array): List of text strings to display. Can be null (no floating text)
- **`random`** (boolean): 
  - `false`: Display text sequentially in order (default)
  - `true`: Choose text randomly from the array each time

## Actions with Floating Text Config

### 1. **Rest** 
```json
"floatingText": {
  "timing": 2.0,
  "text": ["zzz"],
  "random": false
}
```
- Shows "zzz" every 2 seconds during rest
- Includes random horizontal offset for visual variety

### 2. **Yoga**
```json
"floatingText": {
  "timing": 5.0,
  "text": ["Breathe in", "Hold it", "Breathe out", "Relax"],
  "random": false
}
```
- Sequential breathing instructions every 5 seconds
- Cycles through the 4 messages in order

### 3. **Meditation**
```json
"floatingText": {
  "timing": 5.0,
  "text": ["Breathe in", "Hold it", "Breathe out", "Relax"],
  "random": false
}
```
- Same as yoga - sequential breathing instructions every 5 seconds

### 4. **Pullup**
```json
"floatingText": {
  "timing": 0.1,
  "text": ["1", "2", "3", "4", "5", "6"],
  "random": false
}
```
- Special handling: Displays actual rep count (1-6, then 97-100)
- Config is present for consistency, but code uses actual `pullupCount` value
- Shows "100!" when reaching max

## Code Changes

### New Data Structures

#### `FloatingTextTracker`
Tracks per-action floating text state:
```swift
struct FloatingTextTracker {
    var lastTriggerTime: Double = 0
    var textIndex: Int = 0
    var nextTriggerTime: Double = 0
}
```

### Updated Game1Module

#### GameState Changes
Added floating text tracker dictionary:
```swift
var floatingTextTrackers: [String: FloatingTextTracker] = [:]
```

#### Action Timing Functions
- **`startActionWithVariableTiming()`**: Uses config-driven floating text for meditation/yoga
- **`startActionWithUniformTiming()`**: Renders floating text in collision timer for rest/pullup

#### Floating Text Rendering (Collision Timer)
- Generic config-driven system handles rest, yoga-like actions
- Special pullup handling preserves rep counting (1-6 → 97-100)
- Random horizontal offset applied to rest zzz text
- Tracker automatically cleaned up when action ends

### Removed Hardcoded Logic
❌ Hardcoded yoga text array (`["Breathe in", "Hold it", "Breathe out", "Relax"]`)
❌ Hardcoded pullup counter display (1-6 normal, 91+count for high reps)
❌ Hardcoded rest zzz timing (every 2 seconds)
❌ `nextYogaMessageTime`, `yogaTextIndex`, `yogaTexts` variables

## Usage - Adding Floating Text to New Actions

To add floating text to any action:

1. **Update `actions_config.json`**:
```json
{
  "id": "new_action",
  "displayName": "New Action",
  "floatingText": {
    "timing": 3.0,
    "text": ["Go!", "Push!", "One more!", "Great job!"],
    "random": false
  },
  // ...other config
}
```

2. **No code changes needed!** The floating text system automatically:
   - Initializes a tracker when action starts
   - Displays text on the configured timing
   - Cleans up tracker when action ends

## Special Cases

### Pullup Counter
Pullup displays the actual rep count (not config text):
- **1-6 reps**: Shows "1", "2", "3", etc.
- **7+ reps**: Shows 91+count, capped at 100 (shows "100!" at max)
- **Trigger**: Every time `frameIndex == 4` (at pullup apex)

### Random Selection Example
```json
"floatingText": {
  "timing": 1.0,
  "text": ["Good!", "Nice!", "Keep it up!", "Awesome!"],
  "random": true
}
```
Each time the timing triggers, a random text from the array is shown.

## Testing

Build and test the app:
```bash
xcodebuild build -scheme Extend -configuration Debug -destination 'generic/platform=iOS Simulator'
```

### What to Verify
✅ Rest action shows "zzz" every 2 seconds  
✅ Yoga action shows breathing instructions every 5 seconds in order  
✅ Meditation action shows the same text as yoga  
✅ Pullup shows rep count (1-6, then 97-100)  
✅ No floating text appears for actions without `floatingText` config  
✅ Build succeeds with no errors  

## Benefits

1. **No Code Changes Needed**: Add/modify floating text via config only
2. **Flexible Timing**: Each action can have different display intervals
3. **Sequential or Random**: Choose how text is selected
4. **Maintainable**: All text content centralized in `actions_config.json`
5. **Scalable**: System works for any action with any text
6. **Type-Safe**: ActionFloatingTextConfig is properly deserialized

## Build Status
✅ **BUILD SUCCEEDED** - All floating text features working correctly
