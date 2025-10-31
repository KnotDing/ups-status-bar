import Combine
import Foundation
import IOKit.ps
import Network
import UserNotifications

class UPSMonitor: ObservableObject {
    @Published var upsInfo: [String: Any] = [: ]
    private var previousUPSInfo: [String: Any] = [: ]

    // State for shutdown logic
    private var onBatterySince: Date? = nil
    private var shutdownCommandIssued = false

    enum NUTError: Error {
        case connectionFailed, noGreeting, authFailed, parseFailed, invalidPort
    }

    private var timer: Timer?

    init(pollInterval: TimeInterval = 5.0) {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        DispatchQueue.global(qos: .utility).async {
            var currentUPSInfo: [String: Any] = [: ]
            
            if let blobRef = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
               let listRef = IOPSCopyPowerSourcesList(blobRef)?.takeRetainedValue() as? [CFTypeRef] {
                for ps in listRef {
                    if let desc = IOPSGetPowerSourceDescription(blobRef, ps)?.takeUnretainedValue() as? [String: Any] {
                        if let type = desc["Type"] as? String, type.lowercased().contains("ups") { currentUPSInfo = desc; break }
                        else if let name = desc[kIOPSNameKey as String] as? String, name.lowercased().contains("ups") { currentUPSInfo = desc; break }
                    }
                }
            }

            let nutHost = (UserDefaults.standard.string(forKey: "NUTHost") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !nutHost.isEmpty {
                let nutPort = UserDefaults.standard.integer(forKey: "NUTPort") > 0 ? UserDefaults.standard.integer(forKey: "NUTPort") : 3493
                let nutUser = UserDefaults.standard.string(forKey: "NUTUser") ?? ""
                let nutPassword = UserDefaults.standard.string(forKey: "NUTPassword") ?? ""
                let selectedUPS = UserDefaults.standard.string(forKey: "NUTSelectedUPS")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !selectedUPS.isEmpty {
                    let semaphore = DispatchSemaphore(value: 0)
                    self.fetchVarsForUPS(upsName: selectedUPS, host: nutHost, port: nutPort, user: nutUser, password: nutPassword) { result in
                        switch result {
                        case .success(let nutVars):
                            nutVars.forEach { currentUPSInfo[$0] = $1 }
                            if currentUPSInfo["NUTName"] == nil { currentUPSInfo["NUTName"] = selectedUPS }
                        case .failure(_):
                            currentUPSInfo["NUTReachable"] = false
                            currentUPSInfo["NUTName"] = selectedUPS
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                }
            }

            DispatchQueue.main.async {
                if let customName = UserDefaults.standard.string(forKey: "CustomUPSName"), !customName.isEmpty {
                    currentUPSInfo["NUTCustomName"] = customName
                }
                
                self.checkForStateChangesAndNotifications(newInfo: currentUPSInfo)
                self.checkForShutdown(newInfo: currentUPSInfo)

                self.upsInfo = currentUPSInfo
                self.previousUPSInfo = currentUPSInfo
            }
        }
    }

    private func checkForStateChangesAndNotifications(newInfo: [String: Any]) {
        let oldInfo = self.previousUPSInfo
        guard !oldInfo.isEmpty else { return }
        
        let newStatus = newInfo["NUTStatus"] as? String
        let oldStatus = oldInfo["NUTStatus"] as? String
        let newStatusIsOnBattery = newStatus?.contains("OB") == true
        let oldStatusWasOnBattery = oldStatus?.contains("OB") == true

        if newStatusIsOnBattery && !oldStatusWasOnBattery {
            self.onBatterySince = Date()
            print("UPS switched to battery power. Starting shutdown timer if configured.")
        } else if !newStatusIsOnBattery && oldStatusWasOnBattery {
            self.onBatterySince = nil
            self.shutdownCommandIssued = false
            print("UPS returned to line power. Resetting shutdown state.")
        }

        if UserDefaults.standard.bool(forKey: "notifyOnStatusChange"), newStatus != oldStatus, let new = newStatus, let old = oldStatus {
            sendNotification(title: "UPS 状态变化", body: "状态已从 \(old) 变为 \(new)。")
        }
        if let newCharge = newInfo["NUTCharge"] as? Int, let oldCharge = oldInfo["NUTCharge"] as? Int {
            if UserDefaults.standard.bool(forKey: "notifyOnLowBattery"), let threshold = Int(UserDefaults.standard.string(forKey: "lowBatteryThreshold") ?? "20"), oldCharge > threshold && newCharge <= threshold {
                sendNotification(title: "UPS 电量低", body: "当前电量为 \(newCharge)%，低于设定的 \(threshold)% 阈值。")
            }
            if UserDefaults.standard.bool(forKey: "notifyOnFullyCharged"), oldCharge < 100 && newCharge >= 100 {
                sendNotification(title: "UPS 已充满", body: "电池电量已达到 100%。")
            }
        }
        if let newLoad = newInfo["NUTLoadPercent"] as? Int, let oldLoad = oldInfo["NUTLoadPercent"] as? Int, UserDefaults.standard.bool(forKey: "notifyOnHighLoad"), let threshold = Int(UserDefaults.standard.string(forKey: "highLoadThreshold") ?? "90"), oldLoad < threshold && newLoad >= threshold {
            sendNotification(title: "UPS 负载过高", body: "当前负载为 \(newLoad)%，超过设定的 \(threshold)% 阈值。")
        }
    }

    private func checkForShutdown(newInfo: [String: Any]) {
        guard UserDefaults.standard.bool(forKey: "autoShutdownEnabled"), !shutdownCommandIssued else { return }
        let conditionIndex = UserDefaults.standard.integer(forKey: "shutdownConditionIndex")
        guard let valueString = UserDefaults.standard.string(forKey: "shutdownValue"), let value = Int(valueString) else { return }

        var shouldShutdown = false
        var reason = ""

        switch conditionIndex {
        case 0:
            if let onBatterySince = self.onBatterySince, Date().timeIntervalSince(onBatterySince) >= Double(value) * 60 {
                shouldShutdown = true
                reason = "断电已超过 \(value) 分钟"
            }
        case 1:
            if let charge = newInfo["NUTCharge"] as? Int, charge <= value {
                shouldShutdown = true
                reason = "电量已低于 \(value)%"
            }
        case 2:
            if let time = newInfo["NUTTimeRemaining"] as? Int, (time / 60) <= value {
                shouldShutdown = true
                reason = "剩余时间已少于 \(value) 分钟"
            }
        default: break
        }

        if shouldShutdown {
            let body = "UPS满足关机条件: \(reason)。系统将在5秒后关闭。"
            print("Shutdown condition met: \(body)")
            sendNotification(title: "自动关机", body: body)
            shutdownCommandIssued = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                AppleScriptRunner.shutDown()
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func probeRaw(host: String, port: Int, sendLines: [String], timeout: TimeInterval, completion: @escaping (Result<String, Error>) -> Void) {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { completion(.failure(NUTError.invalidPort)); return }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let conn = NWConnection(to: endpoint, using: params)
        let queue = DispatchQueue.global(qos: .utility)
        var accumulated = ""
        var finished = false
        let startDate = Date()
        func finishWithSuccess(_ response: String) { if finished { return }; finished = true; conn.cancel(); completion(.success(response)) }
        func finishWithFailure(_ error: Error) { if finished { return }; finished = true; conn.cancel(); completion(.failure(error)) }
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                for line in sendLines { conn.send(content: (line + "\n").data(using: .utf8), completion: .contentProcessed({ _ in })) }
                func receiveLoop() {
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
                        if let err = error { finishWithFailure(err); return }
                        if let d = data, !d.isEmpty, let s = String(data: d, encoding: .utf8) { accumulated += s }
                        if Date().timeIntervalSince(startDate) < timeout && !isComplete { receiveLoop() } else { finishWithSuccess(accumulated) }
                    }
                }
                receiveLoop()
            case .failed(let err): finishWithFailure(err)
            case .cancelled: if !finished { finishWithSuccess(accumulated) }
            default: break
            }
        }
        conn.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout + 0.5) { if !finished { finishWithSuccess(accumulated) } }
    }

    func fetchVarsForUPS(upsName: String, host: String, port: Int, user: String, password: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var sendLines: [String] = []
        if !user.isEmpty && !password.isEmpty { sendLines.append("LOGIN \(user) \(password)"); sendLines.append("USERNAME \(user)"); sendLines.append("PASSWORD \(password)") }
        sendLines.append("LIST VAR \(upsName)")
        let probeVars = ["battery.charge", "battery.runtime", "runtime", "ups.status", "device.model", "device.mfr", "ups.model", "ups.mfr", "battery.voltage", "input.voltage", "output.voltage", "load.percent", "ups.power.nominal"]
        for v in probeVars { sendLines.append("GET VAR \(upsName) \(v)") }
        probeRaw(host: host, port: port, sendLines: sendLines, timeout: 3.0) { res in
            switch res {
            case .failure(let err): completion(.failure(err))
            case .success(let response):
                let parsed = Self.parseVars(from: response, upsName: upsName)
                if parsed.isEmpty { completion(.success(["NUTReachable": true, "NUTBanner": response])) } else { var out = parsed; out["NUTReachable"] = true; completion(.success(out)) }
            }
        }
    }

    func discoverUPS(host: String, port: Int, user: String, password: String, completion: @escaping ([String]) -> Void) {
        func parseNames(from response: String) -> [String] {
            var found = Set<String>()
            let lines = response.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            var inBlock = false
            for line in lines {
                if line.hasPrefix("BEGIN LIST UPS") { inBlock = true; continue }
                if line.hasPrefix("END LIST UPS") { inBlock = false; continue }
                if line.hasPrefix("UPS ") { let comps = line.components(separatedBy: " "); if comps.count >= 2 { found.insert(comps[1]) } }
                else if line.hasPrefix("VAR ") { let comps = line.components(separatedBy: " "); if comps.count >= 2 { found.insert(comps[1]) } }
                else if inBlock { let token = line.split(separator: " ").first.map(String.init) ?? line; if !token.isEmpty { found.insert(token) } }
                else { let token = line.split(separator: " ").first.map(String.init) ?? line; if token.range(of: "[A-Za-z0-9_-]+", options: .regularExpression) != nil { found.insert(token) } }
            }
            return Array(found).filter { !$0.lowercased().contains("err") && !$0.lowercased().contains("ok") }.sorted()
        }
        var authLines: [String] = []
        if !user.isEmpty && !password.isEmpty { authLines = ["LOGIN \(user) \(password)", "USERNAME \(user)", "PASSWORD \(password)"] }
        let probes = [authLines + ["LIST UPS"], authLines + ["LIST VAR"], authLines + ["LIST UPS"]]
        let timeouts: [TimeInterval] = [2.0, 2.0, 4.0]
        func attempt(index: Int) {
            if index >= probes.count { completion([]); return }
            let sendLines = probes[index]
            let timeout = timeouts[index]
            probeRaw(host: host, port: port, sendLines: sendLines, timeout: timeout) { result in
                switch result {
                case .failure(_): attempt(index: index + 1)
                case .success(let response): let names = parseNames(from: response); if !names.isEmpty { completion(names) } else { attempt(index: index + 1) }
                }
            }
        }
        attempt(index: 0)
    }

    private static func parseVars(from response: String, upsName: String) -> [String: Any] {
        var results: [String: Any] = [: ]
        let lines = response.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for line in lines {
            if line.hasPrefix("VAR ") {
                let comps = line.components(separatedBy: " ")
                if comps.count >= 4 {
                    let ups = comps[1], varName = comps[2]; guard ups == upsName else { continue }
                    var rawValue = comps[3...].joined(separator: " "); if rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") { rawValue.removeFirst(); rawValue.removeLast() }
                    let lowerVar = varName.lowercased()
                    if lowerVar.contains("charge") { results["NUTCharge"] = Int(Double(rawValue.filter("0123456789.".contains)) ?? 0) }
                    else if lowerVar.contains("runtime") || lowerVar.contains("time") { results["NUTTimeRemaining"] = Int(Double(rawValue.filter("0123456789.".contains)) ?? 0) }
                    else if lowerVar.contains("status") { results["NUTStatus"] = rawValue }
                    else if lowerVar.contains("model") || lowerVar.contains("product") { results["NUTModel"] = rawValue }
                    else if lowerVar.contains("vendor") || lowerVar.contains("mfr") { results["NUTVendor"] = rawValue }
                    else if lowerVar.contains("load") { results["NUTLoadPercent"] = Int(Double(rawValue.filter("0123456789.".contains)) ?? 0) }
                    else { results["NUT.\(varName)"] = rawValue }
                    results["NUTName"] = upsName
                }
            } else if line.hasPrefix("UPS ") { let comps = line.components(separatedBy: " "); if comps.count >= 2 { results["NUTName"] = comps[1] } }
            else { if results["NUTBanner"] == nil { results["NUTBanner"] = line } }
        }
        return results
    }
}
