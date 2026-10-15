import Foundation

/// Bounds-checked reads of fixed-width integers from a byte buffer.
///
/// Offsets are relative to the start of the buffer, whatever `Data`'s own indices are, so a slice
/// can be passed in without adjusting offsets.
struct ByteReader: Sendable {
    let data: Data

    init(_ data: Data) {
        self.data = data
    }

    var count: Int { data.count }

    func contains(_ offset: Int, length: Int) -> Bool {
        offset >= 0 && length >= 0 && offset <= data.count - length
    }

    func uint8(at offset: Int) throws(ByteReaderError) -> UInt8 {
        guard contains(offset, length: 1) else { throw .outOfBounds(offset: offset, length: 1) }
        return data[data.startIndex + offset]
    }

    func uint16LE(at offset: Int) throws(ByteReaderError) -> UInt16 {
        UInt16(truncatingIfNeeded: try littleEndian(at: offset, length: 2))
    }

    func uint32LE(at offset: Int) throws(ByteReaderError) -> UInt32 {
        UInt32(truncatingIfNeeded: try littleEndian(at: offset, length: 4))
    }

    func uint64LE(at offset: Int) throws(ByteReaderError) -> UInt64 {
        try littleEndian(at: offset, length: 8)
    }

    func uint32BE(at offset: Int) throws(ByteReaderError) -> UInt32 {
        UInt32(truncatingIfNeeded: try bigEndian(at: offset, length: 4))
    }

    func uint64BE(at offset: Int) throws(ByteReaderError) -> UInt64 {
        try bigEndian(at: offset, length: 8)
    }

    /// A fixed-size, NUL-padded ASCII field such as a Mach-O segment name.
    func fixedString(at offset: Int, length: Int) throws(ByteReaderError) -> String {
        let bytes = try self.bytes(at: offset, length: length)
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[bytes.startIndex..<end], as: UTF8.self)
    }

    func bytes(at offset: Int, length: Int) throws(ByteReaderError) -> Data {
        guard contains(offset, length: length) else { throw .outOfBounds(offset: offset, length: length) }
        let start = data.startIndex + offset
        return data[start..<(start + length)]
    }

    private func littleEndian(at offset: Int, length: Int) throws(ByteReaderError) -> UInt64 {
        guard contains(offset, length: length) else { throw .outOfBounds(offset: offset, length: length) }
        let start = data.startIndex + offset
        var value: UInt64 = 0
        for index in (0..<length).reversed() {
            value = value << 8 | UInt64(data[start + index])
        }
        return value
    }

    private func bigEndian(at offset: Int, length: Int) throws(ByteReaderError) -> UInt64 {
        guard contains(offset, length: length) else { throw .outOfBounds(offset: offset, length: length) }
        let start = data.startIndex + offset
        var value: UInt64 = 0
        for index in 0..<length {
            value = value << 8 | UInt64(data[start + index])
        }
        return value
    }
}

enum ByteReaderError: Error, Equatable {
    case outOfBounds(offset: Int, length: Int)
}
