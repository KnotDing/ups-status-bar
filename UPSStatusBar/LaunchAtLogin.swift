import Foundation

struct LaunchAtLogin {

    private static var launchAgentDirectory: URL? {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("LaunchAgents")
    }

    private static var launchAgentURL: URL? {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.gemini.UPSStatusBar"
        return launchAgentDirectory?.appendingPathComponent("\(bundleID).plist")
    }

    private static var executablePath: String? {
        return Bundle.main.executablePath
    }

    private static func plistContent() -> String? {
        guard let executablePath = executablePath else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.gemini.UPSStatusBar"
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleID)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }

    static var isEnabled: Bool {
        guard let url = launchAgentURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func setEnabled(_ enabled: Bool) {
        guard let directory = launchAgentDirectory, let url = launchAgentURL else {
            print("Could not find LaunchAgents directory.")
            return
        }

        do {
            if enabled {
                guard let content = plistContent() else {
                    print("Could not get executable path for plist.")
                    return
                }
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                }
                try content.write(to: url, atomically: true, encoding: .utf8)
                print("Created Launch Agent at \(url.path)")
            } else {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    print("Removed Launch Agent from \(url.path)")
                }
            }
        } catch {
            print("Failed to update Launch Agent: \(error.localizedDescription)")
        }
    }
}
