import Testing
@testable import SizeLedgerKit

@Test func versionIsSemantic() {
    let pattern = #/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/#
    #expect(SizeLedger.version.wholeMatch(of: pattern) != nil)
}
