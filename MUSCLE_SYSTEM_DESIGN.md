# Muscle System Design

## Overview
A comprehensive system that ties muscle development to stick figure body part growth, with actions awarding points that scale body parts over time.

---

## 1. Body Part Scaling

- As muscle points increase (0-100), linked body parts get **LARGER**
- As muscle points decrease, body parts get **SMALLER**
- Starting point: **0 points = "Extra Small Stand"**
- Ending point: **100 points = "Extra Large Stand"**
- Middle tiers distributed: 
  - Small Stand: 25 points
  - Stand (default): 50 points
  - Large Stand: 75 points
  - Extra Large Stand: 100 points

---

## 2. Muscle-to-Body Part Mapping

**One muscle can affect MULTIPLE body parts**

### Controllable Body Parts:
- Shoulders (fusiform)
- Neck (width)
- Hand Size
- Foot Size
- Upper Torso (fusiform)
- Lower Torso (fusiform)
- Upper Arms (fusiform)
- Lower Arms (fusiform)
- Upper Legs (fusiform)
- Lower Legs (fusiform)

### Additional Controllable Properties:
- **Stroke** (strokeThickness) - line thickness of body parts
- **Skeleton Size** (skeletonSize) - thickness of joint connectors
- **Waist Point** (waistThicknessMultiplier) - triangle point position in mid-torso

---

## 3. Actions & Point Distribution

- Each muscle has **1 or more actions** tied to it
- Each action specifies:
  - **Which muscle it targets** (defined in the action, not the muscle)
  - **What percentage of points it awards** that muscle (explicit in JSON)
  - Example: If "Legs" has 2 actions, each can be worth 50% (or different percentages)

---

## 4. Frame Interpolation

Extract values from 5 Stand frames at these points:
- **0 points** = Extra Small Stand
- **25 points** = Small Stand
- **50 points** = Stand (default)
- **75 points** = Large Stand
- **100 points** = Extra Large Stand

**Linear interpolation** between these checkpoints for any muscle point value.

---

## 5. Points Acquisition & Rate Control (CONFIGURABLE)

### Dynamic Point System
Points awarded to muscles are **configurable via JSON** to allow easy adjustment without code changes.

#### Configuration Structure:
A "Points" section in `game_muscles.json` defines:
- `count` - number of points awarded
- `timeframe` - duration before points can be earned again
  - Options: `"minutes"`, `"hours"`, `"days"`
- `value` - the numeric value (e.g., 5 minutes, 10 points per day)

#### Example:
```json
"points": {
  "count": 5,
  "timeframe": "minutes",
  "value": 5
}
```
This means: Award 5 points to a muscle once per 5 minutes of performing that action.

### Implementation Notes:
- Timestamp each muscle's last point award
- Check if enough time has passed before awarding new points
- Prevents rapid point grinding and balances progression
- **TODO**: Determine optimal values per action type (e.g., Move = 5 points/5 mins, Squats = 10 points/10 mins)

---

## 6. Persistence & Override

- Muscle points **persist** and **save to local storage**
- Dev has **+/- buttons** in Customization to manually override muscle values
- Points automatically update as actions are performed in gameplay

---

## 7. JSON File Structure

### game_muscles.json
```json
{
  "muscles": [
    {
      "id": "legs",
      "name": "Legs",
      "bodyParts": [
        "fusiformUpperLegs",
        "fusiformLowerLegs"
      ],
      "actions": [
        {
          "name": "Move",
          "percentage": 50
        },
        {
          "name": "Squats",
          "percentage": 50
        }
      ]
    },
    {
      "id": "arms",
      "name": "Arms",
      "bodyParts": [
        "fusiformUpperArms",
        "fusiformLowerArms"
      ],
      "actions": [
        {
          "name": "Curls",
          "percentage": 100
        }
      ]
    }
    // ... more muscles
  ],
  "points": {
    "count": 5,
    "timeframe": "minutes",
    "value": 5
  }
}
```

---

## 8. Gameplay Integration

### When an action is performed:
1. Look up action in `game_muscles.json`
2. Find which muscle it targets
3. Calculate points based on `percentage` and `points` config
4. Apply points to that muscle
5. Update body part values via linear interpolation
6. Refresh stick figure rendering
7. Save muscle points to local storage

### Example Flow:
- User performs "Move" action
- Move is linked to "Legs" muscle at 50% (if 2 actions per muscle)
- Global points config: 5 points per 5 minutes
- So Move awards 2.5 points to Legs (5 × 0.5)
- Check last timestamp for Legs × Move
- If 5+ minutes passed, award 2.5 points
- Legs points increase from (e.g.) 50 → 52.5
- Body parts interpolate proportionally
- Render updated stick figure

---

## 9. Development Checklist

- [ ] Create `game_muscles.json` with muscle definitions
- [ ] Extract body part values from 5 Stand frames
- [ ] Implement linear interpolation engine
- [ ] Create local storage persistence layer
- [ ] Add muscle tracking to game state
- [ ] Wire actions to muscle point awards
- [ ] Implement time-based point throttling
- [ ] Add +/- buttons to Customization UI
- [ ] Test interpolation across all body parts
- [ ] Verify persistence across app restarts
- [ ] Balance point values to prevent grinding
- [ ] Create animations for body part changes

---

**Last Updated**: March 4, 2026
**Status**: Design Phase - Ready for Implementation
