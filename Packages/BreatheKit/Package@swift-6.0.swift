// swift-tools-version: 6.0
//
// Manifest used by Swift 6.0+ toolchains (Xcode 16 and later). Builds the same
// targets as Package.swift, in Swift 6 language mode with strict concurrency.
import PackageDescription

let package = Package(
    name: "BreatheKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "BreatheKit", targets: ["BreatheKit"]),
        .executable(name: "breathe-sim", targets: ["breathe-sim"]),
    ],
    targets: [
        .target(name: "BreatheKit"),
        .executableTarget(
            name: "breathe-sim",
            dependencies: ["BreatheKit"]
        ),
        .testTarget(
            name: "BreatheKitTests",
            dependencies: ["BreatheKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
