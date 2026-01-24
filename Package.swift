// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraDemo",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .executable(name: "CameraDemo", targets: ["CameraDemo"])
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        .target(
            name: "JuliaKit",
            path: "Sources/JuliaKit",
            exclude: [
                "Filters/JuliaWarp.ci.metal",
            ],
            resources: [
                .copy("Filters/JuliaWarp.ci.metallib"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        ),
        .executableTarget(
            name: "CameraDemo",
            dependencies: ["JuliaKit"],
            path: "Sources/CameraDemo",
            swiftSettings: [
                .define("ENABLE_AVFOUNDATION")
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"], .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "JuliaKitTests",
            dependencies: ["JuliaKit"],
            path: "Tests/JuliaKitTests",
            linkerSettings: [
                .linkedFramework("CoreImage"),
            ]
        ),
    ]
)
