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
    private let entryByPath: [PathKey: ZipEntry]

    var kind: InputKind { .ipa }

    init(url: URL, limits: AnalysisLimits = .default) throws {
        let archive = try ZipArchive(url: url, limits: limits)
        // Xcode never writes a ".." component, and unzip tools refuse or strip it. Counting such an
        // entry would put its bytes in a ".." folder of the bundle that does not exist on a device.
        // Components are split on bytes (see BundlePath), so "../\u{301}x" is caught too.
        if let entry = archive.entries.first(where: { BundlePath.components(of: $0.path).contains { BundlePath.same($0, "..") } }) {
            throw InputError.unreadable(url.path, "entry \(entry.path) has a \"..\" path component")
        }
        try Self.check(archive.entries, url: url, limits: limits)
        // Keyed by bytes, so two bundles whose names differ only in Unicode normalization are two.
        var appsByKey: [PathKey: String] = [:]
        for name in archive.entries.compactMap({ Self.appName(in: $0.path) }) { appsByKey[PathKey(name)] = name }
        let apps = appsByKey.values.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        guard let app = apps.first else { throw InputError.noApp(url.lastPathComponent) }
        guard apps.count == 1 else { throw InputError.severalApps(url.lastPathComponent, apps) }

        let prefix = "Payload/\(app)/"
        // A ZIP may list the same path twice; extraction keeps the last one, so measure that one
        // once rather than adding both. Insertion order is preserved so the report is stable.
        // Paths are keyed by their bytes: NFC and NFD spellings of a name are two files on disk.
        var insideOrder: [PathKey] = []
        var inside: [PathKey: BundleEntry] = [:]
        var outsideOrder: [PathKey] = []
        var outside: [PathKey: BundleEntry] = [:]
        var byPath: [PathKey: ZipEntry] = [:]
        for entry in archive.entries where !entry.isDirectory {
            let inBundle = BundlePath.hasPrefix(entry.path, prefix)
            let path = inBundle ? BundlePath.dropping(prefix, from: entry.path) : entry.path
            let key = PathKey(path)
            let record = BundleEntry(
                path: path,
                bytes: entry.uncompressedSize,
                compressedBytes: entry.compressedSize,
                isSymbolicLink: entry.isSymbolicLink
            )
            if inBundle {
                if inside[key] == nil { insideOrder.append(key) }
                inside[key] = record
                byPath[key] = entry
            } else {
                if outside[key] == nil { outsideOrder.append(key) }
                outside[key] = record
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
        guard let entry = entryByPath[PathKey(path)] else { throw CocoaError(.fileNoSuchFile) }
        return try archive.contents(of: entry, ranges: ranges)
    }

    /// `MyApp.app` for paths under `Payload/MyApp.app/`.
    private static func appName(in path: String) -> String? {
        let parts = path.utf8.split(separator: BundlePath.separator, maxSplits: 2, omittingEmptySubsequences: false)
        // "Payload/MyApp.app" without a trailing slash is a file named like a bundle, not a bundle.
        guard parts.count == 3, parts[0].elementsEqual("Payload".utf8) else { return nil }
        let name = String(decoding: parts[1], as: UTF8.self)
        guard BundlePath.hasSuffix(name, ".app"), name.utf8.count > ".app".utf8.count else { return nil }
        return name
    }
}
