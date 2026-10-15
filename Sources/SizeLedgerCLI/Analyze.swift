import ArgumentParser
import Foundation
import SizeLedgerKit

/// `sizeledger analyze <input>`: measures an app and prints or writes the report.
public struct Analyze: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Measure an .app bundle, an .ipa or an .xcarchive.",
        discussion: """
        Prints where the app's bytes are: by category, largest items, languages and binaries \
        with their architecture slices. Sizes are in decimal units (1 MB = 1,000,000 bytes).

        "Install size (estimate)" rounds every file up to whole 4 KiB blocks. It is not the \
        App Store's download or install size, which depend on thinning, encryption and \
        compression done by Apple. For an .ipa the compressed size inside the archive is shown too.

        Exit status: 0 when the report was made, 2 when the input could not be read or the \
        report could not be written, 64 for invalid options.
        """
    )

    public enum Format: String, ExpressibleByArgument, CaseIterable, Sendable {
        case tty, markdown, json
    }

    public enum ColorMode: String, ExpressibleByArgument, CaseIterable, Sendable {
        case auto, always, never
    }

    @Argument(help: ArgumentHelp("The .app folder, .ipa file or .xcarchive folder to measure.", valueName: "input"))
    var input: String

    @Option(name: .shortAndLong, help: "What to print: tty (a table), markdown or json.")
    var format: Format = .tty

    @Option(name: .shortAndLong, help: ArgumentHelp("Also write the JSON report to this file; missing folders are created.", valueName: "file"))
    var out: String?

    @Option(help: "How many of the largest items, languages and binaries to list.")
    var top: Int = 10

    @Option(help: "Colour in tty output: auto (only in a terminal, and not when NO_COLOR is set), always or never.")
    var color: ColorMode = .auto

    @Flag(name: .shortAndLong, help: "Print nothing; use with --out.")
    var quiet = false

    public init() {}

    public func validate() throws {
        guard top >= 1 else { throw ValidationError("--top must be 1 or more.") }
    }

    public func run() throws {
        var output = StandardStream.output
        var errors = StandardStream.error
        let status = execute(
            output: &output,
            errors: &errors,
            environment: ProcessInfo.processInfo.environment,
            isTerminal: StandardStream.outputIsTerminal
        )
        if status != ExitStatus.success { throw ExitCode(status) }
    }

    /// Runs the command with the given streams; returns the exit status.
    func execute(
        output: inout some TextOutputStream,
        errors: inout some TextOutputStream,
        environment: [String: String] = [:],
        isTerminal: Bool = false
    ) -> Int32 {
        let report: SizeReport
        do {
            report = try SizeLedger.analyze(URL(fileURLWithPath: input))
        } catch {
            errors.write("sizeledger: \(error)\n")
            return ExitStatus.failure
        }

        if let out {
            do {
                let url = URL(fileURLWithPath: out)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try report.jsonData().write(to: url, options: .atomic)
            } catch {
                errors.write("sizeledger: cannot write \(out): \(error.localizedDescription)\n")
                return ExitStatus.failure
            }
        }

        guard !quiet else { return ExitStatus.success }
        switch format {
        case .tty:
            let useColor = color == .always || (color == .auto && isTerminal && environment["NO_COLOR"] == nil && environment["TERM"] != "dumb")
            output.write(TextReport.render(report, options: .init(top: top, color: useColor)))
        case .markdown:
            output.write(MarkdownReport.render(report, options: .init(top: top)))
        case .json:
            // jsonData() only fails for values JSON cannot hold; a report has none.
            output.write(String(decoding: (try? report.jsonData()) ?? Data(), as: UTF8.self))
        }
        return ExitStatus.success
    }
}
