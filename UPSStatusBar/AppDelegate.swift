import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var popover = NSPopover()
    var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to make it a status bar app without a Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }

        let monitor = UPSMonitor()

        // Create the SwiftUI content and inject UPSMonitor as environment object
        let contentView = ContentView()
            .environmentObject(monitor)

        // popover.contentSize = NSSize(width: 320, height: 160) // Removed for dynamic sizing
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        statusBarController = StatusBarController(popover: popover, monitor: monitor)
    }
}
