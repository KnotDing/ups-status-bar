import Foundation

struct AppleScriptRunner {
    static func run(script: String) -> Bool {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
                return false
            } else {
                print("AppleScript executed successfully.")
                return true
            }
        }
        return false
    }

    static func shutDown() {
        print("Executing shutdown AppleScript...")
        // Using `sudo` is not feasible. This script asks the system to shut down gracefully.
        let script = "tell application \"System Events\" to shut down"
        _ = run(script: script)
    }

    static func runShellScript(path: String) {
        print("Executing custom shutdown script at \(path)...")
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = [path]
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            print("Custom shutdown script failed with exit code \(task.terminationStatus).")
        } else {
            print("Custom shutdown script executed successfully.")
        }
    }
}
