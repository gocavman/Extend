# Eye Blinking Debug - Troubleshooting Guide

**Status**: Debug output ENABLED  
**Purpose**: Find why blinking isn't working

---

## What to Look For in Console Output

When you run the game and stand idle for 10+ seconds, you should see console output like:

### Expected Sequence

1. **Eyes Disabled Check** (if applicable):
   ```
   👁️ BLINK: Eyes disabled, skipping blink check
   ```

2. **Blinking Debug Updates** (every frame while idle):
   ```
   👁️ BLINK DEBUG: timeSinceLastInteraction=0.1s, threshold=15.0s, isBlinking=false
   👁️ BLINK DEBUG: timeSinceLastInteraction=0.2s, threshold=15.0s, isBlinking=false
   ...continues until 15+ seconds...
   👁️ BLINK DEBUG: timeSinceLastInteraction=15.1s, threshold=15.0s, isBlinking=false
   ```

3. **Blink Triggered** (after 15 seconds):
   ```
   👁️ BLINK: Triggering blink after 15.1 seconds of inactivity
   ```

4. **Blink Ending** (after 0.25 seconds):
   ```
   👁️ BLINK: Ending blink, restoring eyes
   ```

---

## What Could Go Wrong

### Issue 1: Eyes Not Enabled
If you see:
```
👁️ BLINK: Eyes disabled, skipping blink check
```
**Solution**: Enable eyes in the appearance settings

### Issue 2: Timer Never Accumulates
If you see:
```
👁️ BLINK DEBUG: timeSinceLastInteraction=0.0s, threshold=15.0s, isBlinking=false
👁️ BLINK DEBUG: timeSinceLastInteraction=0.0s, threshold=15.0s, isBlinking=false
```
**Problem**: `lastInteractionTime` is being reset constantly  
**Solution**: Check if handleTouchMoved or something else is resetting it

### Issue 3: updateEyeBlinking Not Being Called
If you see NO debug output while idle  
**Problem**: The function isn't being called  
**Solution**: Check if idle state is being detected correctly

### Issue 4: Threshold Too High/Low
If timer keeps resetting after 10-15 seconds:
```
inactivityThreshold value in code
```
Currently set to 15.0 seconds

---

## How to Test

1. **Run the game**
2. **Enable eyes** in appearance if needed
3. **Stand idle** - don't move or perform actions
4. **Watch console** for debug output
5. **Wait 15+ seconds** (current threshold)
6. **Look for "Triggering blink" message**
7. **Observe character eyes close**

---

## Common Issues to Check

1. **Are eyes enabled?**
   - Check if `StickFigureAppearance.shared.eyesEnabled` is `true`

2. **Is character actually idle?**
   - Make sure not moving (`isMovingLeft`/`isMovingRight`)
   - Make sure not performing action (`currentStickFigure` is nil)
   - Make sure no active animation

3. **Is timer being reset?**
   - Check handleTouchMoved/handleTouchBegan
   - Check if something else resets `lastInteractionTime`

4. **Is threshold correct?**
   - Current: `inactivityThreshold = 15.0`
   - Adjust if needed

---

## Next Steps

Run the game with this debug output enabled and report:
1. What console messages you see
2. How long the timer counts up to
3. Whether you see the "Triggering blink" message
4. Any other relevant output

This will help identify exactly where the blinking breaks down.
