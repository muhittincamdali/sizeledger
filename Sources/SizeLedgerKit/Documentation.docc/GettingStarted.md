# Getting started

Add SizeLedgerKit to a package, measure an app and print the result.

## Add the package

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/sizeledger", from: "0.1.1"),
],
targets: [
    .executableTarget(
        name: "SizeCheck",
        dependencies: [.product(name: "SizeLedgerKit", package: "sizeledger")]
    ),
]
```

SizeLedgerKit needs Swift 6.2 or later and runs on macOS 13 or later and on Linux.

## Measure an app

``SizeLedger/analyze(_:)`` takes the path of an `.app` folder, an `.ipa` file or an `.xcarchive`
folder:

```swift
import Foundation
import SizeLedgerKit

let report = try SizeLedger.analyze(URL(fileURLWithPath: "build/MyApp.ipa"))
```

It throws ``InputError`` when the path does not exist, is none of the three, or holds no app or
more than one.

## Read the numbers

```swift
let total = report.totals
print("\(total.files) files, \(ByteFormat.string(total.bytes))")
print("install size (estimate):", ByteFormat.string(total.installBytes))
if let compressed = total.compressedBytes {
    print("in the .ipa:", ByteFormat.string(compressed))
}

for category in report.categories {
    print(category.category.title, ByteFormat.share(category.bytes, of: total.bytes))
}

for binary in report.binaries {
    let slices = binary.slices.map { "\($0.architecture) \(ByteFormat.string($0.bytes))" }
    print(binary.path, slices.joined(separator: ", "))
}
```

``SizeReport/notes`` says when the numbers need context, for example for a simulator build or a
binary with more than one architecture. Show the notes wherever you show the numbers.

## Print or save it

``TextReport`` and ``MarkdownReport`` render the same tables the command prints, and
``SizeReport/jsonData()`` gives the JSON that `sizeledger analyze --out` writes:

```swift
print(TextReport.render(report, options: .init(top: 5)))
try report.jsonData().write(to: URL(fileURLWithPath: "size/main.json"))
let again = try SizeReport.decode(from: Data(contentsOf: URL(fileURLWithPath: "size/main.json")))
```

The `Examples/LibraryUsage` package in the repository is a complete program that does this.
