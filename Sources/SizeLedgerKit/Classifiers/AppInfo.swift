import Foundation

/// What the app's Info.plist says about it. Every field is optional: a bundle without an
/// Info.plist, or with an unreadable one, is still measured.
public struct AppInfo: Codable, Equatable, Sendable {
    /// `CFBundleDisplayName`, or `CFBundleName` when there is no display name.
    public var name: String?
    /// `CFBundleIdentifier`.
    public var bundleIdentifier: String?
    /// `CFBundleShortVersionString`.
    public var version: String?
    /// `CFBundleVersion`.
    public var build: String?
    /// `CFBundleExecutable`: the main binary's file name.
    public var executable: String?
    /// `MinimumOSVersion`.
    public var minimumOSVersion: String?
    /// `DTPlatformName`: the SDK the app was built with, such as `iphoneos` or `iphonesimulator`.
    public var platform: String?
    /// True when the bundle is an App Clip (its Info.plist has an `NSAppClip` dictionary).
    public var isAppClip: Bool

    /// Creates app information; every field defaults to unknown.
    public init(
        name: String? = nil,
        bundleIdentifier: String? = nil,
        version: String? = nil,
        build: String? = nil,
        executable: String? = nil,
        minimumOSVersion: String? = nil,
        platform: String? = nil,
        isAppClip: Bool = false
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.build = build
        self.executable = executable
        self.minimumOSVersion = minimumOSVersion
        self.platform = platform
        self.isAppClip = isAppClip
    }

    /// True for builds made for a simulator, which App Store thinning never sees.
    public var isSimulatorBuild: Bool {
        platform?.hasSuffix("simulator") == true
    }

    /// Reads an XML or binary property list. Returns nil when it is not a dictionary.
    static func parse(_ data: Data) -> AppInfo? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any]
        else { return nil }
        func string(_ key: String) -> String? {
            dictionary[key] as? String
        }
        return AppInfo(
            name: string("CFBundleDisplayName") ?? string("CFBundleName"),
            bundleIdentifier: string("CFBundleIdentifier"),
            version: string("CFBundleShortVersionString"),
            build: string("CFBundleVersion"),
            executable: string("CFBundleExecutable"),
            minimumOSVersion: string("MinimumOSVersion"),
            platform: string("DTPlatformName"),
            isAppClip: dictionary["NSAppClip"] is [String: Any]
        )
    }
}
