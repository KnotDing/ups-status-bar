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

        updateStatusItem()  // Initial update
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
            var statusParts: [String] = []

            if UserDefaults.standard.bool(forKey: "showStatusSymbolInMenuBar") {
                if let status = monitor.upsInfo["NUTStatus"] as? String ?? monitor.upsInfo["Status"]
                    as? String
                {
                    let statusSymbol = status.contains("OB") ? "⚡️" : "🔌"
                    statusParts.append(statusSymbol)
                }
            }

            if UserDefaults.standard.bool(forKey: "showChargeInMenuBar") {
                if let charge = monitor.upsInfo["NUTCharge"] as? Int ?? monitor.upsInfo["Charge"]
                    as? Int
                {
                    statusParts.append("\(charge)%")
                }
            }

            if UserDefaults.standard.bool(forKey: "showTimeRemainingInMenuBar") {
                if let timeInSeconds = monitor.upsInfo["NUTTimeRemaining"] as? Int {
                    statusParts.append(formatSecondsToHMS(timeInSeconds))
                }
            }

            if UserDefaults.standard.bool(forKey: "showLoadInMenuBar") {
                if let load = monitor.upsInfo["NUTLoadPercent"] as? Int {
                    let powerText: String = {
                        if let nominalPowerString = monitor.upsInfo["NUT.ups.power.nominal"]
                            as? String,
                            let nominalPower = Double(nominalPowerString)
                        {
                            let powerInWatts = nominalPower * (Double(load) / 100.0) * 0.8
                            return String(format: "%.0fW", powerInWatts)
                        }
                        return ""
                    }()
                    statusParts.append("\(powerText)")
                }
            }

            let statusText = statusParts.joined(separator: " ")
            button.title = statusText.isEmpty ? "UPS" : statusText
            button.image = nil
        } else {
            if let image = NSImage(
                systemSymbolName: "bolt.horizontal",
                accessibilityDescription: NSLocalizedString(
                    "UPS", comment: "Accessibility description for UPS status icon"))
            {
                image.isTemplate = true
                button.image = image
                button.title = ""
            } else {
                button.title = NSLocalizedString(
                    "UPS", comment: "Fallback title for UPS status icon")
                button.image = nil
            }
        }
    }

    private func formatSecondsToHMS(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
