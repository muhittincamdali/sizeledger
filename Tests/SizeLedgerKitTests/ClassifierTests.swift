import Foundation
import Testing
@testable import SizeLedgerKit

@Suite struct ClassifierTests {
    @Test("puts each file in one category", arguments: [
        ("Shop", SizeCategory.executable),
        ("Frameworks/Kit.framework/Kit", .frameworks),
        ("Frameworks/Kit.framework/Assets.car", .frameworks),
        ("Frameworks/libswiftCore.dylib", .frameworks),
        ("PlugIns/Widget.appex/Widget", .appExtensions),
        ("Extensions/Share.appex/Share", .appExtensions),
        ("AppClips/Clip.app/Clip", .appClips),
        ("Watch/Watch.app/Watch", .watchApp),
        ("en.lproj/Localizable.strings", .localizations),
        ("Base.lproj/Main.storyboardc/Info.plist", .localizations),
        ("Assets.car", .assetCatalogs),
        ("_CodeSignature/CodeResources", .codeSignature),
        ("embedded.mobileprovision", .codeSignature),
        ("SC_Info/Shop.sinf", .codeSignature),
        ("Info.plist", .resources),
        ("catalog.json", .resources),
        ("Settings.bundle/en.lproj/Root.strings", .resources),
        // A top-level file named like a container is not one.
        ("Frameworks", .resources),
        // Only the main executable counts as one; other binaries at the top are resources.
        ("Helper", .resources),
    ])
    func category(path: String, expected: SizeCategory) {
        #expect(Classifier.category(of: path, executable: "Shop") == expected)
    }

    @Test func noExecutableNameMeansNoExecutableCategory() {
        #expect(Classifier.category(of: "Shop", executable: nil) == .resources)
    }

    @Test("groups files into components", arguments: [
        ("Shop", "Shop"),
        ("Frameworks/Kit.framework/Kit", "Frameworks/Kit.framework"),
        ("Frameworks/Kit.framework/en.lproj/Kit.strings", "Frameworks/Kit.framework"),
        ("Frameworks/libswiftCore.dylib", "Frameworks/libswiftCore.dylib"),
        ("PlugIns/Widget.appex/Info.plist", "PlugIns/Widget.appex"),
        ("en.lproj/Localizable.strings", "en.lproj"),
        ("_CodeSignature/CodeResources", "_CodeSignature"),
        ("Settings.bundle/Root.plist", "Settings.bundle"),
    ])
    func component(path: String, expected: String) {
        #expect(Classifier.component(of: path) == expected)
    }

    @Test("finds the language of .lproj files anywhere", arguments: [
        ("en.lproj/Localizable.strings", "en"),
        ("pt-BR.lproj/Localizable.strings", "pt-BR"),
        ("Base.lproj/Main.storyboardc/Info.plist", "Base"),
        ("Frameworks/Kit.framework/zh-Hans.lproj/Kit.strings", "zh-Hans"),
        ("Settings.bundle/de.lproj/Root.strings", "de"),
    ])
    func language(path: String, expected: String) {
        #expect(Classifier.language(of: path) == expected)
    }

    @Test func filesOutsideLprojHaveNoLanguage() {
        #expect(Classifier.language(of: "Assets.car") == nil)
        // A file (not a folder) named like a localization folder.
        #expect(Classifier.language(of: "en.lproj") == nil)
        #expect(Classifier.language(of: ".lproj/x") == nil)
    }

    @Test func categoriesKeepTheirDeclaredOrder() {
        #expect(SizeCategory.allCases.sorted() == SizeCategory.allCases)
        #expect(SizeCategory.executable < SizeCategory.resources)
    }
}

@Suite struct AppInfoTests {
    static let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleName</key><string>Shop</string>
        <key>CFBundleDisplayName</key><string>Sample Shop</string>
        <key>CFBundleIdentifier</key><string>com.example.shop</string>
        <key>CFBundleShortVersionString</key><string>2.0</string>
        <key>CFBundleVersion</key><string>7</string>
        <key>CFBundleExecutable</key><string>Shop</string>
        <key>MinimumOSVersion</key><string>17.0</string>
        <key>DTPlatformName</key><string>iphonesimulator</string>
    </dict>
    </plist>
    """

    @Test func readsAnXMLPropertyList() throws {
        let info = try #require(AppInfo.parse(Data(Self.xml.utf8)))
        #expect(info == AppInfo(
            name: "Sample Shop",
            bundleIdentifier: "com.example.shop",
            version: "2.0",
            build: "7",
            executable: "Shop",
            minimumOSVersion: "17.0",
            platform: "iphonesimulator"
        ))
        #expect(info.isSimulatorBuild)
    }

    @Test func readsABinaryPropertyList() throws {
        let dictionary: [String: Any] = ["CFBundleName": "Clip", "NSAppClip": ["NSAppClipRequestEphemeralUserNotification": false], "DTPlatformName": "iphoneos"]
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
        let info = try #require(AppInfo.parse(data))
        #expect(info.name == "Clip")
        #expect(info.isAppClip)
        #expect(!info.isSimulatorBuild)
    }

    @Test func returnsNilForSomethingElse() {
        #expect(AppInfo.parse(Data("not a plist".utf8)) == nil)
        let array = try! PropertyListSerialization.data(fromPropertyList: ["a"], format: .xml, options: 0)
        #expect(AppInfo.parse(array) == nil)
    }
}
