import Foundation
import Testing
@testable import SizeLedgerKit

@Suite struct MachOTests {
    static let app = MachOBuilder(
        segments: [
            .init(name: "__PAGEZERO", fileSize: 0),
            .init(name: "__TEXT", fileSize: 16_384, sections: [
                .init(name: "__text", size: 9_000),
                .init(name: "__swift5_typeref", size: 120),
                .init(name: "__swift5_types", size: 40),
            ]),
            .init(name: "__DATA_CONST", fileSize: 4_096, sections: [.init(name: "__swift5_protos", size: 8)]),
            .init(name: "__LINKEDIT", fileSize: 8_192),
        ],
        codeSignatureSize: 2_345,
        totalSize: 28_672
    )

    static func slices(_ data: Data) throws -> [MachOSlice] {
        try MachO.slices(fileSize: UInt64(data.count)) { ranges in read(data, ranges) }
    }

    /// The bytes of `data` in each range, cut short at its end, as a bundle source returns them.
    static func read(_ data: Data, _ ranges: [Range<Int>]) -> [Data] {
        ranges.map { range in data[min(range.lowerBound, data.count)..<min(range.upperBound, data.count)] }
    }

    @Test func recognizesMagicNumbers() {
        #expect(MachO.format(of: Data([0xCF, 0xFA, 0xED, 0xFE])) == .thin)
        #expect(MachO.format(of: Data([0xCE, 0xFA, 0xED, 0xFE])) == .thin)
        #expect(MachO.format(of: Data([0xCA, 0xFE, 0xBA, 0xBE])) == .fat(is64: false))
        #expect(MachO.format(of: Data([0xCA, 0xFE, 0xBA, 0xBF])) == .fat(is64: true))
        #expect(MachO.format(of: Data("PK\u{3}\u{4}".utf8)) == nil)
        #expect(MachO.format(of: Data([0xCF, 0xFA])) == nil)
    }

    @Test func readsAThinBinary() throws {
        let slices = try Self.slices(Self.app.build())
        #expect(slices.count == 1)
        let slice = try #require(slices.first)
        #expect(slice.architecture == "arm64")
        #expect(slice.fileType == "executable")
        #expect(slice.offset == 0)
        #expect(slice.bytes == 28_672)
        #expect(slice.segments.map(\.name) == ["__TEXT", "__DATA_CONST", "__LINKEDIT"])
        #expect(slice.segments.map(\.bytes) == [16_384, 4_096, 8_192])
        #expect(slice.swiftMetadataBytes == 168)
        #expect(slice.codeSignatureBytes == 2_345)
    }

    @Test func readsA32BitBinary() throws {
        var builder = MachOBuilder(cpuType: 12, cpuSubtype: 9, fileType: 6, is64: false)
        builder.segments = [.init(name: "__TEXT", fileSize: 4_096, sections: [.init(name: "__swift5_fieldmd", size: 64)])]
        let slice = try #require(try Self.slices(builder.build()).first)
        #expect(slice.architecture == "armv7")
        #expect(slice.fileType == "dylib")
        #expect(slice.swiftMetadataBytes == 64)
        #expect(slice.segments == [MachOSegment(name: "__TEXT", bytes: 4_096)])
    }

    @Test("reads every slice of a universal binary", arguments: [false, true])
    func readsAUniversalBinary(is64: Bool) throws {
        var intel = Self.app
        intel.cpuType = 0x0100_0007
        intel.cpuSubtype = 3
        var arm64e = Self.app
        arm64e.cpuSubtype = 0x8000_0002
        let data = MachOBuilder.fat([Self.app, intel, arm64e], is64: is64)
        let slices = try Self.slices(data)
        #expect(slices.map(\.architecture) == ["arm64", "x86_64", "arm64e"])
        #expect(slices.map(\.bytes) == [28_672, 28_672, 28_672])
        #expect(slices.map(\.offset) == [4_096, 32_768, 61_440])
        #expect(slices.allSatisfy { $0.swiftMetadataBytes == 168 })
    }

    @Test func readsOnlyTheHeaders() throws {
        let data = MachOBuilder.fat([Self.app, Self.app])
        var requests: [[Range<Int>]] = []
        _ = try MachO.slices(fileSize: UInt64(data.count)) { ranges in
            requests.append(ranges)
            return Self.read(data, ranges)
        }
        // The fat table, then the start of both slices (at 4,096 and 32,768) in one request.
        #expect(requests == [[0..<4_096], [4_096..<8_192, 32_768..<36_864]])
    }

    @Test func readsLongLoadCommandsAsFarAsTheyReach() throws {
        var builder = Self.app
        builder.segments += (0..<60).map { .init(name: "__SEG\($0)", fileSize: 16) }
        builder.totalSize = 65_536
        let data = builder.build()
        var requests: [[Range<Int>]] = []
        let slices = try MachO.slices(fileSize: UInt64(data.count)) { ranges in
            requests.append(ranges)
            return Self.read(data, ranges)
        }
        #expect(slices.first?.segments.count == 63)
        let commandEnd = 32 + Int(try ByteReader(data).uint32LE(at: 20))
        #expect(commandEnd > 4_096)
        #expect(requests == [[0..<4_096], [0..<commandEnd]])
    }

    @Test func keepsReadsSmallWhenAFatHeaderPointsFarIntoTheFile() throws {
        // A universal binary whose only slice claims to start 1 GB in, as in a crafted .ipa where
        // the gap is a few kilobytes of DEFLATE data that decompresses to zeros.
        let gigabyte = 1 << 30
        var head = Data([0xCA, 0xFE, 0xBA, 0xBE]) + be32(1)
        head += be32(0x0100_000C) + be32(0) + be32(UInt32(gigabyte)) + be32(4_096) + be32(12)
        var requests: [[Range<Int>]] = []
        #expect(throws: MachO.ParseError.self) {
            _ = try MachO.slices(fileSize: UInt64(gigabyte + 4_096)) { ranges in
                requests.append(ranges)
                // Everything past the fat table reads as zeros, so the slice has no Mach-O magic.
                return ranges.map { $0.lowerBound == 0 ? head : Data(count: $0.count) }
            }
        }
        #expect(requests == [[0..<4_096], [gigabyte..<(gigabyte + 4_096)]])
    }

    @Test func refusesSliceRangesThatOverflow() {
        var head = Data([0xCA, 0xFE, 0xBA, 0xBF]) + be32(1)
        head += be32(0x0100_000C) + be32(0) + be64(UInt64.max - 10) + be64(4_096) + be32(12) + be32(0)
        #expect(throws: MachO.ParseError.malformed("slice 1 ends past the end of the file")) {
            _ = try MachO.slices(fileSize: 1 << 20) { ranges in Self.read(head, ranges) }
        }
    }

    @Test func rejectsAJavaClassFile() {
        // Magic 0xCAFEBABE followed by class file version 52.0.
        let data = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x34]) + Data(count: 100)
        #expect(throws: MachO.ParseError.notMachO) { _ = try Self.slices(data) }
    }

    @Test func rejectsASliceBeyondTheFile() {
        let data = MachOBuilder.fat([Self.app])
        #expect(throws: MachO.ParseError.self) {
            _ = try MachO.slices(fileSize: 5_000) { ranges in Self.read(data, ranges) }
        }
    }

    @Test func rejectsTruncatedLoadCommands() {
        // The directory says the file is complete, but its data ends after 100 bytes.
        let data = Self.app.build()
        #expect(throws: MachO.ParseError.truncated) {
            _ = try MachO.slices(fileSize: UInt64(data.count)) { ranges in Self.read(data.prefix(100), ranges) }
        }
    }

    @Test("refuses a header without a CPU type or file type", arguments: [(UInt32(0), UInt32(2)), (0x0100_000C, 0), (0, 0)])
    func refusesAnEmptyHeader(cpuType: UInt32, fileType: UInt32) {
        var builder = Self.app
        builder.cpuType = cpuType
        builder.fileType = fileType
        #expect(throws: MachO.ParseError.malformed("slice at offset 0 has no CPU type or file type")) {
            _ = try Self.slices(builder.build())
        }
        // In a universal binary the second slice starts at 32,768.
        #expect(throws: MachO.ParseError.malformed("slice at offset 32768 has no CPU type or file type")) {
            _ = try Self.slices(MachOBuilder.fat([Self.app, builder]))
        }
    }

    @Test func namesArchitectures() {
        #expect(MachO.architectureName(cpuType: 0x0200_000C, cpuSubtype: 1) == "arm64_32")
        #expect(MachO.architectureName(cpuType: 0x0100_0007, cpuSubtype: 8) == "x86_64h")
        #expect(MachO.architectureName(cpuType: 12, cpuSubtype: 12) == "armv7k")
        #expect(MachO.architectureName(cpuType: 7, cpuSubtype: 3) == "i386")
        #expect(MachO.architectureName(cpuType: 18, cpuSubtype: 0) == "cpu18")
        #expect(MachO.fileTypeName(8) == "bundle")
        #expect(MachO.fileTypeName(99) == "type99")
    }

    @Test func refusesLoadCommandSizesLargerThanTheSlice() {
        var data = Self.app.build()
        data.replaceSubrange(20..<24, with: le32(0x7FFF_FFFF))
        var largest = 0
        #expect(throws: MachO.ParseError.self) {
            _ = try MachO.slices(fileSize: UInt64(data.count)) { ranges in
                largest = max(largest, ranges.map(\.upperBound).max() ?? 0)
                return Self.read(data, ranges)
            }
        }
        // Nothing past the start of the file was asked for.
        #expect(largest <= 4_096)
    }
}
