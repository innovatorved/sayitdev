// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SayItDevCoreConsumer",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(name: "sayitdev", path: "../../../../"),
    ],
    targets: [
        .executableTarget(
            name: "sayitdevcore-consumer",
            dependencies: [
                .product(name: "SayItDevCore", package: "sayitdev"),
            ]
        )
    ]
)
