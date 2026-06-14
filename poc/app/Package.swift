// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "app",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "app",
            targets: ["app"]
        )
    ],
    targets: [
        .executableTarget(
            name: "app",
            dependencies: ["JPEGStructureParser"],
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
            name: "JPEGStructureParser",
            publicHeadersPath: "include"
        )
    ],
    swiftLanguageModes: [.v6]
)
