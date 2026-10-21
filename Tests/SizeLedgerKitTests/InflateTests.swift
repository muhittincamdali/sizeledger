import Foundation
import Testing
@testable import SizeLedgerKit

@Suite struct InflateTests {
    struct Expected: Decodable {
        let size: Int
        let crc32: UInt32
    }

    static let manifest: [String: Expected] = {
        let data = try! Data(contentsOf: Fixtures.archive("deflate-manifest.json"))
        return try! JSONDecoder().decode([String: Expected].self, from: data)
    }()

    @Test("decodes zlib's output for every block type", arguments: ["stored", "fixed", "dynamic", "mixed", "empty"])
    func matchesZlib(name: String) throws {
        let stream = try Fixtures.data(Fixtures.archive("\(name).deflate"))
        let expected = try #require(Self.manifest[name])
        let output = try Inflate.decompress(stream)
        #expect(output.count == expected.size)
        #expect(crc32(output) == expected.crc32)
    }

    @Test("stops soon after the limit and returns the right prefix", arguments: ["stored", "fixed", "dynamic", "mixed"])
    func limit(name: String) throws {
        let stream = try Fixtures.data(Fixtures.archive("\(name).deflate"))
        let full = try Inflate.decompress(stream)
        let partial = try Inflate.decompress(stream, limit: 4_096)
        #expect(partial.count >= 4_096)
        #expect(partial.count < full.count)
        #expect(Array(full.prefix(partial.count)) == partial)
    }

    @Test("returns each range of the output", arguments: ["stored", "fixed", "dynamic", "mixed"])
    func ranges(name: String) throws {
        let stream = try Fixtures.data(Fixtures.archive("\(name).deflate"))
        let full = try Inflate.decompress(stream)
        let ranges = [100..<200, 0..<10, full.count - 50..<full.count + 50, full.count + 10..<full.count + 20]
        let pieces = try Inflate.decompress(stream, ranges: ranges)
        #expect(pieces.map(\.count) == [100, 10, 50, 0])
        for (piece, range) in zip(pieces, ranges) {
            #expect(piece == Array(full[min(range.lowerBound, full.count)..<min(range.upperBound, full.count)]))
        }
    }

    @Test func readsFarIntoTheOutputWithASmallBuffer() throws {
        let gap = 16 << 20
        var builder = DeflateBuilder()
        builder.literals(Data("head".utf8))
        builder.zeros(gap)
        builder.literals(Data("tail".utf8))
        let stream = builder.finish()
        #expect(stream.count < 1 << 20)

        let (pieces, largestBuffer) = try Inflate.decode(stream, ranges: [0..<4, (gap + 4)..<(gap + 8), 1_000..<1_010])
        #expect(pieces == [Array("head".utf8), Array("tail".utf8), [UInt8](repeating: 0, count: 10)])
        // 16 MiB went through a buffer of the 32 KiB DEFLATE window plus one drop step.
        #expect(largestBuffer < 512 << 10)
    }

    @Test func readsAPrefixWithoutCopyingTheStream() throws {
        // 64 MiB of stored blocks inside a larger buffer, the way an entry lies in a mapped
        // archive. Copying the stream on every read made 10,000 reads of its first bytes move
        // 640 GiB (10.5 s on a Mac with Apple silicon); reading in place makes them cost a few bytes each.
        let block = 65_535
        var buffer = Data("before".utf8)
        for index in 0..<1_024 {
            buffer.append(index == 1_023 ? 1 : 0) // BFINAL on the last block, BTYPE 00: stored
            buffer.append(le16(UInt16(block)))
            buffer.append(le16(~UInt16(block)))
            buffer.append(Data(repeating: UInt8(truncatingIfNeeded: index), count: block))
        }
        buffer.append(Data("after".utf8))
        let stream = buffer[6..<(buffer.count - 5)]
        let elapsed = try ContinuousClock().measure {
            for _ in 0..<10_000 {
                let head = try Inflate.decompress(stream, limit: 4)
                #expect(head.prefix(4) == [0, 0, 0, 0])
            }
        }
        #expect(try Inflate.decompress(stream, ranges: [(1_023 * block)..<(1_023 * block + 2)]) == [[0xFF, 0xFF]])
        #expect(elapsed < .seconds(2))
    }

    @Test func truncatedStreamThrows() throws {
        let stream = try Fixtures.data(Fixtures.archive("dynamic.deflate"))
        #expect(throws: InflateError.self) {
            _ = try Inflate.decompress(stream.prefix(stream.count / 2))
        }
    }

    @Test func reservedBlockTypeThrows() {
        // BFINAL = 1, BTYPE = 11 (reserved).
        #expect(throws: InflateError.invalidBlockType) {
            _ = try Inflate.decompress(Data([0b0000_0111]))
        }
    }

    @Test func storedLengthMismatchThrows() {
        // BFINAL = 1, BTYPE = 00, then LEN = 1 and an NLEN that is not its complement.
        #expect(throws: InflateError.storedLengthMismatch) {
            _ = try Inflate.decompress(Data([0x01, 0x01, 0x00, 0x00, 0x00, 0x41]))
        }
    }

    @Test func distanceBeforeStartThrows() {
        // Fixed block: length 3 (symbol 257, code 0000001) at distance 1 with nothing written yet.
        #expect(throws: InflateError.distanceTooFar) {
            _ = try Inflate.decompress(Data([0x03, 0x02, 0x00, 0x00]))
        }
    }
}
