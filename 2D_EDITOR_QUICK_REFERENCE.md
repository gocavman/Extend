# 2D Stick Figure Editor - Quick Reference

## What's New

### Expandable Sections
All major editor sections can now be expanded/collapsed to reduce clutter:

1. **Figure Size** (New)
   - Scale (50%-200%)
   - Head size multiplier (0.5-2.0)

2. **Frames** (New)
   - Save and load animation frames
   - View saved frames count

3. **Controls** (Reorganized)
   - **Angle Sliders subsection**
     - All joint rotations (waist, shoulders, elbows, knees, feet, head)
   - **Stroke & Fusiform subsection**
     - Individual stroke thickness for each body part
     - Fusiform (tapered) control for each body part

## New Controls

### Stroke Thickness (7 independent sliders)
Control the line width of each body part independently:
- **Upper Arms** - affects left and right upper arms
- **Lower Arms** - affects forearms
- **Upper Legs** - affects thighs
- **Lower Legs** - affects shins
- **Joints** - affects joint connection points
- **Upper Torso** - affects upper body/shoulders
- **Lower Torso** - affects lower body

**Range:** 0.5 to 10.0 (pixels)

### Fusiform/Taper Controls (6 sliders)
Create tapered limbs that are thicker on one end than the other:
- **Upper Arms** - Normal: thinner at elbow
- **Lower Arms** - Normal: thinner at wrist
- **Upper Legs** - Normal: thinner at knee
- **Lower Legs\*** - Inverted: thicker at knee (larger at top)
- **Upper Torso\*** - Inverted: thicker at shoulders (larger at top)
- **Lower Torso** - Normal: thinner at waist

**Range:** 0% to 100%
- 0% = No taper (straight lines)
- 50% = Mild taper
- 100% = Maximum taper

\* = Inverted (larger at top, smaller at bottom)

## Usage Tips

1. **Start Collapsed:** All sections collapse by default to save space
2. **Expand As Needed:** Click section headers to expand/collapse
3. **Tapered Limbs:** Lower legs and upper torso are inverted (look like real anatomy!)
4. **Independent Thickness:** Change one body part without affecting others
5. **Save Your Work:** Use the Frames section to save and load poses

## Example Configurations

### Muscular Physique
- Upper arms stroke: 5.5
- Upper arms fusiform: 30%
- Upper legs stroke: 5.0
- Upper legs fusiform: 40%

### Slim Figure
- All stroke thickness: 2.0-3.0
- All fusiform: 0% (straight)

### Athletic Build
- Upper/lower arms: 3.5-4.0, 20% fusiform
- Upper/lower legs: 4.5-4.0, 30% fusiform
- Torso: 5.0-4.5, 20% fusiform

---

**Last Updated:** February 27, 2026
