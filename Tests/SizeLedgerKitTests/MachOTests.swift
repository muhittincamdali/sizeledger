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
        try MachO.slices(fileSize: UInt64(data.count)) { limit in data.prefix(limit) }
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

    @Test func readsOnlyAsFarAsTheHeadersReach() throws {
        let data = MachOBuilder.fat([Self.app, Self.app])
        var limits: [Int] = []
        _ = try MachO.slices(fileSize: UInt64(data.count)) { limit in
            limits.append(limit)
            return data.prefix(limit)
        }
        // The second slice starts at 32,768; its load commands end well before the file does.
        #expect(limits.max()! < data.count)
        #expect(limits.max()! > 32_768)
    }

    @Test func rejectsAJavaClassFile() {
        // Magic 0xCAFEBABE followed by class file version 52.0.
        let data = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x34]) + Data(count: 100)
        #expect(throws: MachO.ParseError.notMachO) { _ = try Self.slices(data) }
    }

    @Test func rejectsASliceBeyondTheFile() {
        let data = MachOBuilder.fat([Self.app])
        #expect(throws: MachO.ParseError.self) {
            _ = try MachO.slices(fileSize: 5_000) { limit in data.prefix(limit) }
        }
    }

    @Test func rejectsTruncatedLoadCommands() {
        let data = Self.app.build().prefix(100)
        #expect(throws: MachO.ParseError.truncated) { _ = try Self.slices(data) }
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
}
