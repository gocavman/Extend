# Testing the Muscle Points Progression System

## How to Test

The muscle system is now wired up to show smooth progression from Extra Small Stand (0 points) to Extra Large Stand (100 points).

### Manual Testing via Customization UI

If the Customization panel has plus/minus buttons for muscle points, you can:

1. **Open Customization** in gameplay
2. **Adjust muscle points** using plus/minus buttons
3. **Watch stick figure change** in real-time

### Expected Behavior at Each Threshold

| Muscle Points | Expected Result |
|---------------|-----------------|
| **0** | Extra Small Stand - very thin skeleton, minimal fusiforms |
| **~12-25** | Small Stand - small but defined musculature |
| **~37-50** | Stand (Normal) - regular build, balanced proportions |
| **~62-75** | Large Stand - noticeably more muscular, larger fusiforms |
| **~87-100** | Extra Large Stand - maximum size, fully developed fusiforms |

### What Changes as Points Increase

As muscle points go from 0 to 100, these properties scale:

- **Fusiform values** (muscle size for each limb/torso section)
- **Skeleton size** (joint thickness and connector thickness)
- **Stroke thickness** (line weight of limbs)
- **Neck width** (based on upper body mass)
- **Hand/foot size** (proportional to overall build)

### Example: Testing Upper Arms Muscle

1. Set ALL muscles to 0 (Extra Small Stand)
2. Slowly increase "Biceps/Triceps" muscle using +5 buttons
3. Watch upper arms grow gradually
4. At 25 points: Small Stand bicep size
5. At 50 points: Normal Stand bicep size  
6. At 100 points: Extra Large Stand bicep size

The transition should be **smooth and continuous**, not jumping between levels.

---

## Verification Checklist

- [ ] At 0 points: Very thin stick figure (barely visible skeleton)
- [ ] At 25 points: Noticeably thicker than 0, but still lean
- [ ] At 50 points: Normal, healthy build
- [ ] At 75 points: Clearly muscular, thicker limbs/torso
- [ ] At 100 points: Maximum muscle definition, very thick

If any threshold looks wrong, the issue is likely:

1. **Incorrect frame values in animations.json** - Check that each Stand frame (Extra Small, Small, Stand, Large, Extra Large) has correct property values
2. **Interpolation calculation bug** - Check MuscleSystem.interpolateProperty()
3. **Property not being applied** - Check GameplayScene.applyMuscleScaling()

---

## Debug Output

When testing, watch the console for these logs:

```
🦵 SCALE: Muscle 'Upper Torso' (id: upper_torso) has 50.0 points
🦵 INTERP: upper_torso fusiformUpperTorso at 50.0 points, interpolating...
🦵 SCALE: Applied Upper Torso → fusiformUpperTorso = 5.85
```

This tells you:
- Which muscle is being processed
- How many points it has
- What body part property is being interpolated
- The final interpolated value

---

## Frame Definition Verification

To verify frame values are correct, open the editor and select each Stand frame:

1. **Extra Small Stand** (frame 0)
   - Should have fusiform values at minimum (mostly 0)
   - Skeleton size should be 0
   - Stroke thickness should be minimal

2. **Small Stand** (frame 0)
   - Fusiform values ~25% of normal
   - Skeleton size ~25% of normal
   - Stroke thickness ~25% of normal

3. **Stand** (frame 0)
   - Fusiform values at normal level (~5.85 for upperTorso)
   - Skeleton size at normal (~4.18)
   - Stroke thickness at normal (~5 for upperTorso)

4. **Large Stand** (frame 0)
   - Fusiform values ~75% of normal
   - Skeleton size ~75% of normal
   - Stroke thickness ~75% of normal

5. **Extra Large Stand** (frame 0)
   - Fusiform values at maximum
   - Skeleton size at maximum
   - Stroke thickness at maximum

If these don't match expectations, regenerate the frames or edit them to the correct values.

---

## Known Limitations (Current)

- **No automatic point progression yet** - Points don't automatically increase with actions
- **Manual testing only** - Uses dev plus/minus buttons in Customization
- **No point decay** - Points stay at set value (will implement decay later)
- **All muscles affect all parts** - Can't disable certain muscles yet

---

## Next: Automatic Point Awarding

Once manual testing confirms the progression is working, wire up:

1. Action completion detection
2. Look up action in game_muscles.json
3. Find target muscle
4. Award points based on configuration
5. Stick figure updates automatically on next render

