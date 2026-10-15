import Foundation

extension SizeReport {
    /// The report as JSON: keys sorted, two-space indent, one trailing newline. The same report
    /// gives the same bytes on every platform, so reports can be committed and compared.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(self)
        data.append(0x0A)
        return data
    }

    /// Reads a report written by ``jsonData()``.
    ///
    /// - Throws: ``ReportError/newerSchema(_:)`` for a report from a newer sizeledger, or a
    ///   `DecodingError` for JSON that is not a report.
    public static func decode(from data: Data) throws -> SizeReport {
        struct Header: Decodable { let schemaVersion: Int }
        let header = try JSONDecoder().decode(Header.self, from: data)
        guard header.schemaVersion <= currentSchemaVersion else { throw ReportError.newerSchema(header.schemaVersion) }
        return try JSONDecoder().decode(SizeReport.self, from: data)
    }
}

/// Why a saved report could not be read.
public enum ReportError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The report was written with a newer layout than this version reads.
    case newerSchema(Int)

    /// A sentence for the user.
    public var description: String {
        switch self {
        case .newerSchema(let version):
            "the report uses schema version \(version), newer than this sizeledger reads (\(SizeReport.currentSchemaVersion)); update sizeledger"
        }
    }
}
