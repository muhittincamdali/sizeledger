import Foundation
import Testing
import SizeLedgerKit

/// Runs the built `sizeledger` executable as a separate process, the way users and CI run it.
@Suite struct EndToEndTests {
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SizeLedgerCLITests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent()

    /// `swift build` (and `swift build --build-tests`, which CI runs) links the executable here.
    static let executable = repository.appendingPathComponent(".build/debug/sizeledger")

    static func run(_ arguments: [String]) throws -> (status: Int32, output: String, errors: String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ["NO_COLOR": "1"]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: outputData, as: UTF8.self), String(decoding: errorData, as: UTF8.self))
    }

    static var built: Bool { FileManager.default.isExecutableFile(atPath: executable.path) }

    @Test(.enabled(if: built, "run `swift build` first"))
    func printsTheSameReportAsTheSnapshot() throws {
        let ipa = Self.repository.appendingPathComponent("Fixtures/apps/SampleShop-2.0.ipa").path
        let result = try Self.run(["analyze", ipa])
        #expect(result.status == 0)
        #expect(result.errors.isEmpty)
        let snapshot = try String(contentsOf: Self.repository.appendingPathComponent("Fixtures/snapshots/SampleShop-2.0.txt"), encoding: .utf8)
        #expect(result.output == snapshot)
    }

    @Test(.enabled(if: built, "run `swift build` first"))
    func writesJSONThatDecodes() throws {
        let ipa = Self.repository.appendingPathComponent("Fixtures/apps/SampleShop-1.0.ipa").path
        let result = try Self.run(["analyze", ipa, "--format", "json"])
        #expect(result.status == 0)
        let report = try SizeReport.decode(from: Data(result.output.utf8))
        #expect(report.tool.version == SizeLedger.version)
        #expect(report.app.version == "1.0")
    }

    @Test(.enabled(if: built, "run `swift build` first"))
    func writesTheReportToStandardOutputAndNull() throws {
        // `--out /dev/stdout` used to end with status 2 and "cannot write": the report was
        // written to a temporary file in /dev and moved over the device.
        let ipa = Self.repository.appendingPathComponent("Fixtures/apps/SampleShop-1.0.ipa").path
        let json = try Self.run(["analyze", ipa, "--format", "json"])
        let stdout = try Self.run(["analyze", ipa, "--out", "/dev/stdout", "--quiet"])
        #expect(stdout.status == 0)
        #expect(stdout.errors.isEmpty)
        #expect(stdout.output == json.output)
        let null = try Self.run(["analyze", ipa, "--out", "/dev/null", "--quiet"])
        #expect(null.status == 0)
        #expect(null.errors.isEmpty)
    }

    @Test(.enabled(if: built, "run `swift build` first"))
    func exitsWith2ForAMissingInput() throws {
        let result = try Self.run(["analyze", "/nonexistent/App.ipa"])
        #expect(result.status == 2)
        #expect(result.output.isEmpty)
        #expect(result.errors == "sizeledger: /nonexistent/App.ipa does not exist\n")
    }

    @Test(.enabled(if: built, "run `swift build` first"))
    func exitsWith64ForInvalidOptions() throws {
        let result = try Self.run(["analyze", "x.ipa", "--top", "0"])
        #expect(result.status == 64)
        #expect(result.errors.contains("--top must be 1 or more."))

        let quiet = try Self.run(["analyze", "x.ipa", "--quiet"])
        #expect(quiet.status == 64)
        #expect(quiet.errors.contains("--quiet prints nothing, so it needs --out <file> to write the report to."))
    }

    @Test(.enabled(if: built, "run `swift build` first"))
    func suggestsAnalyzeForAnAppWithoutASubcommand() throws {
        let result = try Self.run(["MyApp.ipa", "--top", "5"])
        #expect(result.status == 64)
        #expect(result.output.isEmpty)
        #expect(result.errors.hasPrefix("Error: MyApp.ipa is not a subcommand. To measure it, run:\n  sizeledger analyze MyApp.ipa --top 5\n"))
    }

    @Test(.enabled(if: built, "run `swift build` first"))
    func printsTheVersion() throws {
        let result = try Self.run(["--version"])
        #expect(result.output == SizeLedger.version + "\n")
    }
}
