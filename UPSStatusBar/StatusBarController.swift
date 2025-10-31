import Cocoa
import Combine

class StatusBarController: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem
    private var window: NSWindow
    private var monitor: UPSMonitor
    private var cancellable: AnyCancellable?
    private var eventMonitor: Any?

    init(window: NSWindow, monitor: UPSMonitor) {
        self.window = window
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.action = #selector(toggleWindow(_:))
            button.target = self
        }

        cancellable = monitor.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }

        window.delegate = self
        updateStatusItem()  // Initial update
    }

    @objc func toggleWindow(_ sender: Any?) {
        if window.isVisible {
            window.orderOut(sender)
            removeEventMonitor()
        } else {
            positionWindow()
            window.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
            addEventMonitor()
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeEventMonitor()
    }

    private func positionWindow() {
        guard let button = statusItem.button else { return }
        let buttonFrame = button.window!.convertToScreen(button.frame)

        let view = window.contentView!
        let windowSize = view.fittingSize
        window.setFrame(NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height), display: true)

        var windowFrame = window.frame
        windowFrame.origin.x = buttonFrame.origin.x + (buttonFrame.width - windowFrame.width) / 2
        windowFrame.origin.y = buttonFrame.origin.y - windowFrame.height

        window.setFrame(windowFrame, display: true)
    }

    private func addEventMonitor() {
        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return }
                if self.window.isVisible, event.windowNumber != self.window.windowNumber {
                    self.window.orderOut(nil)
                    self.removeEventMonitor()
                }
            }
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
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
                    let powerInWatts: String
                    if let nominalPowerString = monitor.upsInfo["NUT.ups.power.nominal"] as? String,
                       let nominalPower = Double(nominalPowerString), nominalPower > 0 {
                        let calculatedPower = nominalPower * (Double(load) / 100.0)
                        powerInWatts = String(format: "%.0fW", calculatedPower)
                    } else {
                        powerInWatts = "\(load)%"
                    }
                    statusParts.append(powerInWatts)
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
