import Foundation

/// One architecture slice of a Mach-O file: the whole file for a thin binary, or one entry of a
/// universal ("fat") binary.
public struct MachOSlice: Codable, Equatable, Sendable {
    /// `arm64`, `arm64e`, `x86_64`, `armv7` and so on.
    public var architecture: String
    /// Where the slice starts in the file (0 for a thin binary).
    public var offset: UInt64
    /// Size of the slice in the file.
    public var bytes: UInt64
    /// `executable`, `dylib`, `bundle` or another Mach-O file type.
    public var fileType: String
    /// Segments in file order with the bytes they occupy in the file (segments that take no file
    /// space, such as `__PAGEZERO`, are left out).
    public var segments: [MachOSegment]
    /// Bytes in Swift's `__swift5_*` sections (type, field and protocol conformance metadata).
    /// A lower bound of what Swift metadata costs: some of it lives in `__const`.
    public var swiftMetadataBytes: UInt64
    /// Bytes of the embedded code signature (part of `__LINKEDIT`).
    public var codeSignatureBytes: UInt64
}

/// A segment of a Mach-O slice, such as `__TEXT` or `__LINKEDIT`.
public struct MachOSegment: Codable, Equatable, Sendable {
    /// The segment name.
    public var name: String
    /// Bytes the segment takes in the file.
    public var bytes: UInt64
}

/// Reads Mach-O headers and load commands. Only what sizes need is read: the fat header, each
/// slice's header and its load commands; nothing is loaded or executed.
enum MachO {
    enum Format: Equatable {
        case thin
        case fat(is64: Bool)
    }

    enum ParseError: Error, Equatable {
        case notMachO
        case truncated
        case malformed(String)
    }

    /// Real binaries have tens of kilobytes of load commands; more than this is a damaged or
    /// crafted file.
    static let maximumLoadCommandBytes = 1 << 20
    /// Bytes read at the start of the file and of each slice: enough for the fat table and, in
    /// most binaries, for the header and every load command.
    static let headerProbe = 4_096

    /// Recognizes a Mach-O file from its first four bytes.
    static func format(of prefix: Data) -> Format? {
        let reader = ByteReader(prefix)
        guard let magic = try? reader.uint32LE(at: 0) else { return nil }
        switch magic {
        case 0xFEED_FACF, 0xFEED_FACE: return .thin
        case 0xBEBA_FECA: return .fat(is64: false)
        case 0xBFBA_FECA: return .fat(is64: true)
        default: return nil
        }
    }

    /// Parses every slice. `read(ranges)` returns the bytes of the file in each range, cut short
    /// where the file ends. It is called at most three times (twice for a thin binary), with one
    /// range per slice of at most `headerProbe` or `headerSize + maximumLoadCommandBytes` bytes,
    /// so what is held in memory follows the size of the headers, never the offsets a fat header
    /// claims.
    static func slices(fileSize: UInt64, read: ([Range<Int>]) throws -> [Data]) throws -> [MachOSlice] {
        let head = try read([0..<headerProbe])[0]
        guard let format = format(of: head) else { throw ParseError.notMachO }

        // The start of each slice (for a thin binary, the bytes already read), then, for slices
        // whose load commands go past it, exactly as far as the commands reach.
        let ranges: [(offset: Int, size: UInt64)]
        var windows: [Data]
        switch format {
        case .thin:
            ranges = [(0, fileSize)]
            windows = [head]
        case .fat(let is64):
            ranges = try fatRanges(ByteReader(head), is64: is64, fileSize: fileSize)
            windows = try read(ranges.map { $0.offset..<($0.offset + Int(min($0.size, UInt64(headerProbe)))) })
        }
        let commandEnds = try zip(ranges, windows).map { range, window in
            try loadCommandsEnd(ByteReader(window), size: range.size)
        }
        let longer = windows.indices.filter { commandEnds[$0] > windows[$0].count }
        if !longer.isEmpty {
            let more = try read(longer.map { ranges[$0].offset..<(ranges[$0].offset + commandEnds[$0]) })
            for (index, window) in zip(longer, more) {
                windows[index] = window
            }
        }
        return try ranges.indices.map { index in
            guard windows[index].count >= commandEnds[index] else { throw ParseError.truncated }
            return try slice(ByteReader(windows[index]), offset: ranges[index].offset, size: ranges[index].size)
        }
    }

    /// Where each slice of a universal binary starts and how long it is.
    private static func fatRanges(_ reader: ByteReader, is64: Bool, fileSize: UInt64) throws -> [(offset: Int, size: UInt64)] {
        guard reader.count >= 8 else { throw ParseError.truncated }
        let count = Int(try reader.uint32BE(at: 4))
        // 0xCAFEBABE is also the magic of Java class files, where these bytes are a version
        // number in the forties or higher.
        guard (1...32).contains(count) else { throw ParseError.notMachO }
        let entrySize = is64 ? 32 : 20
        // At most 8 + 32 * 32 bytes, so a file the size of `headerProbe` holds the whole table.
        guard reader.count >= 8 + count * entrySize else { throw ParseError.truncated }
        return try (0..<count).map { index in
            let entry = 8 + index * entrySize
            let offset = is64 ? try reader.uint64BE(at: entry + 8) : UInt64(try reader.uint32BE(at: entry + 8))
            let size = is64 ? try reader.uint64BE(at: entry + 16) : UInt64(try reader.uint32BE(at: entry + 12))
            let (end, overflow) = offset.addingReportingOverflow(size)
            guard !overflow, end <= fileSize, let start = Int(exactly: offset) else {
                throw ParseError.malformed("slice \(index + 1) ends past the end of the file")
            }
            return (start, size)
        }
    }

    /// Where a slice's load commands end, from the header at the start of `reader`.
    private static func loadCommandsEnd(_ reader: ByteReader, size: UInt64) throws -> Int {
        guard reader.count >= 24 else { throw ParseError.truncated }
        let headerSize = try reader.uint32LE(at: 0) == 0xFEED_FACF ? 32 : 28
        let commandBytes = Int(try reader.uint32LE(at: 20))
        // The header's size field decides how much is read (and, in an .ipa, decompressed), so a
        // value larger than the slice or than any real binary uses is refused.
        guard commandBytes <= maximumLoadCommandBytes, UInt64(headerSize + commandBytes) <= size else {
            throw ParseError.malformed("load commands of \(commandBytes) bytes do not fit the slice")
        }
        return headerSize + commandBytes
    }

    /// Reads one slice whose header starts at the start of `reader`; `offset` is where the slice
    /// starts in the file.
    private static func slice(_ reader: ByteReader, offset: Int, size: UInt64) throws -> MachOSlice {
        let magic = try reader.uint32LE(at: 0)
        let is64: Bool
        switch magic {
        case 0xFEED_FACF: is64 = true
        case 0xFEED_FACE: is64 = false
        default: throw ParseError.malformed("slice at offset \(offset) has no Mach-O header")
        }
        let cpuType = try reader.uint32LE(at: 4)
        let cpuSubtype = try reader.uint32LE(at: 8)
        let fileType = try reader.uint32LE(at: 12)
        // No loader accepts CPU type 0 or file type 0; a header that is zero after the magic would
        // otherwise be listed as a "cpu0" slice of "type0".
        guard cpuType != 0, fileType != 0 else {
            throw ParseError.malformed("slice at offset \(offset) has no CPU type or file type")
        }
        let commandCount = Int(try reader.uint32LE(at: 16))
        var command = is64 ? 32 : 28

        var segments: [MachOSegment] = []
        var swiftBytes: UInt64 = 0
        var signatureBytes: UInt64 = 0
        for _ in 0..<commandCount {
            let kind = try reader.uint32LE(at: command)
            let length = Int(try reader.uint32LE(at: command + 4))
            guard length >= 8 else { throw ParseError.malformed("load command shorter than 8 bytes") }
            switch kind {
            case LoadCommand.segment64, LoadCommand.segment:
                let wide = kind == LoadCommand.segment64
                let name = try reader.fixedString(at: command + 8, length: 16)
                let fileSize = wide ? try reader.uint64LE(at: command + 48) : UInt64(try reader.uint32LE(at: command + 36))
                let sectionCount = Int(try reader.uint32LE(at: command + (wide ? 64 : 48)))
                if fileSize > 0 { segments.append(MachOSegment(name: name, bytes: fileSize)) }
                var section = command + (wide ? 72 : 56)
                for _ in 0..<sectionCount {
                    let sectionName = try reader.fixedString(at: section, length: 16)
                    if sectionName.hasPrefix("__swift5_") {
                        let sectionBytes = wide ? try reader.uint64LE(at: section + 40) : UInt64(try reader.uint32LE(at: section + 36))
                        swiftBytes = swiftBytes.addingSaturating(sectionBytes)
                    }
                    section += wide ? 80 : 68
                }
            case LoadCommand.codeSignature:
                signatureBytes = UInt64(try reader.uint32LE(at: command + 12))
            default:
                break
            }
            command += length
        }
        return MachOSlice(
            architecture: architectureName(cpuType: cpuType, cpuSubtype: cpuSubtype),
            offset: UInt64(offset),
            bytes: size,
            fileType: fileTypeName(fileType),
            segments: segments,
            swiftMetadataBytes: swiftBytes,
            codeSignatureBytes: signatureBytes
        )
    }

    private enum LoadCommand {
        static let segment: UInt32 = 0x1
        static let segment64: UInt32 = 0x19
        static let codeSignature: UInt32 = 0x1D
    }

    static func architectureName(cpuType: UInt32, cpuSubtype: UInt32) -> String {
        let subtype = cpuSubtype & 0x00FF_FFFF
        switch cpuType {
        case 0x0100_000C:
            switch subtype {
            case 2: return "arm64e"
            default: return "arm64"
            }
        case 0x0200_000C: return "arm64_32"
        case 0x0100_0007: return subtype == 8 ? "x86_64h" : "x86_64"
        case 7: return "i386"
        case 12:
            let names: [UInt32: String] = [6: "armv6", 9: "armv7", 10: "armv7f", 11: "armv7s", 12: "armv7k", 13: "armv8", 14: "armv6m", 15: "armv7m", 16: "armv7em"]
            return names[subtype] ?? "arm"
        default:
            return "cpu\(cpuType)"
        }
    }

    static func fileTypeName(_ type: UInt32) -> String {
        let names: [UInt32: String] = [
            1: "object", 2: "executable", 3: "fvmlib", 4: "core", 5: "preload", 6: "dylib",
            7: "dylinker", 8: "bundle", 9: "dylib-stub", 10: "dsym", 11: "kext", 12: "fileset",
        ]
        return names[type] ?? "type\(type)"
    }
}
