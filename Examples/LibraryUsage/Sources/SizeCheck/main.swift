import Foundation
import SizeLedgerKit

// swift run SizeCheck <app.ipa | App.app | App.xcarchive> [limit in MB]
//
// Prints the totals and the five largest items, then compares the install size estimate with
// the limit (decimal megabytes, as App Store Connect counts them). Names, paths and notes come
// from the app, so they go through Sanitize.text before they reach the terminal.

let arguments = CommandLine.arguments.dropFirst()
guard let path = arguments.first else {
    print("usage: SizeCheck <app.ipa | App.app | App.xcarchive> [limit in MB]")
    exit(64)
}
let limitMB = arguments.dropFirst().first.flatMap(Double.init)

let report: SizeReport
do {
    report = try SizeLedger.analyze(URL(fileURLWithPath: path))
} catch {
    print("error: \(Sanitize.text(String(describing: error)))")
    exit(2)
}

let totals = report.totals
print("\(Sanitize.text(report.app.name ?? report.input.bundle)): \(totals.files) files")
print("  bytes:                   \(ByteFormat.string(totals.bytes))")
print("  install size (estimate): \(ByteFormat.string(totals.installBytes))")
if let compressed = totals.compressedBytes {
    print("  compressed in the .ipa:  \(ByteFormat.string(compressed))")
}

print("Largest items:")
for component in report.components.prefix(5) {
    let share = ByteFormat.share(component.bytes, of: totals.bytes)
    print("  \(Sanitize.text(component.path)): \(ByteFormat.string(component.bytes)) (\(share))")
}

for note in report.notes {
    print("note: \(Sanitize.text(note))")
}

if let limitMB {
    let limit = UInt64(limitMB * 1_000_000)
    if totals.installBytes > limit {
        print("over the limit: \(ByteFormat.string(totals.installBytes)) > \(ByteFormat.string(limit))")
        exit(1)
    }
    print("within the limit of \(ByteFormat.string(limit))")
}
