import Foundation

/// Writes a raw DEFLATE stream as one block with the fixed Huffman codes. Runs of zeros become
/// 258-byte back-references of 13 bits each, so a few hundred kilobytes of stream decompress to
/// tens of megabytes, the way a crafted `.ipa` hides a large gap in a small file.
struct DeflateBuilder {
    private var bytes: [UInt8] = []
    private var bitBuffer: UInt32 = 0
    private var bitCount = 0

    init() {
        writeBits(1, count: 1) // BFINAL
        writeBits(1, count: 2) // BTYPE 01: fixed codes
    }

    mutating func literals(_ data: Data) {
        for byte in data { literal(byte) }
    }

    mutating func zeros(_ count: Int) {
        guard count > 0 else { return }
        // A back-reference at distance 1 repeats the byte before it, so start with a literal 0.
        literal(0)
        var remaining = count - 1
        while remaining >= 258 {
            writeCode(0xC5, length: 8) // length symbol 285: 258 bytes
            writeBits(0, count: 5) // distance symbol 0: distance 1
            remaining -= 258
        }
        for _ in 0..<remaining { literal(0) }
    }

    mutating func finish() -> Data {
        writeCode(0, length: 7) // end of block (symbol 256)
        if bitCount > 0 { bytes.append(UInt8(bitBuffer & 0xFF)) }
        return Data(bytes)
    }

    private mutating func literal(_ byte: UInt8) {
        if byte < 144 {
            writeCode(0x30 + Int(byte), length: 8)
        } else {
            writeCode(0x190 + Int(byte) - 144, length: 9)
        }
    }

    /// Huffman codes go into the stream most significant bit first.
    private mutating func writeCode(_ code: Int, length: Int) {
        for bit in (0..<length).reversed() {
            writeBits((code >> bit) & 1, count: 1)
        }
    }

    private mutating func writeBits(_ value: Int, count: Int) {
        bitBuffer |= UInt32(value) << UInt32(bitCount)
        bitCount += count
        while bitCount >= 8 {
            bytes.append(UInt8(bitBuffer & 0xFF))
            bitBuffer >>= 8
            bitCount -= 8
        }
    }
}
