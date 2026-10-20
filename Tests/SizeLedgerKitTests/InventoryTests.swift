import Foundation
import Testing
@testable import SizeLedgerKit

@Suite struct InventoryTests {
    @Test func walksAFolderAndKeepsLinksAsLinks() throws {
        let temp = try TemporaryDirectory()
        try temp.file("Demo.app/Demo", size: 5_000)
        try temp.file("Demo.app/Info.plist", size: 700)
        try temp.file("Demo.app/en.lproj/Localizable.strings", size: 120)
        try temp.file("Demo.app/Frameworks/Kit.framework/Kit", size: 9_000)
        try temp.directory("Demo.app/Empty")
        try temp.file("Elsewhere/huge.bin", size: 50_000)
        try temp.symlink("Demo.app/Shared", to: "../Elsewhere")

        let source = try DirectorySource(root: temp.url.appendingPathComponent("Demo.app"), kind: .app)
        #expect(source.bundleName == "Demo.app")
        #expect(source.entries.map(\.path) == [
            "Demo", "Frameworks/Kit.framework/Kit", "Info.plist", "Shared", "en.lproj/Localizable.strings",
        ])
        let link = try #require(source.entries.first { $0.path == "Shared" })
        #expect(link.isSymbolicLink)
        #expect(link.bytes == UInt64("../Elsewhere".utf8.count))
        #expect(source.entries.allSatisfy { $0.compressedBytes == nil })
        #expect(try source.contents(of: "Demo", limit: 10).count == 10)
        #expect(try source.contents(of: "Info.plist", limit: 10_000).count == 700)
        #expect(try source.contents(of: "Demo", ranges: [4_990..<5_010, 100..<104, 6_000..<6_010]).map(\.count) == [10, 4, 0])
    }

    @Test func folderWalkStopsAtTheDepthLimit() throws {
        let temp = try TemporaryDirectory()
        try temp.file("Two.app/a/b/f", size: 1)
        try temp.file("Three.app/a/b/c/f", size: 1)
        let limits = AnalysisLimits(maxDepth: 2)

        let two = try DirectorySource(root: temp.url.appendingPathComponent("Two.app"), kind: .app, limits: limits)
        #expect(two.entries.map(\.path) == ["a/b/f"])
        let error = try #require(throws: InputError.self) {
            _ = try DirectorySource(root: temp.url.appendingPathComponent("Three.app"), kind: .app, limits: limits)
        }
        guard case .unreadable(let path, let reason) = error else { Issue.record("\(error)"); return }
        #expect(path.hasSuffix("Three.app/a/b/c"))
        #expect(reason == "it is nested deeper than 2 folders (raise --max-depth)")
    }

    @Test func folderWalkStopsAtTheFileLimit() throws {
        let temp = try TemporaryDirectory()
        for name in ["a", "b", "c"] {
            try temp.file("Three.app/\(name)", size: 1)
        }
        try temp.symlink("Three.app/sub/link", to: "../a")
        let root = temp.url.appendingPathComponent("Three.app")

        // Folders do not count; files and links do.
        #expect(try DirectorySource(root: root, kind: .app, limits: AnalysisLimits(maxFiles: 4)).entries.count == 4)
        let error = try #require(throws: InputError.self) {
            _ = try DirectorySource(root: root, kind: .app, limits: AnalysisLimits(maxFiles: 3))
        }
        #expect(error == .unreadable(root.path, "it has more than 3 files (raise --max-files)"))
    }

    @Test func readsTheAppInsideAnIPA() throws {
        var builder = ZipBuilder()
        builder.add("Payload/", mode: 0o040755)
        builder.add("Payload/Demo.app/", mode: 0o040755)
        builder.add("Payload/Demo.app/Demo", Data(repeating: 1, count: 300))
        builder.add("Payload/Demo.app/Info.plist", Data("plist".utf8))
        builder.add("SwiftSupport/iphoneos/libswiftCore.dylib", Data(repeating: 2, count: 40))
        builder.add("iTunesMetadata.plist", Data("meta".utf8))
        let temp = try TemporaryDirectory()
        let url = try temp.file("Demo.ipa", contents: builder.build())

        let source = try IPASource(url: url)
        #expect(source.kind == .ipa)
        #expect(source.bundleName == "Demo.app")
        #expect(source.entries.map(\.path) == ["Demo", "Info.plist"])
        #expect(source.entries.map(\.bytes) == [300, 5])
        #expect(source.entries.map(\.compressedBytes) == [300, 5])
        #expect(source.outsideEntries.map(\.path) == ["SwiftSupport/iphoneos/libswiftCore.dylib", "iTunesMetadata.plist"])
        #expect(source.archiveBytes == UInt64(try Data(contentsOf: url).count))
        #expect(try source.contents(of: "Info.plist", limit: 100) == Data("plist".utf8))
        #expect(try source.contents(of: "Info.plist", ranges: [1..<3, 4..<9]) == [Data("li".utf8), Data("t".utf8)])
    }

    @Test func refusesAnIPAWithoutAnApp() throws {
        var builder = ZipBuilder()
        builder.add("Payload/readme.txt", Data("x".utf8))
        builder.add("Payload/Fake.app", Data("a file named like a bundle".utf8))
        let temp = try TemporaryDirectory()
        let url = try temp.file("Empty.ipa", contents: builder.build())
        #expect(throws: InputError.noApp("Empty.ipa")) { _ = try IPASource(url: url) }
    }

    @Test func refusesAnIPAWithTwoApps() throws {
        var builder = ZipBuilder()
        builder.add("Payload/B.app/B", Data("b".utf8))
        builder.add("Payload/A.app/A", Data("a".utf8))
        let temp = try TemporaryDirectory()
        let url = try temp.file("Two.ipa", contents: builder.build())
        #expect(throws: InputError.severalApps("Two.ipa", ["A.app", "B.app"])) { _ = try IPASource(url: url) }
    }

    @Test("refuses an .ipa with a .. path component", arguments: ["Payload/Demo.app/../escape.bin", "../Payload/Demo.app/x"])
    func refusesParentPathComponents(name: String) throws {
        var builder = ZipBuilder()
        builder.add("Payload/Demo.app/Demo", Data(repeating: 1, count: 300))
        builder.add(name, Data(repeating: 2, count: 500))
        let temp = try TemporaryDirectory()
        let url = try temp.file("Escape.ipa", contents: builder.build())
        let error = InputError.unreadable(url.path, "entry \(name) has a \"..\" path component")
        #expect(throws: error) { _ = try IPASource(url: url) }
        #expect(throws: error) { _ = try InputLocator.open(url) }
    }

    @Test func findsTheAppInAnXcodeArchive() throws {
        let temp = try TemporaryDirectory()
        try temp.file("Demo.xcarchive/Info.plist", size: 10)
        try temp.file("Demo.xcarchive/dSYMs/Demo.app.dSYM/Contents/Info.plist", size: 10)
        try temp.file("Demo.xcarchive/Products/Applications/Demo.app/Demo", size: 64)
        let source = try InputLocator.open(temp.url.appendingPathComponent("Demo.xcarchive"))
        #expect(source.kind == .xcarchive)
        #expect(source.bundleName == "Demo.app")
        #expect(source.entries.map(\.path) == ["Demo"])
    }

    @Test(
        "refuses an .xcarchive whose way to the app goes through a symbolic link",
        arguments: [
            ("Products", "../Elsewhere/Products"),
            ("Products/Applications", "../../Elsewhere/Products/Applications"),
            ("Products/Applications/Demo.app", "../../../Elsewhere/Products/Applications/Demo.app"),
        ]
    )
    func refusesLinksInsideAnXcodeArchive(link: String, destination: String) throws {
        let temp = try TemporaryDirectory()
        try temp.file("Elsewhere/Products/Applications/Demo.app/id_rsa", size: 10)
        try temp.file("Demo.xcarchive/Info.plist", size: 10)
        try temp.symlink("Demo.xcarchive/" + link, to: destination)
        // The link resolves, so following it would have measured the folder outside the archive.
        let linked = temp.url.appendingPathComponent("Demo.xcarchive/Products/Applications/Demo.app/id_rsa")
        #expect(FileManager.default.fileExists(atPath: linked.path))

        let expected = InputError.unreadable(
            temp.url.appendingPathComponent("Demo.xcarchive/" + link).path,
            "it is a symbolic link, and links inside an .xcarchive are not followed"
        )
        #expect(throws: expected) {
            _ = try InputLocator.open(temp.url.appendingPathComponent("Demo.xcarchive"))
        }
    }

    @Test func followsAnInputPathThatIsALink() throws {
        let temp = try TemporaryDirectory()
        try temp.file("Builds/Demo.app/Demo", size: 64)
        try temp.symlink("Latest.app", to: "Builds/Demo.app")
        let source = try InputLocator.open(temp.url.appendingPathComponent("Latest.app"))
        #expect(source.entries.map(\.path) == ["Demo"])
    }

    @Test func explainsInputsItCannotRead() throws {
        let temp = try TemporaryDirectory()
        try temp.directory("Plain")
        try temp.file("notes.txt", contents: Data("not an archive".utf8))
        try temp.directory("Empty.xcarchive/Products/Applications")

        #expect(throws: InputError.notFound(temp.url.appendingPathComponent("missing.ipa").path)) {
            _ = try InputLocator.open(temp.url.appendingPathComponent("missing.ipa"))
        }
        #expect(throws: InputError.unsupported(temp.url.appendingPathComponent("Plain").path)) {
            _ = try InputLocator.open(temp.url.appendingPathComponent("Plain"))
        }
        #expect(throws: InputError.unsupported(temp.url.appendingPathComponent("notes.txt").path)) {
            _ = try InputLocator.open(temp.url.appendingPathComponent("notes.txt"))
        }
        #expect(throws: InputError.noApp("Empty.xcarchive")) {
            _ = try InputLocator.open(temp.url.appendingPathComponent("Empty.xcarchive"))
        }
    }

    @Test func explainsAnIPAThatIsNotAWholeArchive() throws {
        let temp = try TemporaryDirectory()
        var builder = ZipBuilder()
        builder.add("Payload/A.app/A", Data(repeating: 1, count: 64))
        let whole = builder.build()
        try temp.file("Cut.ipa", contents: whole.prefix(whole.count / 2))
        try temp.file("Noise.ipa", contents: Data(repeating: 0x2C, count: 100))

        let cut = temp.url.appendingPathComponent("Cut.ipa")
        #expect(throws: InputError.unreadable(cut.path, ZipError.malformed("it has no end of central directory record; the file may be cut short").description)) {
            _ = try InputLocator.open(cut)
        }
        let noise = temp.url.appendingPathComponent("Noise.ipa")
        #expect(throws: InputError.unreadable(noise.path, "not a ZIP archive (an .ipa is one)")) {
            _ = try InputLocator.open(noise)
        }
    }

    @Test func messagesNameThePath() {
        #expect(InputError.notFound("a.ipa").description == "a.ipa does not exist")
        #expect(InputError.severalApps("x.ipa", ["A.app", "B.app"]).description.contains("A.app, B.app"))
    }

    @Test func messagesCutTheMiddleOfALongName() {
        let deep = "Payload/A.app/" + String(repeating: "a/", count: 5_000) + "file"
        let reason = "entry \(deep) is nested deeper than 64 folders (raise --max-depth)"
        let message = InputError.unreadable("Deep.ipa", reason).description
        #expect(message.unicodeScalars.count == Sanitize.longestMessage)
        #expect(message.hasPrefix("Deep.ipa cannot be read: entry Payload/A.app/a/"))
        #expect(message.hasSuffix("a/file is nested deeper than 64 folders (raise --max-depth)"))
        #expect(message.contains("…"))

        let zalgo = "A" + String(repeating: "\u{0301}", count: 10_000) + ".app"
        #expect(InputError.notFound(zalgo).description.unicodeScalars.count == Sanitize.longestMessage)
        #expect(InputError.notFound("a.ipa").description == "a.ipa does not exist")
    }

    @Test func messagesReplaceControlCharacters() {
        let name = "Payload/A.app/\u{1B}]0;title\u{07}\n.bin"
        #expect(ZipError.encrypted(name).description == "Payload/A.app/\u{FFFD}]0;title\u{FFFD}\u{FFFD}.bin is encrypted")
        let error = InputError.unreadable("x.ipa", ZipError.unsupportedMethod(14, name).description)
        #expect(!error.description.contains { $0.unicodeScalars.contains { $0.properties.generalCategory == .control } })
        #expect(InputError.notFound("\u{1B}[2J.ipa").description == "\u{FFFD}[2J.ipa does not exist")
    }
}
