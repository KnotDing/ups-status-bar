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
}
