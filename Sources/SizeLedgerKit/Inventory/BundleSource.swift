import Foundation

/// What was measured: an app bundle folder, an `.ipa` archive or an Xcode archive.
public enum InputKind: String, Codable, Sendable {
    /// An `.app` bundle folder.
    case app
    /// An `.ipa` archive.
    case ipa
    /// An Xcode archive; the app inside `Products/Applications` is measured.
    case xcarchive
}

/// A regular file or symbolic link inside an app bundle.
public struct BundleEntry: Sendable, Equatable {
    /// Path relative to the bundle root, with `/` separators.
    public var path: String
    /// Uncompressed size. For a symbolic link, the length of the path it points to.
    public var bytes: UInt64
    /// Size inside the `.ipa`; `nil` for a folder on disk.
    public var compressedBytes: UInt64?
    /// True for a symbolic link, which is listed but not followed.
    public var isSymbolicLink: Bool
    /// The path as stored, relative to the bundle root. `path` is its decoded text, and two
    /// stored names can decode to the same text, so entries are told apart by this key.
    let key: PathKey

    /// Creates an entry whose stored path is the UTF-8 of `path`.
    public init(path: String, bytes: UInt64, compressedBytes: UInt64? = nil, isSymbolicLink: Bool = false) {
        self.init(key: PathKey(path), bytes: bytes, compressedBytes: compressedBytes, isSymbolicLink: isSymbolicLink)
    }

    /// Creates an entry for the stored path `key`, shown as its decoded text.
    init(key: PathKey, bytes: UInt64, compressedBytes: UInt64? = nil, isSymbolicLink: Bool = false) {
        path = BundlePath.decode(key.bytes)
        self.key = key
        self.bytes = bytes
        self.compressedBytes = compressedBytes
        self.isSymbolicLink = isSymbolicLink
    }
}

/// The files of one app bundle, from a folder or from an archive.
protocol BundleSource: Sendable {
    var kind: InputKind { get }
    /// Name of the bundle folder, such as `MyApp.app`.
    var bundleName: String { get }
    /// Files and links in the bundle, sorted by path.
    var entries: [BundleEntry] { get }
    /// Files in an `.ipa` outside `Payload/<name>.app` (SwiftSupport, Symbols and the like).
    var outsideEntries: [BundleEntry] { get }
    /// Size of the `.ipa` file itself.
    var archiveBytes: UInt64? { get }
    /// The bytes of the file stored at `key` (relative to the bundle root) in each of `ranges`,
    /// cut short where the file ends. Memory use follows the ranges' lengths, not their offsets.
    func contents(of key: PathKey, ranges: [Range<Int>]) throws -> [Data]
}

extension BundleSource {
    /// The bytes of `entry` in each of `ranges`.
    func contents(of entry: BundleEntry, ranges: [Range<Int>]) throws -> [Data] {
        try contents(of: entry.key, ranges: ranges)
    }

    /// The first `limit` bytes of `entry`, or all of it.
    func contents(of entry: BundleEntry, limit: Int) throws -> Data {
        try contents(of: entry.key, ranges: [0..<limit])[0]
    }

    /// The bytes of the file whose stored path is the UTF-8 of `path`.
    func contents(of path: String, ranges: [Range<Int>]) throws -> [Data] {
        try contents(of: PathKey(path), ranges: ranges)
    }

    /// The first `limit` bytes of the file whose stored path is the UTF-8 of `path`.
    func contents(of path: String, limit: Int) throws -> Data {
        try contents(of: PathKey(path), ranges: [0..<limit])[0]
    }
}

extension Array where Element == BundleEntry {
    /// Sorted by the bytes of the path as shown, then as stored, so the order does not depend on
    /// locale or platform, and two names that read the same keep one order.
    func sortedByPath() -> [BundleEntry] {
        sorted {
            if $0.path.utf8.elementsEqual($1.path.utf8) {
                return $0.key.bytes.lexicographicallyPrecedes($1.key.bytes)
            }
            return $0.path.utf8.lexicographicallyPrecedes($1.path.utf8)
        }
    }
}
