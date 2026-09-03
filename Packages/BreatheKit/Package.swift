// swift-tools-version: 5.10
//
// Manifest used by Swift 5.10 toolchains (Linux CI without Swift 6, older Xcode).
// Swift 6.0+ toolchains and Xcode 16+ pick up Package@swift-6.0.swift instead,
// which builds the same targets in Swift 6 language mode.
import PackageDescription

let package = Package(
    name: "BreatheKit",
    platforms: [
        .iOS("18.0"),
        .macOS("15.0"),
        .watchOS("11.0"),
    ],
    products: [
        .library(name: "BreatheKit", targets: ["BreatheKit"]),
        .executable(name: "breathe-sim", targets: ["breathe-sim"]),
    ],
    targets: [
        .target(
            name: "BreatheKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "breathe-sim",
            dependencies: ["BreatheKit"]
        ),
        .testTarget(
            name: "BreatheKitTests",
            dependencies: ["BreatheKit"]
        ),
    ]
)
