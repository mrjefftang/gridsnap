import Cocoa
import ApplicationServices

struct GridRect {
    let row: Int
    let column: Int
    let width: Int
    let height: Int
}

struct WindowInfo {
    let appName: String
    let appIcon: NSImage?
    let windowElement: AXUIElement
    let screen: NSScreen
}

enum WindowManager {

    static func getFrontmostWindow() -> WindowInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        guard result == .success,
              CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else {
            return nil
        }

        // Force cast is safe — CFGetTypeID confirmed AXUIElement type above
        let windowElement = focusedWindow as! AXUIElement
        let frame = getWindowFrame(windowElement)

        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) })
                ?? NSScreen.main
                ?? NSScreen.screens.first else {
            return nil
        }

        return WindowInfo(
            appName: app.localizedName ?? "Unknown",
            appIcon: app.icon,
            windowElement: windowElement,
            screen: screen
        )
    }

    static func getWindowFrame(_ element: AXUIElement) -> NSRect {
        var posVal: AnyObject?
        var sizeVal: AnyObject?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal)

        var position = CGPoint.zero
        var size = CGSize.zero

        if posResult == .success,
           let pv = posVal,
           CFGetTypeID(pv) == AXValueGetTypeID() {
            // Force cast is safe here — CFGetTypeID confirmed the type above
            AXValueGetValue(pv as! AXValue, .cgPoint, &position)
        }
        if sizeResult == .success,
           let sv = sizeVal,
           CFGetTypeID(sv) == AXValueGetTypeID() {
            AXValueGetValue(sv as! AXValue, .cgSize, &size)
        }

        return NSRect(origin: position, size: size)
    }

    /// Check if an AXUIElement still refers to a valid, accessible window.
    static func isValidWindow(_ element: AXUIElement) -> Bool {
        var roleVal: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        return result == .success
    }

    @discardableResult
    static func setWindowFrame(_ element: AXUIElement, frame: NSRect) -> Bool {
        guard isValidWindow(element) else { return false }
        var position = frame.origin
        var size = frame.size
        var success = true

        if let posValue = AXValueCreate(.cgPoint, &position) {
            let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
            if result != .success { success = false }
        } else {
            success = false
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
            if result != .success { success = false }
        } else {
            success = false
        }
        // Set size again after position (some windows constrain based on screen)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }
        return success
    }

    static func calculateTargetFrame(
        gridRect: GridRect,
        screen: NSScreen,
        rows: Int,
        columns: Int
    ) -> NSRect {
        guard rows > 0, columns > 0 else { return screen.visibleFrame }

        let visible = screen.visibleFrame
        guard visible.width > 0, visible.height > 0 else { return screen.visibleFrame }

        // Clamp grid rect to valid bounds
        let col = max(0, min(columns - 1, gridRect.column))
        let row = max(0, min(rows - 1, gridRect.row))
        let w = max(1, min(columns - col, gridRect.width))
        let h = max(1, min(rows - row, gridRect.height))

        let cellW = visible.width / CGFloat(columns)
        let cellH = visible.height / CGFloat(rows)

        // AX coordinates: origin top-left of main screen
        // visibleFrame: origin bottom-left
        // Convert: AX y = mainScreenHeight - visibleFrame.maxY + row offset
        let mainHeight = NSScreen.main?.frame.height ?? visible.height

        let x = visible.minX + CGFloat(col) * cellW
        let y = mainHeight - visible.maxY + CGFloat(row) * cellH
        let frameW = CGFloat(w) * cellW
        let frameH = CGFloat(h) * cellH

        return NSRect(x: x, y: y, width: frameW, height: frameH)
    }
}
