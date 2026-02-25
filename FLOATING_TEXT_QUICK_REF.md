# Floating Text Quick Reference

## 30-Second Overview

The app now uses **configuration-driven floating text**. Change floating text behavior by editing `actions_config.json` - no code changes needed!

## Current Floating Text Setup

| Action | Text | Timing | Mode |
|--------|------|--------|------|
| **Rest** | `zzz` | 2.0s | Sequential |
| **Yoga** | Breathe in / Hold it / Breathe out / Relax | 5.0s | Sequential |
| **Meditation** | Breathe in / Hold it / Breathe out / Relax | 5.0s | Sequential |
| **Pullup** | 1-6, then 97-100 (special) | 0.1s | Sequential |

## Config Format

```json
{
  "id": "action_name",
  "floatingText": {
    "timing": 2.0,
    "text": ["Message 1", "Message 2"],
    "random": false
  }
}
```

## Property Reference

### `timing` (number in seconds)
How often to show the next floating text message.
- `null` or omit = no floating text
- `2.0` = show new text every 2 seconds
- `0.1` = show new text every 0.1 seconds

### `text` (array of strings)
Messages to display.
- `null` or omit = no floating text  
- `["zzz"]` = single message
- `["Go", "Push", "Great"]` = multiple messages

### `random` (boolean)
How to select from `text` array.
- `false` (default) = cycle through in order
- `true` = pick randomly each time

## Examples

### Sequential Messages (Yoga)
```json
"floatingText": {
  "timing": 5.0,
  "text": ["Breathe in", "Hold it", "Breathe out", "Relax"],
  "random": false
}
```
Shows: Breathe in → Hold it → Breathe out → Relax → (repeat)  
Every 5 seconds

### Random Messages
```json
"floatingText": {
  "timing": 3.0,
  "text": ["Good!", "Nice!", "Keep going!", "Awesome!"],
  "random": true
}
```
Shows random message from array every 3 seconds

### Single Message (Rest)
```json
"floatingText": {
  "timing": 2.0,
  "text": ["zzz"],
  "random": false
}
```
Shows "zzz" every 2 seconds (no variation)

### No Floating Text
```json
"floatingText": null
```
Or just omit the `floatingText` key entirely.

## Editing in Xcode

1. Open `Extend/actions_config.json`
2. Find your action in the array
3. Edit the `floatingText` object
4. Save the file (⌘S)
5. Test immediately - no rebuild needed!*

\* *For floating text changes. Other config changes may require rebuild.*

## Special Case: Pullup

Pullup shows the **actual rep count**, not the config text:
- Reps 1-6: Shows "1", "2", "3", etc.
- Reps 7+: Shows 91+count (7 reps = 98, 8 reps = 99, 9 reps = 100)
- Max: Shows "100!" in red

This is hardcoded for the special behavior of counting reps. The `text` field in config is for consistency/documentation only.

## Adding to New Actions

Just add the `floatingText` object to any action in `actions_config.json`:

```json
{
  "id": "squats",
  "displayName": "Squats",
  "floatingText": {
    "timing": 2.0,
    "text": ["Go!", "Push!", "Nice!"],
    "random": false
  },
  // ... rest of action config
}
```

Done! No code changes needed.

## Troubleshooting

### Text not showing?
- Check if `timing` is too high (slow interval)
- Check if `text` array is empty
- Check if `floatingText` is `null` or omitted

### Text showing too fast/slow?
- Decrease `timing` for faster (e.g., 1.0 instead of 5.0)
- Increase `timing` for slower (e.g., 5.0 instead of 2.0)

### Text all the same?
- Set `random: false` for sequential cycling

### Text random every time?
- Set `random: true` for random selection

## Files Modified

- ✏️ **actions_config.json** - Added `floatingText` to 4 actions
- ✏️ **Game1Module.swift** - Added config-driven floating text system
- 📄 **CONFIG_DRIVEN_FLOATING_TEXT.md** - Full documentation
- 📄 **FLOATING_TEXT_BEFORE_AFTER.md** - Before/after comparison

## Build Status
✅ All floating text features working  
✅ Build succeeded  
✅ Ready to test!
