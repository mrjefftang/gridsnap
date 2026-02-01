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
        guard result == .success else { return nil }

        let windowElement = focusedWindow as! AXUIElement
        let frame = getWindowFrame(windowElement)

        let screen = NSScreen.screens.first { $0.frame.intersects(frame) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]

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
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal)

        var position = CGPoint.zero
        var size = CGSize.zero
        if let pv = posVal { AXValueGetValue(pv as! AXValue, .cgPoint, &position) }
        if let sv = sizeVal { AXValueGetValue(sv as! AXValue, .cgSize, &size) }

        return NSRect(origin: position, size: size)
    }

    static func setWindowFrame(_ element: AXUIElement, frame: NSRect) {
        var position = frame.origin
        var size = frame.size

        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }
        // Set size again after position (some windows constrain based on screen)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    static func calculateTargetFrame(
        gridRect: GridRect,
        screen: NSScreen,
        rows: Int,
        columns: Int
    ) -> NSRect {
        let visible = screen.visibleFrame
        let cellW = visible.width / CGFloat(columns)
        let cellH = visible.height / CGFloat(rows)

        // AX coordinates: origin top-left of main screen
        // visibleFrame: origin bottom-left
        // Convert: AX y = mainScreenHeight - visibleFrame.maxY + row offset
        let mainHeight = NSScreen.screens.first?.frame.height ?? visible.height

        let x = visible.minX + CGFloat(gridRect.column) * cellW
        let y = mainHeight - visible.maxY + CGFloat(gridRect.row) * cellH
        let w = CGFloat(gridRect.width) * cellW
        let h = CGFloat(gridRect.height) * cellH

        return NSRect(x: x, y: y, width: w, height: h)
    }
}
