import Foundation
import Testing
@testable import SizeLedgerKit

/// Paths are split and compared on their bytes, the way a file system and an unzip tool see them.
///
/// Swift's `String` treats canonically equivalent text as equal and splits by `Character`, so
/// NFC "café.bin" and NFD "café.bin" were one dictionary key, and a "/" followed by a combining
/// mark was not a separator: the mark joins the slash into one `Character`. Each test below
/// failed before paths were handled as bytes.
@Suite struct PathBytesTests {
    static let nfc = "caf\u{E9}.bin"
    static let nfd = "cafe\u{301}.bin"

    let temp: TemporaryDirectory

    init() throws {
        temp = try TemporaryDirectory()
    }

    @Test func refusesADotDotComponentFollowedByACombiningMark() throws {
        let name = "Payload/G.app/../\u{301}evil"
        let url = try ipa(["Payload/G.app/G": 300, name: 500])
        let error = InputError.unreadable(url.path, "entry \(name) has a \"..\" path component")
        #expect(throws: error) { _ = try IPASource(url: url) }
    }

    @Test func keepsANameThatStartsWithACombiningMarkInTheBundle() throws {
        let url = try ipa(["Payload/G.app/Info.plist": 10, "Payload/G.app/\u{301}big.bin": 5_000])
        let source = try IPASource(url: url)
        #expect(source.outsideEntries.isEmpty)
        #expect(source.entries.map(\.path.utf8).contains { $0.elementsEqual("\u{301}big.bin".utf8) })
        let report = try SizeLedger.analyze(url)
        #expect(report.totals.bytes == 5_010)
    }

    @Test func countsNFCAndNFDNamesAsTwoFiles() throws {
        let url = try ipa(["Payload/G.app/" + Self.nfc: 1_000, "Payload/G.app/" + Self.nfd: 5_000])
        let source = try IPASource(url: url)
        #expect(source.entries.count == 2)
        #expect(try source.contents(of: Self.nfc, limit: 10_000).count == 1_000)
        #expect(try source.contents(of: Self.nfd, limit: 10_000).count == 5_000)
        let report = try SizeLedger.analyze(url)
        #expect(report.totals.files == 2)
        #expect(report.totals.bytes == 6_000)
    }

    @Test func refusesTwoAppsThatDifferOnlyInNormalization() throws {
        let url = try ipa(["Payload/Caf\u{E9}.app/x": 1, "Payload/Cafe\u{301}.app/y": 1])
        #expect(throws: InputError.self) { _ = try IPASource(url: url) }
    }

    @Test func countsEverySlashTowardTheDepthLimit() throws {
        #expect(AnalysisLimits.depth(of: "a/\u{301}b/\u{301}c") == 3)
        let deep = "Payload/G.app/" + String(repeating: "d/\u{301}", count: 70) + "f"
        let url = try ipa(["Payload/G.app/Info.plist": 1, deep: 1])
        #expect(throws: InputError.self) { _ = try IPASource(url: url) }
    }

    @Test func treatsATrailingSlashAfterAPrependCharacterAsAFolder() {
        // U+0600 is a prepended concatenation mark: it joins the "/" after it into one Character.
        let entry = ZipEntry(path: "Payload/G.app/x\u{600}/", compressedSize: 0, uncompressedSize: 0, method: 0, flags: 0, localHeaderOffset: 0)
        #expect(entry.isDirectory)
    }

    /// An `.ipa` with one stored file of `size` bytes per path, in this test's own directory.
    private func ipa(_ files: KeyValuePairs<String, Int>) throws -> URL {
        var builder = ZipBuilder()
        for (path, size) in files {
            builder.add(path, Data(repeating: 7, count: size))
        }
        return try temp.file("G.ipa", contents: builder.build())
    }
}
