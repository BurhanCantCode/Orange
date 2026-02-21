// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OrangeApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OrangeApp", targets: ["OrangeApp"])
    ],
    targets: [
        .executableTarget(
            name: "OrangeApp",
            path: "Sources/OrangeApp"
        ),
        .testTarget(
            name: "OrangeAppTests",
            dependencies: ["OrangeApp"],
            path: "Tests/OrangeAppTests"
        )
    ]
)
