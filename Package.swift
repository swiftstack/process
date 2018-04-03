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
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/time.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/async.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/test.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/fiber.git",
            .branch("master"))
    ],
    targets: [
        .target(
            name: "Process",
            dependencies: ["Platform", "Time", "Async"]),
        .testTarget(
            name: "ProcessTests",
            dependencies: ["Process", "Test", "Fiber"])
    ]
)
