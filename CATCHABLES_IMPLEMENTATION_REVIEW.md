# Catchables.json Implementation Review for SpriteKit Gameplay

**Status:** Review Only (No Code Changes)  
**Date:** March 13, 2026  
**Scope:** What needs to be done to integrate catchables.json into SpriteKit GameplayScene

---

## CURRENT STATE

### ✅ What's ALREADY Implemented

#### 1. **catchables.json File Structure** 
- **Location:** `/Users/cavan/Developer/Extend/Extend/catchables.json`
- **Current Catchables (5 items):**
  - `leaf` - unlocks at Level 1, 1 point
  - `heart` - unlocks at Level 4, 5 points
  - `brain` - unlocks at Level 7, 10 points
  - `sun` - unlocks at Level 10, 15 points
  - `shaker` - unlocks at Level 1, 20 points (special collision animation)

#### 2. **CatchableConfig Struct**
- **Location:** `/Users/cavan/Developer/Extend/Extend/Modules/Game1Module.swift` (line ~268-279)
- **Properties Defined:**
  - `id` - unique identifier
  - `name` - display name
  - `assetName` - image asset for custom sprites (or null for SF Symbols)
  - `iconName` - SF Symbol name or asset name
  - `unlockLevel` - when this catchable becomes available
  - `direction` - "falls" or "vertical" movement
  - `spins` - whether it rotates
  - `spinSpeed` - rotation speed
  - `collisionAnimation` - optional action animation ID to trigger when caught
  - `baseSpawnChance` - probability of spawning each frame
  - `baseVerticalSpeed` - initial fall speed
  - `baseVerticalSpeedMax` - max fall speed
  - `color` - hex color for SF Symbols
  - `points` - points awarded

#### 3. **Global CATCHABLE_CONFIGS**
- **Location:** `/Users/cavan/Developer/Extend/Extend/Modules/Game1Module.swift` (line ~315)
- **Function:** `loadCatchables()` reads from catchables.json at app startup
- **Status:** ✅ Pre-loaded and ready to use

#### 4. **SwiftUI Gameplay (Game1Module) Integration**
- **Spawning:** `checkFallingItemCollisions()` (line ~1008-1025)
  - Filters catchables by `unlockLevel <= currentLevel`
  - Respects `baseSpawnChance` for spawn probability
  - Creates `FallingItem` objects with config properties
  - Respects spinSpeed for rotation

- **Collision Detection:** (line ~1040-1062)
  - Checks distance between figure and falling item
  - Awards points from `config.points`
  - Tracks caught items in `catchablesCaught[config.id]` dictionary
  - Triggers `collisionAnimation` if configured
  - Creates floating text with hex color from `config.color`

- **Shaker (Special Case):** `checkShakerCollisions()` (line ~1071+)
  - Uses dedicated fallng array `fallingShakers`
  - Respects baseSpawnChance
  - Has special "Boost!" behavior

- **Statistics Window:** ✅ Shows all catchables from CATCHABLE_CONFIGS
  - Displays caught count for each
  - Shows unlock levels

---

## ❌ WHAT'S MISSING FOR SPRITEKIT GAMEPLAY

### Issue 1: No Catchable Spawning in GameplayScene
**Problem:** GameplayScene (SpriteKit version) doesn't spawn falling catchables
- No `FallingItem` array property
- No spawn logic in `updateGameLogic()` method
- No collision detection with character
- No rendering of falling items

### Issue 2: No Catchable Rendering
**Problem:** Can't display the falling catchables on screen
- No method to render SF Symbols in SpriteKit
- No method to render custom asset sprites in SpriteKit
- No rotation/animation for spinning catchables

### Issue 3: No Collision Detection
**Problem:** No logic to detect when character collides with catchables
- No distance calculation between character and items
- No points awarding on collision
- No collision animation triggering
- No floating text display
- No tracking in `gameState.catchablesCaught`

### Issue 4: No Catchable State in GameplayScene
**Problem:** GameplayScene doesn't track caught items
- Missing `fallingItems: [FallingItem]` array
- Missing `fallingShakers: [FallingShaker]` array (if Shaker support needed)
- Missing reference to gameState's `catchablesCaught` dictionary

---

## WHAT NEEDS TO BE IMPLEMENTED

### Part 1: Data Structures & Properties

**Add to GameplayScene:**
```swift
private var fallingItems: [FallingItem] = []
private var fallingShakers: [FallingShaker] = []  // If Shaker special handling needed
```

**FallingItem struct** - Already exists in Game1Module but needs to be:
- Accessible to GameplayScene (move to shared location or duplicate)
- Contains: id, itemType, x, y, rotation, horizontalVelocity, verticalSpeed

**FallingShaker struct** - Already exists in Game1Module but needs to be:
- Accessible to GameplayScene (move to shared location or duplicate)
- Contains: x, y, rotation, verticalSpeed

---

### Part 2: Spawning Logic

**Method to Add:** `spawnFallingCatchables()` in GameplayScene
- **Responsibilities:**
  - Filter CATCHABLE_CONFIGS by `unlockLevel <= gameState.currentLevel`
  - Check spawn probability using `baseSpawnChance`
  - Create new FallingItem with random X position, speed from config
  - Limit max items on screen based on level
  - Handle Shaker separately if needed (special collision animation)

**Where to Call:** In `updateGameLogic()` each frame

---

### Part 3: Rendering Logic

**Method to Add:** `renderFallingItems()` in GameplayScene
- **For SF Symbol items** (iconName not null, assetName null):
  - Create SKLabelNode with SF Symbol
  - Position on screen
  - Rotate if config.spins is true
  - Apply color from config.color (hex)
  
- **For Asset items** (assetName not null):
  - Create SKSpriteNode with image asset
  - Position on screen
  - Rotate if config.spins is true

- **Challenges:**
  - SpriteKit doesn't natively render SF Symbols
  - Need to either:
    a) Pre-render SF Symbols to images (complex)
    b) Use SKLabelNode with special encoding
    c) Convert SF Symbols to UIImage then SKTexture

**Where to Call:** In `updateGameLogic()` after spawning

---

### Part 4: Collision Detection

**Method to Add:** `checkFallingItemCollisions()` in GameplayScene
- **Similar to:** Game1Module version but for SpriteKit
- **Responsibilities:**
  - For each falling item:
    - Calculate distance from character position
    - If distance < collision radius (~60 points):
      - Get config from CATCHABLE_CONFIGS
      - Update `gameState.catchablesCaught[config.id]`
      - Award points: `gameState.addPoints(config.points)`
      - Trigger collision animation if config.collisionAnimation is set
      - Create floating text "+X" with hex color
      - Remove item from array
    - Update position (y += verticalSpeed, x += horizontalVelocity)
    - Update rotation if config.spins
    - Remove if off-screen

**Where to Call:** In `updateGameLogic()` before rendering

---

### Part 5: Integrate into updateGameLogic()

**Current updateGameLogic() handles:**
- Eye blinking
- Action animation rendering
- Movement animation
- Standing pose
- Character position wrapping

**Add to updateGameLogic():**
1. Call `spawnFallingCatchables()` - add new items
2. Call `checkFallingItemCollisions()` - detect hits and update state
3. Call `renderFallingItems()` - draw items to screen

---

### Part 6: Handle Shaker Special Behavior (Optional)

**Shaker is special because:**
- Has collision animation ("Shaker" action)
- Might need different spawn limits
- Falls faster than regular items
- Could have special visual treatment

**Options:**
1. Treat as normal catchable (same as SwiftUI version)
2. Keep separate `fallingShakers` array with dedicated logic
3. Add config flags for "isSpecial" handling

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Setup
- [ ] Add FallingItem and FallingShaker structs to GameplayScene
- [ ] Add `fallingItems` and `fallingShakers` properties
- [ ] Add methods: `spawnFallingCatchables()`, `checkFallingItemCollisions()`, `renderFallingItems()`

### Phase 2: Spawning
- [ ] Implement spawn logic using CATCHABLE_CONFIGS
- [ ] Test spawn probability matches config values
- [ ] Verify level-based filtering works

### Phase 3: Rendering
- [ ] Handle SF Symbol rendering (choose strategy)
- [ ] Handle asset sprite rendering
- [ ] Handle rotation based on spinSpeed
- [ ] Test visibility at various screen sizes

### Phase 4: Collision & Effects
- [ ] Implement distance-based collision detection
- [ ] Award points from config
- [ ] Trigger collision animations
- [ ] Display floating text with colors
- [ ] Update gameState.catchablesCaught

### Phase 5: Polish & Testing
- [ ] Verify catchables appear at correct unlock levels
- [ ] Test collision feels responsive
- [ ] Check floating text displays correctly
- [ ] Verify stats window reflects caught items
- [ ] Test wrapping behavior at screen edges

---

## KEY CONSIDERATIONS

### 1. SF Symbol Rendering Challenge
SpriteKit doesn't have native SF Symbol support. Solutions:
- **Option A:** Pre-render SF Symbols to UIImage (done once at app startup)
- **Option B:** Use custom fonts/emoji (limited visual control)
- **Option C:** Store pre-rendered images in assets for each catchable

### 2. Performance
- Spawning/rendering multiple items each frame
- Distance calculations for each item
- Recommend: max 10-15 items on screen at once

### 3. Coordinate System
- GameplayScene uses SpriteKit coordinates (bottom-left origin)
- Verify character position calculations match expectations
- Falling items spawn at y=0 (top) and move down

### 4. State Sync
- GameplayScene updates `gameState.catchablesCaught`
- Statistics window reads same dictionary
- Both should stay in sync automatically

### 5. Level Progression
- Catchables unlock based on `unlockLevel` property
- No additional database queries needed
- Config-driven completely

---

## DEPENDENCIES

**Already Available:**
- ✅ CATCHABLE_CONFIGS (pre-loaded from JSON)
- ✅ ACTION_CONFIGS (for collision animations)
- ✅ gameState reference (for points and tracking)
- ✅ StickFigureAppearance (for custom colors)

**Need to Replicate:**
- FallingItem struct (from Game1Module)
- FallingShaker struct (from Game1Module, if needed)
- Floating text display logic (already in GameplayScene as `addFloatingText`)
- Color hex parsing (already in GameplayScene as `getColorFromHex`)
- Point awarding logic (already in GameplayScene as `addPoints`)

---

## ESTIMATED COMPLEXITY

- **Spawning:** Low (straightforward config-driven logic)
- **Collision:** Low (basic distance calculation)
- **Rendering SF Symbols:** Medium (needs UI/SpriteKit bridge)
- **Rendering Assets:** Low (standard SKSpriteNode)
- **Overall:** Medium-Low (most pieces already exist)

---

## RELATED FILES

**Config:**
- `/Users/cavan/Developer/Extend/Extend/catchables.json`

**Code:**
- `/Users/cavan/Developer/Extend/Extend/Modules/Game1Module.swift` (reference implementation)
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/GameplayScene.swift` (target file)
- `/Users/cavan/Developer/Extend/Extend/SpriteKit/GameScene.swift` (parent class)

**Documentation:**
- `STATISTICS_WINDOW_COMPLETE.md` - catchables display in stats
- `CodeRules.swift` - catchables design philosophy

---

## NEXT STEPS

Ready to implement once you confirm:
1. Which rendering approach for SF Symbols (pre-render, custom font, etc.)?
2. Should Shaker have special handling or be treated as normal catchable?
3. Any performance constraints or max item limits?
4. Any visual/gameplay tweaks to catchable behavior (speeds, spawn rates, etc.)?

