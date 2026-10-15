import Foundation
import Testing
@testable import SizeLedgerKit

@Suite struct FormattingTests {
    @Test("formats sizes in decimal units", arguments: [
        (UInt64(0), "0 B"),
        (999, "999 B"),
        (1_000, "1.0 kB"),
        (12_345, "12.3 kB"),
        (999_949, "999.9 kB"),
        (999_999, "1.00 MB"),
        (5_840_000, "5.84 MB"),
        (5_845_000, "5.85 MB"),
        (999_994_999, "999.99 MB"),
        (999_995_000, "1.00 GB"),
        (1_234_567_890, "1.23 GB"),
        (999_999_999_999_999_999, "1000000000.00 GB"),
        (.max, "18446744073.71 GB"),
    ])
    func bytes(value: UInt64, expected: String) {
        #expect(ByteFormat.string(value) == expected)
    }

    @Test func shares() {
        #expect(ByteFormat.share(1, of: 3) == "33.3%")
        #expect(ByteFormat.share(2, of: 3) == "66.7%")
        #expect(ByteFormat.share(5, of: 5) == "100.0%")
        #expect(ByteFormat.share(0, of: 0) == "0.0%")
        #expect(ByteFormat.share(.max, of: .max) == "100.0%")
        #expect(ByteFormat.share(.max / 3, of: .max) == "33.3%")
    }

    @Test func replacesControlCharacters() {
        #expect(Sanitize.text("a\u{1B}[31mb\nc\u{7F}\u{85}") == "a\u{FFFD}[31mb\u{FFFD}c\u{FFFD}\u{FFFD}")
        #expect(Sanitize.text("Ünïcödé 日本") == "Ünïcödé 日本")
    }

    @Test func replacesBidirectionalControls() {
        let controls = (0x202A...0x202E).map { $0 } + (0x2066...0x2069).map { $0 }
        for value in controls {
            let scalar = Unicode.Scalar(UInt32(value))!
            #expect(Sanitize.text("a\(Character(scalar))b") == "a\u{FFFD}b")
        }
        // Marks and right-to-left text are left alone.
        #expect(Sanitize.text("\u{200E}\u{200F}\u{061C}") == "\u{200E}\u{200F}\u{061C}")
        #expect(Sanitize.text("שלום مرحبا") == "שלום مرحبا")
    }

    @Test func shortensPathsFromTheLeft() {
        #expect(Sanitize.shortened("  Frameworks/ShopCore.framework/ShopCore", width: 33) == "  …/ShopCore.framework/ShopCore")
        #expect(Sanitize.shortened("  Frameworks/A.framework/A", width: 33) == "  Frameworks/A.framework/A")
        #expect(Sanitize.shortened("PlugIns/Widget.appex/VeryLongExecutableName", width: 20) == "VeryLongE…utableName")
        #expect(Sanitize.shortened("AnExtremelyLongSingleFileName.json", width: 15) == "AnExtre…me.json")
        #expect(Sanitize.middleTruncated("short", width: 15) == "short")
    }

    @Test func wrapsAtWordBoundaries() {
        #expect(TextReport.wrap("one two three four", width: 9) == ["one two", "three", "four"])
        #expect(TextReport.wrap("", width: 9) == [])
    }
}

@Suite struct TextReportTests {
    static func report() throws -> SizeReport {
        let temp = try TemporaryDirectory()
        return try withExtendedLifetime(temp) { try SizeLedger.analyze(try SyntheticApp.ipa(in: temp)) }
    }

    @Test func showsTheAppTotalsAndSections() throws {
        let text = TextReport.render(try Self.report())
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines[0] == "Shop 1.2 (34)")
        #expect(lines[1] == "com.example.shop · iphoneos · minimum OS 17.0")
        #expect(lines[2] == "Shop.ipa → Shop.app")
        #expect(text.contains("Total                                59.5 kB   12 files"))
        #expect(text.contains("Install size (estimate)              86.0 kB   files rounded up to 4 KiB blocks"))
        #expect(text.contains("Compressed in the .ipa               59.5 kB   bundle files only; the .ipa file is 61.6 kB"))
        #expect(text.contains("  Asset catalogs                     20.0 kB   33.6%      1"))
        #expect(text.contains("Languages (3 .lproj languages)"))
        #expect(text.contains("  Frameworks/Kit.framework/Kit       12.3 kB   arm64 4.1 kB, x86_64 4.1 kB"))
        #expect(text.hasSuffix("\n"))
        #expect(!text.contains("\u{1B}"))
    }

    @Test func colorAddsANSIStylesOnly() throws {
        let report = try Self.report()
        let plain = TextReport.render(report)
        let colored = TextReport.render(report, options: .init(color: true))
        #expect(colored.contains("\u{1B}[1;34m"))
        let stripped = colored.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
        #expect(stripped == plain)
    }

    @Test func limitsListsToTop() throws {
        let text = TextReport.render(try Self.report(), options: .init(top: 2))
        #expect(text.contains("  … and 8 more (--top shows more)"))
        #expect(text.contains("  … and 1 more (--top shows more)"))
    }

    @Test func neutralizesNamesThatCarryTerminalSequences() throws {
        let temp = try TemporaryDirectory()
        try temp.file("Evil.app/\u{1B}]0;title\u{07}.txt", size: 10)
        let report = try SizeLedger.analyze(temp.url.appendingPathComponent("Evil.app"))
        let text = TextReport.render(report)
        #expect(!text.contains("\u{1B}"))
        #expect(!text.contains("\u{07}"))
        #expect(text.contains("\u{FFFD}]0;title\u{FFFD}.txt"))
    }
}

@Suite struct MarkdownReportTests {
    @Test func rendersTablesForASummary() throws {
        let markdown = MarkdownReport.render(try TextReportTests.report())
        #expect(markdown.hasPrefix(#"### Shop 1.2 \(34\): app size"# + "\n"))
        #expect(markdown.contains("`Shop.ipa` → `Shop.app` · com.example.shop · iphoneos · minimum OS 17.0"))
        #expect(markdown.contains("| **Total** (12 files) | **59.5 kB** |"))
        #expect(markdown.contains("| Compressed in the .ipa | 59.5 kB |"))
        #expect(markdown.contains("| Asset catalogs | 20.0 kB | 33.6% | 1 |"))
        #expect(markdown.contains("| `Frameworks/Kit.framework` | 13.2 kB | 22.2% | 3 |"))
        #expect(markdown.contains("| `Frameworks/Kit.framework/Kit` | 12.3 kB | arm64 4.1 kB, x86_64 4.1 kB |"))
        #expect(markdown.contains("#### Notes"))
    }

    @Test func escapesMarkdownInValuesFromTheApp() {
        #expect(MarkdownReport.text("a|b *c* <img> [x](y)") == #"a\|b \*c\* \<img\> \[x\]\(y\)"#)
        #expect(MarkdownReport.code("plain.txt") == "`plain.txt`")
        #expect(MarkdownReport.code("a`b") == "``a`b``")
        #expect(MarkdownReport.code("`edge`") == "`` `edge` ``")
        #expect(MarkdownReport.code("x|y") == #"`x\|y`"#)
        #expect(MarkdownReport.code("line\nbreak") == "`line break`")
    }
}
