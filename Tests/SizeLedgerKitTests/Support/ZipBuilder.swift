import Foundation

/// Writes small ZIP archives with stored (uncompressed) entries, or DEFLATE streams written by the
/// test, for tests of the archive reader that need a particular structure: ZIP64 fields, odd
/// names, flags or broken records.
struct ZipBuilder {
    struct Entry {
        var name: [UInt8]
        var contents: Data
        var unixMode: UInt32?
        var flags: UInt16 = 0x0800
        var method: UInt16 = 0
        /// Write sizes and offset as 0xFFFFFFFF plus a ZIP64 extra field.
        var zip64 = false
        /// The size once decompressed, for a DEFLATE entry; a stored entry's is its length.
        var uncompressedSize: Int?

        var size: Int { uncompressedSize ?? contents.count }
    }

    var entries: [Entry] = []
    var comment = Data()
    /// Write a ZIP64 end record and locator before the classic end record.
    var zip64End = false

    mutating func add(_ name: String, _ contents: Data = Data(), mode: UInt32? = 0o100644, zip64: Bool = false) {
        entries.append(Entry(name: Array(name.utf8), contents: contents, unixMode: mode, zip64: zip64))
    }

    /// Adds an entry whose contents are the DEFLATE `stream`, which decompresses to `size` bytes.
    mutating func addDeflated(_ name: String, stream: Data, size: Int) {
        entries.append(Entry(name: Array(name.utf8), contents: stream, unixMode: 0o100644, method: 8, uncompressedSize: size))
    }

    func build() -> Data {
        var out = Data()
        var central = Data()
        for entry in entries {
            let offset = UInt32(out.count)
            out.append(le32(0x0403_4B50))
            out.append(le16(20))
            out.append(le16(entry.flags))
            out.append(le16(entry.method))
            out.append(le16(0))
            out.append(le16(0))
            out.append(le32(0))
            out.append(le32(UInt32(entry.contents.count)))
            out.append(le32(UInt32(entry.size)))
            out.append(le16(UInt16(entry.name.count)))
            out.append(le16(0))
            out.append(contentsOf: entry.name)
            out.append(entry.contents)

            var extra = Data()
            if entry.zip64 {
                extra.append(le16(0x0001))
                extra.append(le16(24))
                extra.append(le64(UInt64(entry.size)))
                extra.append(le64(UInt64(entry.contents.count)))
                extra.append(le64(UInt64(offset)))
            }
            let marker: UInt32 = 0xFFFF_FFFF
            central.append(le32(0x0201_4B50))
            central.append(le16(entry.unixMode == nil ? 20 : 3 << 8 | 20))
            central.append(le16(20))
            central.append(le16(entry.flags))
            central.append(le16(entry.method))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le32(0))
            central.append(le32(entry.zip64 ? marker : UInt32(entry.contents.count)))
            central.append(le32(entry.zip64 ? marker : UInt32(entry.size)))
            central.append(le16(UInt16(entry.name.count)))
            central.append(le16(UInt16(extra.count)))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le32((entry.unixMode ?? 0) << 16))
            central.append(le32(entry.zip64 ? marker : offset))
            central.append(contentsOf: entry.name)
            central.append(extra)
        }
        let directoryOffset = out.count
        out.append(central)
        if zip64End {
            let record = out.count
            out.append(le32(0x0606_4B50))
            out.append(le64(44))
            out.append(le16(45))
            out.append(le16(45))
            out.append(le32(0))
            out.append(le32(0))
            out.append(le64(UInt64(entries.count)))
            out.append(le64(UInt64(entries.count)))
            out.append(le64(UInt64(central.count)))
            out.append(le64(UInt64(directoryOffset)))
            out.append(le32(0x0706_4B50))
            out.append(le32(0))
            out.append(le64(UInt64(record)))
            out.append(le32(1))
        }
        out.append(le32(0x0605_4B50))
        out.append(le16(0))
        out.append(le16(0))
        out.append(le16(zip64End ? 0xFFFF : UInt16(entries.count)))
        out.append(le16(zip64End ? 0xFFFF : UInt16(entries.count)))
        out.append(le32(zip64End ? 0xFFFF_FFFF : UInt32(central.count)))
        out.append(le32(zip64End ? 0xFFFF_FFFF : UInt32(directoryOffset)))
        out.append(le16(UInt16(comment.count)))
        out.append(comment)
        return out
    }
}

func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
func le64(_ value: UInt64) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
func be32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }
func be64(_ value: UInt64) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }
