import Foundation
import Testing
@testable import SizeLedgerKit

/// Tests on a real app: SampleShop 1.0 and 2.0, built with swiftc and actool for the iOS
/// Simulator. They run the same on macOS and Linux and compare with the same snapshots.
@Suite struct SampleShopTests {
    @Test("the JSON report matches the snapshot", arguments: SampleShop.versions)
    func jsonSnapshot(version: String) throws {
        let report = SampleShop.normalized(try SizeLedger.analyze(SampleShop.ipa(version)))
        let json = String(decoding: try report.jsonData(), as: UTF8.self)
        #expect(try matchesSnapshot(json, "SampleShop-\(version).json"))
    }

    @Test("the text and Markdown reports match their snapshots", arguments: SampleShop.versions)
    func textSnapshots(version: String) throws {
        let report = SampleShop.normalized(try SizeLedger.analyze(SampleShop.ipa(version)))
        #expect(try matchesSnapshot(TextReport.render(report), "SampleShop-\(version).txt"))
        #expect(try matchesSnapshot(MarkdownReport.render(report), "SampleShop-\(version).md"))
    }

    @Test("the extracted .app gives the same sizes as the .ipa", arguments: SampleShop.versions)
    func folderMatchesArchive(version: String) throws {
        let temp = try TemporaryDirectory()
        let app = try SampleShop.extract(version, into: temp.url)
        let folder = try SizeLedger.analyze(app)
        let ipa = try SizeLedger.analyze(SampleShop.ipa(version))
        #expect(folder.totals.files == ipa.totals.files)
        #expect(folder.totals.bytes == ipa.totals.bytes)
        #expect(folder.totals.installBytes == ipa.totals.installBytes)
        #expect(folder.categories.map(\.bytes) == ipa.categories.map(\.bytes))
        #expect(folder.components.map(\.path) == ipa.components.map(\.path))
        #expect(folder.languages.map(\.bytes) == ipa.languages.map(\.bytes))
        #expect(folder.binaries == ipa.binaries)
        #expect(folder.app == ipa.app)
        #expect(folder.input.kind == .app)
        #expect(folder.totals.compressedBytes == nil)
    }

    /// The v0.1 acceptance check: totals agree with `du` within 1% on the platform running the
    /// tests. `du` also counts folders (4 KiB each on ext4, nothing on APFS), so on Linux the
    /// difference is the folders and stays well under 1% for an app of this size.
    @Test("totals agree with du within 1%", arguments: SampleShop.versions)
    func agreesWithDu(version: String) throws {
        let temp = try TemporaryDirectory()
        let app = try SampleShop.extract(version, into: temp.url)
        let report = try SizeLedger.analyze(app)

        let allocated = try duBytes(app, apparent: false)
        let apparent = try duBytes(app, apparent: true)
        let allocatedDifference = abs(Double(report.totals.installBytes) - Double(allocated)) / Double(allocated)
        let apparentDifference = abs(Double(report.totals.bytes) - Double(apparent)) / Double(apparent)
        #expect(allocatedDifference <= 0.01, "install estimate \(report.totals.installBytes) vs du \(allocated)")
        #expect(apparentDifference <= 0.01, "bytes \(report.totals.bytes) vs du apparent size \(apparent)")
    }

    @Test func reportsWhatTheBuildScriptPutIn() throws {
        let old = try SizeLedger.analyze(SampleShop.ipa("1.0"))
        let new = try SizeLedger.analyze(SampleShop.ipa("2.0"))
        #expect(old.app.version == "1.0")
        #expect(new.app.version == "2.0")
        #expect(old.app.isSimulatorBuild && new.app.isSimulatorBuild)
        #expect(old.languages.map(\.language).sorted() == ["de", "en", "ja", "tr"])
        #expect(new.languages.map(\.language).sorted() == ["de", "en", "es", "fr", "ja", "pt-BR", "tr"])
        #expect(old.components.filter { $0.category == .frameworks }.map(\.path) == ["Frameworks/ShopCore.framework"])
        #expect(new.components.filter { $0.category == .frameworks }.map(\.path).sorted() == [
            "Frameworks/Analytics.framework", "Frameworks/ShopCore.framework",
        ])
        for report in [old, new] {
            #expect(report.binaries.allSatisfy { Set($0.slices.map(\.architecture)) == ["arm64", "x86_64"] })
            #expect(report.binaries.first { $0.path == "SampleShop" }?.slices.allSatisfy { $0.fileType == "executable" } == true)
            #expect(report.categories.reduce(0) { $0 + $1.bytes } == report.totals.bytes)
            #expect(report.totals.compressedBytes! < report.totals.bytes)
            #expect(report.input.archiveBytes! > report.totals.compressedBytes!)
        }
        #expect(new.totals.bytes > old.totals.bytes)
    }

    @Test func analyzingTheSameInputTwiceGivesTheSameBytes() throws {
        let first = try SizeLedger.analyze(SampleShop.ipa("2.0")).jsonData()
        let second = try SizeLedger.analyze(SampleShop.ipa("2.0")).jsonData()
        #expect(first == second)
    }
}

/// Bytes `du` reports for a folder: allocated blocks, or apparent size (GNU `--apparent-size`,
/// BSD `-A`).
private func duBytes(_ url: URL, apparent: Bool) throws -> UInt64 {
    #if os(Linux)
    let arguments = apparent ? ["-s", "-b", "--apparent-size", url.path] : ["-s", "-k", url.path]
    let unit: UInt64 = apparent ? 1 : 1_024
    #else
    let arguments = apparent ? ["-s", "-A", url.path] : ["-s", "-k", url.path]
    let unit: UInt64 = apparent ? 512 : 1_024
    #endif
    let result = try run("/usr/bin/du", arguments)
    guard result.status == 0, let number = result.output.split(whereSeparator: { $0 == "\t" || $0 == " " }).first.flatMap({ UInt64($0) }) else {
        throw CocoaError(.fileReadUnknown)
    }
    return number * unit
}
