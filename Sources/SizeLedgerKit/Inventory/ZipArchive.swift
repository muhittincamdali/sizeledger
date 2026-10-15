import Foundation

/// One file, directory or symbolic link listed in a ZIP archive's central directory.
struct ZipEntry: Sendable, Equatable {
    var path: String
    var compressedSize: UInt64
    var uncompressedSize: UInt64
    var method: UInt16
    var flags: UInt16
    var localHeaderOffset: UInt64
    /// Unix mode bits, when the archive was written on a Unix system (as Xcode's exports are).
    var unixMode: UInt32?

    var isDirectory: Bool {
        path.hasSuffix("/") || unixMode.map { $0 & 0o170000 == 0o040000 } == true
    }

    var isSymbolicLink: Bool {
        unixMode.map { $0 & 0o170000 == 0o120000 } == true
    }

    var isEncrypted: Bool { flags & 1 != 0 }
}

/// Reads a ZIP archive (an `.ipa` is one) from its central directory.
///
/// Sizes come straight from the directory, so listing an archive never decompresses anything.
/// ZIP64 archives (over 4 GB or 65,535 entries) are supported; multi-disk archives are not.
struct ZipArchive: Sendable {
    let entries: [ZipEntry]
    private let reader: ByteReader

    static let storedMethod: UInt16 = 0
    static let deflateMethod: UInt16 = 8

    init(url: URL) throws(ZipError) {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw .unreadable(error.localizedDescription)
        }
        try self.init(data: data)
    }

    init(data: Data) throws(ZipError) {
        reader = ByteReader(data)
        do {
            entries = try Self.readCentralDirectory(reader)
        } catch let error as ZipError {
            throw error
        } catch {
            throw .malformed("the central directory points outside the file")
        }
    }

    /// The entry's uncompressed bytes, or at least the first `limit` of them.
    func contents(of entry: ZipEntry, limit: Int = .max) throws(ZipError) -> Data {
        guard !entry.isEncrypted else { throw .encrypted(entry.path) }
        let compressed: Data
        do {
            let offset = Int(entry.localHeaderOffset)
            guard try reader.uint32LE(at: offset) == 0x0403_4B50 else {
                throw ZipError.malformed("no local header for \(entry.path)")
            }
            let nameLength = Int(try reader.uint16LE(at: offset + 26))
            let extraLength = Int(try reader.uint16LE(at: offset + 28))
            compressed = try reader.bytes(at: offset + 30 + nameLength + extraLength, length: Int(entry.compressedSize))
        } catch let error as ZipError {
            throw error
        } catch {
            throw .malformed("\(entry.path) extends past the end of the archive")
        }
        switch entry.method {
        case Self.storedMethod:
            return limit < compressed.count ? compressed.prefix(limit) : compressed
        case Self.deflateMethod:
            do {
                let bytes = try Inflate.decompress(compressed, limit: limit)
                return Data(limit < bytes.count ? bytes[0..<limit] : bytes[...])
            } catch {
                throw .malformed("\(entry.path) is not valid DEFLATE data (\(error))")
            }
        default:
            throw .unsupportedMethod(entry.method, entry.path)
        }
    }

    // MARK: Central directory

    private static func readCentralDirectory(_ reader: ByteReader) throws -> [ZipEntry] {
        let end = try findEndOfCentralDirectory(reader)
        var entryCount = UInt64(try reader.uint16LE(at: end + 10))
        var directorySize = UInt64(try reader.uint32LE(at: end + 12))
        var directoryOffset = UInt64(try reader.uint32LE(at: end + 16))

        // ZIP64: the classic record holds 0xFFFF.. markers and a locator right before it points
        // at the 64-bit record.
        if end >= 20, try reader.uint32LE(at: end - 20) == 0x0706_4B50 {
            let record = Int(try reader.uint64LE(at: end - 20 + 8))
            guard try reader.uint32LE(at: record) == 0x0606_4B50 else {
                throw ZipError.malformed("ZIP64 locator does not point at a ZIP64 record")
            }
            entryCount = try reader.uint64LE(at: record + 32)
            directorySize = try reader.uint64LE(at: record + 40)
            directoryOffset = try reader.uint64LE(at: record + 48)
        }
        guard reader.contains(Int(directoryOffset), length: Int(directorySize)) else {
            throw ZipError.malformed("the central directory points outside the file")
        }

        var entries: [ZipEntry] = []
        entries.reserveCapacity(Int(min(entryCount, 1 << 20)))
        var offset = Int(directoryOffset)
        for _ in 0..<entryCount {
            guard try reader.uint32LE(at: offset) == 0x0201_4B50 else {
                throw ZipError.malformed("central directory entry \(entries.count + 1) has no signature")
            }
            let madeBy = try reader.uint16LE(at: offset + 4)
            let flags = try reader.uint16LE(at: offset + 8)
            let method = try reader.uint16LE(at: offset + 10)
            var compressedSize = UInt64(try reader.uint32LE(at: offset + 20))
            var uncompressedSize = UInt64(try reader.uint32LE(at: offset + 24))
            let nameLength = Int(try reader.uint16LE(at: offset + 28))
            let extraLength = Int(try reader.uint16LE(at: offset + 30))
            let commentLength = Int(try reader.uint16LE(at: offset + 32))
            let externalAttributes = try reader.uint32LE(at: offset + 38)
            var localHeaderOffset = UInt64(try reader.uint32LE(at: offset + 42))
            let name = try reader.bytes(at: offset + 46, length: nameLength)

            // ZIP64 extended information: only the fields whose classic value is 0xFFFFFFFF are
            // present, in this order.
            var extra = offset + 46 + nameLength
            let extraEnd = extra + extraLength
            while extra + 4 <= extraEnd {
                let id = try reader.uint16LE(at: extra)
                let size = Int(try reader.uint16LE(at: extra + 2))
                if id == 0x0001 {
                    var field = extra + 4
                    if uncompressedSize == 0xFFFF_FFFF {
                        uncompressedSize = try reader.uint64LE(at: field)
                        field += 8
                    }
                    if compressedSize == 0xFFFF_FFFF {
                        compressedSize = try reader.uint64LE(at: field)
                        field += 8
                    }
                    if localHeaderOffset == 0xFFFF_FFFF {
                        localHeaderOffset = try reader.uint64LE(at: field)
                    }
                }
                extra += 4 + size
            }

            let unixHost: UInt16 = 3
            let osxHost: UInt16 = 19
            let host = madeBy >> 8
            let mode = (host == unixHost || host == osxHost) ? externalAttributes >> 16 : 0
            entries.append(ZipEntry(
                path: decodeName(name),
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                method: method,
                flags: flags,
                localHeaderOffset: localHeaderOffset,
                unixMode: mode == 0 ? nil : mode
            ))
            offset = extraEnd + commentLength
        }
        return entries
    }

    /// The end-of-central-directory record sits in the last 22 bytes plus an optional comment of
    /// up to 65,535 bytes; search backwards for its signature.
    private static func findEndOfCentralDirectory(_ reader: ByteReader) throws -> Int {
        let minimumSize = 22
        guard reader.count >= minimumSize else { throw ZipError.notAZipArchive }
        let lowest = max(0, reader.count - minimumSize - 0xFFFF)
        var offset = reader.count - minimumSize
        while offset >= lowest {
            if try reader.uint32LE(at: offset) == 0x0605_4B50 { return offset }
            offset -= 1
        }
        throw ZipError.notAZipArchive
    }

    /// Names are UTF-8 when the archive says so (flag bit 11) and, in practice, also when it does
    /// not: Info-ZIP and `ditto` write UTF-8 either way. Invalid UTF-8 falls back to Latin-1.
    private static func decodeName(_ bytes: Data) -> String {
        if let name = String(data: bytes, encoding: .utf8) { return name }
        return String(decoding: bytes.map { UInt16($0) }, as: UTF16.self)
    }
}

/// Why a ZIP archive could not be read.
public enum ZipError: Error, Equatable, Sendable {
    case unreadable(String)
    case notAZipArchive
    case malformed(String)
    case encrypted(String)
    case unsupportedMethod(UInt16, String)
}

extension ZipError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unreadable(let reason): "the file cannot be read: \(reason)"
        case .notAZipArchive: "not a ZIP archive (an .ipa is one)"
        case .malformed(let reason): "damaged ZIP archive: \(reason)"
        case .encrypted(let path): "\(path) is encrypted"
        case .unsupportedMethod(let method, let path): "\(path) uses compression method \(method); only stored (0) and DEFLATE (8) are supported"
        }
    }
}
