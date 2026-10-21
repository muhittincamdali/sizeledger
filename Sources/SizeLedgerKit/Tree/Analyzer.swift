import Foundation

extension SizeLedger {
    /// Measures an `.app` bundle folder, an `.ipa` or an `.xcarchive`.
    ///
    /// Nothing is extracted to disk and nothing is executed: sizes come from the file system or
    /// the archive's directory, and only Info.plist and Mach-O headers are read.
    ///
    /// - Throws: ``InputError`` when the path is missing, of an unsupported kind, or contains no
    ///   app or several apps, or when it passes one of `limits`. A `limits.maxDepth` above
    ///   ``AnalysisLimits/deepestAllowed`` counts as that ceiling.
    public static func analyze(_ url: URL, limits: AnalysisLimits = .default) throws -> SizeReport {
        let source = try InputLocator.open(url, limits: limits.honoured)
        return Analyzer(source: source).report(inputName: url.lastPathComponent)
    }
}

/// Turns the files of one bundle into a ``SizeReport``.
struct Analyzer {
    let source: any BundleSource

    /// Info.plist files are a few kilobytes; anything far larger is not one worth parsing.
    static let infoPlistLimit = 4 << 20
    /// The smallest Mach-O file worth looking at: a 64-bit header is 32 bytes.
    static let smallestBinary: UInt64 = 32

    func report(inputName: String) -> SizeReport {
        var notes: [String] = []
        let info = readInfo(notes: &notes)

        var total = Tally()
        var categories: [SizeCategory: Tally] = [:]
        // Keyed by the stored bytes (see BundlePath), so NFC and NFD spellings of a name stay
        // apart, and so do a Latin-1 name and the UTF-8 name it reads as. The decoded path has
        // the same components as the stored one, so a component count or index found on the
        // text picks the matching stored bytes.
        var components: [PathKey: (path: String, category: SizeCategory, tally: Tally)] = [:]
        var languages: [PathKey: (language: String, tally: Tally)] = [:]
        for entry in source.entries {
            let category = Classifier.category(of: entry.path, executable: info.executable)
            total.add(entry)
            categories[category, default: Tally()].add(entry)
            let component = Classifier.component(of: entry.path)
            let componentKey = entry.key.leading(BundlePath.components(of: component).count)
            components[componentKey, default: (component, category, Tally())].tally.add(entry)
            let parts = BundlePath.components(of: entry.path)
            if let index = Classifier.languageFolder(in: parts) {
                let language = BundlePath.droppingSuffix(Classifier.lprojSuffix, from: parts[index])
                languages[entry.key.component(at: index), default: (language, Tally())].tally.add(entry)
            }
        }

        let binaries = readBinaries(notes: &notes)
        addReadingNotes(info: info, binaries: binaries, notes: &notes)

        return SizeReport(
            schemaVersion: SizeReport.currentSchemaVersion,
            tool: .init(name: "sizeledger", version: SizeLedger.version),
            input: .init(name: inputName, kind: source.kind, bundle: source.bundleName, archiveBytes: source.archiveBytes),
            app: info,
            totals: .init(files: total.files, bytes: total.bytes, installBytes: total.installBytes, compressedBytes: total.compressedBytes),
            categories: categories
                .map { .init(category: $0.key, files: $0.value.files, bytes: $0.value.bytes, installBytes: $0.value.installBytes, compressedBytes: $0.value.compressedBytes) }
                .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.category < $1.category },
            components: components.values
                .map { .init(path: $0.path, category: $0.category, files: $0.tally.files, bytes: $0.tally.bytes, installBytes: $0.tally.installBytes, compressedBytes: $0.tally.compressedBytes) }
                .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) },
            languages: languages.values
                .map { .init(language: $0.language, files: $0.tally.files, bytes: $0.tally.bytes, installBytes: $0.tally.installBytes, compressedBytes: $0.tally.compressedBytes) }
                .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.language.utf8.lexicographicallyPrecedes($1.language.utf8) },
            binaries: binaries,
            outsideBundle: source.outsideEntries.map { .init(path: $0.path, bytes: $0.bytes, compressedBytes: $0.compressedBytes) },
            notes: notes,
            tree: TreeBuilder.build(rootName: source.bundleName, entries: source.entries) {
                Classifier.category(of: $0.path, executable: info.executable)
            }
        )
    }

    private func readInfo(notes: inout [String]) -> AppInfo {
        let unknown = "the app's name, version and main executable are unknown, so the executable is counted under other resources."
        guard let plist = source.entries.first(where: { BundlePath.same($0.path, "Info.plist") }) else {
            notes.append("No Info.plist at the top of \(source.bundleName): \(unknown)")
            return AppInfo()
        }
        guard !plist.isSymbolicLink else {
            notes.append("Info.plist at the top of \(source.bundleName) is a symbolic link, and links are not followed: \(unknown)")
            return AppInfo()
        }
        guard let data = try? source.contents(of: plist, limit: Self.infoPlistLimit),
              let info = AppInfo.parse(data)
        else {
            notes.append("Info.plist could not be read as a property list: the app's name, version and main executable are unknown.")
            return AppInfo()
        }
        return info
    }

    private func readBinaries(notes: inout [String]) -> [SizeReport.Binary] {
        var binaries: [SizeReport.Binary] = []
        for entry in source.entries where !entry.isSymbolicLink && entry.bytes >= Self.smallestBinary {
            guard let prefix = try? source.contents(of: entry, limit: 4), MachO.format(of: prefix) != nil else {
                continue
            }
            do {
                let slices = try MachO.slices(fileSize: entry.bytes) { ranges in
                    try source.contents(of: entry, ranges: ranges)
                }
                binaries.append(.init(path: entry.path, bytes: entry.bytes, slices: slices))
            } catch {
                notes.append("\(entry.path) starts like a Mach-O file but its headers could not be read (\(error)); its size is counted, its architectures are not.")
            }
        }
        return binaries.sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
    }

    private func addReadingNotes(info: AppInfo, binaries: [SizeReport.Binary], notes: inout [String]) {
        if info.isSimulatorBuild {
            notes.append("Simulator build (\(info.platform ?? "simulator")): it has no App Store thinning or encryption, and its binaries are built for the simulator, so a device build of the same app differs in size.")
        }
        let universal = binaries.filter { $0.slices.count > 1 }
        if !universal.isEmpty {
            let count = universal.count == 1 ? "1 binary contains" : "\(universal.count) binaries contain"
            notes.append("\(count) more than one architecture. Sizes count every slice; a device keeps one, so after App Store thinning these binaries are smaller.")
        }
        let notUTF8 = (source.entries + source.outsideEntries).filter { !BundlePath.isUTF8($0.key.bytes) }.count
        if notUTF8 > 0 {
            let count = notUTF8 == 1 ? "1 file has a name" : "\(notUTF8) files have names"
            notes.append("\(count) that \(notUTF8 == 1 ? "is" : "are") not valid UTF-8, shown read as Latin-1. Files are told apart by their stored bytes, so two rows can read the same and still be different files.")
        }
        if !source.outsideEntries.isEmpty {
            let count = source.outsideEntries.count == 1 ? "1 file" : "\(source.outsideEntries.count) files"
            notes.append("\(count) in the .ipa \(source.outsideEntries.count == 1 ? "is" : "are") outside Payload/\(source.bundleName) and not part of the totals (see outsideBundle).")
        }
        if info.isAppClip {
            notes.append("This bundle is an App Clip. App Store Connect checks its thinned, uncompressed size against the App Clip size limit; the install estimate here is the closest local number.")
        }
    }
}
