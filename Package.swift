// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ScanMasterCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ScanMasterCore", targets: ["ScanMasterCore"])
    ],
    targets: [
        .target(
            name: "ScanMasterCore",
            path: "ScanMasterAI/Domain"
        ),
        .testTarget(
            name: "ScanMasterCoreTests",
            dependencies: ["ScanMasterCore"],
            path: "ScanMasterAITests/Core"
        )
    ]
)
