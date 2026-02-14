////
////  QUICK START GUIDE
////  Get Extend running in 3 simple steps
////

# 🚀 QUICK START - 3 STEPS

## Step 1: Clear Xcode Cache
```bash
# In Terminal:
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf Extend.xcodeproj/xcuserdata
```

## Step 2: Open Project
- Open `Extend.xcodeproj` in Xcode
- Wait for indexing to complete (~30 seconds)

## Step 3: Build & Run
- Press **Cmd + B** to build
- Press **Cmd + R** to run on simulator or device
- Select an iPhone simulator (iPhone 15 Pro recommended)

---

## ✅ What You'll See

### On First Launch:
1. **NavBar at bottom** with 3 modules:
   - 🏋️ Workouts
   - ⏱️ Timer
   - 📊 Progress

2. **Tap any module** to view its content

3. **Tap the ⚙️ gear button** to:
   - Turn modules on/off
   - Reorder them (up/down arrows)

---

## 🎯 Test Checklist

- [ ] App launches without crashes
- [ ] Can switch between modules
- [ ] Module names display correctly
- [ ] Settings sheet opens and closes
- [ ] Can toggle module visibility
- [ ] Can reorder modules
- [ ] Settings persist on app relaunch

---

## 📱 Test on Different Devices

Try on multiple simulator sizes:
- iPhone SE (small screen) ← Important!
- iPhone 15 (standard)
- iPhone 15 Pro Max (large screen)

---

## 🆘 If You Get Errors

### "missingTarget" Error?
- Run the cache clear commands above
- Clean build folder: **Cmd + Shift + K**
- Rebuild: **Cmd + B**

### "Cannot find module" Error?
- Check all files exist in `/Extend/Modules/`, `/Extend/Components/`, `/Extend/State/`
- Verify they're showing in Xcode's file navigator
- Try cleaning derived data again

### Build Fails?
- Check Xcode version: Should be 15.2+
- Verify iOS deployment target: Should be 17.0+
- See `BUILD_INSTRUCTIONS.md` for detailed help

---

## 🎓 Next: Add Your First Custom Module

See `COMPLETE_SUMMARY.md` section "HOW TO ADD NEW MODULES"

Quick example:
1. Create `Extend/Modules/SettingsModule.swift`
2. Copy structure from `WorkoutModule.swift`
3. Register in `ContentView.swift`
4. Your module appears automatically! ✨

---

## 📖 Documentation

- **CodeRules.swift** - Coding standards for future development
- **COMPLETE_SUMMARY.md** - Full architecture breakdown
- **iOS_SETUP_GUIDE.md** - iPhone-specific development tips
- **BUILD_INSTRUCTIONS.md** - Troubleshooting build issues

---

## 💡 Tips

- Start by exploring how the sample modules work
- Look at `ModuleProtocol.swift` to understand the module interface
- Check `ContentView.swift` to see how modules are registered and navigated
- Use `ModuleRegistry.swift` to understand the registration system

---

**You're ready! Have fun building!** 🎉
