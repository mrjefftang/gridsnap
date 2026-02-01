# GridSnap - macOS Window Management App

## Overview
Native macOS menu bar app (like Divvy). Global hotkey triggers a transparent overlay with a configurable grid. User drags to select cells, and the frontmost window resizes to match.

## Tech Stack
- Swift, AppKit + SwiftUI hybrid, no external dependencies
- Carbon APIs for global hotkey (RegisterEventHotKey)
- AXUIElement APIs for window manipulation
- MenuBarExtra (SwiftUI) for status bar
- Cannot be sandboxed (accessibility APIs require it)

## Project Structure
```
GridSnap/
├── GridSnapApp.swift          # @main, MenuBarExtra scene
├── AppDelegate.swift          # Lifecycle, hotkey→overlay→resize coordination
├── Settings.swift             # UserDefaults wrapper (grid rows/cols, hotkey)
├── HotkeyManager.swift        # Carbon RegisterEventHotKey wrapper
├── WindowManager.swift        # AXUIElement: get frontmost window, resize/move
├── OverlayWindow.swift        # NSWindow subclass: borderless, transparent, floating
├── GridOverlayView.swift      # SwiftUI: app icon/name header + grid cells + selection
├── MouseTrackingNSView.swift  # NSViewRepresentable for click-drag mouse events
├── PreferencesView.swift      # Grid dimension steppers, hotkey display
└── Info.plist                 # LSUIElement=true, accessibility usage description
```

## Implementation Order

### 1. Xcode Project Setup
- Create macOS App project "GridSnap" at `/Users/jeff/Projects/claude/GridSnap`
- Set deployment target macOS 13+ (for MenuBarExtra)
- Configure Info.plist: `LSUIElement=true`, `NSAccessibilityUsageDescription`
- Disable App Sandbox entitlement

### 2. Settings.swift
- Singleton with `@Published` properties: `gridRows` (default 6), `gridColumns` (default 6)
- Hotkey config: keyCode (default 49/Space), modifiers (default Ctrl+Option)
- Persist via UserDefaults

### 3. HotkeyManager.swift
- Wrap Carbon `RegisterEventHotKey` / `UnregisterEventHotKey`
- Event handler dispatches callback to main queue
- Support re-registration when settings change

### 4. WindowManager.swift
- `getFrontmostWindow()` → returns app name, icon, AXUIElement, screen
- `setWindowFrame()` → AXUIElementSetAttributeValue for position + size
- `calculateGridFrame()` → map GridRect to screen coordinates using `screen.visibleFrame`
- Handle coordinate flipping (macOS bottom-left origin)

### 5. OverlayWindow.swift
- NSWindow: `.borderless`, `isOpaque=false`, `backgroundColor=.clear`
- Level: `.popUpMenu`, collection behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`
- Override `canBecomeKey` → true (for keyboard events)

### 6. GridOverlayView.swift + MouseTrackingNSView.swift
- SwiftUI view: header (app icon + name), grid with cell highlighting
- NSViewRepresentable wrapping NSView for mouseDown/mouseDragged/mouseUp
- Map mouse coordinates → grid cells, support drag selection across cells
- Escape key cancels overlay
- Blue highlight on selected cells during drag

### 7. AppDelegate.swift
- On launch: check `AXIsProcessTrustedWithOptions` (prompt if needed)
- Register hotkey via HotkeyManager
- Hotkey callback: get frontmost window → show overlay → on selection → resize window → hide overlay

### 8. GridSnapApp.swift
- `@main` App with `MenuBarExtra` (system image: `square.grid.3x3`)
- Menu: grid dimensions display, Preferences button, Quit button
- `@NSApplicationDelegateAdaptor(AppDelegate.self)`

### 9. PreferencesView.swift
- Steppers for rows (2-20) and columns (2-20)
- Display current hotkey
- Reset to defaults button

## Add Launch at Login

Use `SMAppService.mainApp` (ServiceManagement framework, macOS 13+). No entitlements or Info.plist changes needed.

### Files to modify

**`Settings.swift`**
- Add `@Published var launchAtLogin: Bool` (not persisted to UserDefaults — read from `SMAppService.mainApp.status` instead)
- Add a method `updateLaunchAtLogin(_ enabled: Bool)` that calls `SMAppService.mainApp.register()` / `.unregister()`
- Add a method `refreshLaunchAtLogin()` that reads `.status` and sets the published property

**`PreferencesView.swift`**
- Add a Toggle for "Launch at Login" bound to `settings.launchAtLogin`
- On toggle change, call `settings.updateLaunchAtLogin(newValue)`
- On appear, call `settings.refreshLaunchAtLogin()` to sync with system state

**`GridSnapApp.swift`**
- Add "Launch at Login" toggle to the MenuBarExtra menu as well

### Key details
- Always read status from `SMAppService.mainApp.status` (user can change via System Settings independently)
- Handle `.requiresApproval` by calling `SMAppService.openSystemSettingsLoginItems()`
- Wrap register/unregister in do/catch — fail gracefully

### Verification
1. Open Preferences, toggle "Launch at Login" on
2. Check System Settings > General > Login Items — GridSnap should appear
3. Log out and log back in — GridSnap should launch automatically
4. Toggle off — GridSnap removed from Login Items

## Key Edge Cases
- No focused window → show notification, skip overlay
- Accessibility denied → alert with "Open System Settings" button
- Multi-monitor → overlay appears on screen containing target window
- Window can't resize (system apps) → fail silently
- Escape key → close overlay without action

## Verification
1. Build and run in Xcode
2. Grant accessibility permissions when prompted
3. Press Ctrl+Option+Space → overlay should appear with frontmost app info
4. Click and drag across grid cells → cells highlight blue
5. Release mouse → frontmost window resizes to match selected grid region
6. Press Escape → overlay dismisses without action
7. Change grid dimensions in menu → overlay reflects new grid size
8. Test with multiple monitors (if available)
