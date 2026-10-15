import Foundation

/// An app bundle folder on disk: a `.app`, or the one inside an `.xcarchive`.
///
/// Symbolic links are listed as links and not followed, the way `du` counts them, so a link to a
/// folder elsewhere does not add that folder's size.
struct DirectorySource: BundleSource {
    let kind: InputKind
    let root: URL
    let entries: [BundleEntry]

    var bundleName: String { root.lastPathComponent }
    var outsideEntries: [BundleEntry] { [] }
    var archiveBytes: UInt64? { nil }

    init(root: URL, kind: InputKind) throws {
        self.root = root
        self.kind = kind
        var found: [BundleEntry] = []
        try Self.walk(root.path, prefix: "", into: &found)
        entries = found.sortedByPath()
    }

    func contents(of path: String, ranges: [Range<Int>]) throws -> [Data] {
        let handle = try FileHandle(forReadingFrom: root.appendingPathComponent(path))
        defer { try? handle.close() }
        return try ranges.map { range in
            try handle.seek(toOffset: UInt64(range.lowerBound))
            return try handle.read(upToCount: range.count) ?? Data()
        }
    }

    private static func walk(_ directory: String, prefix: String, into entries: inout [BundleEntry]) throws {
        let manager = FileManager.default
        for name in try manager.contentsOfDirectory(atPath: directory) {
            let absolute = directory + "/" + name
            let relative = prefix.isEmpty ? name : prefix + "/" + name
            // attributesOfItem reads the link itself (lstat), not what it points to.
            let attributes = try manager.attributesOfItem(atPath: absolute)
            let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            switch attributes[.type] as? FileAttributeType {
            case .typeDirectory?:
                try walk(absolute, prefix: relative, into: &entries)
            case .typeSymbolicLink?:
                entries.append(BundleEntry(path: relative, bytes: size, isSymbolicLink: true))
            case .typeRegular?:
                entries.append(BundleEntry(path: relative, bytes: size))
            default:
                // Sockets, FIFOs and devices do not occur in app bundles and have no size.
                continue
            }
        }
    }
}
