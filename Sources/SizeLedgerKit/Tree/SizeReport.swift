/// Everything sizeledger measured about one app. Encodes to the JSON that `sizeledger analyze
/// --out` writes; decoding it back gives the same value.
///
/// Sizes are in bytes. Three numbers describe each part of the app:
///
/// - `bytes`: the files' sizes added up, as a file manager shows them.
/// - `installBytes`: an estimate of the space on the device. Every file is rounded up to whole
///   4 KiB blocks (APFS allocates whole blocks); it is not what the App Store shows, which
///   depends on thinning, encryption and compression that happen on Apple's servers.
/// - `compressedBytes`: the size inside the `.ipa` archive, only for `.ipa` input.
public struct SizeReport: Codable, Equatable, Sendable {
    /// The JSON layout version. It stays 0 while the layout may still change; 1.0 freezes it at 1.
    public static let currentSchemaVersion = 0

    public var schemaVersion: Int
    public var tool: Tool
    public var input: Input
    public var app: AppInfo
    public var totals: Totals
    /// Non-empty categories, largest first.
    public var categories: [CategoryTotal]
    /// Top-level items, with frameworks, dylibs and extensions split out; largest first.
    public var components: [Component]
    /// `.lproj` folders anywhere in the bundle, grouped by language; largest first.
    public var languages: [LanguageTotal]
    /// Every Mach-O file in the bundle, largest first.
    public var binaries: [Binary]
    /// `.ipa` files outside `Payload/<name>.app`; not part of the totals.
    public var outsideBundle: [OutsideFile]
    /// Remarks that change how to read the numbers, such as "this is a simulator build".
    public var notes: [String]
    /// The whole bundle as a tree of folders and files, each folder's children largest first.
    public var tree: SizeNode

    public struct Tool: Codable, Equatable, Sendable {
        public var name: String
        public var version: String
    }

    public struct Input: Codable, Equatable, Sendable {
        /// File name of what was measured, without its folder.
        public var name: String
        public var kind: InputKind
        /// Name of the app bundle that was measured, such as `MyApp.app`.
        public var bundle: String
        /// Size of the `.ipa` file; only for `.ipa` input.
        public var archiveBytes: UInt64?
    }

    public struct Totals: Codable, Equatable, Sendable {
        public var files: Int
        public var bytes: UInt64
        public var installBytes: UInt64
        public var compressedBytes: UInt64?
    }

    public struct CategoryTotal: Codable, Equatable, Sendable {
        public var category: SizeCategory
        public var files: Int
        public var bytes: UInt64
        public var installBytes: UInt64
        public var compressedBytes: UInt64?
    }

    public struct Component: Codable, Equatable, Sendable {
        public var path: String
        public var category: SizeCategory
        public var files: Int
        public var bytes: UInt64
        public var installBytes: UInt64
        public var compressedBytes: UInt64?
    }

    public struct LanguageTotal: Codable, Equatable, Sendable {
        public var language: String
        public var files: Int
        public var bytes: UInt64
        public var installBytes: UInt64
        public var compressedBytes: UInt64?
    }

    public struct Binary: Codable, Equatable, Sendable {
        public var path: String
        public var bytes: UInt64
        public var slices: [MachOSlice]
    }

    public struct OutsideFile: Codable, Equatable, Sendable {
        public var path: String
        public var bytes: UInt64
        public var compressedBytes: UInt64?
    }
}
