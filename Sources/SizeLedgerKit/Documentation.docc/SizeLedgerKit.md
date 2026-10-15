# ``SizeLedgerKit``

Measure an iOS app and see where its bytes are: by category, framework, asset catalog, language
and architecture.

## Overview

SizeLedgerKit is the library behind the `sizeledger` command. It reads an `.app` bundle, an
`.ipa` or an `.xcarchive` and returns a ``SizeReport``: totals, a breakdown by
``SizeCategory``, the largest components, the languages of the `.lproj` folders, every Mach-O
binary with its architecture slices, and the whole bundle as a tree of ``SizeNode`` values.

```swift
import Foundation
import SizeLedgerKit

let report = try SizeLedger.analyze(URL(fileURLWithPath: "build/MyApp.ipa"))
print(ByteFormat.string(report.totals.bytes))          // "8.75 MB"
for component in report.components.prefix(5) {
    print(Sanitize.text(component.path), ByteFormat.string(component.bytes))
}
```

Paths, names and notes come from the app, so they go through ``Sanitize/text(_:)`` before they
are printed; ``TextReport`` and ``MarkdownReport`` do that for you.

Nothing is extracted to disk and nothing is executed. Sizes come from the file system or from the
`.ipa`'s ZIP directory; only `Info.plist` and the headers of Mach-O files are read. The library
has no dependencies (its ZIP reader, DEFLATE decoder and Mach-O parser are part of it) and runs
the same on macOS and Linux.

Every report carries three sizes, and they answer different questions:

- term `bytes`: the files' sizes added up, what a file manager shows.
- term `installBytes`: an estimate of the space on a device. Each file is rounded up to whole
  4 KiB blocks. It is not the App Store's number; see <doc:InstallSizeEstimate>.
- term `compressedBytes`: the size inside the `.ipa` archive, for `.ipa` input only.

## Topics

### Essentials

- <doc:GettingStarted>
- ``SizeLedger``
- ``SizeReport``

### Reading a report

- <doc:JSONLayout>
- <doc:InstallSizeEstimate>
- ``SizeCategory``
- ``SizeNode``
- ``AppInfo``
- ``MachOSlice``
- ``MachOSegment``
- ``InputKind``
- ``BundleEntry``

### Printing a report

- ``TextReport``
- ``MarkdownReport``
- ``ByteFormat``
- ``Sanitize``

### Errors

- ``InputError``
- ``ZipError``
- ``ReportError``
