import Carbon
import Cocoa

class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var callback: (() -> Void)?
    private var isRegistered = false

    private static let hotkeyID = EventHotKeyID(
        signature: OSType(0x47534E50), // "GSNP"
        id: 1
    )

    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        unregister()
        self.callback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                // Dispatch to main thread before reading any mutable state
                // to avoid data races with register/unregister on main thread
                DispatchQueue.main.async {
                    guard manager.isRegistered else { return }
                    manager.callback?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else { return }

        var ref: EventHotKeyRef?
        let hotkeyID = HotkeyManager.hotkeyID
        let hotkeyStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if hotkeyStatus == noErr {
            hotKeyRef = ref
            isRegistered = true
        } else {
            // Clean up event handler if hotkey registration failed
            if let handler = eventHandlerRef {
                RemoveEventHandler(handler)
                eventHandlerRef = nil
            }
        }
    }

    func unregister() {
        isRegistered = false
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        callback = nil
    }

    deinit {
        unregister()
    }
}
