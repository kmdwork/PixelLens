// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DPIInspectorApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DPIInspectorApp",
            targets: ["DPIInspectorApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DPIInspectorApp",
            dependencies: ["AppCore", "DPIEngine"],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .target(
            name: "AppCore",
            dependencies: ["DPIEngine"],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .target(
            name: "DPIEngine",
            publicHeadersPath: "include"
        )
    ],
    swiftLanguageModes: [.v6]
)
