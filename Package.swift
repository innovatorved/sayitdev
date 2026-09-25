// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "sayitdev",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SayItDevCore", targets: ["SayItDevCore"]),
        .executable(name: "dev", targets: ["dev"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.6"),
        // lesbar: shared on-device file -> text (Vision OCR + PDFKit) + image
        // classification. Owns the -f/pipe extraction stack so it is maintained once
        // (also consumed by auge). Framework-bearing target used only by the executable.
        .package(url: "https://github.com/Arthur-Ficial/lesbar.git", from: "0.3.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CReadline",
            path: "Sources/CReadline"
        ),
        // Pure-logic library — no FoundationModels, testable
        .target(
            name: "SayItDevCore",
            dependencies: [],
            path: "Sources/Core"
        ),
        // CLI argument parsing — depends on SayItDevCore for ContextStrategy
        .target(
            name: "SayItDevCLI",
            dependencies: ["SayItDevCore"],
            path: "Sources/CLI"
        ),
        // Main executable — depends on SayItDevCore + SayItDevCLI + Hummingbird + FoundationModels
        .executableTarget(
            name: "dev",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                "SayItDevCore",
                "SayItDevCLI",
                "CReadline",
                .product(name: "Lesbar", package: "lesbar"),
                .product(name: "LesbarCore", package: "lesbar"),
            ],
            path: "Sources",
            exclude: ["Core", "CLI"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ])
            ]
        ),
        // Test runner — pure Swift, no XCTest/Testing (Command Line Tools only)
        .executableTarget(
            name: "sayitdev-tests",
            dependencies: ["SayItDevCore", "SayItDevCLI"],
            path: "Tests/sayitdevTests"
        ),
        .executableTarget(
            name: "sayitdevcore-context-strategies-example",
            dependencies: ["SayItDevCore"],
            path: "Examples/ContextStrategies"
        ),
        .executableTarget(
            name: "sayitdevcore-openai-types-example",
            dependencies: ["SayItDevCore"],
            path: "Examples/OpenAITypes"
        ),
        .executableTarget(
            name: "sayitdevcore-tool-calling-example",
            dependencies: ["SayItDevCore"],
            path: "Examples/ToolCalling"
        ),
        .executableTarget(
            name: "sayitdevcore-error-handling-example",
            dependencies: ["SayItDevCore"],
            path: "Examples/ErrorHandling"
        ),
        .executableTarget(
            name: "sayitdevcore-mcp-protocol-example",
            dependencies: ["SayItDevCore"],
            path: "Examples/MCPProtocol"
        ),
    ]
)
