// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "StoryKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "StoryKit", targets: ["StoryKit"]),
    ],
    targets: [
        // All logic lives here so it is testable via `swift test` (CLAUDE.md).
        .target(name: "StoryKit"),
        // Uses Swift Testing (bundled with the toolchain), NOT XCTest.
        .testTarget(
            name: "StoryKitTests",
            dependencies: ["StoryKit"]
        ),
    ]
)
