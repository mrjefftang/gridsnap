import Cocoa
import SwiftUI
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = HotkeyManager()
    private var overlayWindow: OverlayWindow?
    private var savedWindowInfo: WindowInfo?
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibility()
        registerHotkey()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: .hotkeyDidChange,
            object: nil
        )
    }

    @objc private func hotkeySettingsChanged() {
        registerHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    // MARK: - Accessibility

    private func checkAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showAccessibilityAlert()
            }
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "GridSnap Needs Accessibility Permissions"
        alert.informativeText = "Enable GridSnap in System Settings > Privacy & Security > Accessibility to resize windows."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Hotkey

    func registerHotkey() {
        let settings = Settings.shared
        hotkeyManager.register(
            keyCode: settings.hotkeyKeyCode,
            modifiers: settings.hotkeyModifiers
        ) { [weak self] in
            self?.handleHotkey()
        }
    }

    private func handleHotkey() {
        if overlayWindow != nil {
            hideOverlay()
            return
        }

        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return
        }

        guard let info = WindowManager.getFrontmostWindow() else { return }
        savedWindowInfo = info
        showOverlay(for: info)
    }

    // MARK: - Overlay

    private func showOverlay(for info: WindowInfo) {
        let settings = Settings.shared
        let overlay = OverlayWindow(screen: info.screen)

        let view = GridOverlayView(
            appName: info.appName,
            appIcon: info.appIcon,
            rows: settings.gridRows,
            columns: settings.gridColumns,
            onSelection: { [weak self] gridRect in
                self?.handleSelection(gridRect)
            },
            onCancel: { [weak self] in
                self?.hideOverlay()
            }
        )

        overlay.onCancel = { [weak self] in
            self?.hideOverlay()
        }
        overlay.contentView = NSHostingView(rootView: view)
        overlay.show()
        overlayWindow = overlay
    }

    private func handleSelection(_ gridRect: GridRect) {
        guard let info = savedWindowInfo else { return }
        let settings = Settings.shared

        let targetFrame = WindowManager.calculateTargetFrame(
            gridRect: gridRect,
            screen: info.screen,
            rows: settings.gridRows,
            columns: settings.gridColumns
        )

        hideOverlay()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WindowManager.setWindowFrame(info.windowElement, frame: targetFrame)
        }
    }

    private func hideOverlay() {
        overlayWindow?.hide()
        overlayWindow = nil
        savedWindowInfo = nil
    }

    // MARK: - Preferences

    func openPreferences() {
        if let existing = preferencesWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "GridSnap Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = window
    }
}
