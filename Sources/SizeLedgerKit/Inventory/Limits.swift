import Foundation

/// Bounds on what one input may cost to measure. An `.app`, `.ipa` or `.xcarchive` is untrusted,
/// so a crafted one could declare a billion files, a slice that unpacks to terabytes or a path
/// nested thousands deep. These caps are far above any real app and stop a crafted input from
/// exhausting memory, time or the stack before anything is read. The CLI raises them with
/// `--max-files`, `--max-bytes`, `--max-ratio` and `--max-depth`.
public struct AnalysisLimits: Sendable, Equatable {
    /// Most files (archive entries or bundle files) measured. A crafted central directory can
    /// claim far more entries than its bytes hold; reading them all would exhaust memory.
    public var maxFiles: Int
    /// Most total uncompressed bytes an input may declare, across every file.
    public var maxTotalBytes: UInt64
    /// Largest ratio of a single file's declared uncompressed size to its stored (compressed)
    /// size. A higher ratio is a zip bomb, not a real asset.
    public var maxCompressionRatio: UInt64
    /// Deepest path (number of `/`-separated components) measured. Values above
    /// ``deepestAllowed`` are lowered to it.
    public var maxDepth: Int

    /// Creates a set of limits. Any argument left out keeps the default.
    public init(
        maxFiles: Int = 500_000,
        maxTotalBytes: UInt64 = 8 << 30,
        maxCompressionRatio: UInt64 = 300,
        maxDepth: Int = 64
    ) {
        self.maxFiles = maxFiles
        self.maxTotalBytes = maxTotalBytes
        self.maxCompressionRatio = maxCompressionRatio
        self.maxDepth = maxDepth
    }

    /// The defaults, documented in the README's Limits section.
    public static let `default` = AnalysisLimits()

    /// The highest ``maxDepth`` that is honoured. The JSON report nests two levels per folder,
    /// and `JSONEncoder` and `JSONDecoder` recurse once per level: a few hundred folders pass the
    /// encoder's 512-level limit, and fewer than that can already exhaust the stack of a thread
    /// that is not the main one. 100 folders is far deeper than any real bundle.
    public static let deepestAllowed = 100

    /// These limits with ``maxDepth`` lowered to ``deepestAllowed``.
    var honoured: AnalysisLimits {
        var limits = self
        limits.maxDepth = min(maxDepth, Self.deepestAllowed)
        return limits
    }

    /// The number of `/`-separated components in a bundle path.
    static func depth(of path: String) -> Int {
        path.split(separator: "/", omittingEmptySubsequences: true).count
    }
}

extension UInt64 {
    /// `self * other`, or `UInt64.max` when the product does not fit, for comparing a declared
    /// size against a multiple of a stored one without trapping on crafted numbers.
    func multipliedSaturating(by other: UInt64) -> UInt64 {
        let (product, overflow) = multipliedReportingOverflow(by: other)
        return overflow ? .max : product
    }
}
