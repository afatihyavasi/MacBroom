// swift-tools-version:5.9
import PackageDescription

// Architecture:
//   MacBroomCore     — dependency-free, testable logic (engine protocol models,
//                      EngineBridge, formatting). No SwiftUI.
//   MacBroom         — the SwiftUI MenuBarExtra app (@main), imports the core.
//   MacBroomSelfTest — a framework-free executable test runner that works even
//                      with only Command Line Tools installed (no full Xcode),
//                      which is our CI/dev baseline. Run: `swift run MacBroomSelfTest`.
let package = Package(
    name: "MacBroom",
    platforms: [
        .macOS(.v13) // MenuBarExtra requires macOS 13+
    ],
    // Sparkle temporarily removed while diagnosing the menu-bar click regression
    // (clicks broke when auto-update landed). Re-add once confirmed unrelated.
    targets: [
        .target(
            name: "MacBroomCore",
            path: "Sources/MacBroomCore"
        ),
        .executableTarget(
            name: "MacBroom",
            dependencies: ["MacBroomCore"],
            path: "Sources/MacBroom"
        ),
        .executableTarget(
            name: "MacBroomSelfTest",
            dependencies: ["MacBroomCore"],
            path: "Sources/MacBroomSelfTest"
        )
    ]
)
