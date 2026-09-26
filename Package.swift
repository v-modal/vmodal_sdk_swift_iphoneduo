// swift-tools-version: 5.10
// SDK release: 1.2.6

import PackageDescription

let package = Package(
    name: "VModalSDK",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "VModalSDK", targets: ["VModalSDK"]),
        .executable(name: "RouteSync", targets: ["RouteSync"]),
        .executable(name: "ReleaseManifest", targets: ["ReleaseManifest"]),
        .executable(name: "SDKSimulation", targets: ["SDKSimulation"]),
        .executable(name: "LiveTest", targets: ["LiveTest"]),
        .executable(name: "LiveCCTVTest", targets: ["LiveCCTVTest"]),
        .executable(name: "PerformanceBenchmark", targets: ["PerformanceBenchmark"]),
    ],
    targets: [
        .target(
            name: "VModalSDK",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(name: "RouteSync", dependencies: ["VModalSDK"], path: "Tools/RouteSync"),
        .executableTarget(name: "ReleaseManifest", dependencies: ["VModalSDK"], path: "Tools/ReleaseManifest"),
        .executableTarget(name: "SDKSimulation", dependencies: ["VModalSDK"], path: "Tools/SDKSimulation"),
        .executableTarget(name: "LiveTest", dependencies: ["VModalSDK"], path: "Tools/LiveTest"),
        .executableTarget(name: "LiveCCTVTest", dependencies: ["VModalSDK"], path: "Tools/LiveCCTVTest"),
        .executableTarget(name: "PerformanceBenchmark", dependencies: ["VModalSDK"], path: "Tools/PerformanceBenchmark"),
        .testTarget(
            name: "VModalSDKTests",
            dependencies: ["VModalSDK"],
            resources: [.process("Fixtures")]
        ),
    ]
)
