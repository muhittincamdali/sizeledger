import Foundation

/// Decoder for raw DEFLATE streams (RFC 1951), the compression that ZIP archives, and so `.ipa`
/// files, use for most entries.
///
/// sizeledger only decompresses what it has to read: the app's Info.plist and the headers of its
/// Mach-O binaries. Decoding stops once the last requested byte is out, so reading the first
/// kilobytes of a 100 MB binary does not decompress the rest. Bytes before a requested range are
/// decoded and dropped, keeping only the 32 KiB that later back-references can reach, so reading
/// a header deep inside a file costs time but not memory. Written in Swift instead of linking zlib
/// so that the same code runs on macOS and Linux without system libraries.
enum Inflate {
    /// Decompresses `input`, stopping once at least `limit` bytes are produced.
    static func decompress(_ input: Data, limit: Int = .max) throws(InflateError) -> [UInt8] {
        try decompress(input, ranges: [0..<limit])[0]
    }

    /// The bytes of the decompressed stream in each of `ranges`, cut short where the stream ends.
    static func decompress(_ input: Data, ranges: [Range<Int>]) throws(InflateError) -> [[UInt8]] {
        try decode(input, ranges: ranges).pieces
    }

    /// Like ``decompress(_:ranges:)``, also returning the largest size the decoding buffer reached.
    ///
    /// The stream is read where it lies, a slice of the mapped archive, and never copied: reading
    /// a 4-byte prefix of a 100 MB entry costs a few bytes of input, not 100 MB.
    static func decode(_ input: Data, ranges: [Range<Int>]) throws(InflateError) -> (pieces: [[UInt8]], largestBuffer: Int) {
        let result = input.withUnsafeBytes { bytes -> Result<(pieces: [[UInt8]], largestBuffer: Int), InflateError> in
            var inflater = Inflater(input: bytes, ranges: ranges)
            do throws(InflateError) {
                try inflater.run()
            } catch {
                return .failure(error)
            }
            inflater.collect(upTo: inflater.produced)
            return .success((inflater.pieces, inflater.largestBuffer))
        }
        return try result.get()
    }
}

enum InflateError: Error, Equatable, CustomStringConvertible {
    case truncated
    case invalidBlockType
    case storedLengthMismatch
    case invalidCodeLengths
    case invalidSymbol
    case distanceTooFar

    /// Words for the "not valid DEFLATE data" error, which quotes this reason.
    var description: String {
        switch self {
        case .truncated: "the data ends early"
        case .invalidBlockType: "a block has an unknown type"
        case .storedLengthMismatch: "a stored block's length and its check do not match"
        case .invalidCodeLengths: "a Huffman table is invalid"
        case .invalidSymbol: "a code is not in its Huffman table"
        case .distanceTooFar: "a back-reference points before the start of the data"
        }
    }
}

private let lengthBase: [Int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
private let lengthExtra: [Int] = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
private let distanceBase: [Int] = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
private let distanceExtra: [Int] = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
/// Order in which the code length code lengths are stored in a dynamic block header.
private let codeLengthOrder: [Int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

private struct Inflater {
    /// The farthest back a DEFLATE length/distance pair can reach.
    static let history = 32_768
    /// Decoded bytes are dropped from the front of `output` in steps of this size.
    static let dropStep = 256 << 10

    /// Valid only inside the `withUnsafeBytes` call that made this decoder.
    let input: UnsafeRawBufferPointer
    let ranges: [Range<Int>]
    let limit: Int
    /// The bytes of each range, filled as decoding passes them.
    private(set) var pieces: [[UInt8]]
    /// The last decoded bytes: at least `history` of them, at most `history + dropStep` plus one
    /// block's worth.
    private var output: [UInt8] = []
    /// Decoded bytes no longer in `output`.
    private var dropped = 0
    private(set) var largestBuffer = 0
    private var position = 0
    private var bitBuffer: UInt64 = 0
    private var bitCount = 0

    init(input: UnsafeRawBufferPointer, ranges: [Range<Int>]) {
        self.input = input
        self.ranges = ranges
        limit = ranges.map(\.upperBound).max() ?? 0
        pieces = Array(repeating: [], count: ranges.count)
    }

    /// Bytes decoded so far.
    var produced: Int { dropped + output.count }

    mutating func run() throws(InflateError) {
        var isFinal = false
        while !isFinal, produced < limit {
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

    // MARK: Output

    /// Copies the decoded bytes before `end` that fall in a range into that range's piece.
    mutating func collect(upTo end: Int) {
        for (index, range) in ranges.enumerated() {
            let lower = max(range.lowerBound, dropped)
            let upper = min(range.upperBound, end)
            guard lower < upper else { continue }
            pieces[index].append(contentsOf: output[(lower - dropped)..<(upper - dropped)])
        }
    }

    /// Keeps `output` from growing with the stream: once it holds `dropStep` bytes more than
    /// back-references need, those bytes go to the pieces that want them and leave the buffer.
    private mutating func dropOldOutput() {
        largestBuffer = max(largestBuffer, output.count)
        guard output.count >= Self.history + Self.dropStep else { return }
        let count = output.count - Self.history
        collect(upTo: dropped + count)
        output.removeFirst(count)
        dropped += count
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

    /// Tops the bit buffer up to at least 57 bits while input remains, so the decoding loop
    /// rarely has to come back for more.
    private mutating func refill() {
        while bitCount <= 56, position < input.count {
            bitBuffer |= UInt64(input[position]) << UInt64(bitCount)
            position += 1
            bitCount += 8
        }
    }

    private mutating func decode(_ code: Huffman) throws(InflateError) -> Int {
        refill()
        let entry = code.fast[Int(bitBuffer & Huffman.fastMask)]
        let length = Int(entry & 0xF)
        // Bits past the end of the input read as zero, so a short code that fits in the bits
        // that are left is still decoded by the table.
        if entry != 0, length <= bitCount {
            bitBuffer >>= UInt64(length)
            bitCount -= length
            return Int(entry >> 4)
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
        dropOldOutput()
    }

    private mutating func compressedBlock(literals: Huffman, distances: Huffman) throws(InflateError) {
        while produced < limit {
            dropOldOutput()
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
            // Byte by byte: a slice of `output` appended to itself would keep a second reference
            // to the buffer and force a copy of everything decoded so far. It also handles
            // overlapping copies (distance < length) the way DEFLATE defines them.
            let start = output.count - distance
            for offset in 0..<length { output.append(output[start + offset]) }
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
