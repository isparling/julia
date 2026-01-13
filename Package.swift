// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraDemo",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "CameraDemo", targets: ["CameraDemo"])
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        .executableTarget(
            name: "CameraDemo",
            dependencies: [],
            swiftSettings: [
                .define("ENABLE_AVFOUNDATION")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        )
    ]
)
