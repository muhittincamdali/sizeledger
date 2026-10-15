import Foundation

/// Decoder for raw DEFLATE streams (RFC 1951), the compression that ZIP archives, and so `.ipa`
/// files, use for most entries.
///
/// sizeledger only decompresses what it has to read: the app's Info.plist and the headers of its
/// Mach-O binaries. A `limit` stops decoding as soon as enough bytes are out, so reading the
/// first kilobytes of a 100 MB binary does not decompress the rest. Written in Swift instead of
/// linking zlib so that the same code runs on macOS and Linux without system libraries.
enum Inflate {
    /// Decompresses `input`, stopping once at least `limit` bytes are produced.
    static func decompress(_ input: Data, limit: Int = .max) throws(InflateError) -> [UInt8] {
        var inflater = Inflater(input: [UInt8](input), limit: limit)
        try inflater.run()
        return inflater.output
    }
}

enum InflateError: Error, Equatable {
    case truncated
    case invalidBlockType
    case storedLengthMismatch
    case invalidCodeLengths
    case invalidSymbol
    case distanceTooFar
}

private let lengthBase: [Int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
private let lengthExtra: [Int] = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
private let distanceBase: [Int] = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
private let distanceExtra: [Int] = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
/// Order in which the code length code lengths are stored in a dynamic block header.
private let codeLengthOrder: [Int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

/// A canonical Huffman code. Codes of up to `fastBits` bits decode with one table lookup; longer
/// ones fall back to walking the code lengths one bit at a time.
private struct Huffman {
    static let fastBits = 9
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

private struct Inflater {
    let input: [UInt8]
    let limit: Int
    var output: [UInt8] = []
    private var position = 0
    private var bitBuffer: UInt64 = 0
    private var bitCount = 0

    init(input: [UInt8], limit: Int) {
        self.input = input
        self.limit = limit
    }

    mutating func run() throws(InflateError) {
        var isFinal = false
        while !isFinal, output.count < limit {
            isFinal = try bits(1) == 1
            switch try bits(2) {
            case 0: try storedBlock()
            case 1: try compressedBlock(literals: Self.fixedLiterals, distances: Self.fixedDistances)
            case 2:
                let (literals, distances) = try dynamicTables()
                try compressedBlock(literals: literals, distances: distances)
            default: throw .invalidBlockType
            }
        }
    }

    // MARK: Bits

    /// Loads whole bytes until `count` bits are buffered or the input ends.
    @discardableResult
    private mutating func fill(_ count: Int) -> Bool {
        while bitCount < count, position < input.count {
            bitBuffer |= UInt64(input[position]) << UInt64(bitCount)
            position += 1
            bitCount += 8
        }
        return bitCount >= count
    }

    private mutating func bits(_ count: Int) throws(InflateError) -> Int {
        guard count > 0 else { return 0 }
        guard fill(count) else { throw .truncated }
        let value = Int(bitBuffer & ((1 << UInt64(count)) - 1))
        bitBuffer >>= UInt64(count)
        bitCount -= count
        return value
    }

    private mutating func decode(_ code: Huffman) throws(InflateError) -> Int {
        if fill(Huffman.fastBits) {
            let entry = code.fast[Int(bitBuffer & UInt64((1 << Huffman.fastBits) - 1))]
            if entry != 0 {
                let length = Int(entry & 0xF)
                bitBuffer >>= UInt64(length)
                bitCount -= length
                return Int(entry >> 4)
            }
        }
        // Canonical decoding one bit at a time (as in zlib's reference decoder, puff.c).
        var value = 0, first = 0, index = 0
        for length in 1...Huffman.maxBits {
            value |= try bits(1)
            let count = code.counts[length]
            if value - count < first { return code.symbols[index + (value - first)] }
            index += count
            first = (first + count) << 1
            value <<= 1
        }
        throw .invalidSymbol
    }

    // MARK: Blocks

    private mutating func storedBlock() throws(InflateError) {
        _ = try bits(bitCount & 7)
        let length = try bits(16)
        let complement = try bits(16)
        guard length == ~complement & 0xFFFF else { throw .storedLengthMismatch }
        var remaining = length
        while remaining > 0, bitCount >= 8 {
            output.append(UInt8(try bits(8)))
            remaining -= 1
        }
        guard position + remaining <= input.count else { throw .truncated }
        output.append(contentsOf: input[position..<(position + remaining)])
        position += remaining
    }

    private mutating func compressedBlock(literals: Huffman, distances: Huffman) throws(InflateError) {
        while output.count < limit {
            let symbol = try decode(literals)
            if symbol < 256 {
                output.append(UInt8(symbol))
                continue
            }
            if symbol == 256 { return }
            let lengthIndex = symbol - 257
            guard lengthIndex < lengthBase.count else { throw .invalidSymbol }
            let length = lengthBase[lengthIndex] + (try bits(lengthExtra[lengthIndex]))
            let distanceIndex = try decode(distances)
            guard distanceIndex < distanceBase.count else { throw .invalidSymbol }
            let distance = distanceBase[distanceIndex] + (try bits(distanceExtra[distanceIndex]))
            guard distance <= output.count else { throw .distanceTooFar }
            let start = output.count - distance
            if distance >= length {
                output.append(contentsOf: output[start..<(start + length)])
            } else {
                for offset in 0..<length { output.append(output[start + offset]) }
            }
        }
    }

    private mutating func dynamicTables() throws(InflateError) -> (Huffman, Huffman) {
        let literalCount = try bits(5) + 257
        let distanceCount = try bits(5) + 1
        let codeLengthCount = try bits(4) + 4
        guard literalCount <= 286, distanceCount <= 30 else { throw .invalidCodeLengths }

        var codeLengthLengths = [Int](repeating: 0, count: 19)
        for index in 0..<codeLengthCount {
            codeLengthLengths[codeLengthOrder[index]] = try bits(3)
        }
        let codeLengths = try Huffman(lengths: codeLengthLengths)

        var lengths: [Int] = []
        lengths.reserveCapacity(literalCount + distanceCount)
        while lengths.count < literalCount + distanceCount {
            let symbol = try decode(codeLengths)
            switch symbol {
            case 0...15:
                lengths.append(symbol)
            case 16:
                guard let previous = lengths.last else { throw .invalidCodeLengths }
                lengths.append(contentsOf: repeatElement(previous, count: 3 + (try bits(2))))
            case 17:
                lengths.append(contentsOf: repeatElement(0, count: 3 + (try bits(3))))
            case 18:
                lengths.append(contentsOf: repeatElement(0, count: 11 + (try bits(7))))
            default:
                throw .invalidSymbol
            }
        }
        guard lengths.count == literalCount + distanceCount, lengths[256] != 0 else { throw .invalidCodeLengths }
        return (
            try Huffman(lengths: Array(lengths[0..<literalCount])),
            try Huffman(lengths: Array(lengths[literalCount...]))
        )
    }

    // The fixed codes of block type 1 (RFC 1951, 3.2.6). The lengths are valid, so building them
    // cannot fail.
    private static let fixedLiterals: Huffman = {
        let lengths = (0..<288).map { symbol in
            switch symbol {
            case 0...143: 8
            case 144...255: 9
            case 256...279: 7
            default: 8
            }
        }
        return try! Huffman(lengths: lengths)
    }()

    private static let fixedDistances: Huffman = try! Huffman(lengths: [Int](repeating: 5, count: 30))
}
