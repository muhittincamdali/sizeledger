import Foundation
import Testing
@testable import SizeLedgerKit

/// Values from the app go into GitHub Markdown, so the escaping is checked against GitHub's own
/// renderer, not against an idea of it. `Fixtures/markdown/escaping.json` holds each tricky input,
/// what `MarkdownReport.text` and `.code` make of it, the table row built from them and the HTML
/// GitHub rendered for that row (`Fixtures/scripts/render-markdown-fixture.py`, which calls
/// `gh api markdown` in gfm mode). This test fails when the escaping changes without the fixture
/// being rendered again, or when GitHub's HTML shows a link, mention, image, math or extra cell.
@Suite struct MarkdownEscapingTests {
    struct Case: Codable {
        var name: String
        var input: String
        var text: String?
        var code: String?
        var row: String?
        var html: String?
    }

    struct File: Codable {
        var cases: [Case]
    }

    static let url = Fixtures.root.appendingPathComponent("markdown").appendingPathComponent("escaping.json")

    /// The table row the script renders: both forms of the value, then a marker cell that must
    /// come out as the third and last cell.
    static func row(text: String, code: String) -> String {
        "| \(text) | \(code) | end |"
    }

    @Test func matchesWhatGitHubRendered() throws {
        var file = try JSONDecoder().decode(File.self, from: Data(contentsOf: Self.url))
        if ProcessInfo.processInfo.environment["SIZELEDGER_UPDATE_SNAPSHOTS"] != nil {
            for index in file.cases.indices {
                let input = file.cases[index].input
                file.cases[index].text = MarkdownReport.text(input)
                file.cases[index].code = MarkdownReport.code(input)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try (encoder.encode(file) + Data("\n".utf8)).write(to: Self.url)
            return
        }
        #expect(file.cases.count >= 20)
        for item in file.cases {
            let text = MarkdownReport.text(item.input)
            let code = MarkdownReport.code(item.input)
            #expect(text == item.text, "\(item.name): escaping changed; update the fixture and render it again")
            #expect(code == item.code, "\(item.name): escaping changed; update the fixture and render it again")
            #expect(item.row == Self.row(text: text, code: code), "\(item.name): the HTML was rendered from another row")
            let html = try #require(item.html, "\(item.name): run Fixtures/scripts/render-markdown-fixture.py")
            #expect(html.components(separatedBy: "<td").count - 1 == 3, "\(item.name): the row was split")
            #expect(html.contains("<td>end</td>"), "\(item.name): the marker cell moved")
            for markup in ["<a ", "<img", "user-mention", "issue-link", "<script", "<br", "math-renderer", "<math"] {
                #expect(!html.contains(markup), "\(item.name): GitHub rendered \(markup)")
            }
        }
    }

    @Test func markdownKeepsEveryDollarInACodeSpan() throws {
        // GitHub typesets $...$ as math even with the dollars backslash-escaped, so an app named
        // like this would print a green "Size check passed" into a job summary.
        let payload = #"$\color{green}{\textsf{Size check passed}}$"#
        let temp = try TemporaryDirectory()
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>CFBundleDisplayName</key><string>\(payload)</string>
        <key>CFBundleShortVersionString</key><string>$1$</string>
        <key>CFBundleIdentifier</key><string>com.example.$x$</string>
        </dict></plist>
        """
        try temp.file("App.app/Info.plist", contents: Data(plist.utf8))
        try temp.file("App.app/$\\huge{x}$.bin", size: 5_000)
        let markdown = MarkdownReport.render(try SizeLedger.analyze(temp.url.appendingPathComponent("App.app")))
        #expect(markdown.contains("`$\\huge{x}$.bin`"))
        for line in markdown.split(separator: "\n") {
            #expect(!Self.outsideCodeSpans(String(line)).contains("$"), "\(line)")
        }
    }

    /// The parts of a line outside CommonMark code spans: a run of backticks opens a span that
    /// the next run of the same length closes; a run with no closing match is literal text.
    static func outsideCodeSpans(_ line: String) -> String {
        let scalars = Array(line.unicodeScalars)
        func run(at index: Int) -> Int {
            var end = index
            while end < scalars.count, scalars[end] == "`" { end += 1 }
            return end - index
        }
        var outside = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            guard scalars[index] == "`", index == 0 || scalars[index - 1] != "\\" else {
                outside.append(scalars[index])
                index += 1
                continue
            }
            let length = run(at: index)
            var close = index + length
            while close < scalars.count {
                if scalars[close] == "`" {
                    let closing = run(at: close)
                    if closing == length { break }
                    close += closing
                } else {
                    close += 1
                }
            }
            if close >= scalars.count {
                outside.append(contentsOf: scalars[index..<(index + length)])
                index += length
            } else {
                index = close + length
            }
        }
        return String(outside)
    }
}
