# Statistics Window - Quick Reference

## Location in Code

**File:** `Game1Module.swift`

| Component | Lines | Purpose |
|-----------|-------|---------|
| `StatsOverlayView` | 2020-2090 | Main window layout & appearance |
| `StatsListContent` | 1922-2020 | All statistics sections |
| `StatRow` | 1897-1918 | Individual stat row display |
| Global `CATCHABLE_CONFIGS` | 312 | Pre-loaded catchables |

---

## What Changed

### 1. Window Layout
```swift
// BEFORE: Centered with padding and rounded corners
.frame(maxHeight: .infinity, alignment: .top)
.background(Color.white)
.cornerRadius(12)
.padding(.horizontal, 12)
.padding(.top, 50)

// AFTER: Full width, edge-to-edge
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
.background(Color.white)
.ignoresSafeArea(edges: .horizontal)
```

### 2. Header Section
```swift
// BEFORE
HStack {
    Text("Statistics").font(.headline)
    Spacer()
    Button(action: { showStats.wrappedValue = false }) { ... }
}
.padding(16)
.background(Color.white)

// AFTER
HStack {
    Text("Statistics").font(.system(size: 20, weight: .bold))
    Spacer()
    Button(action: { showStats.wrappedValue = false }) { ... }
}
.padding(.horizontal, 20)
.padding(.vertical, 16)
.background(Color(UIColor.systemGray6))
```

### 3. Collectibles Section
```swift
// BEFORE: Hardcoded items
StatRow(label: "Leaves", value: "\(gameState.totalLeavesCaught) caught", isUnlocked: true)
StatRow(label: "Hearts", value: "\(gameState.totalHeartsCaught) caught", isUnlocked: gameState.currentLevel >= 4, unlocksAt: 4)
// ... more hardcoded items

// AFTER: Dynamic from CATCHABLE_CONFIGS
Section(header: Text("Collectibles")) {
    ForEach(CATCHABLE_CONFIGS, id: \.id) { catchable in
        let count = gameState.catchablesCaught[catchable.id] ?? 0
        let isUnlocked = gameState.currentLevel >= catchable.unlockLevel
        StatRow(
            label: catchable.name,
            value: "\(count) caught",
            isUnlocked: isUnlocked,
            unlocksAt: !isUnlocked ? catchable.unlockLevel : nil
        )
    }
}
```

### 4. Dividers Removed
```swift
// BEFORE: Hardcoded text dividers
Divider()
Text("Catchables (Always Available)")
    .font(.headline)
StatRow(label: "Leaves", ...)
Divider()
Text("Actions & Points")
    .font(.headline)

// AFTER: Clean SwiftUI sections
Section(header: Text("Collectibles")) { ... }
Section(header: Text("Actions & Points")) { ... }
```

---

## Key Features

✅ **Full Width** - Window extends edge-to-edge  
✅ **Solid Background** - No transparency  
✅ **Slides from Bottom** - Proper animation  
✅ **Clean Headers** - No hardcoded dividers  
✅ **Dynamic Collectibles** - Auto-loads from catchables.json  
✅ **Proper Spacing** - Better visual hierarchy  
✅ **Unlock Info** - Shows when items unlock  

---

## How to Extend

### Add New Collectible
1. Edit `catchables.json` - add new item
2. Update `gameState` tracking - add count storage
3. Done! Window auto-updates

### Change Window Color
Edit line ~2080:
```swift
.background(Color.blue)  // or any color
```

### Change Header Color
Edit line ~2034:
```swift
.background(Color.green)  // or any color
```

### Change Title Size
Edit line ~2025:
```swift
.font(.system(size: 24, weight: .bold))  // Increase to 24
```

---

## Testing Checklist

- [ ] Window slides up from bottom
- [ ] Window extends full width (no padding)
- [ ] Background is solid white
- [ ] No dashes or underscores visible
- [ ] All section headers are clean
- [ ] Collectibles from catchables.json display
- [ ] Caught counts are accurate
- [ ] Unlock levels show correctly
- [ ] Close button works
- [ ] All sections visible (scroll if needed)

---

## Build Command

```bash
cd /Users/cavan/Developer/Extend
xcodebuild -scheme Extend -configuration Debug clean build
```

Status: ✅ **BUILD SUCCEEDED**

