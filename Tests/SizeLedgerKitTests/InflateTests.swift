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
