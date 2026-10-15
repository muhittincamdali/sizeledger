import Foundation

extension SizeLedger {
    /// Measures an `.app` bundle folder, an `.ipa` or an `.xcarchive`.
    ///
    /// Nothing is extracted to disk and nothing is executed: sizes come from the file system or
    /// the archive's directory, and only Info.plist and Mach-O headers are read.
    ///
    /// - Throws: ``InputError`` when the path is missing, of an unsupported kind, or contains no
    ///   app or several apps.
    public static func analyze(_ url: URL, limits: AnalysisLimits = .default) throws -> SizeReport {
        let source = try InputLocator.open(url, limits: limits)
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
        var components: [String: (category: SizeCategory, tally: Tally)] = [:]
        var languages: [String: Tally] = [:]
        for entry in source.entries {
            let category = Classifier.category(of: entry.path, executable: info.executable)
            total.add(entry)
            categories[category, default: Tally()].add(entry)
            let component = Classifier.component(of: entry.path)
            components[component, default: (category, Tally())].tally.add(entry)
            if let language = Classifier.language(of: entry.path) {
                languages[language, default: Tally()].add(entry)
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
            components: components
                .map { .init(path: $0.key, category: $0.value.category, files: $0.value.tally.files, bytes: $0.value.tally.bytes, installBytes: $0.value.tally.installBytes, compressedBytes: $0.value.tally.compressedBytes) }
                .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) },
            languages: languages
                .map { .init(language: $0.key, files: $0.value.files, bytes: $0.value.bytes, installBytes: $0.value.installBytes, compressedBytes: $0.value.compressedBytes) }
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
        guard source.entries.contains(where: { $0.path == "Info.plist" && !$0.isSymbolicLink }) else {
            notes.append("No Info.plist at the top of \(source.bundleName): the app's name, version and main executable are unknown, so the executable is counted under other resources.")
            return AppInfo()
        }
        guard let data = try? source.contents(of: "Info.plist", limit: Self.infoPlistLimit),
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
            guard let prefix = try? source.contents(of: entry.path, limit: 4), MachO.format(of: prefix) != nil else {
                continue
            }
            do {
                let slices = try MachO.slices(fileSize: entry.bytes) { ranges in
                    try source.contents(of: entry.path, ranges: ranges)
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
        if !source.outsideEntries.isEmpty {
            let count = source.outsideEntries.count == 1 ? "1 file" : "\(source.outsideEntries.count) files"
            notes.append("\(count) in the .ipa \(source.outsideEntries.count == 1 ? "is" : "are") outside Payload/\(source.bundleName) and not part of the totals (see outsideBundle).")
        }
        if info.isAppClip {
            notes.append("This bundle is an App Clip. App Store Connect checks its thinned, uncompressed size against the App Clip size limit; the install estimate here is the closest local number.")
        }
    }
}
