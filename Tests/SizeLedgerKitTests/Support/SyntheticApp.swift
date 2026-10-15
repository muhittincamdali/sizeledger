import Foundation

/// A small app bundle with one file of every kind the classifiers know, written as a folder and
/// as an .ipa with the same files.
enum SyntheticApp {
    static func files() throws -> [(path: String, data: Data)] {
        let info: [String: Any] = [
            "CFBundleName": "Shop",
            "CFBundleIdentifier": "com.example.shop",
            "CFBundleShortVersionString": "1.2",
            "CFBundleVersion": "34",
            "CFBundleExecutable": "Shop",
            "MinimumOSVersion": "17.0",
            "DTPlatformName": "iphoneos",
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
        let executable = MachOBuilder(segments: [
            .init(name: "__TEXT", fileSize: 8_192, sections: [.init(name: "__swift5_types", size: 24)]),
            .init(name: "__LINKEDIT", fileSize: 4_096),
        ], codeSignatureSize: 512, totalSize: 12_288)
        let thin = executable.build()
        let kit = MachOBuilder.fat([
            MachOBuilder(fileType: 6, segments: [.init(name: "__TEXT", fileSize: 4_096)]),
            MachOBuilder(cpuType: 0x0100_0007, fileType: 6, segments: [.init(name: "__TEXT", fileSize: 4_096)]),
        ])
        return [
            ("Info.plist", plist),
            ("Shop", thin),
            ("Frameworks/Kit.framework/Kit", kit),
            ("Frameworks/Kit.framework/Info.plist", Data(repeating: 1, count: 600)),
            ("Frameworks/Kit.framework/de.lproj/Kit.strings", Data(repeating: 2, count: 300)),
            ("en.lproj/Localizable.strings", Data(repeating: 3, count: 5_000)),
            ("de.lproj/Localizable.strings", Data(repeating: 4, count: 5_500)),
            ("Base.lproj/LaunchScreen.storyboardc/Info.plist", Data(repeating: 5, count: 250)),
            ("Assets.car", Data(repeating: 6, count: 20_000)),
            ("_CodeSignature/CodeResources", Data(repeating: 7, count: 3_000)),
            ("catalog.json", Data(repeating: 8, count: 1)),
            ("Empty.txt", Data()),
        ]
    }

    static func folder(in temp: TemporaryDirectory) throws -> URL {
        for file in try files() {
            try temp.file("Shop.app/\(file.path)", contents: file.data)
        }
        return temp.url.appendingPathComponent("Shop.app")
    }

    static func ipa(in temp: TemporaryDirectory, extra: [(String, Data)] = []) throws -> URL {
        var builder = ZipBuilder()
        builder.add("Payload/", mode: 0o040755)
        builder.add("Payload/Shop.app/", mode: 0o040755)
        for file in try files() {
            builder.add("Payload/Shop.app/\(file.path)", file.data)
        }
        for (path, data) in extra {
            builder.add(path, data)
        }
        return try temp.file("Shop.ipa", contents: builder.build())
    }
}
