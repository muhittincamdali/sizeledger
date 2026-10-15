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

    /// Layout version of the JSON; see ``currentSchemaVersion``.
    public var schemaVersion: Int
    /// The sizeledger that wrote the report.
    public var tool: Tool
    /// What was measured.
    public var input: Input
    /// What the app's Info.plist says about it.
    public var app: AppInfo
    /// The whole bundle.
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

    /// The program that wrote a report.
    public struct Tool: Codable, Equatable, Sendable {
        /// Always `sizeledger`.
        public var name: String
        /// ``SizeLedger/version`` of the writer.
        public var version: String
    }

    /// The file or folder that was measured.
    public struct Input: Codable, Equatable, Sendable {
        /// File name of what was measured, without its folder.
        public var name: String
        /// Whether it was an `.app`, an `.ipa` or an `.xcarchive`.
        public var kind: InputKind
        /// Name of the app bundle that was measured, such as `MyApp.app`.
        public var bundle: String
        /// Size of the `.ipa` file; only for `.ipa` input.
        public var archiveBytes: UInt64?
    }

    /// Sizes of the whole bundle.
    public struct Totals: Codable, Equatable, Sendable {
        /// Files and symbolic links in the bundle.
        public var files: Int
        /// The files' sizes added up.
        public var bytes: UInt64
        /// Every file rounded up to whole 4 KiB blocks: an estimate of the space on a device.
        public var installBytes: UInt64
        /// Size inside the `.ipa`; only for `.ipa` input.
        public var compressedBytes: UInt64?
    }

    /// Sizes of the files in one category.
    public struct CategoryTotal: Codable, Equatable, Sendable {
        /// The category.
        public var category: SizeCategory
        /// Files in the category.
        public var files: Int
        /// Their sizes added up.
        public var bytes: UInt64
        /// Their install size estimate (whole 4 KiB blocks).
        public var installBytes: UInt64
        /// Their size inside the `.ipa`; only for `.ipa` input.
        public var compressedBytes: UInt64?
    }

    /// A top-level file or folder, or a framework, dylib or extension inside a container folder.
    public struct Component: Codable, Equatable, Sendable {
        /// Path inside the bundle, such as `Assets.car` or `Frameworks/Kit.framework`.
        public var path: String
        /// The category of its files.
        public var category: SizeCategory
        /// Files in it.
        public var files: Int
        /// Their sizes added up.
        public var bytes: UInt64
        /// Their install size estimate (whole 4 KiB blocks).
        public var installBytes: UInt64
        /// Their size inside the `.ipa`; only for `.ipa` input.
        public var compressedBytes: UInt64?
    }

    /// Sizes of the files in the `.lproj` folders of one language, anywhere in the bundle.
    public struct LanguageTotal: Codable, Equatable, Sendable {
        /// The folder name without `.lproj`, such as `en`, `pt-BR` or `Base`.
        public var language: String
        /// Files in those folders.
        public var files: Int
        /// Their sizes added up.
        public var bytes: UInt64
        /// Their install size estimate (whole 4 KiB blocks).
        public var installBytes: UInt64
        /// Their size inside the `.ipa`; only for `.ipa` input.
        public var compressedBytes: UInt64?
    }

    /// A Mach-O file in the bundle.
    public struct Binary: Codable, Equatable, Sendable {
        /// Path inside the bundle.
        public var path: String
        /// Size of the whole file, all slices included.
        public var bytes: UInt64
        /// One entry per architecture, in file order.
        public var slices: [MachOSlice]
    }

    /// A file in an `.ipa` that is not part of the app bundle.
    public struct OutsideFile: Codable, Equatable, Sendable {
        /// Path inside the archive, such as `SwiftSupport/iphoneos/libswiftCore.dylib`.
        public var path: String
        /// Its extracted size.
        public var bytes: UInt64
        /// Its size inside the archive.
        public var compressedBytes: UInt64?
    }
}
