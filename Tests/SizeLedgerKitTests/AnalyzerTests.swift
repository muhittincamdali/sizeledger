import Foundation
import Testing
@testable import SizeLedgerKit

@Suite struct AnalyzerTests {
    static func analyzeFolder() throws -> SizeReport {
        let temp = try TemporaryDirectory()
        return try withExtendedLifetime(temp) { try SizeLedger.analyze(try SyntheticApp.folder(in: temp)) }
    }

    @Test func measuresEveryFileOnce() throws {
        let report = try Self.analyzeFolder()
        let files = try SyntheticApp.files()
        #expect(report.totals.files == files.count)
        #expect(report.totals.bytes == files.reduce(0) { $0 + UInt64($1.data.count) })
        #expect(report.totals.compressedBytes == nil)
        // Categories, components and the tree each add up to the totals.
        #expect(report.categories.reduce(0) { $0 + $1.bytes } == report.totals.bytes)
        #expect(report.categories.reduce(0) { $0 + $1.files } == report.totals.files)
        #expect(report.components.reduce(0) { $0 + $1.bytes } == report.totals.bytes)
        #expect(report.components.reduce(0) { $0 + $1.installBytes } == report.totals.installBytes)
        #expect(report.tree.bytes == report.totals.bytes)
        #expect(report.tree.installBytes == report.totals.installBytes)
        #expect(report.tree.files == report.totals.files)
    }

    @Test func estimatesInstallSizeInWholeBlocks() throws {
        let report = try Self.analyzeFolder()
        let expected = try SyntheticApp.files().reduce(UInt64(0)) { sum, file in
            sum + (UInt64(file.data.count) + 4_095) / 4_096 * 4_096
        }
        #expect(report.totals.installBytes == expected)
        #expect(report.totals.installBytes % 4_096 == 0)
        let empty = try #require(report.components.first { $0.path == "Empty.txt" })
        #expect(empty.installBytes == 0)
        let tiny = try #require(report.components.first { $0.path == "catalog.json" })
        #expect(tiny.installBytes == 4_096)
    }

    @Test func readsTheAppAndItsCategories() throws {
        let report = try Self.analyzeFolder()
        #expect(report.input == .init(name: "Shop.app", kind: .app, bundle: "Shop.app", archiveBytes: nil))
        #expect(report.app.name == "Shop")
        #expect(report.app.version == "1.2")
        #expect(report.app.executable == "Shop")
        #expect(report.schemaVersion == 0)
        #expect(report.tool.version == SizeLedger.version)
        let byCategory = Dictionary(uniqueKeysWithValues: report.categories.map { ($0.category, $0.bytes) })
        #expect(byCategory[.executable] == 12_288)
        #expect(byCategory[.assetCatalogs] == 20_000)
        #expect(byCategory[.localizations] == 10_750)
        #expect(byCategory[.codeSignature] == 3_000)
        #expect(byCategory[.appExtensions] == nil)
        #expect(report.categories.map(\.bytes) == report.categories.map(\.bytes).sorted(by: >))
    }

    @Test func countsLanguagesAcrossTheBundle() throws {
        let report = try Self.analyzeFolder()
        #expect(report.languages.map(\.language) == ["de", "en", "Base"])
        #expect(report.languages.first?.bytes == 5_800)
        #expect(report.languages.first?.files == 2)
    }

    @Test func listsBinariesWithTheirSlices() throws {
        let report = try Self.analyzeFolder()
        // Both are 12,288 bytes; equal sizes are ordered by path.
        #expect(report.binaries.map(\.path) == ["Frameworks/Kit.framework/Kit", "Shop"])
        let shop = report.binaries[1]
        #expect(shop.slices.map(\.architecture) == ["arm64"])
        #expect(shop.slices[0].swiftMetadataBytes == 24)
        let kit = report.binaries[0]
        #expect(kit.slices.map(\.architecture) == ["arm64", "x86_64"])
        #expect(kit.slices.allSatisfy { $0.fileType == "dylib" })
        #expect(report.notes == ["1 binary contains more than one architecture. Sizes count every slice; a device keeps one, so after App Store thinning these binaries are smaller."])
    }

    @Test func anIPAGivesTheSameNumbersPlusCompressedSizes() throws {
        let temp = try TemporaryDirectory()
        let folder = try SizeLedger.analyze(try SyntheticApp.folder(in: temp))
        let url = try SyntheticApp.ipa(in: temp, extra: [("Symbols/Shop.symbols", Data(repeating: 9, count: 77))])
        let ipa = try SizeLedger.analyze(url)

        #expect(ipa.input.kind == .ipa)
        #expect(ipa.input.archiveBytes == UInt64(try Data(contentsOf: url).count))
        #expect(ipa.totals.bytes == folder.totals.bytes)
        #expect(ipa.totals.installBytes == folder.totals.installBytes)
        // The test archive stores files uncompressed.
        #expect(ipa.totals.compressedBytes == ipa.totals.bytes)
        #expect(ipa.binaries == folder.binaries)
        #expect(ipa.languages.map(\.bytes) == folder.languages.map(\.bytes))
        #expect(ipa.outsideBundle == [.init(path: "Symbols/Shop.symbols", bytes: 77, compressedBytes: 77)])
        #expect(ipa.notes.last == "1 file in the .ipa is outside Payload/Shop.app and not part of the totals (see outsideBundle).")
    }

    @Test func treeFoldersAreSumsAndLargestFirst() throws {
        let report = try Self.analyzeFolder()
        func check(_ node: SizeNode) {
            guard let children = node.children else {
                #expect(node.category != nil)
                #expect(node.files == 1)
                return
            }
            #expect(node.category == nil)
            #expect(children.reduce(0) { $0 + $1.bytes } == node.bytes)
            #expect(children.reduce(0) { $0 + $1.files } == node.files)
            #expect(children.map(\.bytes) == children.map(\.bytes).sorted(by: >))
            children.forEach(check)
        }
        check(report.tree)
        #expect(report.tree.name == "Shop.app")
        #expect(report.tree.children?.first?.name == "Assets.car")
    }

    @Test func notesAMissingInfoPlist() throws {
        let temp = try TemporaryDirectory()
        try temp.file("Bare.app/Bare", contents: MachOBuilder().build())
        let report = try SizeLedger.analyze(temp.url.appendingPathComponent("Bare.app"))
        #expect(report.app == AppInfo())
        #expect(report.categories.map(\.category) == [.resources])
        #expect(report.notes.first?.hasPrefix("No Info.plist at the top of Bare.app") == true)
    }

    @Test func notesAnInfoPlistThatIsALink() throws {
        // The plist is there but is a link; saying "No Info.plist" sent people looking for a
        // missing file.
        let temp = try TemporaryDirectory()
        try temp.file("Real.plist", contents: Data("<plist></plist>".utf8))
        try temp.file("Linked.app/Linked", contents: MachOBuilder().build())
        try temp.symlink("Linked.app/Info.plist", to: temp.url.appendingPathComponent("Real.plist").path)
        let report = try SizeLedger.analyze(temp.url.appendingPathComponent("Linked.app"))
        #expect(report.app == AppInfo())
        #expect(report.notes.first?.hasPrefix("Info.plist at the top of Linked.app is a symbolic link, and links are not followed: ") == true)
        #expect(!report.notes.contains { $0.hasPrefix("No Info.plist") })
    }

    @Test func notesBrokenMachOHeadersAndCarriesOn() throws {
        let temp = try TemporaryDirectory()
        var broken = MachOBuilder().build()
        broken.replaceSubrange(20..<24, with: le32(0xFFFF))
        try temp.file("Odd.app/Odd", contents: broken.prefix(64))
        let report = try SizeLedger.analyze(temp.url.appendingPathComponent("Odd.app"))
        #expect(report.totals.files == 1)
        #expect(report.binaries.isEmpty)
        #expect(report.notes.contains { $0.hasPrefix("Odd starts like a Mach-O file") })
    }

    @Test func readsASliceFarIntoACompressedBinary() throws {
        // A universal binary whose one slice starts 16 MiB in, deflated so the .ipa stays small:
        // the shape of a crafted file whose fat header points 1 GB in, which once made sizeledger
        // hold every byte before the slice in memory.
        let offset = 16 << 20
        let slice = MachOTests.app.build()
        let head = Data([0xCA, 0xFE, 0xBA, 0xBE]) + be32(1)
            + be32(0x0100_000C) + be32(0) + be32(UInt32(offset)) + be32(UInt32(slice.count)) + be32(14)
        var stream = DeflateBuilder()
        stream.literals(head)
        stream.zeros(offset - head.count)
        stream.literals(slice)
        var builder = ZipBuilder()
        builder.add("Payload/", mode: 0o040755)
        builder.add("Payload/Far.app/", mode: 0o040755)
        builder.addDeflated("Payload/Far.app/Far", stream: stream.finish(), size: offset + slice.count)
        let temp = try TemporaryDirectory()
        let url = try temp.file("Far.ipa", contents: builder.build())
        #expect(try Data(contentsOf: url).count < 1 << 20)

        let report = try SizeLedger.analyze(url)
        let binary = try #require(report.binaries.first)
        #expect(binary.bytes == UInt64(offset + slice.count))
        #expect(binary.slices.map(\.offset) == [UInt64(offset)])
        #expect(binary.slices.map(\.architecture) == ["arm64"])
        #expect(binary.slices.first?.codeSignatureBytes == 2_345)
    }

    @Test func survivesSizesNear2To64() throws {
        // Three ZIP64 entries that each claim almost 2^64 bytes: adding them up, rounding them to
        // 4 KiB blocks and printing them used to overflow and stop sizeledger.
        var builder = ZipBuilder()
        for name in ["a.bin", "b.bin", "c.bin"] {
            builder.add("Payload/Huge.app/" + name, Data("x".utf8), zip64: true)
            builder.entries[builder.entries.count - 1].declaredSize = .max - 15
        }
        let temp = try TemporaryDirectory()
        let url = try temp.file("Huge.ipa", contents: builder.build())

        // The default limits refuse such an archive outright; with them lifted, the sums saturate.
        #expect(throws: InputError.self) { _ = try SizeLedger.analyze(url) }
        let unlimited = AnalysisLimits(maxTotalBytes: .max, maxCompressionRatio: .max)
        let report = try SizeLedger.analyze(url, limits: unlimited)
        #expect(report.totals.files == 3)
        #expect(report.totals.bytes == .max)
        #expect(report.totals.installBytes == .max)
        #expect(report.tree.bytes == .max)
        #expect(TextReport.render(report).contains("18446744073.71 GB   3 files"))
        #expect(MarkdownReport.render(report).contains("| **Total** (3 files) | **18446744073.71 GB** |"))
    }

    @Test func roundTripsThroughJSON() throws {
        let report = try Self.analyzeFolder()
        let data = try report.jsonData()
        #expect(data.last == 0x0A)
        #expect(try SizeReport.decode(from: data) == report)
        // Optional sizes that do not apply are left out rather than written as null.
        #expect(!String(decoding: data, as: UTF8.self).contains("null"))
        #expect(!String(decoding: data, as: UTF8.self).contains("compressedBytes"))
    }

    @Test func refusesAReportFromANewerSchema() throws {
        let data = Data(#"{"schemaVersion": 99}"#.utf8)
        #expect(throws: ReportError.newerSchema(99)) { _ = try SizeReport.decode(from: data) }
    }

    @Test func encodingIsStable() throws {
        // Encoding, decoding and encoding again gives identical bytes.
        let report = try Self.analyzeFolder()
        #expect(try report.jsonData() == (try SizeReport.decode(from: report.jsonData())).jsonData())
    }
}
