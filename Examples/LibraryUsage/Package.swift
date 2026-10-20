// swift-tools-version: 6.2
import PackageDescription

// A small program that uses SizeLedgerKit: it prints the five largest items of an app and exits
// with 1 when the install size estimate is over a limit you pass. In your own package, depend on
// .package(url: "https://github.com/muhittincamdali/sizeledger", from: "0.1.7") instead of the
// local path.
let package = Package(
    name: "LibraryUsage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(name: "sizeledger", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "SizeCheck",
            dependencies: [.product(name: "SizeLedgerKit", package: "sizeledger")]
        ),
    ]
)
