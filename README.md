# GridSnap

A native macOS window management app inspired by Divvy. Press a global hotkey to summon a grid overlay, drag to select cells, and the focused window snaps to that region of your screen.

## Features

- **Global hotkey** (default: `⌃⌥Space`) triggers the grid overlay
- **Click-and-drag grid selection** to define window position and size
- **Configurable grid** dimensions (2×2 up to 20×20)
- **Customizable hotkey** via a built-in recorder in Preferences
- **Multi-monitor aware** — overlay appears on the screen containing the target window
- **Menu bar agent** — runs quietly with no Dock icon

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permissions (prompted on first launch)

## Building

1. Open `GridSnap.xcodeproj` in Xcode
2. Build and run (`⌘R`)
3. Grant Accessibility permissions when prompted

The app cannot be sandboxed — Accessibility APIs require it.

## Usage

1. Focus the window you want to reposition
2. Press `⌃⌥Space` (or your custom hotkey)
3. Drag across the grid cells to select a region
4. Release the mouse — the window snaps to that area
5. Press `Esc` to dismiss without changes

## Preferences

Click the grid icon in the menu bar → **Preferences...**

- **Grid Dimensions** — adjust rows and columns
- **Hotkey** — click the recorder field and press a new key combination (must include at least one modifier)
- **Reset to Defaults** — restores 6×6 grid and `⌃⌥Space`

## Project Structure

| File | Purpose |
|------|---------|
| `GridSnapApp.swift` | App entry point, MenuBarExtra |
| `AppDelegate.swift` | Lifecycle, hotkey→overlay→resize coordination |
| `Settings.swift` | UserDefaults-backed preferences |
| `HotkeyManager.swift` | Carbon `RegisterEventHotKey` wrapper |
| `WindowManager.swift` | AXUIElement APIs for window detection and resizing |
| `OverlayWindow.swift` | Borderless transparent NSPanel |
| `GridOverlayView.swift` | SwiftUI grid UI with NSView mouse tracking |
| `HotkeyRecorderView.swift` | Shortcut recorder NSViewRepresentable |
| `PreferencesView.swift` | Grid and hotkey configuration UI |

## License

MIT
