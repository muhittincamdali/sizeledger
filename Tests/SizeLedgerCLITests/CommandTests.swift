import Testing
@testable import SizeLedgerCLI
import SizeLedgerKit

@Test func commandReportsTheLibraryVersion() {
    #expect(SizeLedgerCommand.configuration.version == SizeLedger.version)
}
