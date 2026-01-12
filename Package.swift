// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraDemo",
    platforms: [
        .macOS(.v13)  // Adjust if you need older macOS
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
                .define("ENABLE_AVFOUNDATION")  // optional, just a flag
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Cocoa"),
                .linkedFramework("SwiftUI"),
            ]
        )
    ]
)
