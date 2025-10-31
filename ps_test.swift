#!/usr/bin/env swift
import Foundation
import IOKit.ps

/*
 Small CLI test to print power source info using IOKit Power Sources API.

 Usage:
   swift run (or compile with `swiftc`) and run:
     ./ps_test.swift            # prints once
     ./ps_test.swift --watch 5  # poll every 5 seconds

 This script is intentionally small and dependency-free to help debug power source / UPS detection.
*/

func string(from value: Any?) -> String {
    guard let v = value else { return "-" }
    if let s = v as? String { return s }
    if let i = v as? Int { return String(i) }
    if let d = v as? Double { return String(d) }
    return String(describing: v)
}

func prettyPrintPowerSource(_ desc: [String: Any]) {
    // Try common keys (some constants may not be available in all build environments)
    let name = desc["Name"] as? String ?? desc[kIOPSNameKey as String] as? String ?? "Unknown"
    let type =
        desc["Type"] as? String ?? desc["Power Source Type"] as? String ?? desc[
            kIOPSPowerSourceTypeKey as String] as? String ?? "Unknown"
    let state =
        desc["Power Source State"] as? String ?? desc[kIOPSPowerSourceStateKey as String] as? String
        ?? "-"
    let current =
        desc["Current Capacity"] as? Int ?? desc[kIOPSCurrentCapacityKey as String] as? Int
    let max = desc["Max Capacity"] as? Int ?? desc[kIOPSMaxCapacityKey as String] as? Int
    let percent =
        desc["PercentCharge"] as? Int
        ?? {
            if let c = current, let m = max, m > 0 {
                return Int((Double(c) / Double(m)) * 100.0)
            }
            return nil
        }()

    let timeToEmpty = desc["Time to Empty"] as? Int ?? desc[kIOPSTimeToEmptyKey as String] as? Int
    let timeToFull =
        desc["Time to Full Charge"] as? Int ?? desc[kIOPSTimeToFullChargeKey as String] as? Int

    print("-----------")
    print("Name:   \(name)")
    print("Type:   \(type)")
    print("State:  \(state)")
    if let cur = current, let m = max {
        print("Capacity: \(cur) / \(m) (\(percent.map{ "\($0)%" } ?? "-"))")
    } else if let p = percent {
        print("Charge: \(p)%")
    } else {
        print("Capacity: -")
    }
    if let t = timeToEmpty {
        print("Time to empty: \(t) min")
    } else if let t = timeToFull {
        print("Time to full: \(t) min")
    } else {
        print("Time: -")
    }

    // Print any other useful keys (filtered)
    let usefulKeys = ["Manufacturer", "Serial Number", "Vendor", "Product"]
    for k in usefulKeys {
        if let v = desc[k] {
            print("\(k): \(string(from: v))")
        }
    }
}

func fetchAndPrintPowerSources() {
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
        print("Unable to copy power sources info.")
        return
    }

    guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
        print("Unable to get power sources list.")
        return
    }

    if list.isEmpty {
        print("No power sources found.")
        return
    }

    var foundAny = false
    for ps in list {
        if let cfd = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue()
            as? [String: Any]
        {
            prettyPrintPowerSource(cfd)
            foundAny = true
        }
    }

    if !foundAny {
        print("No describable power sources.")
    }

    // Additionally, print summary of system power sources snapshot (optional)
    if let summary = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as? String {
        print("Providing power source type (system): \(summary)")
    }
}

enum CLI {
    static func usage() {
        let name = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "ps_test"
        print(
            """
            Usage:
              \(name) [--watch seconds]

            Options:
              --watch <seconds>   Poll every N seconds (float allowed). Default: once.
            """)
    }
}

func main() {
    var watchInterval: TimeInterval? = nil
    let args = CommandLine.arguments
    if args.contains("--help") || args.contains("-h") {
        CLI.usage()
        exit(0)
    }
    if let idx = args.firstIndex(of: "--watch"), idx + 1 < args.count {
        if let n = Double(args[idx + 1]) {
            watchInterval = n
        } else {
            print("Invalid watch interval: \(args[idx + 1])")
            CLI.usage()
            exit(2)
        }
    }

    if let interval = watchInterval {
        print("Polling every \(interval) seconds. Press Ctrl-C to stop.")
        while true {
            fetchAndPrintPowerSources()
            // flush stdout
            fflush(stdout)
            Thread.sleep(forTimeInterval: interval)
            print("")  // blank line between iterations
        }
    } else {
        fetchAndPrintPowerSources()
    }
}

main()
