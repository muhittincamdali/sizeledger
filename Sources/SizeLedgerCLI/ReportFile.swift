import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// Writes the `--out` report without following a symbolic link onto a file or folder and
/// without replacing an existing file unless asked to.
///
/// - A new file is written to a temporary file in the same folder and linked into place, which
///   fails if something appeared at the path in the meantime, so nothing reads half a report and
///   nothing is replaced by accident.
/// - An existing regular file is replaced only with `replacing` (`--force`), by renaming the
///   temporary file over it. A rename replaces the name, never a file a link points to.
/// - Any other existing path, including a symbolic link such as `/dev/stdout`, is opened without
///   creating or emptying anything, and written only if what was opened is a character device
///   or a pipe. The check is made on the opened descriptor, so a path swapped after it was
///   looked at cannot redirect the write onto a file.
enum ReportFile {
    enum WriteError: LocalizedError, Equatable {
        case exists
        case folder
        case symbolicLink
        case notADeviceOrPipe
        case system(operation: String, code: Int32)

        var errorDescription: String? {
            switch self {
            case .exists:
                "it already exists; pass --force to replace it"
            case .folder:
                "it is a folder"
            case .symbolicLink:
                "it is a symbolic link that leads to a file, a folder or nothing; sizeledger follows a link only to a device or pipe"
            case .notADeviceOrPipe:
                "it is neither a regular file nor a device or pipe"
            case let .system(operation, code):
                "\(operation): \(String(cString: strerror(code)))"
            }
        }
    }

    /// Filesystems that cannot hard-link the temporary file into place; the new file is then
    /// created directly, still refusing a path that exists.
    private static let linkUnsupported: [Int32] = [EPERM, ENOTSUP, EOPNOTSUPP, EMLINK]

    static func write(_ data: Data, to path: String, replacing: Bool) throws {
        var info = stat()
        guard lstat(path, &info) == 0 else {
            let code = errno
            guard code == ENOENT else { throw WriteError.system(operation: "cannot inspect it", code: code) }
            let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try writeNewFile(data, to: path, replacing: false)
            return
        }
        switch info.st_mode & mode_t(S_IFMT) {
        case mode_t(S_IFREG):
            guard replacing else { throw WriteError.exists }
            try writeNewFile(data, to: path, replacing: true)
        case mode_t(S_IFDIR):
            throw WriteError.folder
        case mode_t(S_IFLNK):
            try writeToDeviceOrPipe(data, at: path, isLink: true)
        default:
            try writeToDeviceOrPipe(data, at: path, isLink: false)
        }
    }

    private static func writeNewFile(_ data: Data, to path: String, replacing: Bool) throws {
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent().path
        let temporary = folder + "/.sizeledger-\(UUID().uuidString).tmp"
        try writeExclusive(data, to: temporary)
        defer { unlink(temporary) }
        if replacing {
            guard rename(temporary, path) == 0 else { throw WriteError.system(operation: "cannot replace it", code: errno) }
            return
        }
        guard link(temporary, path) != 0 else { return }
        let code = errno
        if code == EEXIST { throw WriteError.exists }
        guard linkUnsupported.contains(code) else { throw WriteError.system(operation: "cannot create it", code: code) }
        try writeExclusive(data, to: path)
    }

    /// Creates `path`, which must not exist yet (not even as a link), and writes `data` to it.
    private static func writeExclusive(_ data: Data, to path: String) throws {
        let descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o666)
        guard descriptor >= 0 else {
            let code = errno
            if code == EEXIST { throw WriteError.exists }
            throw WriteError.system(operation: "cannot create it", code: code)
        }
        do {
            try FileHandle(fileDescriptor: descriptor, closeOnDealloc: false).write(contentsOf: data)
        } catch {
            close(descriptor)
            unlink(path)
            throw error
        }
        guard close(descriptor) == 0 else {
            let code = errno
            unlink(path)
            throw WriteError.system(operation: "cannot finish writing it", code: code)
        }
    }

    private static func writeToDeviceOrPipe(_ data: Data, at path: String, isLink: Bool) throws {
        // No O_CREAT and no O_TRUNC: opening a link to a file leaves that file as it was.
        let descriptor = open(path, O_WRONLY | O_NOCTTY | O_CLOEXEC)
        guard descriptor >= 0 else {
            let code = errno
            // A dangling link or a link to a folder.
            if isLink, code == ENOENT || code == EISDIR { throw WriteError.symbolicLink }
            throw WriteError.system(operation: "cannot open it", code: code)
        }
        defer { close(descriptor) }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0 else { throw WriteError.system(operation: "cannot inspect it", code: errno) }
        let kind = opened.st_mode & mode_t(S_IFMT)
        guard kind == mode_t(S_IFCHR) || kind == mode_t(S_IFIFO) else {
            throw isLink ? WriteError.symbolicLink : WriteError.notADeviceOrPipe
        }
        try FileHandle(fileDescriptor: descriptor, closeOnDealloc: false).write(contentsOf: data)
    }
}
