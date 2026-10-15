import Foundation
import Testing
@testable import SizeLedgerKit

/// Regression tests for crafted, untrusted inputs: each one made sizeledger crash, hang or use
/// unbounded memory before its fix, and now ends in a typed error or a bounded, correct result.
@Suite struct SecurityTests {
    // MARK: Mach-O arithmetic

    @Test func sumsOversizedSwiftSectionsWithoutOverflow() throws {
        // Two __swift5_ sections whose sizes add past UInt64.max used to trap on the addition.
        let builder = MachOBuilder(
            segments: [
                .init(name: "__TEXT", fileSize: 16_384, sections: [
                    .init(name: "__swift5_types", size: .max),
                    .init(name: "__swift5_protos", size: .max),
                ]),
            ],
            totalSize: 65_536
        )
        let data = builder.build()
        let slices = try MachO.slices(fileSize: UInt64(data.count)) { MachOTests.read(data, $0) }
        #expect(slices.first?.swiftMetadataBytes == .max)
    }

    // MARK: ZIP64 integer conversions and counts

    @Test func refusesAZip64LocatorOffsetBeyondInt() {
        // The locator claims the ZIP64 record sits 0xF000… bytes in; the Int conversion trapped.
        var data = le32(0x0706_4B50) + le32(0) + le64(0xF000_0000_0000_0000) + le32(1)
        data += endRecord(entries: 0xFFFF, size: 0, offset: 0)
        #expect(throws: ZipError.self) { _ = try ZipArchive(data: data) }
    }

    @Test func refusesAZip64DirectoryOffsetBeyondInt() {
        // A valid locator and record, but the record's central-directory offset is above Int.max.
        let record = zip64Record(entries: 0, dirOffset: 0xF000_0000_0000_0000)
        var data = record
        data += le32(0x0706_4B50) + le32(0) + le64(0) + le32(1)
        data += endRecord(entries: 0xFFFF, size: 0, offset: 0xFFFF_FFFF)
        #expect(throws: ZipError.malformed("the central directory points outside the file")) {
            _ = try ZipArchive(data: data)
        }
    }

    @Test func refusesAnArchiveDeclaringTooManyEntries() {
        let record = zip64Record(entries: 1 << 40, dirOffset: 0)
        var data = record
        data += le32(0x0706_4B50) + le32(0) + le64(0) + le32(1)
        data += endRecord(entries: 0xFFFF, size: 0, offset: 0xFFFF_FFFF)
        #expect(throws: ZipError.self) { _ = try ZipArchive(data: data) }
    }

    // MARK: .ipa resource limits

    @Test func refusesAZipBombEntry() throws {
        let temp = try TemporaryDirectory()
        let ipa = try bombIPA(declared: 1 << 30, stored: 1_024, in: temp)
        #expect(throws: InputError.self) { _ = try IPASource(url: ipa) }
    }

    @Test func refusesMoreUncompressedBytesThanAllowed() throws {
        let temp = try TemporaryDirectory()
        var builder = ZipBuilder()
        builder.add("Payload/App.app/", mode: 0o040755)
        builder.add("Payload/App.app/Info.plist", Data("x".utf8))
        builder.entries.append(.init(name: Array("Payload/App.app/big".utf8), contents: Data(count: 10), unixMode: 0o100644, uncompressedSize: 5_000))
        let ipa = try temp.file("App.ipa", contents: builder.build())
        #expect(throws: InputError.self) {
            _ = try IPASource(url: ipa, limits: AnalysisLimits(maxTotalBytes: 1_000))
        }
    }

    @Test func refusesPathsNestedPastTheDepthLimit() throws {
        let temp = try TemporaryDirectory()
        var builder = ZipBuilder()
        builder.add("Payload/App.app/", mode: 0o040755)
        builder.add("Payload/App.app/Info.plist", Data("x".utf8))
        builder.add("Payload/App.app/" + String(repeating: "d/", count: 70) + "f", Data("x".utf8))
        let ipa = try temp.file("App.ipa", contents: builder.build())
        #expect(throws: InputError.self) { _ = try IPASource(url: ipa) }
    }

    @Test func lowersAMaxDepthAboveTheCeiling() throws {
        // A library caller asking for maxDepth 1000 gets the 100-folder ceiling, so the report it
        // gets back can always be encoded as JSON.
        let temp = try TemporaryDirectory()
        let depth = AnalysisLimits.deepestAllowed
        try temp.file("App.app/" + String(repeating: "d/", count: depth) + "f", contents: Data("x".utf8))
        let accepted = try SizeLedger.analyze(temp.url.appendingPathComponent("App.app"), limits: AnalysisLimits(maxDepth: 1_000))
        #expect(try SizeReport.decode(from: accepted.jsonData()) == accepted)

        try temp.file("Deeper.app/" + String(repeating: "d/", count: depth + 1) + "f", contents: Data("x".utf8))
        #expect(throws: InputError.self) {
            _ = try SizeLedger.analyze(temp.url.appendingPathComponent("Deeper.app"), limits: AnalysisLimits(maxDepth: 1_000))
        }
    }

    @Test func countsADuplicatePathOnce() throws {
        let temp = try TemporaryDirectory()
        var builder = ZipBuilder()
        builder.add("Payload/App.app/", mode: 0o040755)
        builder.add("Payload/App.app/Info.plist", Data("x".utf8))
        builder.add("Payload/App.app/dup", Data(repeating: 1, count: 1_000))
        builder.add("Payload/App.app/dup", Data(repeating: 2, count: 5_000))
        let ipa = try temp.file("App.ipa", contents: builder.build())
        let source = try IPASource(url: ipa)
        let dup = source.entries.filter { $0.path == "dup" }
        #expect(dup.count == 1)
        // The last entry wins, the way an unzip tool extracts it.
        #expect(dup.first?.bytes == 5_000)
    }

    // MARK: Tally and tree

    @Test func tallyDoesNotOverflowOnHugeDeclaredSizes() {
        var tally = Tally()
        tally.add(BundleEntry(path: "a", bytes: .max))
        tally.add(BundleEntry(path: "b", bytes: .max))
        #expect(tally.bytes == .max)
        #expect(tally.installBytes == .max)
    }

    @Test func buildsADeepTreeIteratively() {
        // The tree is built from the leaves up with an explicit stack, not recursion, so nesting
        // does not grow the call stack. Real inputs are refused far shallower by
        // AnalysisLimits.maxDepth (see refusesPathsNestedPastTheDepthLimit); this checks the
        // builder stays correct for a nested path and climbs the whole depth.
        let depth = 800
        let deep = (0..<depth).map { "d\($0)" }.joined(separator: "/") + "/file"
        let tree = TreeBuilder.build(rootName: "App", entries: [BundleEntry(path: deep, bytes: 10)]) { _ in .resources }
        #expect(tree.files == 1)
        #expect(tree.bytes == 10)
        var node = tree
        var levels = 0
        while let child = node.children?.first, node.children?.count == 1 {
            node = child
            levels += 1
        }
        #expect(levels == depth + 1)
    }

    // MARK: Output cleaning

    @Test func jsonEscapesControlCharactersInNames() throws {
        let temp = try TemporaryDirectory()
        _ = try temp.file("App.app/Info.plist", contents: Data("<plist></plist>".utf8))
        _ = try temp.file("App.app/bad\u{9b}31m\u{7f}\u{1b}name", contents: Data("x".utf8))
        let report = try SizeLedger.analyze(temp.url.appendingPathComponent("App.app"))
        let json = String(decoding: try report.jsonData(), as: UTF8.self)
        let raw = json.unicodeScalars.filter { $0.value == 0x7F || (0x80...0x9F).contains($0.value) }
        #expect(raw.isEmpty)
        #expect(json.contains("\\u009b"))
        #expect(json.contains("\\u007f"))
    }

    @Test func markdownNeutralizesAutolinks() {
        let url = MarkdownReport.text("see https://evil.example/x now")
        #expect(url.contains("`https://evil.example/x`"))
        #expect(!url.contains(" https://evil.example/x "))
        #expect(MarkdownReport.text("mail user@evil.example").contains("`user@evil.example`"))
        #expect(MarkdownReport.text("host www.evil.example").contains("`www.evil.example`"))
    }

    // MARK: Memory and time bounds

    @Test func decodesAHugeGapWithinABoundedBuffer() throws {
        // 16 MiB of zeros from a tiny stream: the decode buffer must stay near the 32 KiB window,
        // and reaching a header far into the stream must not hang.
        let gap = 16 << 20
        var builder = DeflateBuilder()
        builder.literals(Data("head".utf8))
        builder.zeros(gap)
        builder.literals(Data("tail".utf8))
        let stream = builder.finish()
        let clock = ContinuousClock()
        var largest = 0
        let elapsed = try clock.measure {
            let (pieces, buffer) = try Inflate.decode(stream, ranges: [(gap + 4)..<(gap + 8)])
            largest = buffer
            #expect(pieces == [Array("tail".utf8)])
        }
        #expect(largest < 512 << 10)
        // A generous upper bound that still catches a hang or runaway slowdown in CI.
        #expect(elapsed < .seconds(30))
    }

    @Test func refusesAZipBombQuicklyAndWithoutDecompressing() throws {
        let temp = try TemporaryDirectory()
        let ipa = try bombIPA(declared: (1 << 30) + (1 << 20), stored: 512, in: temp)
        let elapsed = try ContinuousClock().measure {
            #expect(throws: InputError.self) { _ = try IPASource(url: ipa) }
        }
        #expect(elapsed < .seconds(2))
    }

    // MARK: Fuzzing

    @Test func mutatedBinariesNeverCrash() throws {
        let base = [UInt8](MachOTests.app.build())
        var rng = SplitMix64(seed: 0x5126_1ED5_CA1E)
        for _ in 0..<2_000 {
            var bytes = base
            let flips = 1 + Int(rng.next() % 16)
            for _ in 0..<flips {
                bytes[Int(rng.next() % UInt64(bytes.count))] = UInt8(rng.next() & 0xFF)
            }
            let data = Data(bytes)
            // Any outcome is fine except a crash: a typed error or a slice list, never a trap.
            _ = try? MachO.slices(fileSize: UInt64(data.count)) { MachOTests.read(data, $0) }
        }
    }

    // MARK: Helpers

    private func bombIPA(declared: Int, stored: Int, in temp: TemporaryDirectory) throws -> URL {
        var deflate = DeflateBuilder()
        deflate.zeros(stored * 32)
        var builder = ZipBuilder()
        builder.add("Payload/App.app/", mode: 0o040755)
        builder.add("Payload/App.app/Info.plist", Data("x".utf8))
        builder.addDeflated("Payload/App.app/A", stream: deflate.finish(), size: declared)
        return try temp.file("App.ipa", contents: builder.build())
    }

    private func zip64Record(entries: UInt64, dirOffset: UInt64) -> Data {
        var record = le32(0x0606_4B50) + le64(44) + le16(45) + le16(45) + le32(0) + le32(0)
        record += le64(entries) + le64(entries) + le64(0) + le64(dirOffset)
        return record
    }

    private func endRecord(entries: UInt16, size: UInt32, offset: UInt32) -> Data {
        le32(0x0605_4B50) + le16(0) + le16(0) + le16(entries) + le16(entries) + le32(size) + le32(offset) + le16(0)
    }
}

/// A seedable, deterministic generator so the fuzz test runs the same bytes every time.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
