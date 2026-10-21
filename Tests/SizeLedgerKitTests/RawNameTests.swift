import Foundation
import Testing
@testable import SizeLedgerKit

/// Names that are not UTF-8 are told apart by their stored bytes.
///
/// A ZIP name, or a Linux file name, is a byte string. One that is not valid UTF-8 is shown read
/// as Latin-1, and that text can be the UTF-8 spelling of another name: the byte 0xE9 reads as
/// "é", so `caf\xE9.bin` and the UTF-8 `café.bin` both read "café.bin". Keyed by the decoded text,
/// the second replaced the first as if the archive listed one path twice, and its bytes left the
/// totals without a note.
@Suite struct RawNameTests {
    static let utf8Name = Array("caf\u{E9}.bin".utf8)
    static let latin1Name: [UInt8] = Array("caf".utf8) + [0xE9] + Array(".bin".utf8)

    let temp: TemporaryDirectory

    init() throws {
        temp = try TemporaryDirectory()
    }

    @Test func decodesEachComponentOnItsOwn() {
        #expect(BundlePath.decode(Self.latin1Name) == "caf\u{E9}.bin")
        #expect(BundlePath.decode(Self.utf8Name) == "caf\u{E9}.bin")
        // A valid UTF-8 folder keeps its reading next to a Latin-1 file name.
        let mixed = Array("\u{E9}t\u{E9}/".utf8) + [0xFF]
        #expect(BundlePath.decode(mixed) == "\u{E9}t\u{E9}/\u{FF}")
        #expect(BundlePath.decode(Array("a//b/".utf8)) == "a//b/")
        #expect(!BundlePath.isUTF8(Self.latin1Name))
        #expect(BundlePath.isUTF8(Self.utf8Name))
    }

    @Test func countsAUTF8NameAndTheLatin1NameThatReadsTheSameAsTwoFiles() throws {
        let url = try ipa()
        let source = try IPASource(url: url)
        let names = source.entries.filter { $0.path == "caf\u{E9}.bin" }
        #expect(names.count == 2)
        #expect(Set(names.map(\.key)) == [PathKey(bytes: Self.utf8Name), PathKey(bytes: Self.latin1Name)])
        #expect(try source.contents(of: PathKey(bytes: Self.utf8Name), ranges: [0..<10]) == [Data(repeating: 0x7A, count: 10)])
        #expect(try source.contents(of: PathKey(bytes: Self.latin1Name), ranges: [0..<10]) == [Data(repeating: 0x79, count: 10)])

        let report = try SizeLedger.analyze(url)
        #expect(report.totals.files == 4)
        #expect(report.totals.bytes == 5_000_110 + UInt64(Self.plist.count))
    }

    @Test func stillMeasuresARepeatedRawNameOnce() throws {
        var builder = ZipBuilder()
        builder.add("Payload/G.app/G", Data(repeating: 1, count: 100))
        builder.add(name: Array("Payload/G.app/".utf8) + Self.latin1Name, Data(repeating: 2, count: 10))
        builder.add(name: Array("Payload/G.app/".utf8) + Self.latin1Name, Data(repeating: 3, count: 30))
        let source = try IPASource(url: try temp.file("G.ipa", contents: builder.build()))
        #expect(source.entries.map(\.bytes) == [100, 30])
    }

    @Test func keepsALatin1BundleNameApartFromItsUTF8Reading() throws {
        var builder = ZipBuilder()
        builder.add("Payload/Caf\u{E9}.app/x", Data(count: 1))
        builder.add(name: Array("Payload/Caf".utf8) + [0xE9] + Array(".app/y".utf8), Data(count: 1))
        let url = try temp.file("G.ipa", contents: builder.build())
        #expect(throws: InputError.severalApps("G.ipa", ["Caf\u{E9}.app", "Caf\u{E9}.app"])) { _ = try IPASource(url: url) }
    }

    static let plist = try! PropertyListSerialization.data(fromPropertyList: ["CFBundleExecutable": "G"], format: .binary, options: 0)

    /// The archive from the report: Info.plist, a 100-byte executable, the UTF-8 `café.bin` of
    /// 5,000,000 bytes and the Latin-1 `caf\xE9.bin` of 10.
    private func ipa() throws -> URL {
        var builder = ZipBuilder()
        builder.add("Payload/G.app/Info.plist", Self.plist)
        builder.add("Payload/G.app/G", Data(repeating: 0x78, count: 100))
        builder.add(name: Array("Payload/G.app/".utf8) + Self.utf8Name, Data(repeating: 0x7A, count: 5_000_000))
        builder.add(name: Array("Payload/G.app/".utf8) + Self.latin1Name, Data(repeating: 0x79, count: 10))
        return try temp.file("G.ipa", contents: builder.build())
    }
}
