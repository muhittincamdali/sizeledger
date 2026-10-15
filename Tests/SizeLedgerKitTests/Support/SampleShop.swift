import Foundation
@testable import SizeLedgerKit

/// The SampleShop fixture app: two versions built for the iOS Simulator by
/// Fixtures/scripts/build-sample-app.sh and committed as .ipa files.
enum SampleShop {
    static let versions = ["1.0", "2.0"]

    static func ipa(_ version: String) -> URL {
        Fixtures.root.appendingPathComponent("apps/SampleShop-\(version).ipa")
    }

    static func snapshot(_ name: String) -> URL {
        Fixtures.root.appendingPathComponent("snapshots/\(name)")
    }

    /// Unpacks the .ipa with the library's own ZIP reader into `folder` and returns the app.
    static func extract(_ version: String, into folder: URL) throws -> URL {
        let archive = try ZipArchive(url: ipa(version))
        let manager = FileManager.default
        for entry in archive.entries {
            let target = folder.appendingPathComponent(entry.path)
            if entry.isDirectory {
                try manager.createDirectory(at: target, withIntermediateDirectories: true)
                continue
            }
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            let contents = try archive.contents(of: entry)
            if entry.isSymbolicLink {
                try manager.createSymbolicLink(atPath: target.path, withDestinationPath: String(decoding: contents, as: UTF8.self))
            } else {
                try contents.write(to: target)
            }
        }
        return folder.appendingPathComponent("Payload/SampleShop.app")
    }

    /// The report with the tool version replaced, so snapshots do not change with every release.
    static func normalized(_ report: SizeReport) -> SizeReport {
        var copy = report
        copy.tool.version = "<version>"
        return copy
    }
}

/// Compares `actual` with a committed snapshot, or rewrites the snapshot when the environment
/// variable SIZELEDGER_UPDATE_SNAPSHOTS is 1.
func matchesSnapshot(_ actual: String, _ name: String) throws -> Bool {
    let url = SampleShop.snapshot(name)
    if ProcessInfo.processInfo.environment["SIZELEDGER_UPDATE_SNAPSHOTS"] == "1" {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try actual.write(to: url, atomically: true, encoding: .utf8)
        return true
    }
    return try String(contentsOf: url, encoding: .utf8) == actual
}

/// Runs a command and returns what it printed on standard output.
func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}
