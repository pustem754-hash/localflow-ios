// swift-tools-version:5.10
// Ядро LocalFlow: логика, которую можно проверить без iPhone (R41). Только Foundation.
import PackageDescription

let package = Package(
    name: "LocalFlowCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "LocalFlowCore", targets: ["LocalFlowCore"]),
    ],
    targets: [
        .target(name: "LocalFlowCore"),
        .testTarget(name: "LocalFlowCoreTests", dependencies: ["LocalFlowCore"]),
    ]
)
