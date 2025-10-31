import Cocoa
import Combine

class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var monitor: UPSMonitor
    private var cancellable: AnyCancellable?

    init(popover: NSPopover, monitor: UPSMonitor) {
        self.popover = popover
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        cancellable = monitor.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        
        updateStatusItem() // Initial update
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let showDetails = UserDefaults.standard.bool(forKey: "showStatusInMenuBar")

        if showDetails {
            let charge = monitor.upsInfo["NUTCharge"] as? Int ?? monitor.upsInfo["Charge"] as? Int
            let status = monitor.upsInfo["NUTStatus"] as? String ?? monitor.upsInfo["Status"] as? String ?? ""

            var statusText = ""
            if let charge = charge {
                statusText += "\(charge)%"
            }
            
            if !status.isEmpty {
                let statusSymbol = status.contains("OB") ? "⚡️" : "🔌"
                statusText += " \(statusSymbol)"
            }

            button.title = statusText.isEmpty ? "UPS" : statusText
            button.image = nil
        } else {
            if let image = NSImage(systemSymbolName: "bolt.horizontal", accessibilityDescription: NSLocalizedString("UPS", comment: "Accessibility description for UPS status icon")) {
                image.isTemplate = true
                button.image = image
                button.title = ""
            } else {
                button.title = NSLocalizedString("UPS", comment: "Fallback title for UPS status icon")
                button.image = nil
            }
        }
    }
}