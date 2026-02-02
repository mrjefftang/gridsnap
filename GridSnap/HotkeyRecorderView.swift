import SwiftUI
import Carbon

struct HotkeyRecorderView: NSViewRepresentable {
    @ObservedObject var settings: Settings

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.settings = settings
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.settings = settings
        nsView.needsDisplay = true
    }
}

class HotkeyRecorderNSView: NSView {
    var settings: Settings?
    private var isRecording = false
    private var monitor: Any?

    deinit {
        stopRecording()
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 200, height: 28) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bg: NSColor = isRecording ? .controlAccentColor.withAlphaComponent(0.15) : .controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        path.fill()

        let border: NSColor = isRecording ? .controlAccentColor : .separatorColor
        border.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text: String
        if isRecording {
            text = "Press shortcut…"
        } else {
            text = settings?.hotkeyDisplayName ?? "Click to record"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        str.draw(at: point)
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Remove any existing monitor before creating a new one
        if monitor != nil { stopRecording() }
        isRecording = true
        needsDisplay = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedKey(event)
            return nil // consume the event
        }
    }

    private func stopRecording() {
        isRecording = false
        needsDisplay = true
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handleRecordedKey(_ event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        // Require at least one modifier (Ctrl, Option, Cmd, or Shift)
        let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !mods.isEmpty else { return }

        let carbonMods = Settings.carbonModifiers(from: mods)

        guard let settings = settings else {
            stopRecording()
            return
        }

        settings.hotkeyKeyCode = UInt32(event.keyCode)
        settings.hotkeyModifiers = carbonMods

        stopRecording()

        // Notify that hotkey changed so AppDelegate re-registers
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
    }
}

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
}
