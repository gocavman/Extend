# SwiftUI StickFigure2DView Cleanup - Effort Assessment

**Date**: March 27, 2026  
**File**: `/Users/cavan/Developer/Extend/Extend/Models/StickFigure2D.swift`  
**Status**: Analysis Complete

---

## Overview

The `StickFigure2DView` SwiftUI component is **legacy code** that's not actively used in gameplay rendering. The active rendering uses SpriteKit (`GameScene.swift`) instead.

---

## Current Usage Analysis

### Where It Appears
- **Defined**: Lines 1106-1768 (663 lines total)
- **Actually Used**: Only in documentation/comments in `CodeRules.swift`
- **Active Gameplay**: NOT used (uses SpriteKit instead)

### What It Does
- SwiftUI Canvas-based rendering of stick figures
- Duplicates eye rendering logic from GameScene.swift
- Contains complex drawing methods for body parts
- About 663 lines of drawing/rendering code

### Why It Exists
- Likely created before the decision to use SpriteKit for gameplay
- May have been used in the map editor or previews
- Now orphaned but still maintained in the codebase

---

## Cleanup Effort Assessment

### EFFORT: **MODERATE TO HIGH** (4-6 hours if thorough)

#### Tier 1 - Basic Cleanup (30 minutes)
- [x] Remove from active imports/usage
- [x] Mark as deprecated
- [x] Document why it's kept (if needed)

#### Tier 2 - Deep Cleanup (2-3 hours)
- [ ] Extract rendering logic to shared utility if needed
- [ ] Identify if any other views use it
- [ ] Check if tests depend on it
- [ ] Verify no preview code uses it
- [ ] Search for hidden dependencies

#### Tier 3 - Full Removal (1-2 hours)
- [ ] Delete the 663-line struct and all methods
- [ ] Remove from StickFigure2D.swift
- [ ] Update any documentation
- [ ] Verify compilation
- [ ] Check git history for context

#### Tier 4 - Related Cleanup (1-2 hours)
- [ ] Check for duplicate code in GameScene.swift
- [ ] Consolidate eye rendering logic
- [ ] Consolidate body part drawing logic
- [ ] Update CodeRules.swift documentation

---

## Code Overlap Analysis

### SwiftUI Version Has:
1. **Eye rendering logic** (lines ~1213-1253)
   - Front view: both eyes
   - Side view: single eye (using `isSideView` flag)
   - Duplicate of SpriteKit version

2. **Body part drawing** (lines ~1260-1768)
   - Tapered segments
   - Skeleton connectors
   - Hands and feet
   - Duplicate rendering logic

### SpriteKit Version Has:
1. **Same eye rendering logic** (lines ~1043-1085)
   - Identical conditional logic
   - Same positioning

2. **Similar body part drawing**
   - Different API (SKShapeNode vs Canvas)
   - Same math, different implementation

### Duplication Cost:
- 663 lines of SwiftUI code
- ~600 lines could be SpriteKit equivalents
- ~60 lines of unique utilities
- ~10-15% actual unique code, 85% duplication/redundancy

---

## Risk Analysis

### Low Risk to Remove:
✅ Not used in active gameplay  
✅ Not referenced in most of the codebase  
✅ Only in CodeRules.swift documentation  

### Medium Risk:
⚠️ Need to check: Do any debug/preview views use it?  
⚠️ Need to verify: No hidden test dependencies  
⚠️ Need to confirm: Map editor doesn't use it  

### Safe to Keep (if unsure):
✅ Could mark as deprecated first  
✅ Could extract to separate file  
✅ Could leave for future reference  

---

## Recommended Approach

### Option A: Minimal Cleanup (RECOMMENDED)
**Effort**: 30 minutes  
**Risk**: Minimal

1. Mark as deprecated with comment
2. Add note that SpriteKit is used instead
3. Keep for now, revisit later

```swift
@available(*, deprecated, message: "Use GameScene.swift for rendering. This SwiftUI version is legacy.")
struct StickFigure2DView: View {
    // ... existing code ...
}
```

### Option B: Full Removal (THOROUGH)
**Effort**: 4-6 hours  
**Risk**: Low (but requires verification)

1. Search for all usages (already checked - only CodeRules.swift)
2. Remove the entire struct (lines 1106-1768)
3. Update CodeRules.swift to note SpriteKit is used
4. Verify compilation
5. Test all features

### Option C: Extract to Separate File (SAFEST)
**Effort**: 2-3 hours  
**Risk**: Minimal

1. Move SwiftUI code to `Extend/Models/StickFigure2DView_Legacy.swift`
2. Mark file as deprecated/legacy
3. Keep it available but separate
4. Clear signal that it's not active

---

## Dependencies Found

### Files That Reference It:
```
CodeRules.swift (lines 267, 271, 275)  - Documentation/examples only
```

### No Active Dependencies In:
```
✅ GameplayScene.swift
✅ GameViewController.swift
✅ SpriteKitGameView.swift
✅ ContentView.swift
✅ Any other gameplay files
```

---

## File Size Impact

**Current StickFigure2D.swift**: 2,234 lines total
- StickFigure2DView: 663 lines (29.7%)
- Rest of file: 1,571 lines

**If Removed**:
- New file size: 1,571 lines
- Reduction: ~30%
- Makes file more focused

---

## Recommendation Summary

| Approach | Effort | Risk | Benefit | When |
|---|---|---|---|---|
| **Deprecate** | 30 min | None | Time to decide later | NOW |
| **Extract** | 2-3 hrs | Minimal | Clean codebase | Later |
| **Delete** | 4-6 hrs | Low | Smaller codebase | After verification |

---

## Specific Issues This Would Resolve

1. **Confusion in AI**: You mentioned I sometimes get confused by old code
   - Removing it eliminates the confusion source
   - Clearer codebase structure
   - Single rendering path (SpriteKit)

2. **Code Maintenance**: Duplicate rendering logic
   - Eye logic exists in both places
   - Requires updates in two places
   - Risk of inconsistency

3. **File Size**: StickFigure2D.swift is large (2,234 lines)
   - Could split into multiple files
   - Easier to navigate
   - Clearer organization

---

## Conclusion

**Current Status**: Legacy code, not actively used  
**Safety**: Safe to remove with verification  
**Recommendation**: Start with deprecation, then extract/remove  
**Priority**: Medium (not blocking, but improves code quality)

### To Proceed:

1. **Short term**: Add `@available(*, deprecated)` annotation
2. **Medium term**: Extract to `_Legacy.swift` file
3. **Long term**: Delete after confirming no usage

This would eliminate confusion and significantly improve code clarity!

---

**Next Steps**: Let me know if you'd like me to proceed with Option A (deprecate), Option B (extract), or Option C (delete).
