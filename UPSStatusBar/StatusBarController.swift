import Cocoa

class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover

    init(popover: NSPopover) {
        self.popover = popover
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use an SF Symbol if available (macOS 11+). Fallback: set title.
            if let image = NSImage(
                systemSymbolName: "bolt.horizontal", accessibilityDescription: "UPS")
            {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "UPS"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            // Show the popover. The popover's behavior (e.g. .transient for auto-closing)
            // is configured in AppDelegate.
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Directly make the popover's window key to handle focus correctly.
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
    }
}
