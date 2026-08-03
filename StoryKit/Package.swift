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
        // Reviewer role prompts are authored as Markdown resources, loaded via
        // Bundle.module (see Reviewers/Prompt.swift).
        .target(
            name: "StoryKit",
            resources: [.process("Reviewers/Prompts")]
        ),
        // Uses Swift Testing (bundled with the toolchain), NOT XCTest.
        .testTarget(
            name: "StoryKitTests",
            dependencies: ["StoryKit"]
        ),
    ]
)
