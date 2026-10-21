// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlideFix",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GlideFixCore",
            targets: ["GlideFixCore"]
        ),
        .executable(
            name: "GlideFix",
            targets: ["GlideFixApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GlideFixCore",
            dependencies: [],
            path: "Sources/GlideFixCore"
        ),
        .executableTarget(
            name: "GlideFixApp",
            dependencies: ["GlideFixCore"],
            path: "Sources/GlideFixApp",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "GlideFixTests",
            dependencies: ["GlideFixCore"],
            path: "Tests/GlideFixTests"
        )
    ]
)
