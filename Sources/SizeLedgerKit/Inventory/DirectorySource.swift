import Foundation

/// An app bundle folder on disk: a `.app`, or the one inside an `.xcarchive`.
///
/// Symbolic links are listed as links and not followed, the way `du` counts them, so a link to a
/// folder elsewhere does not add that folder's size. `root` itself is opened as given;
/// `InputLocator` makes sure it is not a link inside an `.xcarchive`.
struct DirectorySource: BundleSource {
    let kind: InputKind
    let root: URL
    let entries: [BundleEntry]

    var bundleName: String { root.lastPathComponent }
    var outsideEntries: [BundleEntry] { [] }
    var archiveBytes: UInt64? { nil }

    init(root: URL, kind: InputKind, limits: AnalysisLimits = .default) throws {
        self.root = root
        self.kind = kind
        entries = try Self.walk(root.path, limits: limits).sortedByPath()
    }

    func contents(of path: String, ranges: [Range<Int>]) throws -> [Data] {
        let handle = try FileHandle(forReadingFrom: root.appendingPathComponent(path))
        defer { try? handle.close() }
        return try ranges.map { range in
            try handle.seek(toOffset: UInt64(range.lowerBound))
            return try handle.read(upToCount: range.count) ?? Data()
        }
    }

    /// Walks the bundle with an explicit stack, not recursion, so a folder nested thousands deep
    /// cannot overflow the call stack. Symbolic links are listed, never followed, so a link to a
    /// folder outside the bundle is one entry, not that folder's contents. Depth and entry-count
    /// caps stop a crafted, extracted archive from exhausting memory or time. The file count is
    /// checked entry by entry, but each folder's listing is read whole first, so a single folder
    /// holding millions of names costs that listing's memory before the walk stops.
    private static func walk(_ root: String, limits: AnalysisLimits) throws -> [BundleEntry] {
        let manager = FileManager.default
        var entries: [BundleEntry] = []
        var stack: [(directory: String, prefix: String, depth: Int)] = [(root, "", 0)]
        while let (directory, prefix, depth) = stack.popLast() {
            for name in try manager.contentsOfDirectory(atPath: directory) {
                let absolute = directory + "/" + name
                let relative = prefix.isEmpty ? name : prefix + "/" + name
                // attributesOfItem reads the link itself (lstat), not what it points to.
                let attributes = try manager.attributesOfItem(atPath: absolute)
                let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
                switch attributes[.type] as? FileAttributeType {
                case .typeDirectory?:
                    guard depth < limits.maxDepth else {
                        throw InputError.unreadable(absolute, "it is nested deeper than \(limits.maxDepth) folders (raise --max-depth)")
                    }
                    stack.append((absolute, relative, depth + 1))
                case .typeSymbolicLink?:
                    entries.append(BundleEntry(path: relative, bytes: size, isSymbolicLink: true))
                case .typeRegular?:
                    entries.append(BundleEntry(path: relative, bytes: size))
                default:
                    // Sockets, FIFOs and devices do not occur in app bundles and have no size.
                    continue
                }
                guard entries.count <= limits.maxFiles else {
                    throw InputError.unreadable(root, "it has more than \(limits.maxFiles) files (raise --max-files)")
                }
            }
        }
        return entries
    }
}
