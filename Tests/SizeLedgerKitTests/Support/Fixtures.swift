import Foundation

/// Paths into the repository's Fixtures folder, found from this file's location so the tests run
/// the same from `swift test`, Xcode and a Linux container.
enum Fixtures {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // SizeLedgerKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repository
        .appendingPathComponent("Fixtures")

    static func archive(_ name: String) -> URL {
        root.appendingPathComponent("archives").appendingPathComponent(name)
    }

    static func data(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}

/// CRC-32 (ISO-HDLC, the one ZIP and zlib use), to compare decoded output with the manifest.
func crc32<Bytes: Sequence>(_ bytes: Bytes) -> UInt32 where Bytes.Element == UInt8 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in bytes {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
        }
    }
    return ~crc
}

/// A temporary directory removed when the value is released.
final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sizeledger-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes a file of `size` bytes (or `contents`) at a path relative to the directory.
    @discardableResult
    func file(_ path: String, size: Int = 0, contents: Data? = nil) throws -> URL {
        let target = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (contents ?? Data(repeating: 0x2A, count: size)).write(to: target)
        return target
    }

    func directory(_ path: String) throws {
        try FileManager.default.createDirectory(at: url.appendingPathComponent(path), withIntermediateDirectories: true)
    }

    func symlink(_ path: String, to destination: String) throws {
        let target = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: target.path, withDestinationPath: destination)
    }
}
