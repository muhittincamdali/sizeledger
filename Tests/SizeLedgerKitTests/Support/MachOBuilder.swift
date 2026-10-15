import Foundation

/// Writes minimal Mach-O files: a header, segment load commands with sections, an optional code
/// signature command, padded to a given size. Enough for the parser; nothing that would run.
struct MachOBuilder {
    struct Section {
        var name: String
        var size: UInt64
    }

    struct Segment {
        var name: String
        var fileSize: UInt64
        var sections: [Section] = []
    }

    var cpuType: UInt32 = 0x0100_000C
    var cpuSubtype: UInt32 = 0
    var fileType: UInt32 = 2
    var is64 = true
    var segments: [Segment] = []
    var codeSignatureSize: UInt32?
    var totalSize = 4_096

    func build() -> Data {
        var commands = Data()
        var count: UInt32 = 0
        for segment in segments {
            count += 1
            let sectionSize = is64 ? 80 : 68
            let commandSize = (is64 ? 72 : 56) + segment.sections.count * sectionSize
            commands.append(le32(is64 ? 0x19 : 0x1))
            commands.append(le32(UInt32(commandSize)))
            commands.append(name16(segment.name))
            if is64 {
                commands.append(le64(0)) // vmaddr
                commands.append(le64(segment.fileSize)) // vmsize
                commands.append(le64(0)) // fileoff
                commands.append(le64(segment.fileSize))
            } else {
                commands.append(le32(0))
                commands.append(le32(UInt32(segment.fileSize)))
                commands.append(le32(0))
                commands.append(le32(UInt32(segment.fileSize)))
            }
            commands.append(le32(7)) // maxprot
            commands.append(le32(5)) // initprot
            commands.append(le32(UInt32(segment.sections.count)))
            commands.append(le32(0)) // flags
            for section in segment.sections {
                commands.append(name16(section.name))
                commands.append(name16(segment.name))
                if is64 {
                    commands.append(le64(0))
                    commands.append(le64(section.size))
                } else {
                    commands.append(le32(0))
                    commands.append(le32(UInt32(section.size)))
                }
                commands.append(Data(count: is64 ? 32 : 28))
            }
        }
        if let codeSignatureSize {
            count += 1
            commands.append(le32(0x1D))
            commands.append(le32(16))
            commands.append(le32(0))
            commands.append(le32(codeSignatureSize))
        }
        var out = Data()
        out.append(le32(is64 ? 0xFEED_FACF : 0xFEED_FACE))
        out.append(le32(cpuType))
        out.append(le32(cpuSubtype))
        out.append(le32(fileType))
        out.append(le32(count))
        out.append(le32(UInt32(commands.count)))
        out.append(le32(0)) // flags
        if is64 { out.append(le32(0)) } // reserved
        out.append(commands)
        if out.count < totalSize { out.append(Data(count: totalSize - out.count)) }
        return out
    }

    /// A universal binary with the given slices, each aligned to `alignment` bytes.
    static func fat(_ slices: [MachOBuilder], is64: Bool = false, alignment: Int = 4_096) -> Data {
        let headerSize = 8 + slices.count * (is64 ? 32 : 20)
        var offsets: [Int] = []
        var position = (headerSize + alignment - 1) / alignment * alignment
        let bodies = slices.map { $0.build() }
        for body in bodies {
            offsets.append(position)
            position = (position + body.count + alignment - 1) / alignment * alignment
        }
        var out = Data()
        out.append(be32(is64 ? 0xCAFE_BABF : 0xCAFE_BABE))
        out.append(be32(UInt32(slices.count)))
        for (index, slice) in slices.enumerated() {
            out.append(be32(slice.cpuType))
            out.append(be32(slice.cpuSubtype))
            if is64 {
                out.append(be64(UInt64(offsets[index])))
                out.append(be64(UInt64(bodies[index].count)))
                out.append(be32(12))
                out.append(be32(0))
            } else {
                out.append(be32(UInt32(offsets[index])))
                out.append(be32(UInt32(bodies[index].count)))
                out.append(be32(12))
            }
        }
        for (index, body) in bodies.enumerated() {
            out.append(Data(count: offsets[index] - out.count))
            out.append(body)
        }
        return out
    }

    private func name16(_ name: String) -> Data {
        var bytes = Data(name.utf8.prefix(16))
        bytes.append(Data(count: 16 - bytes.count))
        return bytes
    }
}
