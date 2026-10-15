import ArgumentParser
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
}

/// Exit statuses, also listed in `sizeledger analyze --help`.
enum ExitStatus {
    static let success: Int32 = 0
    /// The input could not be measured or the report could not be written.
    static let failure: Int32 = 2
}
