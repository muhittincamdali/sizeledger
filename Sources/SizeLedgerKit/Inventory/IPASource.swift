import Foundation

/// An `.ipa`: a ZIP archive with the app at `Payload/<name>.app`.
///
/// Sizes come from the archive's central directory: `bytes` is what the file takes once
/// extracted and `compressedBytes` what it takes inside the archive.
struct IPASource: BundleSource {
    let archive: ZipArchive
    let bundleName: String
    let entries: [BundleEntry]
    let outsideEntries: [BundleEntry]
    let archiveBytes: UInt64?
    private let entryByPath: [String: ZipEntry]

    var kind: InputKind { .ipa }

    init(url: URL) throws {
        let archive = try ZipArchive(url: url)
        let apps = Set(archive.entries.compactMap { Self.appName(in: $0.path) }).sorted()
        guard let app = apps.first else { throw InputError.noApp(url.lastPathComponent) }
        guard apps.count == 1 else { throw InputError.severalApps(url.lastPathComponent, apps) }

        let prefix = "Payload/\(app)/"
        var inside: [BundleEntry] = []
        var outside: [BundleEntry] = []
        var byPath: [String: ZipEntry] = [:]
        for entry in archive.entries where !entry.isDirectory {
            let inBundle = entry.path.hasPrefix(prefix)
            let path = inBundle ? String(entry.path.dropFirst(prefix.count)) : entry.path
            let record = BundleEntry(
                path: path,
                bytes: entry.uncompressedSize,
                compressedBytes: entry.compressedSize,
                isSymbolicLink: entry.isSymbolicLink
            )
            if inBundle {
                inside.append(record)
                byPath[path] = entry
            } else {
                outside.append(record)
            }
        }

        self.archive = archive
        bundleName = app
        entries = inside.sortedByPath()
        outsideEntries = outside.sortedByPath()
        entryByPath = byPath
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        archiveBytes = (attributes?[.size] as? NSNumber)?.uint64Value
    }

    func contents(of path: String, limit: Int) throws -> Data {
        guard let entry = entryByPath[path] else { throw CocoaError(.fileNoSuchFile) }
        return try archive.contents(of: entry, limit: limit)
    }

    /// `MyApp.app` for paths under `Payload/MyApp.app/`.
    private static func appName(in path: String) -> String? {
        let parts = path.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2, parts[0] == "Payload", parts[1].hasSuffix(".app"), parts[1].count > 4 else { return nil }
        // "Payload/MyApp.app" without a trailing slash is a file named like a bundle, not a bundle.
        guard parts.count == 3 else { return nil }
        return String(parts[1])
    }
}
