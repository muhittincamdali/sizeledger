import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// An app bundle folder on disk: a `.app`, or the one inside an `.xcarchive`.
///
/// Symbolic links are listed as links and not followed, the way `du` counts them, so a link to a
/// folder elsewhere does not add that folder's size. `root` itself is opened as given;
/// `InputLocator` makes sure it is not a link inside an `.xcarchive`.
///
/// Names are read and opened as the bytes the file system stores. A Linux file name need not be
/// UTF-8, and a `String` made from it cannot open the file again, so the walk lists folders with
/// `readdir` and checks each name with `lstat` on its bytes rather than going through
/// `FileManager`.
struct DirectorySource: BundleSource {
    let kind: InputKind
    let root: URL
    let entries: [BundleEntry]
    private let rootBytes: [UInt8]

    var bundleName: String { root.lastPathComponent }
    var outsideEntries: [BundleEntry] { [] }
    var archiveBytes: UInt64? { nil }

    init(root: URL, kind: InputKind, limits: AnalysisLimits = .default) throws {
        self.root = root
        self.kind = kind
        rootBytes = root.withUnsafeFileSystemRepresentation { Array(UnsafeRawBufferPointer(start: $0, count: $0.map { strlen($0) } ?? 0)) }
        entries = try Self.walk(rootBytes, display: root.path, limits: limits).sortedByPath()
    }

    func contents(of key: PathKey, ranges: [Range<Int>]) throws -> [Data] {
        let path = Self.join(rootBytes, key.bytes)
        let descriptor = Self.withCPath(path) { open($0, O_RDONLY) }
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoSuchFile) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
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
    private static func walk(_ root: [UInt8], display rootDisplay: String, limits: AnalysisLimits) throws -> [BundleEntry] {
        var entries: [BundleEntry] = []
        var stack: [(directory: [UInt8], relative: [UInt8], depth: Int)] = [(root, [], 0)]
        while let (directory, prefix, depth) = stack.popLast() {
            for name in try names(in: directory, display: display(rootDisplay, prefix)) {
                let absolute = join(directory, name)
                let relative = prefix.isEmpty ? name : join(prefix, name)
                var status = stat()
                // lstat reads the link itself, not what it points to.
                guard withCPath(absolute, { lstat($0, &status) }) == 0 else {
                    throw InputError.unreadable(display(rootDisplay, relative), lastError())
                }
                let size = UInt64(max(0, status.st_size))
                switch Int(status.st_mode) & fileTypeMask {
                case directoryType:
                    guard depth < limits.maxDepth else {
                        throw InputError.unreadable(display(rootDisplay, relative), "it is nested deeper than \(limits.maxDepth) folders (raise --max-depth)")
                    }
                    stack.append((absolute, relative, depth + 1))
                case symbolicLinkType:
                    entries.append(BundleEntry(key: PathKey(bytes: relative), bytes: size, isSymbolicLink: true))
                case regularFileType:
                    entries.append(BundleEntry(key: PathKey(bytes: relative), bytes: size))
                default:
                    // Sockets, FIFOs and devices do not occur in app bundles and have no size.
                    continue
                }
                guard entries.count <= limits.maxFiles else {
                    throw InputError.unreadable(rootDisplay, "it has more than \(limits.maxFiles) files (raise --max-files)")
                }
            }
        }
        return entries
    }

    private static let fileTypeMask = 0o170000
    private static let directoryType = 0o040000
    private static let symbolicLinkType = 0o120000
    private static let regularFileType = 0o100000

    /// The names in `directory` as stored, without `.` and `..`.
    private static func names(in directory: [UInt8], display: String) throws -> [[UInt8]] {
        guard let stream = withCPath(directory, { opendir($0) }) else {
            throw InputError.unreadable(display, lastError())
        }
        defer { closedir(stream) }
        var names: [[UInt8]] = []
        while true {
            errno = 0
            guard let record = readdir(stream) else {
                guard errno == 0 else { throw InputError.unreadable(display, lastError()) }
                return names
            }
            var stored = record.pointee.d_name
            let name = withUnsafeBytes(of: &stored) { Array($0.prefix { $0 != 0 }) }
            if name == [0x2E] || name == [0x2E, 0x2E] { continue }
            names.append(name)
        }
    }

    private static func join(_ directory: [UInt8], _ name: [UInt8]) -> [UInt8] {
        directory + [BundlePath.separator] + name
    }

    /// The path shown in a message: the root as given, then the stored relative path decoded.
    private static func display(_ root: String, _ relative: [UInt8]) -> String {
        relative.isEmpty ? root : root + "/" + BundlePath.decode(relative)
    }

    private static func withCPath<T>(_ path: [UInt8], _ body: (UnsafePointer<CChar>) -> T) -> T {
        (path + [0]).withUnsafeBufferPointer { buffer in
            buffer.withMemoryRebound(to: CChar.self) { body($0.baseAddress!) }
        }
    }

    private static func lastError() -> String {
        String(cString: strerror(errno))
    }
}
