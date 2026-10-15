import ArgumentParser
import SizeLedgerKit

/// The `sizeledger` command.
public struct SizeLedgerCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "sizeledger",
        abstract: "Shows where the megabytes of an iOS app come from.",
        version: SizeLedger.version
    )

    public init() {}
}
