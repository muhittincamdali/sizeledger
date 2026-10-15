/// A folder or file in the size tree. A folder's numbers are the sums of its children.
public struct SizeNode: Codable, Equatable, Sendable {
    /// File or folder name; the root is the bundle's name.
    public var name: String
    /// Files under this node (1 for a file).
    public var files: Int
    /// Sizes added up.
    public var bytes: UInt64
    /// Install size estimate (whole 4 KiB blocks).
    public var installBytes: UInt64
    /// Size inside the `.ipa`; only for `.ipa` input.
    public var compressedBytes: UInt64?
    /// Set on files only; folders can mix categories.
    public var category: SizeCategory?
    /// Set on folders only, largest first (ties by name).
    public var children: [SizeNode]?

    /// True for folders, which have ``children``.
    public var isFolder: Bool { children != nil }
}

/// Space a file takes on an APFS volume: whole 4 KiB blocks. Empty files and symbolic links take
/// none (APFS keeps short link targets in the file's metadata).
enum InstallSize {
    static let blockSize: UInt64 = 4_096

    static func estimate(_ entry: BundleEntry) -> UInt64 {
        guard !entry.isSymbolicLink, entry.bytes > 0 else { return 0 }
        return (entry.bytes + blockSize - 1) / blockSize * blockSize
    }
}

/// Running sums for one group of files.
struct Tally: Equatable {
    var files = 0
    var bytes: UInt64 = 0
    var installBytes: UInt64 = 0
    var compressedBytes: UInt64?

    mutating func add(_ entry: BundleEntry) {
        files += 1
        bytes += entry.bytes
        installBytes += InstallSize.estimate(entry)
        if let compressed = entry.compressedBytes {
            compressedBytes = (compressedBytes ?? 0) + compressed
        }
    }

    static func + (lhs: Tally, rhs: Tally) -> Tally {
        var sum = lhs
        sum.files += rhs.files
        sum.bytes += rhs.bytes
        sum.installBytes += rhs.installBytes
        if let compressed = rhs.compressedBytes { sum.compressedBytes = (sum.compressedBytes ?? 0) + compressed }
        return sum
    }
}

/// Builds the tree from flat paths.
enum TreeBuilder {
    private final class Folder {
        var folders: [String: Folder] = [:]
        var files: [SizeNode] = []
    }

    static func build(rootName: String, entries: [BundleEntry], category: (BundleEntry) -> SizeCategory) -> SizeNode {
        let root = Folder()
        for entry in entries {
            let parts = entry.path.split(separator: "/").map(String.init)
            var folder = root
            for part in parts.dropLast() {
                if let next = folder.folders[part] {
                    folder = next
                } else {
                    let next = Folder()
                    folder.folders[part] = next
                    folder = next
                }
            }
            var tally = Tally()
            tally.add(entry)
            folder.files.append(SizeNode(
                name: parts.last ?? entry.path,
                files: 1,
                bytes: tally.bytes,
                installBytes: tally.installBytes,
                compressedBytes: tally.compressedBytes,
                category: category(entry),
                children: nil
            ))
        }
        return node(named: rootName, from: root)
    }

    private static func node(named name: String, from folder: Folder) -> SizeNode {
        let children = folder.folders.map { node(named: $0.key, from: $0.value) } + folder.files
        var tally = Tally()
        for child in children {
            tally = tally + Tally(files: child.files, bytes: child.bytes, installBytes: child.installBytes, compressedBytes: child.compressedBytes)
        }
        return SizeNode(
            name: name,
            files: tally.files,
            bytes: tally.bytes,
            installBytes: tally.installBytes,
            compressedBytes: tally.compressedBytes,
            category: nil,
            children: children.sorted(by: largestFirst)
        )
    }

    /// Largest first; equal sizes by name bytes, so the order never depends on hashing.
    static func largestFirst(_ lhs: SizeNode, _ rhs: SizeNode) -> Bool {
        if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
        return lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
    }
}
