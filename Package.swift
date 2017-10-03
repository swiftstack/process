// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Process",
    products: [
        .library(name: "Process", targets: ["Process"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-stack/platform.git",
            from: "0.4.0"),
        .package(
            url: "https://github.com/swift-stack/async.git",
            from: "0.4.0"),
        .package(
            url: "https://github.com/swift-stack/test.git",
            from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "Process",
            dependencies: ["Platform", "Async"]),
        .testTarget(
            name: "ProcessTests",
            dependencies: ["Process", "Test", "AsyncDispatch"]),
    ]
)
