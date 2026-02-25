# Animation Integration Guide
## How to Use Your 2D Stick Figure Animations in Gameplay

**Date:** February 24, 2026

---

## Overview

The game now automatically uses your saved frames from the 2D Stick Figure Editor! When you save frames with specific animation names, they'll automatically appear in gameplay.

---

## ✅ Step-by-Step Process

### 1. Create Animations in 2D Stick Figure Editor

Open the 2D Stick Figure Editor and create frames for each animation:

#### **Required Animations (Already Working):**

**Stand** - Frame 1
- Your basic standing pose
- Used when character is idle
- This is what you see when not moving/performing actions

**Move** - Frames 1-4
- Walking/running cycle
- Frame 1: Left leg forward
- Frame 2: Mid-stride
- Frame 3: Right leg forward
- Frame 4: Mid-stride back
- Used when character moves left/right

#### **Actions to Create:**

**Rest** - Frame 1
- Resting/idle pose (can be same as Stand or different)
- Level 1 action

**Jump** - Frames 1-3
- Frame 1: Crouch down
- Frame 2: Mid-air jump
- Frame 3: Landing

**Jumping Jacks** - Frames 1-4
- Frame 1: Starting position
- Frame 2: Arms up, legs out
- Frame 3: Arms down, legs together
- Frame 4: Return to start

**Yoga** - Frames 1-4
- Frame 1: Starting yoga pose
- Frame 2: Transitional pose
- Frame 3: Holding pose
- Frame 4: Final pose

**Bicep Curls** - Frames 1-4
- Frame 1: Arms down
- Frame 2: Curling up
- Frame 3: Arms fully curled
- Frame 4: Returning down

**Kettlebell Swings** - Frames 1-4
- Frame 1: Starting position
- Frame 2: Swing back
- Frame 3: Swing forward high
- Frame 4: Return

**Push Ups** - Frames 1-4
- Frame 1: Plank position (up)
- Frame 2: Lowering
- Frame 3: Bottom position
- Frame 4: Pushing up

---

### 2. Save Your Frames with Exact Names

**IMPORTANT:** Animation names MUST match exactly (case-sensitive):
- "Stand" (for standing)
- "Move" (for walking/running)
- "Rest" (for rest action)
- "Jump" (for jump action)
- "Jumping Jacks" (for jumping jacks)
- "Yoga" (for yoga)
- "Bicep Curls" (for bicep curls)
- "Kettlebell Swings" (for kettlebell)
- "Push Ups" (for push ups)

**Frame Numbers:**
- Use sequential frame numbers: 1, 2, 3, 4
- The game will play them in order

**Saving Process:**
1. Pose your stick figure
2. Click "Save Frame"
3. Enter the animation name (e.g., "Move")
4. Enter the frame number (e.g., "1")
5. Save
6. Repeat for all frames in the animation

---

### 3. Frames Automatically Load in Gameplay

The game loads your saved frames automatically when:
- The gameplay screen appears (loads Stand and Move frames)
- You perform an action (loads that action's frames)

**How It Works:**
- Stand and Move frames load immediately
- When you tap to perform an action (e.g., "Rest"), it loads those frames
- The animation plays through your frames in sequence
- After completion, returns to Stand pose

---

## 🎮 Testing Your Animations

### Quick Test Process:
1. Create frames in 2D Stick Figure Editor
2. Save them with correct names and frame numbers
3. Go to Game 1 (gameplay area)
4. Your character will use your frames!
5. Move left/right to see Move animation
6. Tap actions to see your custom animations

### Fallback System:
If frames aren't found, the game falls back to the old images. This means:
- You can gradually replace animations
- Game still works if frames are missing
- No errors if you haven't created all animations yet

---

## 🔧 Technical Details

### Animation System:

**ActionConfig Structure:**
Each action in the game has a `stickFigureAnimation` property that defines:
- `animationName`: The name to look for in saved frames
- `frameNumbers`: Which frame numbers to use (e.g., [1, 2, 3, 4])
- `baseFrameInterval`: Time between frames (speed)

**Frame Loading:**
```swift
StickFigureAnimationConfig(
    animationName: "Move",
    frameNumbers: [1, 2, 3, 4],
    baseFrameInterval: 0.15
)
```

**Storage:**
- Frames are saved in UserDefaults under key: `"saved_frames_2d"`
- Loaded as `[AnimationFrame]` array
- Matched by `name` and `frameNumber`

### Rendering:
- Game uses `StickFigure2DView` to render your frames
- Canvas size: 100×150 (scaled to fit gameplay)
- Supports horizontal flipping for left/right facing
- Coordinates are preserved from your editor

---

## 📝 Current Animation Mappings

| Action | Animation Name | Frames | Status |
|--------|---------------|--------|--------|
| Standing | "Stand" | 1 | ✅ Ready |
| Moving | "Move" | 1-4 | ✅ Ready |
| Rest | "Rest" | 1 | 🔨 Create in Editor |
| Jump | "Jump" | 1-3 | 🔨 Create in Editor |
| Jumping Jacks | "Jumping Jacks" | 1-4 | 🔨 Create in Editor |
| Yoga | "Yoga" | 1-4 | 🔨 Create in Editor |
| Bicep Curls | "Bicep Curls" | 1-4 | 🔨 Create in Editor |
| Kettlebell | "Kettlebell Swings" | 1-4 | 🔨 Create in Editor |
| Push Ups | "Push Ups" | 1-4 | 🔨 Create in Editor |

---

## 💡 Tips for Creating Animations

### Frame Count:
- **Simple actions:** 1-2 frames (Stand, Rest)
- **Loops:** 4 frames works well for repeating cycles
- **Complex:** 4-8 frames for detailed animations

### Timing:
- Fast actions: 0.15-0.2s per frame (Run, Jumping Jacks)
- Medium actions: 0.4s per frame (Curls, Push Ups)
- Slow actions: 2.0s per frame (Yoga, Meditation)

### Poses:
- Use extreme poses for clarity (fully extended/contracted)
- Make sure figure is centered vertically in canvas
- Test at 100% and 200% scale to ensure it looks good
- Use the orange waist dot to reposition if needed

### Testing:
1. Save frames with exact animation names
2. Go to Game 1
3. Move around to test Move animation
4. Select and perform actions to test each one
5. Adjust poses in editor as needed
6. Re-save frames (replaces old versions)
7. Restart game to reload new frames

---

## 🚀 Quick Start Checklist

- [ ] Create "Stand" frame 1 (idle pose)
- [ ] Create "Move" frames 1-4 (walking cycle)
- [ ] Create "Rest" frame 1 (resting pose)
- [ ] Create "Jump" frames 1-3 (jump sequence)
- [ ] Create "Jumping Jacks" frames 1-4 (jumping jack cycle)
- [ ] Create "Yoga" frames 1-4 (yoga sequence)
- [ ] Create "Bicep Curls" frames 1-4 (curl cycle)
- [ ] Create "Kettlebell Swings" frames 1-4 (swing cycle)
- [ ] Create "Push Ups" frames 1-4 (pushup cycle)
- [ ] Test each animation in Game 1
- [ ] Adjust and re-save as needed

---

## 🎨 Advanced: Creating Additional Animations

To add new animations in the future:

1. **Create frames in 2D editor** with a new animation name
2. **Update Game1Module.swift:**
   - Add new `ActionConfig` with `stickFigureAnimation`
   - Define the animation name and frame numbers
   - Set timing and unlock level

Example:
```swift
ActionConfig(
    id: "custom_action",
    displayName: "Custom Action",
    unlockLevel: 11,
    pointsPerCompletion: 11,
    animationFrames: [1, 2, 3, 4],
    baseFrameInterval: 0.3,
    variableTiming: nil,
    flipMode: .none,
    supportsSpeedBoost: true,
    imagePrefix: "custom", // Fallback only
    allowMovement: true,
    stickFigureAnimation: StickFigureAnimationConfig(
        animationName: "Custom Action",
        frameNumbers: [1, 2, 3, 4],
        baseFrameInterval: 0.3
    )
)
```

---

## ✨ Benefits of This System

✅ **No image assets needed** - Just save frames in editor
✅ **Easy to update** - Change pose, re-save, done!
✅ **Consistent coordinates** - Positions preserved from editor
✅ **Full customization** - Colors, sizes, angles all editable
✅ **Quick iteration** - Edit and test immediately
✅ **Scalable** - Easy to add new animations
✅ **Version control friendly** - Frames saved as data, not images

---

## 🔍 Troubleshooting

**Animation not showing?**
- Check animation name matches exactly (case-sensitive)
- Verify frame numbers are correct (1, 2, 3, 4)
- Make sure frames are saved (check in "Open Frame")
- Restart the game to reload frames

**Figure looks wrong?**
- Check centering in editor (should be centered in canvas)
- Verify scale is reasonable (100-200% works well)
- Ensure waist position is around (300, 360)

**Animation too fast/slow?**
- Frame timing is controlled in ACTION_CONFIGS
- Edit baseFrameInterval in Game1Module.swift
- Smaller = faster, larger = slower

---

## 📋 Summary

**What You Need to Do:**
1. Open 2D Stick Figure Editor
2. Create frames for each animation (use exact names above)
3. Save frames with correct numbers
4. Play the game - animations work automatically!

**What the System Does:**
- Loads frames when game starts
- Renders them in real-time during gameplay
- Cycles through frames based on timing
- Handles flipping for left/right facing
- Falls back to images if frames not found

That's it! Create your frames and they'll work automatically in the game. 🎉
