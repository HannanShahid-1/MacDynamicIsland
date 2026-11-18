// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacBookDynamicIslandApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacBookDynamicIslandApp",
            targets: ["MacBookDynamicIslandApp"]
        )
    ],
    targets: [
        .target(
            name: "MacBookDynamicIslandCore"
        ),
        .executableTarget(
            name: "MacBookDynamicIslandApp",
            dependencies: ["MacBookDynamicIslandCore"]
        ),
        .testTarget(
            name: "MacBookDynamicIslandCoreTests",
            dependencies: ["MacBookDynamicIslandCore"]
        ),
        .testTarget(
            name: "MacBookDynamicIslandAppTests",
            dependencies: ["MacBookDynamicIslandApp", "MacBookDynamicIslandCore"]
        )
    ]
)
