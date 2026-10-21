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
        return entry.bytes.addingSaturating(blockSize - 1) / blockSize * blockSize
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
        bytes = bytes.addingSaturating(entry.bytes)
        installBytes = installBytes.addingSaturating(InstallSize.estimate(entry))
        if let compressed = entry.compressedBytes {
            compressedBytes = (compressedBytes ?? 0).addingSaturating(compressed)
        }
    }

    static func + (lhs: Tally, rhs: Tally) -> Tally {
        var sum = lhs
        sum.files += rhs.files
        sum.bytes = sum.bytes.addingSaturating(rhs.bytes)
        sum.installBytes = sum.installBytes.addingSaturating(rhs.installBytes)
        if let compressed = rhs.compressedBytes { sum.compressedBytes = (sum.compressedBytes ?? 0).addingSaturating(compressed) }
        return sum
    }
}

/// Builds the tree from flat paths.
enum TreeBuilder {
    /// Folders are keyed by the stored bytes of their names, so NFC and NFD spellings stay two
    /// folders, and so do a Latin-1 name and the UTF-8 name it reads as.
    private final class Folder {
        let name: String
        var folders: [PathKey: Folder] = [:]
        var files: [SizeNode] = []

        init(name: String) {
            self.name = name
        }
    }

    static func build(rootName: String, entries: [BundleEntry], category: (BundleEntry) -> SizeCategory) -> SizeNode {
        let root = Folder(name: rootName)
        for entry in entries {
            let parts = entry.key.components
            var folder = root
            for part in parts.dropLast() {
                let key = PathKey(bytes: part)
                if let next = folder.folders[key] {
                    folder = next
                } else {
                    let next = Folder(name: BundlePath.decode(part))
                    folder.folders[key] = next
                    folder = next
                }
            }
            var tally = Tally()
            tally.add(entry)
            folder.files.append(SizeNode(
                name: parts.last.map(BundlePath.decode) ?? entry.path,
                files: 1,
                bytes: tally.bytes,
                installBytes: tally.installBytes,
                compressedBytes: tally.compressedBytes,
                category: category(entry),
                children: nil
            ))
        }
        return node(from: root)
    }

    /// Builds every folder's node from the leaves up with an explicit stack, so a bundle nested
    /// thousands of folders deep does not grow the call stack and crash.
    private static func node(from rootFolder: Folder) -> SizeNode {
        var done: [ObjectIdentifier: SizeNode] = [:]
        var stack: [Folder] = [rootFolder]
        while let top = stack.last {
            let pending = top.folders.values.filter { done[ObjectIdentifier($0)] == nil }
            guard pending.isEmpty else {
                stack.append(contentsOf: pending)
                continue
            }
            stack.removeLast()
            let children = top.folders.values.map { done[ObjectIdentifier($0)]! } + top.files
            var tally = Tally()
            for child in children {
                tally = tally + Tally(files: child.files, bytes: child.bytes, installBytes: child.installBytes, compressedBytes: child.compressedBytes)
            }
            done[ObjectIdentifier(top)] = SizeNode(
                name: top.name,
                files: tally.files,
                bytes: tally.bytes,
                installBytes: tally.installBytes,
                compressedBytes: tally.compressedBytes,
                category: nil,
                children: children.sorted(by: largestFirst)
            )
        }
        return done[ObjectIdentifier(rootFolder)]!
    }

    /// Largest first; equal sizes by name bytes, so the order never depends on hashing.
    static func largestFirst(_ lhs: SizeNode, _ rhs: SizeNode) -> Bool {
        if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
        return lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
    }
}

extension UInt64 {
    /// `self + other`, or `UInt64.max` when the sum does not fit. Sizes come from the input, and
    /// a crafted `.ipa` can declare entries of almost 2^64 bytes; a report that says
    /// 18446744073.71 GB is better than a crash.
    func addingSaturating(_ other: UInt64) -> UInt64 {
        let (sum, overflow) = addingReportingOverflow(other)
        return overflow ? .max : sum
    }
}
