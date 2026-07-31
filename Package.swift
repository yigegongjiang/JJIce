// swift-tools-version:6.2
import PackageDescription

// Code-only AppKit executable: no xcodeproj, no Storyboard, no third-party dependencies.
// scripts/build-app.sh turns the built binary into jj-ice.app (Info.plist + icon + ad-hoc signature);
// SwiftPM alone cannot emit an .app bundle.
// defaultIsolation(MainActor): AppKit runs entirely on the main thread, so Swift 6 concurrency
// checking passes without annotating every call site.
let package = Package(
    name: "jj-ice",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "jj-ice",
            path: "Sources/jj-ice",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
