import Foundation
import Testing
@testable import SizeLedgerKit

@Suite struct ZipArchiveTests {
    @Test func listsEntriesWithSizesAndKinds() throws {
        let archive = try ZipArchive(url: Fixtures.archive("kinds.zip"))
        #expect(archive.entries.map(\.path) == ["Payload/", "Payload/Text.txt", "Payload/Noise.bin", "Payload/Link"])

        let directory = archive.entries[0]
        #expect(directory.isDirectory)

        let text = archive.entries[1]
        #expect(text.method == ZipArchive.deflateMethod)
        #expect(text.uncompressedSize == 5_000)
        #expect(text.compressedSize < text.uncompressedSize)

        let noise = archive.entries[2]
        #expect(noise.method == ZipArchive.storedMethod)
        #expect(noise.compressedSize == 3_000)

        let link = archive.entries[3]
        #expect(link.isSymbolicLink)
        #expect(!link.isDirectory)
    }

    @Test func readsDeflatedAndStoredContents() throws {
        let archive = try ZipArchive(url: Fixtures.archive("kinds.zip"))
        let text = try archive.contents(of: archive.entries[1])
        #expect(text.count == 5_000)
        #expect(String(decoding: text.prefix(4), as: UTF8.self).allSatisfy { $0.isLetter || $0 == " " })

        let noise = try archive.contents(of: archive.entries[2])
        #expect(noise.count == 3_000)

        let link = try archive.contents(of: archive.entries[3])
        #expect(String(decoding: link, as: UTF8.self) == "Text.txt")
    }

    @Test func limitReturnsAPrefix() throws {
        let archive = try ZipArchive(url: Fixtures.archive("kinds.zip"))
        let full = try archive.contents(of: archive.entries[1])
        let head = try archive.contents(of: archive.entries[1], limit: 16)
        #expect(head == full.prefix(16))
        #expect(try archive.contents(of: archive.entries[2], limit: 10).count == 10)
    }

    @Test func readsZip64Fields() throws {
        var builder = ZipBuilder()
        builder.add("Payload/Big.bin", Data(repeating: 7, count: 300), zip64: true)
        builder.add("Payload/Small.txt", Data("hi".utf8))
        builder.zip64End = true
        let archive = try ZipArchive(data: builder.build())
        #expect(archive.entries.map(\.path) == ["Payload/Big.bin", "Payload/Small.txt"])
        #expect(archive.entries[0].uncompressedSize == 300)
        #expect(archive.entries[0].compressedSize == 300)
        #expect(try archive.contents(of: archive.entries[0]) == Data(repeating: 7, count: 300))
        #expect(try archive.contents(of: archive.entries[1]) == Data("hi".utf8))
    }

    @Test func findsTheEndRecordBehindAComment() throws {
        var builder = ZipBuilder()
        builder.add("a.txt", Data("a".utf8))
        builder.comment = Data(repeating: 0x20, count: 1_000)
        let archive = try ZipArchive(data: builder.build())
        #expect(archive.entries.map(\.path) == ["a.txt"])
    }

    @Test func decodesNamesThatAreNotUTF8AsLatin1() throws {
        var builder = ZipBuilder()
        builder.entries.append(.init(name: [0x63, 0x61, 0x66, 0xE9], contents: Data(), unixMode: nil, flags: 0))
        let archive = try ZipArchive(data: builder.build())
        #expect(archive.entries.first?.path == "café")
        #expect(archive.entries.first?.unixMode == nil)
    }

    @Test func rejectsFilesThatAreNotArchives() {
        #expect(throws: ZipError.notAZipArchive) {
            _ = try ZipArchive(data: Data(repeating: 0, count: 100))
        }
        #expect(throws: ZipError.notAZipArchive) {
            _ = try ZipArchive(data: Data("PK".utf8))
        }
    }

    @Test func rejectsADirectoryOutsideTheFile() {
        var builder = ZipBuilder()
        builder.add("a.txt", Data("a".utf8))
        var data = builder.build()
        // Point the central directory offset (end record + 16) past the end of the file.
        let end = data.count - 22
        data.replaceSubrange((end + 16)..<(end + 20), with: le32(0x00FF_FFFF))
        #expect(throws: ZipError.self) {
            _ = try ZipArchive(data: data)
        }
    }

    @Test func refusesEncryptedAndUnknownMethods() throws {
        var builder = ZipBuilder()
        builder.entries.append(.init(name: Array("secret".utf8), contents: Data("x".utf8), unixMode: nil, flags: 1))
        builder.entries.append(.init(name: Array("lzma".utf8), contents: Data("x".utf8), unixMode: nil, method: 14))
        let archive = try ZipArchive(data: builder.build())
        #expect(throws: ZipError.encrypted("secret")) {
            _ = try archive.contents(of: archive.entries[0])
        }
        #expect(throws: ZipError.unsupportedMethod(14, "lzma")) {
            _ = try archive.contents(of: archive.entries[1])
        }
        // Listing still works: sizes come from the central directory.
        #expect(archive.entries.map(\.uncompressedSize) == [1, 1])
    }
}
