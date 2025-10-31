// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "NUT",
    platforms: [
        // SwiftUI App + Status Bar API require macOS 11.0+ in this codebase
        .macOS(.v11)
    ],
    products: [
        // Build an executable bundle you can run with `swift run UPSStatusBar`
        .executable(
            name: "UPSStatusBar",
            targets: ["UPSStatusBar"]
        )
    ],
    targets: [
        // The app sources live in the `UPSStatusBar` directory
        .executableTarget(
            name: "UPSStatusBar",
            path: "UPSStatusBar",
            exclude: ["Info.plist"],
            resources: [
                .copy("Contents/Resources/AppIcon.icns"),
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ]),
            ]
        )
    ]
)
