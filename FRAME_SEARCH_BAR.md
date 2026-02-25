# Frame Search Bar Implementation

## Overview
Added a search bar to the "Open Frame" dialog in the Stick Figure Editor that allows users to quickly filter frames by name or frame number.

## Visual Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ ◄ Saved Frames                                           Done    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🔍  [Search frames...                                    ]  ✕  │  ← Search bar
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  □ Stand                            📋    Edit  🗑          │  ← Frame list
│    Frame #0  ·  25 Feb, 3:30 PM                           │     (filtered)
│                                                            │
│  □ Move                              📋                    │
│    Frame #1  ·  25 Feb, 3:31 PM                           │
│                                                            │
│  □ Pull up                           📋    ✏️   🗑         │
│    Frame #4  ·  25 Feb, 3:35 PM                           │
│                                                            │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### 1. Search Bar
- **Location**: Top of the Frames Manager sheet, below the navigation bar
- **Components**:
  - 🔍 Magnifying glass icon (left side)
  - TextField with placeholder "Search frames..."
  - ✕ Clear button (right side, appears only when text is entered)

### 2. Search Functionality
- **Searches by frame name** (case-insensitive)
  - Example: typing "pull" finds "Pull up"
  - Example: typing "MOVE" finds "Move"

- **Searches by frame number** (exact match in string form)
  - Example: typing "4" finds "Pull up" (Frame #4)
  - Example: typing "2" finds all frames with number 2

- **Real-time filtering**
  - Results update as you type
  - No need to press enter

### 3. Clear Button
- Appears only when search text is not empty
- Click to instantly clear the search
- Button style: xmark.circle.fill icon in gray
- Provides quick way to return to full frame list

### 4. Empty States

**No saved frames:**
```
┌─────────────────────────────────┐
│    🎬                           │
│   No saved frames yet           │
│   Save frames to create animations
│                                 │
└─────────────────────────────────┘
```

**No search results:**
```
┌─────────────────────────────────┐
│    🔍                           │
│   No frames found               │
│   Try a different search term   │
│                                 │
└─────────────────────────────────┘
```

## Code Implementation

### State Variable
```swift
@State private var searchText = ""
```

### Computed Filter Property
```swift
private var filteredFrames: [AnimationFrame] {
    if searchText.isEmpty {
        return savedFrames
    }
    return savedFrames.filter { frame in
        frame.name.lowercased().contains(searchText.lowercased()) ||
        String(frame.frameNumber).contains(searchText)
    }
}
```

### Search Bar UI
```swift
HStack(spacing: 12) {
    Image(systemName: "magnifyingglass")
        .foregroundColor(.gray)
    
    TextField("Search frames...", text: $searchText)
        .textFieldStyle(.roundedBorder)
    
    if !searchText.isEmpty {
        Button(action: { searchText = "" }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
        }
    }
}
.padding()
.background(Color(.systemBackground))
```

### Frame List (Filtered)
```swift
List {
    ForEach(filteredFrames) { frame in
        // Frame row UI
    }
}
```

## User Workflow

1. **Open Frame Dialog**
   - Click "Open Frame" button in Stick Figure Editor
   - Frames Manager sheet appears with search bar visible

2. **Search for Frame**
   - Type in search field (e.g., "pull")
   - List immediately filters to matching frames
   - See "Pull up" frame appear

3. **Clear Search**
   - Click X button or select and delete text
   - Full frame list returns

4. **Select Frame**
   - Click a frame from the (possibly filtered) list
   - Frame loads into editor
   - Sheet closes

## Performance Notes

- Search is performed on-demand (computed property)
- No heavy operations needed for small frame lists
- Filtering is instant as user types
- No network calls or background processing

## Styling

- Search bar background: `.systemBackground` color
- Search icon: gray foreground
- Clear button: gray foreground, only visible when needed
- Text field: `.roundedBorder` style for iOS consistency

## Backward Compatibility

- Existing frame functionality unchanged
- Edit and Delete buttons still available
- Frame reordering (drag-and-drop) still works
- All frame operations work with filtered view

## Testing Checklist

- [ ] Search bar appears at top of Frames Manager
- [ ] Typing in search field filters frames by name
- [ ] Typing numbers filters frames by frame number
- [ ] Search is case-insensitive for names
- [ ] X button appears when text is entered
- [ ] Clicking X clears the search
- [ ] "No frames found" message shows when no matches
- [ ] Edit and Delete buttons still work with search
- [ ] Frame selection works with filtered frames
- [ ] Empty state shows when no frames exist
