import SwiftUI
import Carbon

struct PreferencesView: View {
    @ObservedObject var settings = Settings.shared

    var body: some View {
        Form {
            Section("Grid Dimensions") {
                Stepper("Rows: \(settings.gridRows)", value: $settings.gridRows, in: 2...20)
                Stepper("Columns: \(settings.gridColumns)", value: $settings.gridColumns, in: 2...20)
            }

            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.updateLaunchAtLogin($0) }
                ))
            }

            Section("Hotkey") {
                HotkeyRecorderView(settings: settings)
                    .frame(height: 28)
            }

            Section {
                Button("Reset to Defaults") {
                    settings.gridRows = 6
                    settings.gridColumns = 6
                    settings.hotkeyKeyCode = UInt32(kVK_Space)
                    settings.hotkeyModifiers = UInt32(controlKey) | UInt32(optionKey)
                    NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 320)
        .onAppear { settings.refreshLaunchAtLogin() }
    }
}
