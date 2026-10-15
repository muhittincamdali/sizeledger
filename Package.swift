// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sizeledger",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SizeLedgerKit", targets: ["SizeLedgerKit"]),
        .executable(name: "sizeledger", targets: ["sizeledger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
    ],
    targets: [
        // Reads .app bundles, .ipa archives and .xcarchive folders and measures them. No
        // dependencies: the ZIP reader, DEFLATE decoder and Mach-O parser are part of it, so the
        // same code runs on macOS and Linux.
        .target(name: "SizeLedgerKit"),
        // The command-line interface as a library, so tests can run the commands in-process.
        .target(
            name: "SizeLedgerCLI",
            dependencies: [
                "SizeLedgerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(name: "sizeledger", dependencies: ["SizeLedgerCLI"]),
        .testTarget(name: "SizeLedgerKitTests", dependencies: ["SizeLedgerKit"]),
        .testTarget(name: "SizeLedgerCLITests", dependencies: ["SizeLedgerCLI", "SizeLedgerKit"]),
    ],
    swiftLanguageModes: [.v6]
)
