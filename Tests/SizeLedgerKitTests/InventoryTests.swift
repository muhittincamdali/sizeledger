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

    @Test func messagesNameThePath() {
        #expect(InputError.notFound("a.ipa").description == "a.ipa does not exist")
        #expect(InputError.severalApps("x.ipa", ["A.app", "B.app"]).description.contains("A.app, B.app"))
    }
}
