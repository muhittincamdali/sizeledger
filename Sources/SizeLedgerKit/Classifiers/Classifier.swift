/// The part of an app a file belongs to. Every file has exactly one category, so the categories
/// add up to the bundle's total.
public enum SizeCategory: String, Codable, CaseIterable, Sendable, Comparable {
    /// The app's own binary (`CFBundleExecutable`).
    case executable
    /// Everything under `Frameworks/`: embedded frameworks and dylibs, including the Swift
    /// runtime when it is bundled.
    case frameworks
    /// App extensions under `PlugIns/` or `Extensions/`.
    case appExtensions
    /// App Clips under `AppClips/`.
    case appClips
    /// A watchOS app under `Watch/`.
    case watchApp
    /// Localized resources in the bundle's top-level `.lproj` folders.
    case localizations
    /// Compiled asset catalogs (`.car`) at the top level.
    case assetCatalogs
    /// The signature and provisioning profile: `_CodeSignature/`, `embedded.mobileprovision`,
    /// `SC_Info/`.
    case codeSignature
    /// Everything else: storyboards, fonts, data files, resource bundles.
    case resources

    public var title: String {
        switch self {
        case .executable: "Main executable"
        case .frameworks: "Frameworks"
        case .appExtensions: "App extensions"
        case .appClips: "App Clips"
        case .watchApp: "Watch app"
        case .localizations: "Localizations"
        case .assetCatalogs: "Asset catalogs"
        case .codeSignature: "Code signature"
        case .resources: "Other resources"
        }
    }

    public static func < (lhs: SizeCategory, rhs: SizeCategory) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// Decides category, component and language from a file's path inside the bundle.
///
/// The top-level folder decides first: an asset catalog inside a framework counts as part of
/// that framework, not as an asset catalog. Languages are the exception: the language view
/// counts `.lproj` folders anywhere in the bundle.
enum Classifier {
    /// Top-level folders whose children are separate components.
    static let containers: [String: SizeCategory] = [
        "Frameworks": .frameworks,
        "PlugIns": .appExtensions,
        "Extensions": .appExtensions,
        "AppClips": .appClips,
        "Watch": .watchApp,
    ]

    static let signatureFiles: Set<String> = ["_CodeSignature", "SC_Info", "embedded.mobileprovision", "CodeResources"]

    static func category(of path: String, executable: String?) -> SizeCategory {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard let first = parts.first.map(String.init) else { return .resources }
        if parts.count > 1, let container = containers[first] { return container }
        if signatureFiles.contains(first) { return .codeSignature }
        if parts.count == 1 {
            if first == executable { return .executable }
            if first.hasSuffix(".car") { return .assetCatalogs }
            return .resources
        }
        if first.hasSuffix(".lproj") { return .localizations }
        return .resources
    }

    /// The item a file is reported under: the top-level file or folder, or for containers such
    /// as `Frameworks/`, the framework, dylib or extension inside it.
    static func component(of path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard let first = parts.first else { return path }
        if parts.count > 2, containers[String(first)] != nil {
            return "\(first)/\(parts[1])"
        }
        if parts.count == 2, containers[String(first)] != nil {
            return path
        }
        return String(first)
    }

    /// The language of a file inside an `.lproj` folder anywhere in the bundle: `en` for
    /// `en.lproj/Main.strings`, `Base` for `Base.lproj`.
    static func language(of path: String) -> String? {
        for part in path.split(separator: "/").dropLast() where part.hasSuffix(".lproj") && part.count > 6 {
            return String(part.dropLast(6))
        }
        return nil
    }
}
