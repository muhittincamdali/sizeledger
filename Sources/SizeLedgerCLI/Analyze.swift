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

    @Option(name: .shortAndLong, help: ArgumentHelp("Also write the JSON report to this file; missing folders are created. An existing file is kept unless --force is given; a symbolic link is followed only to a device or pipe such as /dev/stdout.", valueName: "file"))
    var out: String?

    @Flag(help: "Replace the --out file if it already exists.")
    var force = false

    @Option(help: "How many of the largest items, languages and binaries to list.")
    var top: Int = 10

    @Option(help: "Colour in tty output: auto (only in a terminal, and not when NO_COLOR is set), always or never.")
    var color: ColorMode = .auto

    @Flag(name: .shortAndLong, help: "Print nothing; needs --out.")
    var quiet = false

    @Option(help: ArgumentHelp("Refuse an input with more files than this.", valueName: "n"))
    var maxFiles: Int = AnalysisLimits.default.maxFiles

    @Option(help: ArgumentHelp("Refuse an .ipa declaring more uncompressed bytes than this. Folders (.app, .xcarchive) are not decompressed and have no such limit.", valueName: "bytes"))
    var maxBytes: UInt64 = AnalysisLimits.default.maxTotalBytes

    @Option(help: ArgumentHelp("Refuse an .ipa entry whose uncompressed-to-stored size ratio is above this (zip bomb).", valueName: "ratio"))
    var maxRatio: UInt64 = AnalysisLimits.default.maxCompressionRatio

    @Option(help: ArgumentHelp("Refuse a path nested deeper than this many folders (at most \(AnalysisLimits.deepestAllowed)).", valueName: "n"))
    var maxDepth: Int = AnalysisLimits.default.maxDepth

    public init() {}

    public func validate() throws {
        guard top >= 1 else { throw ValidationError("--top must be 1 or more.") }
        // Without --out, --quiet would measure the app and keep the result to itself.
        guard !quiet || out != nil else {
            throw ValidationError("--quiet prints nothing, so it needs --out <file> to write the report to.")
        }
        guard !force || out != nil else { throw ValidationError("--force replaces the --out file, so it needs --out <file>.") }
        guard maxFiles >= 1 else { throw ValidationError("--max-files must be 1 or more.") }
        guard maxBytes >= 1 else { throw ValidationError("--max-bytes must be 1 or more.") }
        guard maxRatio >= 1 else { throw ValidationError("--max-ratio must be 1 or more.") }
        guard (1...AnalysisLimits.deepestAllowed).contains(maxDepth) else {
            throw ValidationError("--max-depth must be from 1 to \(AnalysisLimits.deepestAllowed); a deeper report cannot be written as JSON.")
        }
    }

    var limits: AnalysisLimits {
        AnalysisLimits(maxFiles: maxFiles, maxTotalBytes: maxBytes, maxCompressionRatio: maxRatio, maxDepth: maxDepth)
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
            report = try SizeLedger.analyze(URL(fileURLWithPath: input), limits: limits)
        } catch {
            errors.write("sizeledger: \(error)\n")
            return ExitStatus.failure
        }

        // Encoded before anything is written or printed, so a report JSON cannot hold ends with a
        // message and status 2, not with an empty file or empty output and status 0.
        var json = Data()
        if out != nil || (format == .json && !quiet) {
            do {
                json = try report.jsonData()
            } catch {
                errors.write("sizeledger: cannot encode the report as JSON: \(error.localizedDescription)\n")
                return ExitStatus.failure
            }
        }

        if let out {
            do {
                try ReportFile.write(json, to: out, replacing: force)
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
            output.write(String(decoding: json, as: UTF8.self))
        }
        return ExitStatus.success
    }
}
