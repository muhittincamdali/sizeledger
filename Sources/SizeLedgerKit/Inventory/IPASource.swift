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

    init(url: URL, limits: AnalysisLimits = .default) throws {
        let archive = try ZipArchive(url: url, limits: limits)
        // Xcode never writes a ".." component, and unzip tools refuse or strip it. Counting such an
        // entry would put its bytes in a ".." folder of the bundle that does not exist on a device.
        if let entry = archive.entries.first(where: { $0.path.split(separator: "/").contains("..") }) {
            throw InputError.unreadable(url.path, "entry \(entry.path) has a \"..\" path component")
        }
        try Self.check(archive.entries, url: url, limits: limits)
        let apps = Set(archive.entries.compactMap { Self.appName(in: $0.path) }).sorted()
        guard let app = apps.first else { throw InputError.noApp(url.lastPathComponent) }
        guard apps.count == 1 else { throw InputError.severalApps(url.lastPathComponent, apps) }

        let prefix = "Payload/\(app)/"
        // A ZIP may list the same path twice; extraction keeps the last one, so measure that one
        // once rather than adding both. Insertion order is preserved so the report is stable.
        var insideOrder: [String] = []
        var inside: [String: BundleEntry] = [:]
        var outsideOrder: [String] = []
        var outside: [String: BundleEntry] = [:]
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
                if inside[path] == nil { insideOrder.append(path) }
                inside[path] = record
                byPath[path] = entry
            } else {
                if outside[path] == nil { outsideOrder.append(path) }
                outside[path] = record
            }
        }

        self.archive = archive
        bundleName = app
        entries = insideOrder.map { inside[$0]! }.sortedByPath()
        outsideEntries = outsideOrder.map { outside[$0]! }.sortedByPath()
        entryByPath = byPath
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        archiveBytes = (attributes?[.size] as? NSNumber)?.uint64Value
    }

    /// Refuses an archive whose declared sizes or paths exceed the limits: a single entry that
    /// claims to unpack far beyond its stored size (a zip bomb), more total bytes than allowed, or
    /// a path nested past the depth cap. The declared sizes come from the central directory, so
    /// this runs before anything is decompressed.
    private static func check(_ entries: [ZipEntry], url: URL, limits: AnalysisLimits) throws {
        var total: UInt64 = 0
        for entry in entries where !entry.isDirectory {
            if AnalysisLimits.depth(of: entry.path) > limits.maxDepth {
                throw InputError.unreadable(url.path, "entry \(entry.path) is nested deeper than \(limits.maxDepth) folders (raise --max-depth)")
            }
            if entry.uncompressedSize > entry.compressedSize.multipliedSaturating(by: limits.maxCompressionRatio) {
                throw InputError.unreadable(url.path, "entry \(entry.path) declares \(entry.uncompressedSize) bytes from \(entry.compressedSize) stored, above the \(limits.maxCompressionRatio):1 ratio allowed (raise --max-ratio)")
            }
            total = total.addingSaturating(entry.uncompressedSize)
            if total > limits.maxTotalBytes {
                throw InputError.unreadable(url.path, "the archive declares more than \(limits.maxTotalBytes) uncompressed bytes (raise --max-bytes)")
            }
        }
    }

    func contents(of path: String, ranges: [Range<Int>]) throws -> [Data] {
        guard let entry = entryByPath[path] else { throw CocoaError(.fileNoSuchFile) }
        return try archive.contents(of: entry, ranges: ranges)
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
