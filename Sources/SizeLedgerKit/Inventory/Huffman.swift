/// A canonical Huffman code (RFC 1951, 3.2.2), built from the code length of each symbol. Codes of
/// up to `fastBits` bits decode with one table lookup; longer ones fall back to walking the code
/// lengths one bit at a time. The decoding itself is in `Inflate.swift`, next to the bit buffer.
struct Huffman {
    static let fastBits = 9
    static let fastMask = UInt64((1 << fastBits) - 1)
    static let maxBits = 15

    var counts = [Int](repeating: 0, count: maxBits + 1)
    var symbols: [Int]
    /// Indexed by the next `fastBits` input bits: `symbol << 4 | length`, or 0 for a longer code.
    var fast = [UInt16](repeating: 0, count: 1 << fastBits)

    init(lengths: [Int]) throws(InflateError) {
        for length in lengths { counts[length] += 1 }
        counts[0] = 0
        var left = 1
        for length in 1...Self.maxBits {
            left = (left << 1) - counts[length]
            if left < 0 { throw .invalidCodeLengths }
        }

        var offsets = [Int](repeating: 0, count: Self.maxBits + 2)
        for length in 1...Self.maxBits { offsets[length + 1] = offsets[length] + counts[length] }
        symbols = [Int](repeating: 0, count: lengths.count)
        for (symbol, length) in lengths.enumerated() where length != 0 {
            symbols[offsets[length]] = symbol
            offsets[length] += 1
        }

        var nextCode = [Int](repeating: 0, count: Self.maxBits + 1)
        var code = 0
        for length in 1...Self.maxBits {
            code = (code + counts[length - 1]) << 1
            nextCode[length] = code
        }
        for (symbol, length) in lengths.enumerated() where length != 0 {
            let assigned = nextCode[length]
            nextCode[length] += 1
            guard length <= Self.fastBits else { continue }
            // DEFLATE sends Huffman codes most significant bit first into a stream read least
            // significant bit first, so the table is indexed by the reversed code.
            var reversed = 0
            for bit in 0..<length where assigned & (1 << bit) != 0 {
                reversed |= 1 << (length - 1 - bit)
            }
            var index = reversed
            while index < fast.count {
                fast[index] = UInt16(symbol << 4 | length)
                index += 1 << length
            }
        }
    }
}
