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
        if let entry = archive.entries.first(where: { PathKey(bytes: $0.name).components.contains { $0.elementsEqual("..".utf8) } }) {
            throw InputError.unreadable(url.path, "entry \(entry.path) has a \"..\" path component")
        }
        try Self.check(archive.entries, url: url, limits: limits)
        // Keyed by the stored bytes, so two bundles whose names differ only in Unicode
        // normalization, or only in being UTF-8 or not, are two.
        var appsByKey: [PathKey: String] = [:]
        for name in archive.entries.compactMap({ Self.appName(in: $0.name) }) { appsByKey[name] = BundlePath.decode(name.bytes) }
        let apps = appsByKey.sorted { $0.key.bytes.lexicographicallyPrecedes($1.key.bytes) }
        guard let app = apps.first else { throw InputError.noApp(url.lastPathComponent) }
        guard apps.count == 1 else { throw InputError.severalApps(url.lastPathComponent, apps.map(\.value)) }

        let prefix = Array("Payload/".utf8) + app.key.bytes + [BundlePath.separator]
        // A ZIP may list the same path twice; extraction keeps the last one, so measure that one
        // once rather than adding both. Insertion order is preserved so the report is stable.
        // Paths are keyed by their stored bytes: NFC and NFD spellings of a name are two files on
        // disk, and so are "caf\u{E9}.bin" in UTF-8 and the Latin-1 byte 0xE9 that reads the same.
        var insideOrder: [PathKey] = []
        var inside: [PathKey: BundleEntry] = [:]
        var outsideOrder: [PathKey] = []
        var outside: [PathKey: BundleEntry] = [:]
        var byPath: [PathKey: ZipEntry] = [:]
        for entry in archive.entries where !entry.isDirectory {
            let inBundle = entry.name.starts(with: prefix)
            let key = PathKey(bytes: inBundle ? entry.name.dropFirst(prefix.count) : entry.name[...])
            let record = BundleEntry(
                key: key,
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
        bundleName = app.value
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

    func contents(of key: PathKey, ranges: [Range<Int>]) throws -> [Data] {
        guard let entry = entryByPath[key] else { throw CocoaError(.fileNoSuchFile) }
        return try archive.contents(of: entry, ranges: ranges)
    }

    /// The stored bytes of `MyApp.app` for names under `Payload/MyApp.app/`.
    private static func appName(in name: [UInt8]) -> PathKey? {
        let parts = name.split(separator: BundlePath.separator, maxSplits: 2, omittingEmptySubsequences: false)
        // "Payload/MyApp.app" without a trailing slash is a file named like a bundle, not a bundle.
        guard parts.count == 3, parts[0].elementsEqual("Payload".utf8) else { return nil }
        let suffix = Array(".app".utf8)
        guard parts[1].reversed().starts(with: suffix.reversed()), parts[1].count > suffix.count else { return nil }
        return PathKey(bytes: parts[1])
    }
}
