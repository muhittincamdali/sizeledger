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

    /// Creates an entry.
    public init(path: String, bytes: UInt64, compressedBytes: UInt64? = nil, isSymbolicLink: Bool = false) {
        self.path = path
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
    /// The bytes of the file at `path` (relative to the bundle root) in each of `ranges`, cut
    /// short where the file ends. Memory use follows the ranges' lengths, not their offsets.
    func contents(of path: String, ranges: [Range<Int>]) throws -> [Data]
}

extension BundleSource {
    /// The first `limit` bytes of the file at `path`, or all of it.
    func contents(of path: String, limit: Int) throws -> Data {
        try contents(of: path, ranges: [0..<limit])[0]
    }
}

extension Array where Element == BundleEntry {
    /// Sorted by the bytes of the path, so the order does not depend on locale or platform.
    func sortedByPath() -> [BundleEntry] {
        sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
    }
}
