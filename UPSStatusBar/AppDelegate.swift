import Cocoa
import SwiftUI
import UserNotifications

class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to make it a status bar app without a Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            granted, error in
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

        // Create a borderless window to act as a popover
        window = KeyWindow(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.85

        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .menu
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20.0
        visualEffectView.layer?.masksToBounds = true

        window.contentView = visualEffectView

        let hostingView = NSHostingView(rootView: contentView)
        visualEffectView.addSubview(hostingView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])

        window.level = .floating
        window.collectionBehavior = .canJoinAllSpaces

        statusBarController = StatusBarController(window: window, monitor: monitor)
    }
}
