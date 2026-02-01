import SwiftUI

@main
struct GridSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = Settings.shared

    var body: some Scene {
        MenuBarExtra("GridSnap", systemImage: "square.grid.3x3") {
            Text("Grid: \(settings.gridRows) × \(settings.gridColumns)")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Launch at Login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.updateLaunchAtLogin($0) }
            ))

            Divider()

            Button("Preferences...") {
                appDelegate.openPreferences()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit GridSnap") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
