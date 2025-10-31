import SwiftUI

@main
struct StatusBarUPSApp: App {
    // Use an AppDelegate to setup the NSStatusItem / popover
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — keep app in menu bar; provide an empty Settings scene to satisfy SwiftUI
        Settings {
            EmptyView()
        }
    }
}
