import ArgumentParser
import Foundation
import Testing
@testable import SizeLedgerCLI
import SizeLedgerKit

/// Runs `sizeledger analyze` in-process and captures what it prints.
struct Run {
    var status: Int32
    var output = ""
    var errors = ""

    init(_ arguments: [String], environment: [String: String] = [:], isTerminal: Bool = false) throws {
        let command = try Analyze.parse(arguments)
        status = command.execute(output: &output, errors: &errors, environment: environment, isTerminal: isTerminal)
    }
}

/// A one-file app bundle in a temporary folder.
final class TinyApp {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("sizeledger-cli-\(UUID().uuidString)")
        let app = folder.appendingPathComponent("Tiny.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("en.lproj"), withIntermediateDirectories: true)
        let info = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleName": "Tiny", "CFBundleShortVersionString": "1.0", "CFBundleExecutable": "Tiny"],
            format: .xml,
            options: 0
        )
        try info.write(to: app.appendingPathComponent("Info.plist"))
        try Data(repeating: 1, count: 5_000).write(to: app.appendingPathComponent("Tiny"))
        try Data(repeating: 2, count: 300).write(to: app.appendingPathComponent("en.lproj/Localizable.strings"))
    }

    var app: String { folder.appendingPathComponent("Tiny.app").path }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }
}

@Suite struct CommandTests {
    @Test func commandReportsTheLibraryVersion() {
        #expect(SizeLedgerCommand.configuration.version == SizeLedger.version)
    }

    @Test func printsATableByDefault() throws {
        let tiny = try TinyApp()
        let run = try Run([tiny.app])
        #expect(run.status == 0)
        #expect(run.errors.isEmpty)
        #expect(run.output.hasPrefix("Tiny 1.0\nTiny.app\n"))
        #expect(run.output.contains("  Main executable                     5.0 kB"))
        #expect(!run.output.contains("\u{1B}["))
    }

    @Test func colorFollowsTheTerminalAndNO_COLOR() throws {
        let tiny = try TinyApp()
        #expect(try Run([tiny.app], isTerminal: true).output.contains("\u{1B}["))
        #expect(!(try Run([tiny.app], environment: ["NO_COLOR": "1"], isTerminal: true).output.contains("\u{1B}[")))
        #expect(!(try Run([tiny.app], environment: ["TERM": "dumb"], isTerminal: true).output.contains("\u{1B}[")))
        #expect(try Run([tiny.app, "--color", "always"]).output.contains("\u{1B}["))
        #expect(!(try Run([tiny.app, "--color", "never"], isTerminal: true).output.contains("\u{1B}[")))
    }

    @Test func printsJSONAndMarkdown() throws {
        let tiny = try TinyApp()
        let json = try Run([tiny.app, "--format", "json"])
        let report = try SizeReport.decode(from: Data(json.output.utf8))
        #expect(report.totals.files == 3)
        #expect(report.app.name == "Tiny")

        let markdown = try Run([tiny.app, "-f", "markdown"])
        #expect(markdown.output.hasPrefix("### Tiny 1.0: app size\n"))
    }

    @Test func writesTheReportFileAndCreatesFolders() throws {
        let tiny = try TinyApp()
        let target = tiny.folder.appendingPathComponent("size/nested/main.json")
        let run = try Run([tiny.app, "--out", target.path, "--quiet"])
        #expect(run.status == 0)
        #expect(run.output.isEmpty)
        let written = try SizeReport.decode(from: Data(contentsOf: target))
        #expect(written.input.name == "Tiny.app")
        // The file and --format json print the same bytes.
        let json = try Run([tiny.app, "--format", "json"])
        #expect(json.output == String(decoding: try Data(contentsOf: target), as: UTF8.self))
    }

    @Test func failsWithStatus2AndAMessage() throws {
        let missing = try Run(["/nonexistent/App.ipa"])
        #expect(missing.status == 2)
        #expect(missing.output.isEmpty)
        #expect(missing.errors == "sizeledger: /nonexistent/App.ipa does not exist\n")
        // The path is printed with its control characters replaced.
        let escaped = try Run(["/nonexistent/\u{1B}[2JApp.ipa"])
        #expect(escaped.errors == "sizeledger: /nonexistent/\u{FFFD}[2JApp.ipa does not exist\n")

        let tiny = try TinyApp()
        let blocked = tiny.folder.appendingPathComponent("file")
        try Data().write(to: blocked)
        let unwritable = try Run([tiny.app, "--out", blocked.appendingPathComponent("x.json").path])
        #expect(unwritable.status == 2)
        #expect(unwritable.errors.hasPrefix("sizeledger: cannot write "))
    }

    @Test func refusesAnXcodeArchiveThatLinksOutside() throws {
        let tiny = try TinyApp()
        let applications = tiny.folder.appendingPathComponent("Linked.xcarchive/Products/Applications")
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: applications.appendingPathComponent("Tiny.app").path, withDestinationPath: tiny.app)

        let run = try Run([tiny.folder.appendingPathComponent("Linked.xcarchive").path, "--format", "json"])
        #expect(run.status == 2)
        #expect(run.output.isEmpty)
        #expect(run.errors.hasSuffix("Tiny.app cannot be read: it is a symbolic link, and links inside an .xcarchive are not followed\n"))
    }

    @Test func rejectsInvalidOptions() {
        #expect(throws: (any Error).self) { _ = try Analyze.parse(["App.ipa", "--top", "0"]) }
        #expect(throws: (any Error).self) { _ = try Analyze.parse(["App.ipa", "--format", "html"]) }
        #expect(throws: (any Error).self) { _ = try Analyze.parse([]) }
        #expect(throws: (any Error).self) { _ = try Analyze.parse(["App.ipa", "--quiet"]) }
        #expect(throws: (any Error).self) { _ = try Analyze.parse(["App.ipa", "-q", "--format", "json"]) }
        #expect(throws: Never.self) { _ = try Analyze.parse(["App.ipa", "-q", "-o", "size.json"]) }
    }

    @Test func pointsToAnalyzeWhenTheSubcommandIsMissing() {
        #expect(SizeLedgerCommand.subcommandHint(for: ["build/MyApp.ipa"]) == """
        build/MyApp.ipa is not a subcommand. To measure it, run:
          sizeledger analyze build/MyApp.ipa
        """)
        // Options after the app are kept, and the command can be pasted into a shell.
        #expect(SizeLedgerCommand.subcommandHint(for: ["My App.xcarchive/", "--format", "json"])?.hasSuffix(
            "\n  sizeledger analyze 'My App.xcarchive/' --format json"
        ) == true)
        #expect(SizeLedgerCommand.subcommandHint(for: ["it's.APP"])?.hasSuffix(#"analyze 'it'\''s.APP'"#) == true)
        #expect(SizeLedgerCommand.subcommandHint(for: ["\u{1B}[2J.ipa"])?.contains("\u{1B}") == false)
        // Subcommands, options and words that are not apps get ArgumentParser's own messages.
        for arguments in [["analyze", "x.ipa"], ["help"], ["--version"], ["anlyze", "x.ipa"], []] {
            #expect(SizeLedgerCommand.subcommandHint(for: arguments) == nil)
        }
    }

    @Test func helpListsTheExitStatuses() {
        let help = Analyze.helpMessage(columns: 100)
        #expect(help.contains("Exit status: 0 when the report was made, 2 when the input could not be read"))
        #expect(help.contains("--format <format>"))
    }
}
