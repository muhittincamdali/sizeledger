import ArgumentParser
import Foundation
import SizeLedgerKit

/// The `sizeledger` command.
public struct SizeLedgerCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "sizeledger",
        abstract: "Shows where the megabytes of an iOS app come from.",
        discussion: """
        Measure an .app, .ipa or .xcarchive:

          sizeledger analyze build/MyApp.ipa
          sizeledger analyze build/MyApp.ipa --out size/main.json
          sizeledger analyze MyApp.app --format markdown >> "$GITHUB_STEP_SUMMARY"

        Comparing two reports (diff), size budgets (budget) and an HTML treemap (report) are \
        planned for later versions.
        """,
        version: SizeLedger.version,
        subcommands: [Analyze.self]
    )

    public init() {}

    /// Runs the command with the process's arguments. `sizeledger MyApp.ipa` (an app where the
    /// subcommand belongs) fails like any other invalid use, with status 64, but the message
    /// shows the `analyze` command to run instead of only "Unexpected argument".
    public static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let hint = subcommandHint(for: arguments) {
            exit(withError: ValidationError(hint))
        }
        main(arguments)
    }

    /// The message for arguments that start with an app instead of a subcommand, or `nil`.
    static func subcommandHint(for arguments: [String]) -> String? {
        guard let first = arguments.first, !first.hasPrefix("-") else { return nil }
        let subcommands = configuration.subcommands.map { $0._commandName } + ["help"]
        guard !subcommands.contains(first) else { return nil }
        guard appExtensions.contains(URL(fileURLWithPath: first).pathExtension.lowercased()) else { return nil }
        let command = (["sizeledger", "analyze"] + arguments.map(shellQuoted)).joined(separator: " ")
        return "\(shellQuoted(first)) is not a subcommand. To measure it, run:\n  \(command)"
    }

    private static let appExtensions: Set<String> = ["app", "ipa", "xcarchive"]

    /// The argument as it would be typed in a shell, with control characters replaced so that it
    /// cannot send terminal escape sequences.
    private static func shellQuoted(_ argument: String) -> String {
        let visible = String(String.UnicodeScalarView(argument.unicodeScalars.map { scalar in
            scalar.properties.generalCategory == .control ? "\u{FFFD}" : scalar
        }))
        let plain = visible.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || "-_./+:=@%,".unicodeScalars.contains(scalar))
        }
        if plain && !visible.isEmpty { return visible }
        return "'" + visible.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}

/// Exit statuses, also listed in `sizeledger analyze --help`.
enum ExitStatus {
    static let success: Int32 = 0
    /// The input could not be measured or the report could not be written.
    static let failure: Int32 = 2
}
